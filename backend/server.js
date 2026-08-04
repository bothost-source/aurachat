const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const connectDB = require('./src/config/database');
const { setupSocketHandlers } = require('./src/services/socketService');
const { setupAIModeration } = require('./src/services/aiModerationService');
const authRoutes = require('./src/routes/auth');
const chatRoutes = require('./src/routes/chat');
const botRoutes = require('./src/routes/bot');
const moderationRoutes = require('./src/routes/moderation');
const userRoutes = require('./src/routes/users');
const { errorHandler } = require('./src/middleware/errorHandler');
const { requestLogger } = require('./src/middleware/logger');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: process.env.CLIENT_URL || "*",
    methods: ["GET", "POST"]
  }
});

// Security middleware
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { error: 'Too many requests, please try again later.' }
});
app.use('/api/', limiter);

// Stricter rate limit for auth
const authLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 5,
  message: { error: 'Too many auth attempts, please try again later.' }
});
app.use('/api/auth/login', authLimiter);

// Logging
app.use(requestLogger);

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    uptime: process.uptime()
  });
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/bot', botRoutes);
app.use('/api/moderation', moderationRoutes);
app.use('/api/user', userRoutes);

// Socket.IO setup
setupSocketHandlers(io);

// AI Moderation setup
setupAIModeration();

// ============================================================================
// PUSH NOTIFICATIONS - Listen for new messages and send FCM pushes
// ============================================================================
const admin = require('firebase-admin');

// Initialize Firebase Admin with service account
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    }),
  });
}

const db = admin.firestore();
const messaging = admin.messaging();

function startPushNotificationListener() {
  console.log('Starting push notification listener...');
  
  db.collectionGroup('messages')
    .where('sent_to_fcm', '==', false)
    .onSnapshot(async (snapshot) => {
      for (const change of snapshot.docChanges()) {
        if (change.type !== 'added') continue;
        
        const message = change.doc.data();
        const messageId = change.doc.id;
        const chatId = message.chat_id;
        const senderId = message.sender_id;
        
        if (!chatId || !senderId) continue;
        
        try {
          const chatDoc = await db.collection('chats').doc(chatId).get();
          if (!chatDoc.exists) continue;
          
          const chatData = chatDoc.data();
          const participants = chatData.participants || [];
          const chatType = chatData.type || 'direct';
          const chatName = chatData.name || 'AURA Chat';
          const recipients = participants.filter(id => id !== senderId);
          
          if (recipients.length === 0) continue;
          
          const senderDoc = await db.collection('users').doc(senderId).get();
          const senderName = senderDoc.exists 
            ? (senderDoc.data().username || 'Someone') 
            : 'Someone';
          
          let title, body;
          if (chatType === 'direct') {
            title = senderName;
            body = formatMessageBody(message);
          } else if (chatType === 'group') {
            title = chatName;
            body = `${senderName}: ${formatMessageBody(message)}`;
          } else {
            title = chatName;
            body = formatMessageBody(message);
          }
          
          const tokens = [];
          for (const userId of recipients) {
            const userDoc = await db.collection('users').doc(userId).get();
            if (!userDoc.exists) continue;
            
            const userData = userDoc.data();
            const token = userData?.fcmToken;
            if (!token) continue;
            
            const mutedChats = userData?.muted_chats || [];
            if (mutedChats.includes(chatId)) continue;
            
            tokens.push(token);
          }
          
          if (tokens.length === 0) continue;
          
          const sendPromises = tokens.map(token => 
            messaging.send({
              token: token,
              notification: { title, body },
              data: {
                chatId, messageId, senderId, senderName,
                chatType, chatName, type: 'chat_message',
              },
              android: {
                priority: 'high',
                notification: {
                  channelId: 'aura_chat_channel',
                  sound: 'default',
                  priority: 'high',
                },
              },
              apns: {
                payload: {
                  aps: {
                    alert: { title, body },
                    badge: 1,
                    sound: 'default',
                  },
                },
              },
            }).catch(err => {
              console.error('Failed to send to token:', token, err.message);
            })
          );
          
          await Promise.all(sendPromises);
          await change.doc.ref.update({ sent_to_fcm: true });
          
          console.log(`Push sent to ${tokens.length} users for chat ${chatId}`);
          
        } catch (error) {
          console.error('Push notification error:', error);
        }
      }
    });
}

function formatMessageBody(message) {
  const type = message.type || 'text';
  const content = message.content || '';
  
  switch (type) {
    case 'image': return '📷 Photo';
    case 'video': return '🎥 Video';
    case 'audio': case 'voice': return '🎙️ Voice message';
    case 'file': case 'document': return '📎 File';
    default: return content.length > 100 ? content.substring(0, 100) + '...' : content;
  }
}

startPushNotificationListener();

// Error handling
app.use(errorHandler);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

const PORT = process.env.PORT || 3000;

// Connect to database then start server
connectDB().then(() => {
  server.listen(PORT, () => {
    console.log(`
    ╔════════════════════════════════════════════════════╗
    ║                                                    ║
    ║     AURA CHAT Backend Server                       ║
    ║     Running on port ${PORT}                        ║
    ║     Environment: ${process.env.NODE_ENV || 'development'}                    ║
    ║                                                    ║
    ╚════════════════════════════════════════════════════╝
    `);
  });
}).catch(err => {
  console.error('Failed to connect to database:', err);
  process.exit(1);
});

module.exports = { app, server, io };

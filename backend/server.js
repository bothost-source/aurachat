const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

// ============================================================================
// INITIALIZE FIREBASE ADMIN FIRST — Before any routes
// ============================================================================
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    }),
  });
}

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
const emailVerificationRoutes = require('./src/routes/emailVerification');

const app = express();

// FIX: Trust proxy so rate limiting works correctly behind Render's proxy
app.set('trust proxy', 1);

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

// Health check for UptimeRobot (root path)
app.get('/', (req, res) => {
  res.status(200).json({ 
    status: 'ok', 
    message: 'AURA CHAT Backend is running',
    timestamp: new Date().toISOString()
  });
});

// Health check (detailed)
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    uptime: process.uptime()
  });
});

// API Routes
app.use('/api/auth', emailVerificationRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/bot', botRoutes);
app.use('/api/moderation', moderationRoutes);
app.use('/api/user', userRoutes);

// ============================================================================
// CLOUDINARY DELETE ENDPOINT - Delete old files when user changes profile pic
// ============================================================================
const cloudinary = require('cloudinary').v2;

cloudinary.config({
  cloud_name: 'dn2mwp1lc',
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET
});

app.post('/delete-cloudinary', async (req, res) => {
  try {
    const apiKey = req.headers['x-api-key'];
    if (apiKey !== process.env.BACKEND_API_KEY) {
      return res.status(401).json({ success: false, error: 'Unauthorized' });
    }

    const { public_id } = req.body;

    if (!public_id) {
      return res.status(400).json({ success: false, error: 'public_id required' });
    }

    const result = await cloudinary.uploader.destroy(public_id);

    if (result.result === 'ok') {
      res.json({ success: true, message: 'File deleted' });
    } else {
      res.json({ success: false, error: result.result });
    }
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ============================================================================
// Delete old avatar endpoint - called when group/channel/user changes photo
// ============================================================================
app.post('/delete-avatar', async (req, res) => {
  try {
    const apiKey = req.headers['x-api-key'];
    if (apiKey !== process.env.BACKEND_API_KEY) {
      return res.status(401).json({ success: false, error: 'Unauthorized' });
    }

    const { imageUrl } = req.body;

    if (!imageUrl || !imageUrl.includes('cloudinary.com')) {
      return res.status(400).json({ success: false, error: 'Valid Cloudinary URL required' });
    }

    const urlParts = imageUrl.split('/upload/');
    if (urlParts.length <= 1) {
      return res.status(400).json({ success: false, error: 'Invalid Cloudinary URL format' });
    }

    const afterUpload = urlParts[1];
    const pathParts = afterUpload.split('/');
    const startIndex = pathParts[0].startsWith('v') ? 1 : 0;
    const publicIdWithExt = pathParts.slice(startIndex).join('/');
    const publicId = publicIdWithExt.replace(/\.[^/.]+$/, '');

    if (!publicId) {
      return res.status(400).json({ success: false, error: 'Could not extract public_id' });
    }

    const result = await cloudinary.uploader.destroy(publicId);

    if (result.result === 'ok' || result.result === 'not found') {
      res.json({ success: true, message: 'Old avatar deleted', publicId });
    } else {
      res.json({ success: false, error: result.result, publicId });
    }
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Socket.IO setup
setupSocketHandlers(io);

// AI Moderation setup
setupAIModeration();

// ============================================================================
// PUSH NOTIFICATIONS - Listen for new messages and send FCM pushes
// ============================================================================
const db = admin.firestore();
const messaging = admin.messaging();

const processedMessages = new Set();
const PROCESSED_MAX_SIZE = 1000;

function startPushNotificationListener() {
  console.log('Starting push notification listener...');

  const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);

  db.collectionGroup('messages')
    .where('created_at', '>', admin.firestore.Timestamp.fromDate(fiveMinutesAgo))
    .orderBy('created_at', 'desc')
    .limit(50)
    .onSnapshot(async (snapshot) => {
      for (const change of snapshot.docChanges()) {
        if (change.type !== 'added') continue;

        const message = change.doc.data();
        const messageId = change.doc.id;

        if (processedMessages.has(messageId)) continue;
        processedMessages.add(messageId);

        if (processedMessages.size > PROCESSED_MAX_SIZE) {
          const iterator = processedMessages.values();
          processedMessages.delete(iterator.next().value);
        }

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
            if (!token) {
              console.log(`No FCM token for user ${userId}`);
              continue;
            }

            const mutedChats = userData?.muted_chats || [];
            if (mutedChats.includes(chatId)) continue;

            tokens.push(token);
          }

          if (tokens.length === 0) {
            console.log(`No valid tokens for chat ${chatId}`);
            continue;
          }

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
              if (err.code === 'messaging/registration-token-not-registered') {
                _removeInvalidToken(token);
              }
            })
          );

          await Promise.all(sendPromises);
          await change.doc.ref.update({ sent_to_fcm: true });
          console.log(`Push sent to ${tokens.length} users for chat ${chatId}`);

        } catch (error) {
          console.error('Push notification error:', error);
        }
      }
    }, (error) => {
      console.error('Push listener error:', error);
    });
}

async function _removeInvalidToken(token) {
  try {
    const usersSnapshot = await db.collection('users')
      .where('fcmToken', '==', token)
      .limit(1)
      .get();

    usersSnapshot.forEach(doc => {
      doc.ref.update({ fcmToken: null });
      console.log(`Removed invalid token for user ${doc.id}`);
    });
  } catch (e) {
    console.error('Error removing invalid token:', e);
  }
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

// ============================================================================
// CALL NOTIFICATIONS - Send FCM push when call signal is written to RTDB
// NEW: Watches call_signals/{userId} and sends high-priority FCM
// ============================================================================
function startCallNotificationListener() {
  console.log('Starting call notification listener...');

  const rtdb = admin.database();

  rtdb.ref('call_signals').on('child_added', async (userSnapshot) => {
    const userId = userSnapshot.key;
    const signals = userSnapshot.val();

    if (!signals) return;

    const signalKeys = Object.keys(signals);
    const latestSignalKey = signalKeys[signalKeys.length - 1];
    const signal = signals[latestSignalKey];

    if (signal.type !== 'incoming_call') return;
    if (signal._fcmSent) return;

    try {
      const userDoc = await db.collection('users').doc(userId).get();
      const fcmToken = userDoc.data()?.fcmToken;

      if (!fcmToken) {
        console.log('No FCM token for user', userId);
        return;
      }

      const message = {
        token: fcmToken,
        data: {
          type: 'call',
          call_id: signal.call_id,
          caller_id: signal.caller_id,
          caller_name: signal.caller_name || 'Unknown',
          caller_avatar: signal.caller_avatar || '',
          channel_name: signal.channel_name,
          is_video_call: String(signal.is_video_call),
        },
        android: {
          priority: 'high',
          notification: {
            channel_id: 'aura_call_channel',
            title: signal.is_video_call ? 'Incoming Video Call' : 'Incoming Voice Call',
            body: signal.caller_name || 'Unknown',
            sound: 'default',
            priority: 'max',
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: signal.is_video_call ? 'Incoming Video Call' : 'Incoming Voice Call',
                body: signal.caller_name || 'Unknown',
              },
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      await messaging.send(message);
      console.log('Call notification sent to', userId);

      await userSnapshot.ref.child(latestSignalKey).update({ _fcmSent: true });

    } catch (error) {
      console.error('Error sending call notification:', error);
    }
  });
}

startCallNotificationListener();

// ============================================================================
// MONTHLY AUTO-CLEANUP — Delete old media from Cloudinary
// ============================================================================
async function getActiveAvatarUrls() {
  const urls = new Set();

  const usersSnapshot = await db.collection('users').get();
  usersSnapshot.forEach(doc => {
    const avatar = doc.data().avatar_url;
    if (avatar && avatar.includes('cloudinary.com')) urls.add(avatar);
  });

  const chatsSnapshot = await db.collection('chats').get();
  chatsSnapshot.forEach(doc => {
    const avatar = doc.data().avatar_url;
    if (avatar && avatar.includes('cloudinary.com')) urls.add(avatar);
  });

  return urls;
}

function startMonthlyCleanup() {
  console.log('Starting monthly media cleanup scheduler...');

  setInterval(async () => {
    try {
      const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
      console.log(`[Cleanup] Running cleanup for media older than ${thirtyDaysAgo.toISOString()}`);

      const activeAvatarUrls = await getActiveAvatarUrls();
      console.log(`[Cleanup] Found ${activeAvatarUrls.size} active avatar URLs to protect`);

      const oldMessagesSnapshot = await db.collectionGroup('messages')
        .where('created_at', '<', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
        .where('media_url', '!=', null)
        .limit(50)
        .get();

      let deletedCount = 0;
      let errorCount = 0;
      let skippedCount = 0;

      for (const doc of oldMessagesSnapshot.docs) {
        const data = doc.data();
        const mediaUrl = data.media_url;

        if (mediaUrl && mediaUrl.includes('cloudinary.com')) {
          try {
            if (mediaUrl.includes('/permanent/')) {
              skippedCount++;
              console.log(`[Cleanup] SKIPPED permanent file: ${mediaUrl}`);
              continue;
            }

            if (activeAvatarUrls.has(mediaUrl)) {
              skippedCount++;
              console.log(`[Cleanup] SKIPPED active avatar: ${mediaUrl}`);
              continue;
            }

            const urlParts = mediaUrl.split('/upload/');
            if (urlParts.length > 1) {
              const afterUpload = urlParts[1];
              const pathParts = afterUpload.split('/');
              const startIndex = pathParts[0].startsWith('v') ? 1 : 0;
              const publicIdWithExt = pathParts.slice(startIndex).join('/');
              const publicId = publicIdWithExt.replace(/\.[^/.]+$/, '');

              if (publicId) {
                const result = await cloudinary.uploader.destroy(publicId);

                if (result.result === 'ok') {
                  await doc.ref.update({ 
                    media_url: null,
                    file_name: null,
                    file_size: null,
                    duration: null,
                    updated_at: admin.firestore.FieldValue.serverTimestamp(),
                  });
                  deletedCount++;
                  console.log(`[Cleanup] Deleted: ${publicId}`);
                } else {
                  console.log(`[Cleanup] Cloudinary result for ${publicId}: ${result.result}`);
                }
              }
            }
          } catch (e) {
            errorCount++;
            console.error(`[Cleanup] Failed to delete media: ${e.message}`);
          }
        }
      }

      console.log(`[Cleanup] Complete. Deleted: ${deletedCount}, Skipped: ${skippedCount}, Errors: ${errorCount}, Total scanned: ${oldMessagesSnapshot.docs.length}`);

    } catch (error) {
      console.error('[Cleanup] Monthly cleanup error:', error.message);
    }
  }, 20 * 24 * 60 * 60 * 1000);

  console.log('Monthly cleanup scheduled. Next run in 20 days.');
}

startMonthlyCleanup();

// Error handling
app.use(errorHandler);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

const PORT = process.env.PORT || 3000;

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

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
const userRoutes = require('./src/routes/user');
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
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: { error: 'Too many requests, please try again later.' }
});
app.use('/api/', limiter);

// Stricter rate limit for auth
const authLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
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
    ║     TARRIFIC CHAT Backend Server                 ║
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

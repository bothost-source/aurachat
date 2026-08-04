const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const router = express.Router();
const User = require('../models/user');
const { body, validationResult } = require('express-validator');

// Generate JWT
const generateToken = (userId) => {
  return jwt.sign({ userId }, process.env.JWT_SECRET || 'tarrific-secret-key', {
    expiresIn: '30d',
  });
};

// Register / Login with phone
router.post('/phone', [
  body('phoneNumber').isMobilePhone().withMessage('Valid phone number required'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { phoneNumber } = req.body;

    // Check if user exists
    let user = await User.findOne({ phoneNumber });

    if (!user) {
      // Create new user
      user = new User({
        phoneNumber,
        username: `user_${Date.now()}`,
        displayName: 'New User',
        status: 'online',
      });
      await user.save();
    }

    // Generate OTP (in production, send via SMS)
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    user.otp = otp;
    user.otpExpiry = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes
    await user.save();

    res.json({
      message: 'OTP sent successfully',
      otp, // Remove in production - for demo only
      userId: user._id,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Verify OTP
router.post('/verify-otp', [
  body('userId').notEmpty(),
  body('otp').isLength({ min: 6, max: 6 }),
], async (req, res) => {
  try {
    const { userId, otp } = req.body;

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    if (user.otp !== otp || user.otpExpiry < new Date()) {
      return res.status(400).json({ error: 'Invalid or expired OTP' });
    }

    // Clear OTP
    user.otp = null;
    user.otpExpiry = null;
    user.lastLogin = new Date();
    await user.save();

    // Generate token
    const token = generateToken(user._id);

    res.json({
      message: 'Login successful',
      token,
      user: {
        id: user._id,
        phoneNumber: user.phoneNumber,
        username: user.username,
        displayName: user.displayName,
        bio: user.bio,
        avatar: user.avatar,
        isVerified: user.verificationLevel !== 'none',
        verificationLevel: user.verificationLevel,
      },
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Setup profile
router.put('/profile', async (req, res) => {
  try {
    const { userId, displayName, username, bio } = req.body;

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Check username uniqueness
    if (username && username !== user.username) {
      const existing = await User.findOne({ username });
      if (existing) {
        return res.status(400).json({ error: 'Username already taken' });
      }
    }

    user.displayName = displayName || user.displayName;
    user.username = username || user.username;
    user.bio = bio || user.bio;

    await user.save();

    res.json({
      message: 'Profile updated',
      user: {
        id: user._id,
        displayName: user.displayName,
        username: user.username,
        bio: user.bio,
      },
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get current user
router.get('/me', async (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'tarrific-secret-key');
    const user = await User.findById(decoded.userId);

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({
      id: user._id,
      phoneNumber: user.phoneNumber,
      username: user.username,
      displayName: user.displayName,
      bio: user.bio,
      avatar: user.avatar,
      status: user.status,
      isVerified: user.verificationLevel !== 'none',
      verificationLevel: user.verificationLevel,
      privacy: user.privacy,
      createdAt: user.createdAt,
    });
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
  }
});

module.exports = router;

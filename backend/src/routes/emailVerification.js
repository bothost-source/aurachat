const express = require('express');
const router = express.Router();
const { Resend } = require('resend');

const resend = new Resend(process.env.RESEND_API_KEY);

// Store codes temporarily (in production use Redis or DB)
const verificationCodes = new Map();

// Send verification email
router.post('/send-email-verification', async (req, res) => {
  try {
    const { email, userId } = req.body;
    
    if (!email || !userId) {
      return res.status(400).json({ error: 'Email and userId required' });
    }

    // Generate 6-digit code
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    
    // Store code with expiry (15 minutes)
    verificationCodes.set(userId, {
      code,
      email,
      expiresAt: Date.now() + 15 * 60 * 1000
    });

    // Send email via Resend
    await resend.emails.send({
      from: process.env.EMAIL_FROM || 'onboarding@resend.dev',
      to: email,
      subject: 'AURA CHAT - Email Verification',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #8B5CF6;">AURA CHAT</h2>
          <p>Your verification code is:</p>
          <h1 style="font-size: 48px; letter-spacing: 8px; color: #06B6D4;">${code}</h1>
          <p>This code expires in 15 minutes.</p>
          <p style="color: #666;">If you didn't request this, ignore this email.</p>
        </div>
      `
    });

    res.json({ success: true, message: 'Verification code sent' });
  } catch (error) {
    console.error('Email send error:', error);
    res.status(500).json({ error: 'Failed to send verification email' });
  }
});

// Verify email code
router.post('/verify-email', (req, res) => {
  try {
    const { userId, code } = req.body;
    
    if (!userId || !code) {
      return res.status(400).json({ error: 'UserId and code required' });
    }

    const stored = verificationCodes.get(userId);
    
    if (!stored) {
      return res.status(400).json({ error: 'No verification code found' });
    }

    if (Date.now() > stored.expiresAt) {
      verificationCodes.delete(userId);
      return res.status(400).json({ error: 'Code expired' });
    }

    if (stored.code !== code) {
      return res.status(400).json({ error: 'Invalid code' });
    }

    // Success - clean up
    verificationCodes.delete(userId);
    
    res.json({ 
      success: true, 
      message: 'Email verified',
      email: stored.email 
    });
  } catch (error) {
    console.error('Verify error:', error);
    res.status(500).json({ error: 'Verification failed' });
  }
});

module.exports = router;

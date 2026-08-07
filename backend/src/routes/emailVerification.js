const express = require('express');
const router = express.Router();
const sgMail = require('@sendgrid/mail');

// ═══════════════════════════════════════════════════════════════════════════
// INIT SENDGRID WITH FULL DIAGNOSTICS
// ═══════════════════════════════════════════════════════════════════════════
console.log('📧 [EmailVerification] Loading email verification routes...');

const apiKey = process.env.SENDGRID_API_KEY;
console.log('📧 [EmailVerification] SENDGRID_API_KEY present?', !!apiKey);
console.log('📧 [EmailVerification] SENDGRID_API_KEY length:', apiKey ? apiKey.length : 0);
console.log('📧 [EmailVerification] EMAIL_FROM:', process.env.EMAIL_FROM || '(not set)');

if (!apiKey) {
  console.error('❌ [EmailVerification] SENDGRID_API_KEY is missing! Emails will fail.');
}

sgMail.setApiKey(apiKey || '');

const verificationCodes = new Map();

// ═══════════════════════════════════════════════════════════════════════════
// SEND VERIFICATION EMAIL
// ═══════════════════════════════════════════════════════════════════════════
router.post('/send-email-verification', async (req, res) => {
  console.log('\n📤 [send-email-verification] REQUEST RECEIVED');
  console.log('📤 [send-email-verification] Body:', JSON.stringify(req.body, null, 2));

  try {
    const { email, userId } = req.body;

    // ── Validate input ─────────────────────────────────────────────────────
    if (!email) {
      console.log('❌ [send-email-verification] Missing: email');
      return res.status(400).json({ error: 'Email required' });
    }
    if (!userId) {
      console.log('❌ [send-email-verification] Missing: userId');
      return res.status(400).json({ error: 'UserId required' });
    }

    console.log(`📤 [send-email-verification] Sending to: ${email} for user: ${userId}`);

    // ── Generate code ──────────────────────────────────────────────────────
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    console.log(`📤 [send-email-verification] Generated code: ${code}`);

    // Store code
    verificationCodes.set(userId, {
      code,
      email,
      expiresAt: Date.now() + 15 * 60 * 1000
    });
    console.log(`📤 [send-email-verification] Code stored. Total stored: ${verificationCodes.size}`);

    // ── Send via SendGrid ──────────────────────────────────────────────────
    const fromEmail = process.env.EMAIL_FROM;

    if (!fromEmail) {
      console.error('❌ [send-email-verification] EMAIL_FROM not set!');
      return res.status(500).json({ 
        error: 'Server misconfigured: EMAIL_FROM not set' 
      });
    }

    const msg = {
      to: email,
      from: fromEmail,
      subject: 'AURA CHAT - Email Verification',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="text-align: center; margin-bottom: 30px;">
            <h2 style="color: #8B5CF6; font-size: 28px; margin: 0;">AURA CHAT</h2>
            <p style="color: #666; margin-top: 8px;">Secure Messaging</p>
          </div>
          
          <div style="background: #f8f9fa; border-radius: 12px; padding: 30px; text-align: center;">
            <p style="color: #333; font-size: 16px; margin-bottom: 20px;">Your verification code is:</p>
            <h1 style="font-size: 52px; letter-spacing: 12px; color: #06B6D4; margin: 20px 0; font-family: monospace;">${code}</h1>
            <p style="color: #666; font-size: 14px;">This code expires in 15 minutes.</p>
          </div>
          
          <p style="color: #999; font-size: 12px; text-align: center; margin-top: 30px;">
            If you didn't request this code, you can safely ignore this email.
          </p>
        </div>
      `,
      text: `AURA CHAT - Your verification code is: ${code}. This code expires in 15 minutes.`,
    };

    console.log(`📤 [send-email-verification] Sending from: ${fromEmail} to: ${email}`);

    const [response] = await sgMail.send(msg);

    console.log('📤 [send-email-verification] SendGrid response status:', response.statusCode);
    console.log('📤 [send-email-verification] SendGrid headers:', JSON.stringify(response.headers, null, 2));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      console.log(`✅ [send-email-verification] Email sent! MessageId: ${response.headers['x-message-id']}`);
      res.json({ 
        success: true, 
        message: 'Verification code sent',
        messageId: response.headers['x-message-id']
      });
    } else {
      console.error('❌ [send-email-verification] Unexpected status:', response.statusCode);
      res.status(500).json({ 
        error: 'Email service returned unexpected status', 
        status: response.statusCode 
      });
    }

  } catch (error) {
    console.error('💥 [send-email-verification] UNEXPECTED ERROR:', error);
    
    if (error.response) {
      console.error('💥 [send-email-verification] SendGrid error body:', JSON.stringify(error.response.body, null, 2));
    }
    
    res.status(500).json({ 
      error: 'Failed to send email', 
      details: error.message,
      sendgridError: error.response ? error.response.body : null
    });
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// VERIFY EMAIL CODE
// ═══════════════════════════════════════════════════════════════════════════
router.post('/verify-email', (req, res) => {
  console.log('\n📥 [verify-email] REQUEST RECEIVED');
  console.log('📥 [verify-email] Body:', JSON.stringify(req.body, null, 2));
  console.log('📥 [verify-email] Stored codes count:', verificationCodes.size);

  try {
    const { userId, code } = req.body;

    if (!userId || !code) {
      console.log('❌ [verify-email] Missing userId or code');
      return res.status(400).json({ error: 'UserId and code required' });
    }

    const stored = verificationCodes.get(userId);
    console.log('📥 [verify-email] Found stored code?', !!stored);

    if (!stored) {
      console.log(`❌ [verify-email] No code found for userId: ${userId}`);
      return res.status(400).json({ error: 'No verification code found. Request a new one.' });
    }

    console.log(`📥 [verify-email] Stored email: ${stored.email}`);
    console.log(`📥 [verify-email] Stored expiresAt: ${new Date(stored.expiresAt).toISOString()}`);
    console.log(`📥 [verify-email] Now: ${new Date().toISOString()}`);
    console.log(`📥 [verify-email] Expired? ${Date.now() > stored.expiresAt}`);

    if (Date.now() > stored.expiresAt) {
      verificationCodes.delete(userId);
      console.log('❌ [verify-email] Code expired');
      return res.status(400).json({ error: 'Code expired. Request a new one.' });
    }

    console.log(`📥 [verify-email] Comparing: sent="${code}" vs stored="${stored.code}"`);
    console.log(`📥 [verify-email] Match? ${stored.code === code}`);

    if (stored.code !== code) {
      return res.status(400).json({ error: 'Invalid code' });
    }

    // Success
    verificationCodes.delete(userId);
    console.log('✅ [verify-email] Code verified successfully');

    res.json({ 
      success: true, 
      message: 'Email verified',
      email: stored.email 
    });

  } catch (error) {
    console.error('💥 [verify-email] UNEXPECTED ERROR:', error);
    res.status(500).json({ error: 'Verification failed', details: error.message });
  }
});

module.exports = router;

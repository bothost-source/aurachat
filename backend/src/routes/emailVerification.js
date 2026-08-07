const express = require('express');
const router = express.Router();
const { Resend } = require('resend');

// ═══════════════════════════════════════════════════════════════════════════
// INIT RESEND WITH FULL DIAGNOSTICS
// ═══════════════════════════════════════════════════════════════════════════
console.log('📧 [EmailVerification] Loading email verification routes...');

const apiKey = process.env.RESEND_API_KEY;
console.log('📧 [EmailVerification] RESEND_API_KEY present?', !!apiKey);
console.log('📧 [EmailVerification] RESEND_API_KEY length:', apiKey ? apiKey.length : 0);
console.log('📧 [EmailVerification] EMAIL_FROM:', process.env.EMAIL_FROM || '(not set, using default)');

const resend = new Resend(apiKey);

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

    // ── Send via Resend ────────────────────────────────────────────────────
    const fromEmail = process.env.EMAIL_FROM || 'onboarding@resend.dev';
    console.log(`📤 [send-email-verification] Sending from: ${fromEmail}`);

    const { data, error } = await resend.emails.send({
      from: `AURA CHAT <${fromEmail}>`,
      to: email,
      subject: 'AURA CHAT - Email Verification',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #8B5CF6;">AURA CHAT</h2>
          <p>Your verification code is:</p>
          <h1 style="font-size: 48px; letter-spacing: 8px; color: #06B6D4;">${code}</h1>
          <p>This code expires in 15 minutes.</p>
        </div>
      `
    });

    // ── Log EXACT Resend response ──────────────────────────────────────────
    console.log('📤 [send-email-verification] Resend response data:', JSON.stringify(data, null, 2));
    console.log('📤 [send-email-verification] Resend response error:', JSON.stringify(error, null, 2));

    if (error) {
      console.error('❌ [send-email-verification] Resend ERROR:', error);
      return res.status(500).json({ 
        error: 'Failed to send email', 
        details: error.message || error,
        code: error.statusCode || 'unknown'
      });
    }

    if (!data || !data.id) {
      console.error('❌ [send-email-verification] Resend returned empty data:', data);
      return res.status(500).json({ 
        error: 'Email service returned empty response',
        details: data 
      });
    }

    console.log(`✅ [send-email-verification] Email sent! ID: ${data.id}`);
    res.json({ success: true, message: 'Verification code sent', emailId: data.id });

  } catch (error) {
    console.error('💥 [send-email-verification] UNEXPECTED ERROR:', error);
    console.error('💥 [send-email-verification] Stack:', error.stack);
    res.status(500).json({ 
      error: 'Server crashed while sending email', 
      details: error.message,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
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

const express = require('express');
const router = express.Router();
const admin = require('firebase-admin');
const { GoogleGenerativeAI } = require('@google/generative-ai');

const db = admin.firestore();
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// POST /api/moderation/report - Receive report from Flutter
router.post('/report', async (req, res) => {
  try {
    const { messageContent, reporterId, reportedUserId, chatId, messageId } = req.body;

    if (!messageContent || !reporterId || !reportedUserId) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Rate limit check
    const canProceed = await checkRateLimit(reporterId);
    if (!canProceed) {
      return res.status(429).json({ status: 'rate_limited', message: 'Please wait before submitting another report' });
    }

    // Reporter reliability check
    const isReliable = await checkReporterReliability(reporterId);
    if (!isReliable) {
      return res.status(403).json({ status: 'reporter_flagged', message: 'Your reporting privileges are under review' });
    }

    // Call Gemini AI
    const analysis = await callGeminiAI(messageContent);

    // Store report
    const reportId = db.collection('reports').doc().id;
    await db.collection('reports').doc(reportId).set({
      message_id: messageId,
      chat_id: chatId,
      reported_user_id: reportedUserId,
      reporter_id: reporterId,
      message_content: messageContent,
      ai_category: analysis.category,
      ai_confidence: analysis.confidence,
      ai_reasoning: analysis.reasoning,
      status: analysis.confidence > 0.85 ? 'auto_actioned' : 'pending_review',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      reviewed_by: null,
      reviewed_at: null,
      action_taken: analysis.confidence > 0.85 ? analysis.recommended_action : null,
    });

    // Auto-action if high confidence
    if (analysis.confidence > 0.85) {
      await autoAction({
        reportedUserId,
        action: analysis.recommended_action,
        reason: analysis.category,
        reportId
      });
    }

    res.json({ status: 'success', analysis, report_id: reportId });

  } catch (error) {
    console.error('Moderation report error:', error);
    res.status(500).json({ error: 'Analysis failed' });
  }
});

// GET /api/moderation/ban-status/:userId - Check if user is banned
router.get('/ban-status/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const doc = await db.collection('users').doc(userId).get();
    
    if (!doc.exists) return res.json({ is_banned: false });

    const data = doc.data();
    if (data.is_banned !== true) return res.json({ is_banned: false });

    const bannedUntil = data.banned_until?.toDate();
    
    // Auto-unban if expired
    if (bannedUntil && new Date() > bannedUntil) {
      await unbanUser(userId);
      return res.json({ is_banned: false });
    }

    res.json({
      is_banned: true,
      banned_until: bannedUntil,
      ban_reason: data.ban_reason,
      ban_level: data.ban_level
    });

  } catch (error) {
    console.error('Ban status error:', error);
    res.status(500).json({ error: 'Failed to check ban status' });
  }
});

// Helper: Check rate limit
async function checkRateLimit(reporterId) {
  const snapshot = await db.collection('reports')
    .where('reporter_id', '==', reporterId)
    .orderBy('created_at', 'desc')
    .limit(1)
    .get();

  if (snapshot.empty) return true;
  
  const lastTime = snapshot.docs[0].data().created_at?.toDate();
  if (!lastTime) return true;

  const secondsSince = (Date.now() - lastTime.getTime()) / 1000;
  return secondsSince >= 3600;
}

// Helper: Check reporter reliability
async function checkReporterReliability(reporterId) {
  const snapshot = await db.collection('reports')
    .where('reporter_id', '==', reporterId)
    .get();

  if (snapshot.size < 5) return true;

  const dismissed = snapshot.docs.filter(d => d.data().status === 'dismissed').length;
  return (dismissed / snapshot.size) < 0.7;
}

// Helper: Call Gemini AI
async function callGeminiAI(messageContent) {
  try {
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

    const prompt = `You are a content moderation AI for a chat app called AURA. Analyze the following message and classify it.

Message: "${messageContent}"

Respond ONLY with a JSON object in this exact format:
{
  "category": "spam|harassment|scam|hate_speech|clean",
  "confidence": 0.0 to 1.0,
  "reasoning": "brief explanation",
  "recommended_action": "none|warn|mute_24h|ban_24h|ban_30d|permanent_ban"
}

Rules:
- spam = unsolicited promotions, ads, repeated messages
- harassment = bullying, threats, personal attacks
- scam = financial fraud, phishing, asking for money/personal info
- hate_speech = racism, sexism, discrimination, slurs
- clean = normal conversation

Confidence guide:
- 0.0-0.3 = clean/normal
- 0.3-0.7 = suspicious but unclear
- 0.7-0.85 = likely violation
- 0.85-1.0 = clear violation, auto-action recommended`;

    const result = await model.generateContent(prompt);
    const text = result.response.text();
    
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error('No JSON found');

    const parsed = JSON.parse(jsonMatch[0]);
    
    return {
      category: parsed.category || 'clean',
      confidence: parsed.confidence || 0,
      reasoning: parsed.reasoning || 'No reasoning',
      recommended_action: parsed.recommended_action || 'none'
    };

  } catch (error) {
    console.error('Gemini error:', error);
    return fallbackAnalysis(messageContent);
  }
}

// Helper: Fallback keyword analysis
function fallbackAnalysis(messageContent) {
  const lower = messageContent.toLowerCase();
  
  if (lower.includes('spam') || lower.includes('buy now') || lower.includes('click here')) {
    return { category: 'spam', confidence: 0.92, reasoning: 'Spam patterns detected', recommended_action: 'mute_24h' };
  }
  if (lower.includes('hate') || lower.includes('kill') || lower.includes('stupid')) {
    return { category: 'harassment', confidence: 0.88, reasoning: 'Hostile language', recommended_action: 'ban_24h' };
  }
  if (lower.includes('scam') || lower.includes('send money') || lower.includes('bank details')) {
    return { category: 'scam', confidence: 0.95, reasoning: 'Financial fraud attempt', recommended_action: 'permanent_ban' };
  }
  
  return { category: 'clean', confidence: 0.15, reasoning: 'No harmful content', recommended_action: 'none' };
}

// Helper: Auto-action based on AI recommendation
async function autoAction({ reportedUserId, action, reason, reportId }) {
  switch (action) {
    case 'warn':
      await db.collection('users').doc(reportedUserId).update({
        warnings: admin.firestore.FieldValue.arrayUnion([{
          reason,
          report_id: reportId,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        }])
      });
      break;

    case 'mute_24h':
    case 'ban_24h':
      await banUser(reportedUserId, 24 * 60 * 60 * 1000, reason, reportId, '24h');
      break;

    case 'ban_30d':
      await banUser(reportedUserId, 30 * 24 * 60 * 60 * 1000, reason, reportId, '30d');
      break;

    case 'permanent_ban':
      await banUser(reportedUserId, null, reason, reportId, 'permanent');
      break;
  }
}

// Helper: Ban user with escalating durations
async function banUser(userId, durationMs, reason, reportId, level) {
  const userDoc = await db.collection('users').doc(userId).get();
  const banHistory = userDoc.data()?.ban_history || [];
  const banCount = banHistory.length;

  let actualDuration = durationMs;
  let banLevel = level;

  if (durationMs === null || banCount >= 5) {
    actualDuration = null;
    banLevel = 'permanent';
  } else if (banCount === 0) {
    actualDuration = 24 * 60 * 60 * 1000;
    banLevel = '24h';
  } else if (banCount >= 1 && banCount <= 3) {
    actualDuration = 24 * 60 * 60 * 1000;
    banLevel = '24h';
  } else if (banCount === 4) {
    actualDuration = 30 * 24 * 60 * 60 * 1000;
    banLevel = '30d';
  } else {
    actualDuration = null;
    banLevel = 'permanent';
  }

  const bannedUntil = actualDuration 
    ? admin.firestore.Timestamp.fromDate(new Date(Date.now() + actualDuration))
    : null;

  await db.collection('users').doc(userId).update({
    is_banned: true,
    banned_until: bannedUntil,
    ban_reason: reason,
    ban_report_id: reportId,
    ban_level: banLevel,
    ban_history: admin.firestore.FieldValue.arrayUnion([{
      report_id: reportId,
      reason,
      level: banLevel,
      banned_at: admin.firestore.FieldValue.serverTimestamp(),
      banned_until: bannedUntil
    }])
  });
}

// Helper: Unban user
async function unbanUser(userId) {
  await db.collection('users').doc(userId).update({
    is_banned: false,
    banned_until: null,
    ban_reason: null,
    ban_report_id: null,
    ban_level: null
  });
}

module.exports = router;

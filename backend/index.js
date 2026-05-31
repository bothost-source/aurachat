const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ============================================================================
// TRIGGER: Send push notification when new message is created
// ============================================================================
exports.onNewMessage = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const chatId = context.params.chatId;
    const senderId = message.senderId;

    // Don't notify the sender
    if (!senderId) return null;

    try {
      // Get chat info
      const chatDoc = await db.collection('chats').doc(chatId).get();
      const chatData = chatDoc.data();

      if (!chatData) return null;

      // Get all participants except sender
      const participants = chatData.participants || [];
      const recipients = participants.filter(id => id !== senderId);

      if (recipients.length === 0) return null;

      // Get sender info
      const senderDoc = await db.collection('users').doc(senderId).get();
      const senderName = senderDoc.data()?.displayName || senderDoc.data()?.username || 'Someone';

      // Get FCM tokens for all recipients
      const tokens = [];
      for (const userId of recipients) {
        // Check if chat is muted for this user
        const muteDoc = await db.collection('user_settings').doc(userId).get();
        const mutedChats = muteDoc.data()?.mutedChats || [];
        if (mutedChats.includes(chatId)) continue;

        const userDoc = await db.collection('users').doc(userId).get();
        const token = userDoc.data()?.fcmToken;
        if (token) tokens.push(token);
      }

      if (tokens.length === 0) return null;

      // Build notification
      const notification = {
        title: chatData.type === 'direct' ? senderName : chatData.name || 'Group',
        body: _formatMessageBody(message),
      };

      const data = {
        chatId: chatId,
        messageId: context.params.messageId,
        senderId: senderId,
        type: message.type || 'text',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      };

      // Send to all tokens
      const response = await messaging.sendMulticast({
        tokens: tokens,
        notification: notification,
        data: data,
        android: {
          priority: 'high',
          notification: {
            channelId: 'tarrific_chat_channel',
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      });

      console.log(`Push sent: ${response.successCount} success, ${response.failureCount} failed`);

      // Remove invalid tokens
      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.log(`Failed token: ${tokens[idx]} - ${resp.error}`);
            // Optionally remove invalid token from user doc
          }
        });
      }

      return null;
    } catch (error) {
      console.error('Error sending push:', error);
      return null;
    }
  });

// ============================================================================
// HELPER: Format message body for notification
// ============================================================================
function _formatMessageBody(message) {
  const type = message.type || 'text';
  const content = message.content || '';

  switch (type) {
    case 'image': return '📷 Photo';
    case 'video': return '🎥 Video';
    case 'voice': return '🎙️ Voice message';
    case 'document': return '📎 Document';
    case 'location': return '📍 Location';
    case 'contact': return '👤 Contact';
    case 'poll': return '📊 Poll';
    default: return content.length > 100 ? content.substring(0, 100) + '...' : content;
  }
}

// ============================================================================
// HTTP FUNCTION: Send custom notification (for admin use)
// ============================================================================
exports.sendCustomNotification = functions.https.onCall(async (data, context) => {
  // Verify admin
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }

  const { title, body, topic, userIds } = data;

  if (!title || !body) {
    throw new functions.https.HttpsError('invalid-argument', 'Title and body required');
  }

  const payload = {
    notification: { title, body },
    data: { type: 'custom', timestamp: Date.now().toString() },
  };

  if (topic) {
    await messaging.sendToTopic(topic, payload);
    return { success: true, sentTo: 'topic' };
  }

  if (userIds && userIds.length > 0) {
    const tokens = [];
    for (const userId of userIds) {
      const userDoc = await db.collection('users').doc(userId).get();
      const token = userDoc.data()?.fcmToken;
      if (token) tokens.push(token);
    }

    if (tokens.length > 0) {
      await messaging.sendMulticast({
        tokens,
        ...payload,
      });
    }
    return { success: true, sentTo: tokens.length };
  }

  throw new functions.https.HttpsError('invalid-argument', 'Topic or userIds required');
});

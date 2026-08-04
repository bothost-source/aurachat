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
    const { chatId, messageId } = context.params;
    const senderId = message.sender_id;

    // Skip if already processed or no sender
    if (message.sent_to_fcm === true || !senderId) {
      console.log('Skipping: already sent or no sender');
      return null;
    }

    try {
      // 1. Get chat info
      const chatDoc = await db.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) {
        console.log('Chat not found:', chatId);
        return null;
      }

      const chatData = chatDoc.data();
      const participants = chatData.participants || [];
      const chatType = chatData.type || 'direct'; // 'direct', 'group', 'channel'
      const chatName = chatData.name || 'AURA Chat';

      // 2. Get recipients (everyone except sender)
      const recipients = participants.filter(id => id !== senderId);
      if (recipients.length === 0) {
        console.log('No recipients');
        return null;
      }

      // 3. Get sender name
      const senderDoc = await db.collection('users').doc(senderId).get();
      const senderName = senderDoc.exists 
        ? (senderDoc.data().username || 'Someone') 
        : 'Someone';

      // 4. Build notification content
      let title, body;

      if (chatType === 'direct') {
        title = senderName;
        body = _formatMessageBody(message);
      } else if (chatType === 'group') {
        title = chatName;
        body = `${senderName}: ${_formatMessageBody(message)}`;
      } else if (chatType === 'channel') {
        title = chatName;
        body = _formatMessageBody(message);
      } else {
        title = senderName;
        body = _formatMessageBody(message);
      }

      // 5. Collect FCM tokens
      const tokens = [];
      const tokenDocs = await Promise.all(
        recipients.map(userId => db.collection('users').doc(userId).get())
      );

      for (let i = 0; i < tokenDocs.length; i++) {
        const userDoc = tokenDocs[i];
        if (!userDoc.exists) continue;

        const userData = userDoc.data();
        const token = userData?.fcmToken;

        // Skip if no token
        if (!token) {
          console.log('No FCM token for user:', recipients[i]);
          continue;
        }

        // Skip if user muted this chat (stored in user doc)
        const mutedChats = userData?.muted_chats || [];
        if (mutedChats.includes(chatId)) {
          console.log('User muted chat:', recipients[i]);
          continue;
        }

        tokens.push(token);
      }

      if (tokens.length === 0) {
        console.log('No valid tokens to send');
        return null;
      }

      // 6. Send to each token individually (sendMulticast is deprecated)
      const sendPromises = tokens.map(async (token) => {
        try {
          await messaging.send({
            token: token,
            notification: {
              title: title,
              body: body,
            },
            data: {
              chatId: chatId,
              messageId: messageId,
              senderId: senderId,
              senderName: senderName,
              chatType: chatType,
              chatName: chatName,
              type: 'chat_message',
            },
            android: {
              priority: 'high',
              notification: {
                channelId: 'tarrific_chat_channel',
                sound: 'default',
                priority: 'high',
              },
            },
            apns: {
              payload: {
                aps: {
                  alert: {
                    title: title,
                    body: body,
                  },
                  badge: 1,
                  sound: 'default',
                },
              },
            },
          });
          return { success: true, token };
        } catch (error) {
          console.error('Failed to send to token:', token, error.message);
          return { success: false, token, error: error.message };
        }
      });

      const results = await Promise.all(sendPromises);
      const successCount = results.filter(r => r.success).length;
      const failureCount = results.filter(r => !r.success).length;

      console.log(`Push results: ${successCount} success, ${failureCount} failed`);

      // 7. Mark message as processed
      await snap.ref.update({ sent_to_fcm: true });

      return null;

    } catch (error) {
      console.error('Cloud Function error:', error);
      return null;
    }
  });

// ============================================================================
// HELPER: Format message body for notification preview
// ============================================================================
function _formatMessageBody(message) {
  const type = message.type || 'text';
  const content = message.content || '';

  switch (type) {
    case 'image': return '📷 Photo';
    case 'video': return '🎥 Video';
    case 'audio': 
    case 'voice': return '🎙️ Voice message';
    case 'file': 
    case 'document': return '📎 File';
    case 'location': return '📍 Location';
    case 'contact': return '👤 Contact';
    case 'poll': return '📊 Poll';
    default: 
      // Truncate long text messages
      return content.length > 100 ? content.substring(0, 100) + '...' : content;
  }
}

// ============================================================================
// HTTP FUNCTION: Send custom notification (admin use)
// ============================================================================
exports.sendCustomNotification = functions.https.onCall(async (data, context) => {
  // Verify user is logged in
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

  // Send to topic (for group/channel broadcasts)
  if (topic) {
    await messaging.send({
      topic: topic,
      notification: payload.notification,
      data: payload.data,
    });
    return { success: true, sentTo: 'topic', topic };
  }

  // Send to specific users
  if (userIds && userIds.length > 0) {
    const tokens = [];
    const tokenDocs = await Promise.all(
      userIds.map(userId => db.collection('users').doc(userId).get())
    );

    for (const userDoc of tokenDocs) {
      if (!userDoc.exists) continue;
      const token = userDoc.data()?.fcmToken;
      if (token) tokens.push(token);
    }

    if (tokens.length === 0) {
      return { success: false, error: 'No valid tokens' };
    }

    const sendPromises = tokens.map(token => 
      messaging.send({
        token: token,
        notification: payload.notification,
        data: payload.data,
      }).then(() => ({ success: true, token }))
        .catch(err => ({ success: false, token, error: err.message }))
    );

    const results = await Promise.all(sendPromises);
    const successCount = results.filter(r => r.success).length;

    return { success: true, sentTo: successCount, total: tokens.length };
  }

  throw new functions.https.HttpsError('invalid-argument', 'Topic or userIds required');
});

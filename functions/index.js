const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

exports.onNewMessage = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const { chatId, messageId } = context.params;
    const senderId = message.sender_id;

    if (message.sent_to_fcm === true || !senderId) {
      return null;
    }

    try {
      const chatDoc = await db.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return null;

      const chatData = chatDoc.data();
      const participants = chatData.participants || [];
      const chatType = chatData.type || 'direct';
      const chatName = chatData.name || 'AURA Chat';
      const recipients = participants.filter(id => id !== senderId);

      if (recipients.length === 0) return null;

      const senderDoc = await db.collection('users').doc(senderId).get();
      const senderName = senderDoc.exists 
        ? (senderDoc.data().username || 'Someone') 
        : 'Someone';

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

      const tokens = [];
      const tokenDocs = await Promise.all(
        recipients.map(userId => db.collection('users').doc(userId).get())
      );

      for (let i = 0; i < tokenDocs.length; i++) {
        const userDoc = tokenDocs[i];
        if (!userDoc.exists) continue;
        const userData = userDoc.data();
        const token = userData?.fcmToken;
        if (!token) continue;
        const mutedChats = userData?.muted_chats || [];
        if (mutedChats.includes(chatId)) continue;
        tokens.push(token);
      }

      if (tokens.length === 0) return null;

      const sendPromises = tokens.map(async (token) => {
        try {
          await messaging.send({
            token: token,
            notification: { title, body },
            data: {
              chatId, messageId, senderId, senderName,
              chatType, chatName, type: 'chat_message',
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
                  alert: { title, body },
                  badge: 1,
                  sound: 'default',
                },
              },
            },
          });
          return { success: true, token };
        } catch (error) {
          console.error('Failed:', token, error.message);
          return { success: false, token, error: error.message };
        }
      });

      const results = await Promise.all(sendPromises);
      console.log(`Sent: ${results.filter(r => r.success).length}/${tokens.length}`);

      await snap.ref.update({ sent_to_fcm: true });
      return null;

    } catch (error) {
      console.error('Error:', error);
      return null;
    }
  });

function _formatMessageBody(message) {
  const type = message.type || 'text';
  const content = message.content || '';
  switch (type) {
    case 'image': return '📷 Photo';
    case 'video': return '🎥 Video';
    case 'audio': case 'voice': return '🎙️ Voice message';
    case 'file': case 'document': return '📎 File';
    case 'location': return '📍 Location';
    case 'contact': return '👤 Contact';
    case 'poll': return '📊 Poll';
    default: return content.length > 100 ? content.substring(0, 100) + '...' : content;
  }
}

exports.sendCustomNotification = functions.https.onCall(async (data, context) => {
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
    await messaging.send({ topic, notification: payload.notification, data: payload.data });
    return { success: true, sentTo: 'topic', topic };
  }
  if (userIds?.length > 0) {
    const tokens = [];
    const tokenDocs = await Promise.all(userIds.map(id => db.collection('users').doc(id).get()));
    for (const userDoc of tokenDocs) {
      if (userDoc.exists) {
        const token = userDoc.data()?.fcmToken;
        if (token) tokens.push(token);
      }
    }
    if (tokens.length === 0) return { success: false, error: 'No valid tokens' };
    const results = await Promise.all(tokens.map(token =>
      messaging.send({ token, notification: payload.notification, data: payload.data })
        .then(() => ({ success: true, token }))
        .catch(err => ({ success: false, token, error: err.message }))
    ));
    return { success: true, sentTo: results.filter(r => r.success).length, total: tokens.length };
  }
  throw new functions.https.HttpsError('invalid-argument', 'Topic or userIds required');
});

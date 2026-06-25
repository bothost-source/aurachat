import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

// ============================================
// MAIN CHANNEL SCREEN - LIST + CREATE
// ============================================
class ChannelScreen extends StatelessWidget {
  const ChannelScreen({super.key});

  void _createChannel(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final descController = TextEditingController();
        bool isPublic = true;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E),
              title: const Text('New Channel', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Channel name',
                      hintStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Description (optional)',
                      hintStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Public channel', style: TextStyle(color: Colors.white70)),
                      const Spacer(),
                      Switch(
                        value: isPublic,
                        onChanged: (v) => setState(() => isPublic = v),
                        activeColor: Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final currentUser = FirebaseAuth.instance.currentUser;
                    if (currentUser == null) return;

                    await FirebaseFirestore.instance.collection('channels').add({
                      'name': name,
                      'description': descController.text.trim(),
                      'isPublic': isPublic,
                      'createdBy': currentUser.uid,
                      'createdAt': Timestamp.now(),
                      'members': [currentUser.uid],
                      'bannedUsers': [],
                      'memberCount': 1,
                      'lastMessage': '',
                      'lastMessageAt': Timestamp.now(),
                    });
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Create', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editChannel(BuildContext context, String channelId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController(text: data['name']);
        final descController = TextEditingController(text: data['description'] ?? '');
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text('Edit Channel', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Channel name',
                  hintStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Description',
                  hintStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('channels').doc(channelId).update({
                  'name': nameController.text.trim(),
                  'description': descController.text.trim(),
                  'updatedAt': Timestamp.now(),
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _deleteChannel(BuildContext context, String channelId, String channelName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Delete Channel?', style: TextStyle(color: Colors.white)),
        content: Text('Delete "$channelName"? This cannot be undone.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('channels').doc(channelId).delete();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('Channels'),
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('channels').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error', style: TextStyle(color: Colors.white)));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.white));
          final channels = snapshot.data!.docs;
          if (channels.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white24),
                  SizedBox(height: 16),
                  Text('No channels yet\nTap + to create one', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final channel = channels[index];
              final data = channel.data() as Map<String, dynamic>;
              final channelId = channel.id;
              final isOwner = data['createdBy'] == currentUser?.uid;
              final members = List<String>.from(data['members'] ?? []);
              final banned = List<String>.from(data['bannedUsers'] ?? []);
              final isMember = currentUser != null && members.contains(currentUser.uid);
              final isBanned = currentUser != null && banned.contains(currentUser.uid);
              final createdAt = data['createdAt'] as Timestamp?;

              if (isBanned) return const SizedBox.shrink();

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.white12,
                  child: Text((data['name'] as String?)?.substring(0, 1).toUpperCase() ?? '?', style: const TextStyle(color: Colors.white)),
                ),
                title: Text(data['name'] ?? 'Unnamed', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${data['memberCount'] ?? members.length} members • ${data['isPublic'] == true ? 'Public' : 'Private'}${createdAt != null ? ' • ${DateFormat('MMM d').format(createdAt.toDate())}' : ''}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                trailing: isOwner
                    ? PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white54),
                        color: const Color(0xFF1C1C1E),
                        onSelected: (value) {
                          if (value == 'edit') _editChannel(context, channelId, data);
                          else if (value == 'delete') _deleteChannel(context, channelId, data['name'] ?? 'this channel');
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white))),
                          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
                        ],
                      )
                    : isMember
                        ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                        : TextButton(
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('channels').doc(channelId).update({
                                'members': FieldValue.arrayUnion([currentUser!.uid]),
                                'memberCount': FieldValue.increment(1),
                              });
                            },
                            child: const Text('Join', style: TextStyle(color: Colors.white)),
                          ),
                onTap: () {
                  if (!isMember && !isOwner) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Join the channel first')));
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChannelChatScreen(channelId: channelId, channelName: data['name'] ?? 'Channel'),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createChannel(context),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ============================================
// CHANNEL CHAT SCREEN - MESSAGES + TYPING + MEDIA
// ============================================
class ChannelChatScreen extends StatefulWidget {
  final String channelId;
  final String channelName;
  const ChannelChatScreen({super.key, required this.channelId, required this.channelName});

  @override
  State<ChannelChatScreen> createState() => _ChannelChatScreenState();
}

class _ChannelChatScreenState extends State<ChannelChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _setTyping(false);
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty && !_isTyping) {
      _setTyping(true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () => _setTyping(false));
  }

  Future<void> _setTyping(bool typing) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    _isTyping = typing;
    await FirebaseFirestore.instance
        .collection('channels')
        .doc(widget.channelId)
        .collection('typing')
        .doc(currentUser.uid)
        .set({
      'isTyping': typing,
      'name': currentUser.displayName ?? 'User',
      'timestamp': Timestamp.now(),
    });
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && imageUrl == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _messageController.clear();
    _setTyping(false);

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    final userData = userDoc.data();

    await FirebaseFirestore.instance
        .collection('channels')
        .doc(widget.channelId)
        .collection('messages')
        .add({
      'text': text.isNotEmpty ? text : null,
      'imageUrl': imageUrl,
      'senderId': currentUser.uid,
      'senderName': userData?['name'] ?? currentUser.displayName ?? 'Unknown',
      'senderPhoto': userData?['photoUrl'],
      'timestamp': Timestamp.now(),
    });

    await FirebaseFirestore.instance.collection('channels').doc(widget.channelId).update({
      'lastMessage': imageUrl != null ? '📷 Photo' : text,
      'lastMessageAt': Timestamp.now(),
      'lastMessageBy': currentUser.uid,
    });

    _scrollToBottom();
  }

  Future<void> _pickAndSendImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (image == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final ref = FirebaseStorage.instance
        .ref()
        .child('channel_images')
        .child(widget.channelId)
        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

    await ref.putFile(File(image.path));
    final url = await ref.getDownloadURL();
    await _sendMessage(imageUrl: url);
  }

  Future<void> _deleteMessage(String messageId) async {
    await FirebaseFirestore.instance
        .collection('channels')
        .doc(widget.channelId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _showMessageOptions(String messageId, String senderId, bool isOwner) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final canDelete = senderId == currentUser?.uid || isOwner;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(messageId);
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white),
              title: const Text('Copy', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.white54),
              title: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.channelName),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('channels').doc(widget.channelId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final count = data?['memberCount'] ?? 0;
                return Text('$count members', style: const TextStyle(fontSize: 12, color: Colors.white54));
              },
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChannelInfoScreen(channelId: widget.channelId, channelName: widget.channelName),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Typing indicator
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('channels')
                .doc(widget.channelId)
                .collection('typing')
                .where('isTyping', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
              final typings = snapshot.data!.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['timestamp'] != null &&
                    (Timestamp.now().seconds - (data['timestamp'] as Timestamp).seconds) < 5 &&
                    d.id != currentUser?.uid;
              }).toList();

              if (typings.isEmpty) return const SizedBox.shrink();

              final names = typings.map((d) => (d.data() as Map<String, dynamic>)['name'] ?? 'Someone').join(', ');
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                alignment: Alignment.centerLeft,
                child: Text(
                  '$names ${typings.length == 1 ? 'is' : 'are'} typing...',
                  style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              );
            },
          ),

          // Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('channels')
                  .doc(widget.channelId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Error', style: TextStyle(color: Colors.white)));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.white));

                final messages = snapshot.data!.docs;
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet\nBe the first!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)));
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final data = msg.data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == currentUser?.uid;
                    final timestamp = data['timestamp'] as Timestamp?;

                    return GestureDetector(
                      onLongPress: () => _showMessageOptions(msg.id, data['senderId'], false),
                      child: Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFF007AFF) : const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isMe)
                                Text(
                                  data['senderName'] ?? 'Unknown',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              if (!isMe) const SizedBox(height: 4),
                              if (data['imageUrl'] != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    data['imageUrl'],
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return Container(
                                        width: 200,
                                        height: 150,
                                        color: Colors.white12,
                                        child: const Center(child: CircularProgressIndicator(color: Colors.white54)),
                                      );
                                    },
                                  ),
                                ),
                              if (data['text'] != null && (data['text'] as String).isNotEmpty)
                                Text(data['text'], style: const TextStyle(color: Colors.white, fontSize: 15)),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    timestamp != null ? DateFormat('h:mm a').format(timestamp.toDate()) : '',
                                    style: TextStyle(color: isMe ? Colors.white70 : Colors.white54, fontSize: 11),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.done_all, size: 14, color: Colors.white70),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(color: Color(0xFF1C1C1E), border: Border(top: BorderSide(color: Colors.white12))),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.white54),
                    onPressed: _pickAndSendImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Message...',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: _onTextChanged,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () => _sendMessage(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// CHANNEL INFO SCREEN - MEMBERS + ADMIN + LEAVE
// ============================================
class ChannelInfoScreen extends StatelessWidget {
  final String channelId;
  final String channelName;
  const ChannelInfoScreen({super.key, required this.channelId, required this.channelName});

  Future<void> _leaveChannel(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Leave Channel?', style: TextStyle(color: Colors.white)),
        content: const Text('You can rejoin anytime if the channel is public.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('channels').doc(channelId).update({
        'members': FieldValue.arrayRemove([currentUser.uid]),
        'memberCount': FieldValue.increment(-1),
      });
      if (context.mounted) {
        Navigator.pop(context); // Close info
        Navigator.pop(context); // Close chat
      }
    }
  }

  void _kickMember(BuildContext context, String memberId, String memberName, bool isOwner) {
    if (!isOwner) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text('Kick $memberName?', style: const TextStyle(color: Colors.white)),
        content: const Text('They will be removed from the channel.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('channels').doc(channelId).update({
                'members': FieldValue.arrayRemove([memberId]),
                'memberCount': FieldValue.increment(-1),
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Kick', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _banMember(BuildContext context, String memberId, String memberName, bool isOwner) {
    if (!isOwner) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text('Ban $memberName?', style: const TextStyle(color: Colors.white)),
        content: const Text('They will be removed and banned from rejoining.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('channels').doc(channelId).update({
                'members': FieldValue.arrayRemove([memberId]),
                'bannedUsers': FieldValue.arrayUnion([memberId]),
                'memberCount': FieldValue.increment(-1),
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Ban', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('Channel Info'),
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('channels').doc(channelId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final isOwner = data['createdBy'] == currentUser?.uid;
          final members = List<String>.from(data['members'] ?? []);
          final description = data['description'] ?? '';
          final createdAt = data['createdAt'] as Timestamp?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white12,
                        child: Text(
                          channelName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(channelName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(description, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 14)),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '${data['isPublic'] == true ? 'Public' : 'Private'} • ${members.length} members${createdAt != null ? ' • Created ${DateFormat('MMM d, yyyy').format(createdAt.toDate())}' : ''}',
                        style: const TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white12),

                // Members
                const Text('Members', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),

                FutureBuilder<List<Map<String, dynamic>>>(
                  future: Future.wait(members.map((uid) async {
                    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                    return {'uid': uid, ...(doc.data() ?? {})};
                  })),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));
                    final users = snapshot.data!;

                    return Column(
                      children: users.map((user) {
                        final uid = user['uid'] as String;
                        final isOwner = data['createdBy'] == uid;
                        final isCurrentUser = uid == currentUser?.uid;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.white12,
                            backgroundImage: user['photoUrl'] != null ? NetworkImage(user['photoUrl']) : null,
                            child: user['photoUrl'] == null
                                ? Text((user['name'] ?? '?').substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white))
                                : null,
                          ),
                          title: Text(
                            user['name'] ?? 'Unknown',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            isOwner ? 'Owner' : 'Member',
                            style: TextStyle(color: isOwner ? Colors.amber : Colors.white54, fontSize: 12),
                          ),
                          trailing: !isCurrentUser && data['createdBy'] == currentUser?.uid
                              ? PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Colors.white54),
                                  color: const Color(0xFF1C1C1E),
                                  onSelected: (value) {
                                    if (value == 'kick') _kickMember(context, uid, user['name'] ?? 'User', true);
                                    if (value == 'ban') _banMember(context, uid, user['name'] ?? 'User', true);
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'kick', child: Text('Kick', style: TextStyle(color: Colors.white))),
                                    const PopupMenuItem(value: 'ban', child: Text('Ban', style: TextStyle(color: Colors.redAccent))),
                                  ],
                                )
                              : isCurrentUser
                                  ? const Text('You', style: TextStyle(color: Colors.white38, fontSize: 12))
                                  : null,
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 24),
                const Divider(color: Colors.white12),

                // Leave button
                if (!isOwner)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _leaveChannel(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.2),
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Leave Channel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),

                if (isOwner)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'You are the owner. Delete the channel from the list if you want to remove it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;
import '../../providers/chat_provider.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  bool _isBlocking = false;
  bool _isAddingContact = false;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final userId = args?['userId'] as String?;
    final username = args?['username'] as String? ?? 'Unknown';
    final passedAvatarUrl = args?['avatarUrl'] as String? ?? args?['avatar_url'] as String?;
    final bio = args?['bio'] as String?;

    final currentUserId = context.read<AuraAuthProvider>().user?.uid ??
                         context.read<AuraAuthProvider>().mockUserId;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: Text('@$username'),
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // More options menu
          PopupMenuButton<String>(
            color: const Color(0xFF1a103c),
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            onSelected: (value) {
              if (value == 'report') _showReportDialog(context, userId, username);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag, color: Colors.orange, size: 20),
                    SizedBox(width: 12),
                    Text('Report', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: userId == null || currentUserId == null
          ? _buildErrorState('Invalid user')
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .snapshots(),
              builder: (context, userSnapshot) {
                final liveData = userSnapshot.data?.data() as Map<String, dynamic>?;
                final avatarUrl = liveData?['avatar_url'] as String? ?? passedAvatarUrl;

                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUserId)
                      .snapshots(),
                  builder: (context, currentUserSnapshot) {
                    final currentUserData = currentUserSnapshot.data?.data() as Map<String, dynamic>?;
                    final blockedList = List<String>.from(currentUserData?['blocked_users'] ?? []);
                    final contactsList = List<String>.from(currentUserData?['contacts'] ?? []);
                    final isBlocked = blockedList.contains(userId);
                    final isContact = contactsList.contains(userId);

                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 32),

                          // Profile Avatar
                          Center(child: _buildAvatar(avatarUrl, username)),

                          const SizedBox(height: 24),

                          // Username
                          Text(
                            username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // User ID
                          Text(
                            'ID: $userId',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Bio
                          if (bio != null && bio.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: Text(
                                  bio,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 15,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),

                          const SizedBox(height: 32),

                          // Action Buttons Row
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Row(
                              children: [
                                // Message Button
                                Expanded(
                                  child: _buildActionButton(
                                    icon: Icons.message,
                                    label: 'Message',
                                    gradient: const [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                                    onTap: isBlocked
                                        ? () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Unblock user to send messages'),
                                                backgroundColor: Colors.orange,
                                              ),
                                            );
                                          }
                                        : () async {
                                            final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                                            final chat = await chatProvider.startDirectChat(userId);
                                            if (chat != null && mounted) {
                                              Navigator.pushNamed(
                                                context,
                                                '/chat',
                                                arguments: {
                                                  'chatId': chat['id'],
                                                  'chatName': username,
                                                  'chatAvatar': avatarUrl,
                                                  'isGroup': false,
                                                },
                                              );
                                            }
                                          },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Call Button
                                Expanded(
                                  child: _buildActionButton(
                                    icon: Icons.call,
                                    label: 'Call',
                                    gradient: const [Color(0xFF10B981), Color(0xFF06B6D4)],
                                    onTap: isBlocked
                                        ? () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Unblock user to call'),
                                                backgroundColor: Colors.orange,
                                              ),
                                            );
                                          }
                                        : () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Call feature coming soon')),
                                            );
                                          },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Secondary Actions: Add Contact & Block
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Row(
                              children: [
                                // Add/Remove Contact
                                Expanded(
                                  child: _buildSecondaryButton(
                                    icon: isContact ? Icons.person_remove : Icons.person_add,
                                    label: isContact ? 'Remove' : 'Add Contact',
                                    color: isContact ? Colors.orange : const Color(0xFF10B981),
                                    isLoading: _isAddingContact,
                                    onTap: () => _toggleContact(currentUserId, userId, isContact),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Block/Unblock
                                Expanded(
                                  child: _buildSecondaryButton(
                                    icon: isBlocked ? Icons.lock_open : Icons.block,
                                    label: isBlocked ? 'Unblock' : 'Block',
                                    color: isBlocked ? Colors.grey : Colors.red,
                                    isLoading: _isBlocking,
                                    onTap: () => _toggleBlock(currentUserId, userId, isBlocked, username),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  /// Toggle block/unblock user
  Future<void> _toggleBlock(String currentUserId, String targetUserId, bool isBlocked, String username) async {
    setState(() => _isBlocking = true);

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);

      if (isBlocked) {
        // Unblock
        // ✅ FIX: Use .set() with merge instead of .update()
        await userRef.set({
          'blocked_users': FieldValue.arrayRemove([targetUserId]),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unblocked @$username')),
          );
        }
      } else {
        // Block — also remove from contacts if they were one
        // ✅ FIX: Use .set() with merge instead of .update()
        await userRef.set({
          'blocked_users': FieldValue.arrayUnion([targetUserId]),
          'contacts': FieldValue.arrayRemove([targetUserId]),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Blocked @$username'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isBlocking = false);
    }
  }

  /// Toggle add/remove contact
  Future<void> _toggleContact(String currentUserId, String targetUserId, bool isContact) async {
    setState(() => _isAddingContact = true);

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);

      if (isContact) {
        // ✅ FIX: Use .set() with merge instead of .update()
        await userRef.set({
          'contacts': FieldValue.arrayRemove([targetUserId]),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact removed')),
          );
        }
      } else {
        // ✅ FIX: Use .set() with merge instead of .update()
        await userRef.set({
          'contacts': FieldValue.arrayUnion([targetUserId]),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contact added'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isAddingContact = false);
    }
  }

  /// Report user dialog
  void _showReportDialog(BuildContext context, String? reportedUserId, String reportedUsername) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Report @$reportedUsername?',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This will be reviewed by our team. False reports may result in account suspension.',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Reason for reporting (optional)',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () async {
              final currentUserId = context.read<AuraAuthProvider>().user?.uid ??
                                   context.read<AuraAuthProvider>().mockUserId;
              if (currentUserId == null || reportedUserId == null) return;

              Navigator.pop(context);

              try {
                await FirebaseFirestore.instance.collection('reports').add({
                  'reporter_id': currentUserId,
                  'reported_user_id': reportedUserId,
                  'reported_username': reportedUsername,
                  'reason': reasonController.text.trim().isEmpty ? 'No reason provided' : reasonController.text.trim(),
                  'status': 'pending',
                  'created_at': FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report submitted. Thank you.'),
                      backgroundColor: Color(0xFF8B5CF6),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to report: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  /// NULL-SAFE avatar builder
  Widget _buildAvatar(String? avatarUrl, String username) {
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    if (avatarUrl == null || avatarUrl.isEmpty) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Center(
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: const Color(0xFF1a103c),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
              ),
            ),
          ),
          errorWidget: (context, url, error) {
            debugPrint('PublicProfile avatar error: $error');
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Primary action button (Message, Call)
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: -5,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Secondary action button (Add Contact, Block)
  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: isLoading
            ? Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.white.withOpacity(0.3), size: 48),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
          ),
        ],
      ),
    );
  }
}

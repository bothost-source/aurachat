import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;
import '../../providers/chat_provider.dart';
import '../../services/cloudinary_service.dart';
import '../../services/invitation_service.dart';
import '../../utils/verified_badge.dart';

class GroupInfoScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final String? chatAvatar;
  final bool isChannel;

  const GroupInfoScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    this.chatAvatar,
    required this.isChannel,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  bool _isLoading = false;
  bool _isEditing = false;
  String? _invitationLink;
  String? _invitationCode;

  // Edit controllers
  final _editNameController = TextEditingController();
  final _editDescriptionController = TextEditingController();
  String? _editPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadInvitationLink();
  }

  @override
  void dispose() {
    _editNameController.dispose();
    _editDescriptionController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INVITATION LINK
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadInvitationLink() async {
    final preview = await InvitationService.getInvitationPreview(widget.chatId);
    if (preview != null && mounted) {
      setState(() {
        _invitationLink = preview['link'] as String?;
        _invitationCode = preview['code'] as String?;
      });
    }
  }

  Future<void> _copyLinkToClipboard() async {
    if (_invitationLink == null || _invitationLink!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invitation link available')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: _invitationLink!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard')),
      );
    }
  }

  Future<void> _copyCodeToClipboard() async {
    if (_invitationCode == null || _invitationCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invitation code available')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: _invitationCode!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code copied to clipboard')),
      );
    }
  }

  Future<void> _regenerateLink() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        title: const Text('Regenerate Link?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will invalidate the current invitation link and create a new one. Anyone with the old link will no longer be able to join.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final createdBy = authProvider.user?.uid ?? authProvider.mockUserId ?? 'unknown';
      final newLink = await InvitationService.regenerateLink(widget.chatId, createdBy);

      if (newLink != null && mounted) {
        await _loadInvitationLink();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation link regenerated'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to regenerate link')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _shareInvitationLink() async {
    final preview = await InvitationService.getInvitationPreview(widget.chatId);
    if (preview == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active invitation link')),
        );
      }
      return;
    }

    final chatName = preview['chat_name'] ?? 'Unknown';
    final chatType = preview['chat_type'] ?? 'group';
    final memberCount = preview['member_count'] ?? 0;
    final link = preview['link'] ?? '';

    final text = 'Join $chatName on AURA Chat!\n'
        '${widget.isChannel ? "Channel" : "Group"}: $chatType\n'
        'Members: $memberCount\n\n'
        'Tap to join: $link';

    await Share.share(text);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EDIT PROFILE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _pickEditPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? authProvider.mockUserId;
      if (userId == null) throw Exception('Not authenticated');

      final imageUrl = await CloudinaryService.uploadImage(
        File(pickedFile.path),
        'aurachat/permanent/avatars/${widget.isChannel ? "channels" : "groups"}/$userId'
      );

      if (imageUrl != null) {
        setState(() => _editPhotoUrl = imageUrl);
      }
    } catch (e) {
      debugPrint('Photo upload failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteOldAvatar(String? oldUrl) async {
    if (oldUrl == null || oldUrl.isEmpty) return;
    if (!oldUrl.contains('cloudinary.com')) return;

    try {
      await CloudinaryService.deleteImage(oldUrl);
    } catch (e) {
      debugPrint('Failed to delete old avatar: $e');
    }
  }

  Future<void> _saveEdit() async {
    final name = _editNameController.text.trim();
    if (name.isEmpty) {
      _showError('Name cannot be empty');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();
      final oldAvatarUrl = chatDoc.data()?['avatar_url'] as String?;

      final updates = <String, dynamic>{
        'name': name,
        'description': _editDescriptionController.text.trim().isNotEmpty
            ? _editDescriptionController.text.trim()
            : null,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (_editPhotoUrl != null && _editPhotoUrl != oldAvatarUrl) {
        updates['avatar_url'] = _editPhotoUrl;
        await _deleteOldAvatar(oldAvatarUrl);
      }

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update(updates);

      setState(() {
        _isEditing = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Updated successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Update failed: $e');
    }
  }

  void _startEdit(Map<String, dynamic> data) {
    _editNameController.text = data['name'] ?? '';
    _editDescriptionController.text = data['description'] ?? '';
    _editPhotoUrl = data['avatar_url'];
    setState(() => _isEditing = true);
  }

  void _cancelEdit() {
    setState(() => _isEditing = false);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MEMBER MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showMemberOptions(String memberId, String memberName, String memberRole, bool isMe, bool canManage) async {
    if (isMe) return;
    if (!canManage) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final myRole = await _getMyRole();
    if (myRole == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              memberName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (myRole == 'owner' && memberRole == 'member')
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.admin_panel_settings, color: Color(0xFF8B5CF6)),
                ),
                title: const Text('Promote to Admin', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  chatProvider.promoteToAdmin(widget.chatId, memberId);
                },
              ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.remove_circle, color: Colors.orange),
              ),
              title: const Text('Kick', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _confirmKick(memberId, memberName);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.block, color: Colors.red),
              ),
              title: const Text('Ban', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmBan(memberId, memberName);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _getMyRole() async {
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;
    if (userId == null) return null;

    final doc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    return (data['participants_data']?[userId]?['role'] ?? 'member') as String;
  }

  void _confirmKick(String memberId, String memberName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        title: Text('Kick $memberName?', style: const TextStyle(color: Colors.white)),
        content: const Text('They will be removed from this group.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<ChatProvider>(context, listen: false).kickMember(widget.chatId, memberId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Kick'),
          ),
        ],
      ),
    );
  }

  void _confirmBan(String memberId, String memberName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        title: Text('Ban $memberName?', style: const TextStyle(color: Colors.white)),
        content: const Text('They will be removed and banned from rejoining.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<ChatProvider>(context, listen: false).banMember(widget.chatId, memberId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ban'),
          ),
        ],
      ),
    );
  }

  void _showSettings(String currentRole) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => GroupSettingsSheet(
        chatId: widget.chatId,
        currentRole: currentRole,
        isChannel: widget.isChannel,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LEAVE GROUP (NON-OWNER ONLY)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _leaveGroup() async {
    // SECURITY FIX: Owner cannot leave, must delete instead
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;
    
    final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
    if (!chatDoc.exists) return;
    
    final data = chatDoc.data()!;
    final myRole = (data['participants_data']?[userId]?['role'] ?? 'member') as String;
    
    if (myRole == 'owner') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Owner cannot leave. Delete the group instead.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        title: Text('Leave ${widget.isChannel ? "Channel" : "Group"}?', style: const TextStyle(color: Colors.white)),
        content: Text('You will no longer receive messages from this ${widget.isChannel ? "channel" : "group"}.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Provider.of<ChatProvider>(context, listen: false).leaveChat(widget.chatId);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DELETE GROUP (OWNER ONLY)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _deleteGroup() async {
    // SECURITY FIX: Verify owner before showing dialog
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;
    
    final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
    if (!chatDoc.exists) return;
    
    final data = chatDoc.data()!;
    final myRole = (data['participants_data']?[userId]?['role'] ?? 'member') as String;
    
    if (myRole != 'owner') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only the owner can delete this group'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        title: const Text('Delete Group?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete the group and all its messages. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final success = await chatProvider.permanentlyDeleteChat(widget.chatId);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group deleted'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(chatProvider.error ?? 'Failed to delete group'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuraAuthProvider>(context);
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: Text(widget.isChannel ? 'Channel Info' : 'Group Info'),
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final myRole = (data?['participants_data']?[userId]?['role'] ?? 'member') as String;
              final canManage = myRole == 'owner' || myRole == 'admin';
              final isOwner = myRole == 'owner';

              return Row(
                children: [
                  if (canManage && !_isEditing)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white70),
                      onPressed: () => _startEdit(data!),
                    ),
                  if (_isEditing)
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: _saveEdit,
                    ),
                  if (_isEditing)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: _cancelEdit,
                    ),
                  if (canManage && !_isEditing)
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white70),
                      onPressed: () => _showSettings(myRole),
                    ),
                  if (!_isEditing)
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white70),
                      onPressed: _shareInvitationLink,
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final participants = List<String>.from(data['participants'] ?? []);
          final memberCount = data['member_count'] ?? participants.length;
          final description = data['description'] ?? '';
          final createdByEmail = data['created_by_email'] as String?;
          final myRole = (data['participants_data']?[userId]?['role'] ?? 'member') as String;
          final canManage = myRole == 'owner' || myRole == 'admin';
          final isOwner = myRole == 'owner';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _isEditing ? _pickEditPhoto : null,
                        child: Stack(
                          children: [
                            _buildAvatar(_isEditing ? (_editPhotoUrl ?? data['avatar_url']) : data['avatar_url']),
                            if (_isEditing)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_isEditing)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: TextField(
                            controller: _editNameController,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        )
                      else
                        VerifiedUsername(
                          username: data['name'] ?? 'Unknown',
                          email: createdByEmail,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          badgeSize: 16,
                          spacing: 6,
                        ),

                      if (_isEditing) ...[
                        const SizedBox(height: 12),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: TextField(
                            controller: _editDescriptionController,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Add a description...',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ] else if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                        ),
                      ],

                      const SizedBox(height: 4),
                      Text(
                        '$memberCount members \u2022 ${widget.isChannel ? "Channel" : "Group"}',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Actions — FIX: Owner sees Delete, non-owner sees Leave
                if (!_isEditing)
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.person_add,
                          label: 'Add',
                          onTap: () => _showAddMembersSheet(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.share,
                          label: 'Invite',
                          onTap: _shareInvitationLink,
                        ),
                      ),
                      if (!isOwner) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.exit_to_app,
                            label: 'Leave',
                            color: Colors.red,
                            onTap: _leaveGroup,
                          ),
                        ),
                      ],
                      if (isOwner) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.delete_forever,
                            label: 'Delete',
                            color: Colors.red.shade700,
                            onTap: _deleteGroup,
                          ),
                        ),
                      ],
                    ],
                  ),
                if (!_isEditing) const SizedBox(height: 24),

                // INVITATION LINK SECTION
                if (!_isEditing && _invitationLink != null && _invitationLink!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.link, color: Color(0xFF8B5CF6), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Invitation Link',
                              style: TextStyle(
                                color: const Color(0xFF8B5CF6).withOpacity(0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            if (canManage)
                              GestureDetector(
                                onTap: _isLoading ? null : _regenerateLink,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                  ),
                                  child: _isLoading
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                                      )
                                    : const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.refresh, color: Colors.orange, size: 12),
                                          SizedBox(width: 4),
                                          Text(
                                            'Regenerate',
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Code display
                        if (_invitationCode != null && _invitationCode!.isNotEmpty) ...[
                          GestureDetector(
                            onTap: _copyCodeToClipboard,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.06)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B5CF6).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'CODE',
                                      style: TextStyle(
                                        color: Color(0xFF8B5CF6),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _invitationCode!,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'monospace',
                                        fontFamilyFallback: const ['Courier'],
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.copy, color: Colors.white38, size: 16),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        // Link display
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _invitationLink!,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                    fontFamilyFallback: const ['Courier'],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _copyLinkToClipboard,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.copy, color: Color(0xFF8B5CF6), size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _shareInvitationLink,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.share, color: Colors.white, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'Share Link',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _copyLinkToClipboard,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: const Text(
                                  'Copy',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Settings preview (if admin)
                if (canManage && !_isEditing) ...[
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8B5CF6).withOpacity(0.8),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSettingsPreview(data),
                  const SizedBox(height: 24),
                ],

                // Members
                Text(
                  'Members ($memberCount)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8B5CF6).withOpacity(0.8),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),

                FutureBuilder<List<Map<String, dynamic>>>(
                  future: Future.wait(participants.map((uid) async {
                    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                    final userData = doc.data() ?? {};
                    final role = (data['participants_data']?[uid]?['role'] ?? 'member') as String;
                    return {
                      'uid': uid,
                      ...userData,
                      'role': role,
                    };
                  })),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                        ),
                      );
                    }

                    final users = snapshot.data!;
                    users.sort((a, b) {
                      final roleOrder = {'owner': 0, 'admin': 1, 'member': 2};
                      return (roleOrder[a['role']] ?? 3).compareTo(roleOrder[b['role']] ?? 3);
                    });

                    return Column(
                      children: users.map((user) {
                        final uid = user['uid'] as String;
                        final isMe = uid == userId;
                        final role = user['role'] as String;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: _buildMemberAvatar(user['avatar_url'], user['username']),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user['username'] ?? 'Unknown',
                                  style: const TextStyle(color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isMe)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    '(You)',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            role == 'owner' ? 'Owner' : role == 'admin' ? 'Admin' : 'Member',
                            style: TextStyle(
                              color: role == 'owner'
                                  ? Colors.amber
                                  : role == 'admin'
                                      ? const Color(0xFF8B5CF6)
                                      : Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          trailing: !isMe && canManage && role != 'owner'
                              ? IconButton(
                                  icon: const Icon(Icons.more_vert, color: Colors.white54),
                                  onPressed: () => _showMemberOptions(
                                    uid,
                                    user['username'] ?? 'Unknown',
                                    role,
                                    isMe,
                                    canManage,
                                  ),
                                )
                              : null,
                          onTap: () {
                            if (!isMe) {
                              Navigator.pushNamed(
                                context,
                                '/public_profile',
                                arguments: {
                                  'userId': uid,
                                  'username': user['username'],
                                  'avatarUrl': user['avatar_url'],
                                  'bio': user['bio'],
                                },
                              );
                            }
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddMembersSheet(BuildContext context) {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Add Members',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by username...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  ),
                  onChanged: (value) async {
                    if (value.length < 2) {
                      setModalState(() => searchResults = []);
                      return;
                    }
                    final snapshot = await FirebaseFirestore.instance
                        .collection('users')
                        .where('username', isGreaterThanOrEqualTo: value)
                        .where('username', isLessThanOrEqualTo: '$value\uf8ff')
                        .limit(10)
                        .get();
                    setModalState(() {
                      searchResults = snapshot.docs
                          .map((doc) => {'id': doc.id, ...doc.data()})
                          .toList();
                    });
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final user = searchResults[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user['avatar_url'] != null
                              ? NetworkImage(user['avatar_url'])
                              : null,
                          child: user['avatar_url'] == null
                              ? Text((user['username'] ?? 'U')[0].toUpperCase())
                              : null,
                        ),
                        title: Text(user['username'] ?? 'Unknown',
                            style: const TextStyle(color: Colors.white)),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                            final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
                            final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;

                            final userDoc = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user['id'])
                                .get();
                            final privacySettings = userDoc.data()?['privacy_settings'] ?? {};
                            final allowAddToGroups = privacySettings['allow_add_to_groups'] ?? true;

                            if (!allowAddToGroups) {
                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: const Color(0xFF1a103c),
                                    title: const Text("Cannot Add User", style: TextStyle(color: Colors.white)),
                                    content: Text(
                                      "${user['username']} does not allow being added to groups. Send them the invite link instead?",
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          final preview = await InvitationService.getInvitationPreview(widget.chatId);
                                          String link = preview?['link'] ?? '';

                                          if (link.isEmpty) {
                                            final result = await InvitationService.createInvitation(
                                              chatId: widget.chatId,
                                              chatName: widget.chatName,
                                              chatType: widget.isChannel ? 'channel' : 'group',
                                              createdBy: currentUserId!,
                                            );
                                            link = result['link'] as String;
                                          }

                                          if (!context.mounted) return;

                                          final shouldSend = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              backgroundColor: const Color(0xFF1a103c),
                                              title: Text("Send Invite to ${user['username']}?", style: const TextStyle(color: Colors.white)),
                                              content: Text(
                                                "This will open a chat with ${user['username']} and send them the invitation link for \"${widget.chatName}\".",
                                                style: const TextStyle(color: Colors.white70),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                                                  child: const Text('Send'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (shouldSend != true) return;

                                          final dmChat = await chatProvider.startDirectChat(user['id']);

                                          if (dmChat != null && context.mounted) {
                                            final previewData = await InvitationService.getChatPreviewData(widget.chatId);

                                            await FirebaseFirestore.instance
                                                .collection('chats')
                                                .doc(dmChat['id'])
                                                .collection('messages')
                                                .add({
                                              'chat_id': dmChat['id'],
                                              'sender_id': currentUserId,
                                              'type': 'link_preview',
                                              'content': link,
                                              'preview_data': {
                                                'title': previewData['name'] ?? widget.chatName,
                                                'description': previewData['description'] ?? 'Join us on AURA Chat',
                                                'image_url': previewData['avatar_url'],
                                                'member_count': previewData['member_count'] ?? 0,
                                                'type': previewData['type'] ?? 'group',
                                                'source_chat_id': widget.chatId,
                                              },
                                              'created_at': FieldValue.serverTimestamp(),
                                              'is_read': false,
                                              'deleted_for_everyone': false,
                                              'deleted_for': [],
                                              'reactions': {},
                                              'is_edited': false,
                                            });

                                            await FirebaseFirestore.instance
                                                .collection('chats')
                                                .doc(dmChat['id'])
                                                .update({
                                              'last_message': link,
                                              'last_message_at': FieldValue.serverTimestamp(),
                                            });

                                            Navigator.pushNamed(
                                              context,
                                              '/chat',
                                              arguments: {
                                                'chatId': dmChat['id'],
                                                'chatName': user['username'],
                                                'chatAvatar': user['avatar_url'],
                                                'isGroup': false,
                                              },
                                            );

                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text("Invite link sent to ${user['username']}")),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                                        child: const Text('Send Link'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return;
                            }

                            await FirebaseFirestore.instance
                                .collection('chats')
                                .doc(widget.chatId)
                                .update({
                              'participants': FieldValue.arrayUnion([user['id']]),
                              'participants_data.${user['id']}': {
                                'role': 'member',
                                'joined_at': FieldValue.serverTimestamp(),
                              },
                              'member_count': FieldValue.increment(1),
                            });

                            await FirebaseFirestore.instance
                                .collection('chats')
                                .doc(widget.chatId)
                                .collection('messages')
                                .add({
                              'type': 'system',
                              'content': '${user['username']} was added by ${authProvider.userName ?? 'an admin'}',
                              'created_at': FieldValue.serverTimestamp(),
                            });

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Added ${user['username']}')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            minimumSize: const Size(60, 32),
                          ),
                          child: const Text('Add', style: TextStyle(fontSize: 12)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: 40,
      backgroundColor: const Color(0xFF1a103c),
      child: Icon(
        widget.isChannel ? Icons.campaign : Icons.group,
        size: 40,
        color: const Color(0xFF8B5CF6),
      ),
    );
  }

  Widget _buildMemberAvatar(String? avatarUrl, String? username) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFF1a103c),
      child: Text(
        (username ?? 'U')[0].toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: (color ?? const Color(0xFF8B5CF6)).withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (color ?? const Color(0xFF8B5CF6)).withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color ?? const Color(0xFF8B5CF6)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color ?? const Color(0xFF8B5CF6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsPreview(Map<String, dynamic> data) {
    final settings = data['settings'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          _buildSettingRow(
            icon: Icons.chat_bubble,
            label: 'Chat Enabled',
            value: !(settings['chat_disabled'] ?? false),
          ),
          _buildSettingRow(
            icon: Icons.attach_file,
            label: 'File Sharing',
            value: !(settings['file_sharing_disabled'] ?? false),
          ),
          _buildSettingRow(
            icon: Icons.poll,
            label: 'Polls',
            value: settings['polls_enabled'] ?? true,
          ),
          _buildSettingRow(
            icon: Icons.emoji_emotions,
            label: 'Reactions',
            value: settings['reactions_enabled'] ?? true,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String label,
    required bool value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white54),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: value ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }
}

// Settings sheet for owner/admin
class GroupSettingsSheet extends StatefulWidget {
  final String chatId;
  final String currentRole;
  final bool isChannel;

  const GroupSettingsSheet({
    super.key,
    required this.chatId,
    required this.currentRole,
    required this.isChannel,
  });

  @override
  State<GroupSettingsSheet> createState() => _GroupSettingsSheetState();
}

class _GroupSettingsSheetState extends State<GroupSettingsSheet> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final settings = data['settings'] as Map<String, dynamic>? ?? {};
        final isOwner = widget.currentRole == 'owner';

        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Group Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _buildToggle(
                      label: 'Disable Chat',
                      subtitle: 'Only admins can send messages',
                      value: settings['chat_disabled'] ?? false,
                      onChanged: (v) => _updateSetting('chat_disabled', v),
                    ),
                    _buildToggle(
                      label: 'Disable File Sharing',
                      subtitle: 'Prevent members from sending files',
                      value: settings['file_sharing_disabled'] ?? false,
                      onChanged: (v) => _updateSetting('file_sharing_disabled', v),
                    ),
                    _buildToggle(
                      label: 'Announcements Only',
                      subtitle: 'Only admins can send announcements',
                      value: settings['announcements_only'] ?? false,
                      onChanged: isOwner ? (v) => _updateSetting('announcements_only', v) : null,
                    ),
                    _buildToggle(
                      label: 'Enable Polls',
                      value: settings['polls_enabled'] ?? true,
                      onChanged: (v) => _updateSetting('polls_enabled', v),
                    ),
                    _buildToggle(
                      label: 'Enable Reactions',
                      value: settings['reactions_enabled'] ?? true,
                      onChanged: (v) => _updateSetting('reactions_enabled', v),
                    ),
                    _buildToggle(
                      label: 'Allow Forwarding',
                      value: settings['forwarding_enabled'] ?? true,
                      onChanged: (v) => _updateSetting('forwarding_enabled', v),
                    ),
                    if (isOwner)
                      _buildToggle(
                        label: 'Enable Voice Chat',
                        value: settings['voice_chat_enabled'] ?? false,
                        onChanged: (v) => _updateSetting('voice_chat_enabled', v),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToggle({
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(label, style: const TextStyle(color: Colors.white)),
        subtitle: subtitle != null
            ? Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12))
            : null,
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF8B5CF6),
      ),
    );
  }

  Future<void> _updateSetting(String key, bool value) async {
    await Provider.of<ChatProvider>(context, listen: false).toggleSetting(widget.chatId, key, value);
  }
}

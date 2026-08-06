import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;
import '../../providers/chat_provider.dart';
import '../../services/cloudinary_service.dart';
import '../../services/invitation_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();
  final _inviteNameController = TextEditingController();

  String? _groupPhotoUrl;
  bool _isLoading = false;
  List<Map<String, dynamic>> _selectedMembers = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isChannel = false;
  String? _generatedLink;

  // Theme colors matching SetupProfileScreen
  static const Color _bgDark = Color(0xFF0A0A0F);
  static const Color _bgCard = Color(0xFF1a103c);
  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _cyan = Color(0xFF06B6D4);

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    _inviteNameController.dispose();
    super.dispose();
  }

  Future<void> _pickGroupPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? authProvider.mockUserId;

      if (userId == null) {
        throw Exception('Not authenticated');
      }

      final imageUrl = await CloudinaryService.uploadImage(
        File(pickedFile.path),
        'aurachat/groups/$userId'
      );

      if (imageUrl == null) {
        throw Exception('Upload failed');
      }

      setState(() => _groupPhotoUrl = imageUrl);
    } catch (e) {
      debugPrint('Photo upload failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo upload failed: $e. Continuing without photo.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;

      final snapshot = await firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .get();

      final filtered = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .where((u) => u['id'] != currentUserId)
          .toList();

      setState(() => _searchResults = filtered);
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }

  void _toggleMember(Map<String, dynamic> user) {
    setState(() {
      final index = _selectedMembers.indexWhere((m) => m['id'] == user['id']);
      if (index >= 0) {
        _selectedMembers.removeAt(index);
      } else {
        _selectedMembers.add(user);
      }
    });
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter a ${_isChannel ? "channel" : "group"} name');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final firestore = FirebaseFirestore.instance;
      final userId = authProvider.user?.uid ?? authProvider.mockUserId;
      final phoneNumber = authProvider.phoneNumber ?? '';

      if (userId == null) {
        throw Exception('Not authenticated');
      }

      final participants = [userId, ..._selectedMembers.map((m) => m['id'] as String)];
      final participantsData = <String, dynamic>{};

      for (final id in participants) {
        participantsData[id] = {
          'role': id == userId ? 'owner' : 'member',
          'joined_at': FieldValue.serverTimestamp(),
        };
      }

      final chatId = const Uuid().v4();

      await firestore.collection('chats').doc(chatId).set({
        'id': chatId,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        'avatar_url': _groupPhotoUrl,
        'type': _isChannel ? 'channel' : 'group',
        'created_by': userId,
        'created_by_phone': phoneNumber,
        'participants': participants,
        'participants_data': participantsData,
        'member_count': participants.length,
        'banned_users': [],
        'settings': {
          'chat_disabled': false,
          'file_sharing_disabled': false,
          'slow_mode_seconds': 0,
          'restrict_new_members_minutes': 0,
          'message_retention_days': 0,
          'welcome_message': 'Welcome to ${_nameController.text.trim()}!',
          'rules': 'Be respectful and kind to all members.',
          'announcements_only': false,
          'polls_enabled': true,
          'reactions_enabled': true,
          'forwarding_enabled': true,
          'voice_chat_enabled': false,
        },
        'pinned_messages': [],
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'last_message_at': FieldValue.serverTimestamp(),
        'last_message': _isChannel ? 'Channel created' : 'Group created',
      });

      // Create invitation link
      try {
        final inviteResult = await InvitationService.createInvitation(
          chatId: chatId,
          chatName: _nameController.text.trim(),
          chatType: _isChannel ? 'channel' : 'group',
          createdBy: userId,
          customName: _inviteNameController.text.trim().isNotEmpty
              ? _inviteNameController.text.trim()
              : null,
        );
        setState(() => _generatedLink = inviteResult['link'] as String?);
      } catch (e) {
        debugPrint('Invitation creation failed: $e');
      }

      await chatProvider.loadChats();

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_isChannel ? "Channel" : "Group"} created successfully!'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showError('Error: $e');
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _bgDark,
              _bgCard,
              Color(0xFF0f172a),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [_purple, _cyan],
                        ).createShader(bounds),
                        child: Text(
                          _isChannel ? 'New Channel' : 'New Group',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    else
                      TextButton(
                        onPressed: _createGroup,
                        child: const Text('Create', style: TextStyle(color: _cyan, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo upload
                      Center(
                        child: GestureDetector(
                          onTap: _pickGroupPhoto,
                          child: Stack(
                            children: [
                              _buildGroupAvatar(),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(colors: [_purple, _cyan]),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Tap to add photo',
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4)),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Name field
                      _buildGlassInput(
                        label: _isChannel ? 'Channel Name' : 'Group Name',
                        hint: _isChannel ? 'Enter channel name' : 'Enter group name',
                        icon: Icons.edit,
                        controller: _nameController,
                      ),
                      const SizedBox(height: 16),

                      // Description field
                      _buildGlassInput(
                        label: 'Description',
                        hint: 'Add a description (optional)',
                        icon: Icons.description,
                        controller: _descriptionController,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // Invite link name
                      _buildGlassInput(
                        label: 'Invitation Link Name',
                        hint: 'e.g., my-awesome-group (optional)',
                        icon: Icons.link,
                        controller: _inviteNameController,
                      ),
                      const SizedBox(height: 16),

                      // Channel toggle
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _purple.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.campaign, color: _purple, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Create as Channel',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'One-way messaging (only admins can post)',
                                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isChannel,
                              onChanged: (v) => setState(() => _isChannel = v),
                              activeColor: _purple,
                            ),
                          ],
                        ),
                      ),

                      if (_generatedLink != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Link: $_generatedLink',
                                  style: const TextStyle(fontSize: 12, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Search users
                      _buildGlassInput(
                        label: 'Add Members',
                        hint: 'Search users to add... (optional)',
                        icon: Icons.search,
                        controller: _searchController,
                        onChanged: _searchUsers,
                      ),

                      // Selected members
                      if (_selectedMembers.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 90,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedMembers.length,
                            itemBuilder: (context, index) {
                              final member = _selectedMembers[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Column(
                                  children: [
                                    Stack(
                                      children: [
                                        _buildMemberAvatar(member['avatar_url'], member['username']),
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: GestureDetector(
                                            onTap: () => _toggleMember(member),
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      member['username'] ?? 'Unknown',
                                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // Search results
                      if (_searchResults.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ..._searchResults.map((user) {
                          final isSelected = _selectedMembers.any((m) => m['id'] == user['id']);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: _buildMemberAvatar(user['avatar_url'], user['username']),
                              title: Text(user['username'] ?? 'Unknown', style: const TextStyle(color: Colors.white)),
                              subtitle: Text(user['phone'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.4))),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle, color: _purple)
                                  : const Icon(Icons.add_circle_outline, color: Colors.white54),
                              onTap: () => _toggleMember(user),
                            ),
                          );
                        }).toList(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupAvatar() {
    if (_groupPhotoUrl != null && _groupPhotoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 50,
        backgroundColor: _purple.withOpacity(0.2),
        backgroundImage: NetworkImage(_groupPhotoUrl!),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: 50,
      backgroundColor: _purple.withOpacity(0.2),
      child: Icon(
        _isChannel ? Icons.campaign : Icons.group,
        size: 50,
        color: _purple,
      ),
    );
  }

  Widget _buildMemberAvatar(String? avatarUrl, String? username) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: _purple.withOpacity(0.2),
      child: Text(
        (username ?? 'U')[0].toUpperCase(),
        style: const TextStyle(fontSize: 20, color: Colors.white),
      ),
    );
  }

  Widget _buildGlassInput({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.7)),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
              prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.3)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();

  String? _groupPhotoUrl;
  bool _isLoading = false;
  List<Map<String, dynamic>> _selectedMembers = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isChannel = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickGroupPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // FIXED: Use mockUserId as fallback
      final userId = authProvider.user?.id ?? authProvider.mockUserId;

      if (userId == null) {
        throw Exception('Not authenticated');
      }

      final fileBytes = await pickedFile.readAsBytes();
      final fileName = '$userId/${const Uuid().v4()}.jpg';

      await supabase.storage.from('groups').uploadBinary(
        fileName,
        fileBytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );

      final url = supabase.storage.from('groups').getPublicUrl(fileName);
      setState(() => _groupPhotoUrl = url);
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
      final supabase = Supabase.instance.client;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // FIXED: Use mockUserId as fallback
      final currentUserId = authProvider.user?.id ?? authProvider.mockUserId;

      final response = await supabase
          .from('users')
          .select('id, username, avatar_url, phone')
          .ilike('username', '%$query%')
          .limit(20);

      final filtered = List<Map<String, dynamic>>.from(response)
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final supabase = Supabase.instance.client;
      // FIXED: Use mockUserId as fallback
      final userId = authProvider.user?.id ?? authProvider.mockUserId;

      if (userId == null) {
        throw Exception('Not authenticated');
      }

      final groupId = const Uuid().v4();
      final now = DateTime.now().toIso8601String();

      await supabase.from('chats').insert({
        'id': groupId,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isNotEmpty 
            ? _descriptionController.text.trim() 
            : null,
        'avatar_url': _groupPhotoUrl,
        'type': _isChannel ? 'channel' : 'group',
        'created_by': userId,
        'created_at': now,
        'updated_at': now,
      });

      await supabase.from('chat_participants').insert({
        'chat_id': groupId,
        'user_id': userId,
        'role': 'admin',
        'joined_at': now,
      });

      for (final member in _selectedMembers) {
        await supabase.from('chat_participants').insert({
          'chat_id': groupId,
          'user_id': member['id'],
          'role': 'member',
          'joined_at': now,
        });
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isChannel ? 'New Channel' : 'New Group'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            TextButton(
              onPressed: _createGroup,
              child: const Text('Create', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickGroupPhoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                        backgroundImage: _groupPhotoUrl != null
                            ? NetworkImage(_groupPhotoUrl!)
                            : null,
                        child: _groupPhotoUrl == null
                            ? Icon(
                                _isChannel ? Icons.campaign : Icons.group,
                                size: 50,
                                color: Theme.of(context).primaryColor,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: _isChannel ? 'Channel Name' : 'Group Name',
                    hintText: _isChannel ? 'Enter channel name' : 'Enter group name',
                    prefixIcon: const Icon(Icons.edit),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'Add a description (optional)',
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _isChannel,
                      onChanged: (value) => setState(() => _isChannel = value ?? false),
                    ),
                    const Text('Create as Channel (one-way messaging)'),
                  ],
                ),
              ],
            ),
          ),

          if (_selectedMembers.isNotEmpty) ...[
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            CircleAvatar(
                              radius: 28,
                              backgroundImage: member['avatar_url'] != null
                                  ? NetworkImage(member['avatar_url'])
                                  : null,
                              child: member['avatar_url'] == null
                                  ? Text(
                                      (member['username'] ?? 'U')[0].toUpperCase(),
                                      style: const TextStyle(fontSize: 20),
                                    )
                                  : null,
                            ),
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
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          member['username'] ?? 'Unknown',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],

          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _searchUsers,
              decoration: InputDecoration(
                hintText: 'Search users to add... (optional)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults = []);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          Expanded(
            child: _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search,
                          size: 64,
                          color: Colors.grey.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'Search for users to add (optional)'
                              : 'No users found',
                          style: TextStyle(color: Colors.grey.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      final isSelected = _selectedMembers.any((m) => m['id'] == user['id']);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user['avatar_url'] != null
                              ? NetworkImage(user['avatar_url'])
                              : null,
                          child: user['avatar_url'] == null
                              ? Text((user['username'] ?? 'U')[0].toUpperCase())
                              : null,
                        ),
                        title: Text(user['username'] ?? 'Unknown'),
                        subtitle: Text(user['phone'] ?? ''),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
                            : const Icon(Icons.add_circle_outline),
                        onTap: () => _toggleMember(user),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

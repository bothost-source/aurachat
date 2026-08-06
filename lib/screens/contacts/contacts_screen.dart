import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;
import '../../providers/chat_provider.dart';
import '../../services/status_service.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  // Theme colors
  static const Color _bgDark = Color(0xFF0A0A0F);
  static const Color _bgCard = Color(0xFF1a103c);
  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _cyan = Color(0xFF06B6D4);

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    try {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .get();

      final results = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        if (doc.id == currentUserId) continue;

        // Check if already saved
        final isSaved = await StatusService.isContact(currentUserId!, doc.id);

        results.add({
          'id': doc.id,
          ...doc.data(),
          'is_saved': isSaved,
        });
      }

      setState(() => _searchResults = results);
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }

  Future<void> _saveContact(String contactUserId) async {
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;

    if (currentUserId == null) return;

    final success = await StatusService.saveContact(currentUserId, contactUserId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact saved! You can now see their status.'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh search results
      _searchUsers(_searchController.text);

      // Refresh chat provider contacts
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      await chatProvider.loadContacts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bgDark, _bgCard, Color(0xFF0f172a)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                        child: const Text(
                          'Contacts',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    onChanged: _searchUsers,
                    decoration: InputDecoration(
                      hintText: 'Search by username...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.3)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white54),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults = []);
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Search results
              if (_searchResults.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Search Results',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ..._searchResults.map((user) => _buildUserTile(user, isSearchResult: true)),
                const Divider(color: Colors.white12, indent: 24, endIndent: 24),
              ],

              // Saved contacts
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    chatProvider.contacts.isEmpty ? 'No saved contacts' : 'Saved Contacts',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: chatProvider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: _purple))
                    : chatProvider.contacts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: Colors.white.withOpacity(0.1)),
                                const SizedBox(height: 16),
                                Text(
                                  'No contacts yet',
                                  style: TextStyle(color: Colors.white.withOpacity(0.3)),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Search above to find and save contacts',
                                  style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: chatProvider.contacts.length,
                            itemBuilder: (context, index) {
                              final contact = chatProvider.contacts[index];
                              return _buildUserTile(contact, isSearchResult: false);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, {required bool isSearchResult}) {
    final username = user['username'] ?? 'Unknown';
    final avatar = user['avatar_url'];
    final phone = user['phone'] ?? '';
    final isSaved = user['is_saved'] == true || !isSearchResult;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: avatar == null
                ? const LinearGradient(colors: [_purple, _cyan])
                : null,
            image: avatar != null
                ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover)
                : null,
          ),
          child: avatar == null
              ? Text(
                  username[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        title: Text(
          username,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          phone,
          style: TextStyle(color: Colors.white.withOpacity(0.4)),
        ),
        trailing: isSearchResult && !isSaved
            ? ElevatedButton(
                onPressed: () => _saveContact(user['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Save'),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.message, color: _purple),
                    onPressed: () async {
                      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                      final chat = await chatProvider.startDirectChat(user['id']);
                      if (chat != null && context.mounted) {
                        Navigator.pushNamed(context, '/chat', arguments: chat);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.call, color: _cyan),
                    onPressed: () {},
                  ),
                ],
              ),
      ),
    );
  }
}

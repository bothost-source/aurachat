import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../providers/auth_provider.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  List<Map<String, dynamic>> _myStatuses = [];
  List<Map<String, dynamic>> _contactsStatuses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load my statuses (not expired)
      final myResponse = await supabase
          .from('statuses')
          .select('*, status_views(count)')
          .eq('user_id', userId)
          .gte('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      // Load contacts' statuses
      final contactsResponse = await supabase
          .from('statuses')
          .select('*, users(username, avatar_url)')
          .neq('user_id', userId)
          .gte('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      setState(() {
        _myStatuses = List<Map<String, dynamic>>.from(myResponse);
        _contactsStatuses = List<Map<String, dynamic>>.from(contactsResponse);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Load statuses error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteStatus(String statusId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('statuses').delete().eq('id', statusId);
      await _loadStatuses();
    } catch (e) {
      debugPrint('Delete status error: $e');
    }
  }

  void _showStatusViewers(Map<String, dynamic> status) async {
    try {
      final supabase = Supabase.instance.client;
      final viewers = await supabase
          .from('status_views')
          .select('*, users(username, avatar_url)')
          .eq('status_id', status['id']);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Viewed by ${viewers.length} people',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: viewers.length,
                  itemBuilder: (context, index) {
                    final viewer = viewers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: viewer['users']?['avatar_url'] != null
                            ? NetworkImage(viewer['users']['avatar_url'])
                            : null,
                        child: viewer['users']?['avatar_url'] == null
                            ? Text((viewer['users']?['username'] ?? 'U')[0].toUpperCase())
                            : null,
                      ),
                      title: Text(viewer['users']?['username'] ?? 'Unknown'),
                      subtitle: Text(
                        timeago.format(DateTime.parse(viewer['viewed_at'])),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Show viewers error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Status'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Status settings
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatuses,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // My Status Section
                  _buildSectionHeader(context, 'My Status'),
                  const SizedBox(height: 8),

                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/create_status'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundImage: authProvider.userPhotoUrl != null
                                    ? NetworkImage(authProvider.userPhotoUrl!)
                                    : null,
                                child: authProvider.userPhotoUrl == null
                                    ? Icon(
                                        Icons.person,
                                        size: 28,
                                        color: Theme.of(context).primaryColor,
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(context).scaffoldBackgroundColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'My Status',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  _myStatuses.isEmpty
                                      ? 'Tap to add status'
                                      : '${_myStatuses.length} active status${_myStatuses.length > 1 ? 'es' : ''}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // My Active Statuses
                  if (_myStatuses.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ..._myStatuses.map((status) => _buildStatusItem(
                      context,
                      status: status,
                      isMine: true,
                      onTap: () => _showStatusViewers(status),
                      onDelete: () => _deleteStatus(status['id']),
                    )),
                  ],

                  const SizedBox(height: 24),

                  // Contacts' Statuses
                  _buildSectionHeader(context, 'Recent Updates'),
                  const SizedBox(height: 8),

                  if (_contactsStatuses.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.circle_outlined,
                              size: 64,
                              color: Colors.grey.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No recent updates',
                              style: TextStyle(color: Colors.grey.withOpacity(0.7)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._contactsStatuses.map((status) => _buildStatusItem(
                      context,
                      status: status,
                      isMine: false,
                      onTap: () => _viewStatus(status),
                    )),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/create_status'),
        child: const Icon(Icons.camera_alt),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildStatusItem(
    BuildContext context, {
    required Map<String, dynamic> status,
    required bool isMine,
    required VoidCallback onTap,
    VoidCallback? onDelete,
  }) {
    final user = isMine ? null : status['users'];
    final createdAt = DateTime.parse(status['created_at']);
    final expiresAt = DateTime.parse(status['expires_at']);
    final timeLeft = expiresAt.difference(DateTime.now());
    final hoursLeft = timeLeft.inHours;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).primaryColor,
              width: 2,
            ),
          ),
          child: CircleAvatar(
            radius: 26,
            backgroundImage: isMine
                ? (Provider.of<AuthProvider>(context).userPhotoUrl != null
                    ? NetworkImage(Provider.of<AuthProvider>(context).userPhotoUrl!)
                    : null)
                : (user?['avatar_url'] != null
                    ? NetworkImage(user['avatar_url'])
                    : null),
            child: isMine
                ? (Provider.of<AuthProvider>(context).userPhotoUrl == null
                    ? const Icon(Icons.person)
                    : null)
                : (user?['avatar_url'] == null
                    ? Text((user?['username'] ?? 'U')[0].toUpperCase())
                    : null),
          ),
        ),
        title: Text(
          isMine ? 'My Status' : (user?['username'] ?? 'Unknown'),
        ),
        subtitle: Text(
          '${timeago.format(createdAt)} · ${hoursLeft}h left',
        ),
        trailing: isMine
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status['status_views'] != null)
                    Text(
                      '${status['status_views']?['count'] ?? 0} 👁',
                      style: const TextStyle(fontSize: 12),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: onDelete,
                  ),
                ],
              )
            : const Icon(Icons.play_arrow),
        onTap: onTap,
      ),
    );
  }

  void _viewStatus(Map<String, dynamic> status) async {
    // Mark as viewed
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId != null) {
        await supabase.from('status_views').upsert({
          'status_id': status['id'],
          'user_id': userId,
          'viewed_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Mark viewed error: $e');
    }

    // Show status viewer
    showDialog(
      context: context,
      builder: (context) => StatusViewerDialog(status: status),
    );
  }
}

class StatusViewerDialog extends StatefulWidget {
  final Map<String, dynamic> status;

  const StatusViewerDialog({super.key, required this.status});

  @override
  State<StatusViewerDialog> createState() => _StatusViewerDialogState();
}

class _StatusViewerDialogState extends State<StatusViewerDialog> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _startProgress();
  }

  void _startProgress() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted && _progress < 1.0) {
        setState(() {
          _progress += 0.01;
        });
        _startProgress();
      } else if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final user = status['users'];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Status Content
            if (status['media_url'] != null)
              Image.network(
                status['media_url'],
                fit: BoxFit.contain,
              )
            else
              Center(
                child: Text(
                  status['text'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ),

            // Progress Bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 8,
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),

            // User Info
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 16,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: user?['avatar_url'] != null
                        ? NetworkImage(user['avatar_url'])
                        : null,
                    child: user?['avatar_url'] == null
                        ? Text((user?['username'] ?? 'U')[0].toUpperCase())
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    user?['username'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Close Button
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

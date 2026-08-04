import 'package:flutter/material.dart';
import '../../services/invitation_service.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;
import '../../providers/chat_provider.dart';

class InvitationScreen extends StatefulWidget {
  final String? inviteCode;
  const InvitationScreen({super.key, this.inviteCode});

  @override
  State<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends State<InvitationScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _preview;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.inviteCode != null && widget.inviteCode!.isNotEmpty) {
      _codeController.text = widget.inviteCode!;
      _processInvitation(widget.inviteCode!);
    }
  }

  Future<void> _processInvitation(String code) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _preview = null;
    });

    try {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? authProvider.mockUserId;
      final userName = authProvider.phoneNumber ?? 'User';

      if (userId == null) {
        setState(() {
          _error = 'You must be logged in to join';
          _isLoading = false;
        });
        return;
      }

      final result = await InvitationService.processInvitation(
        code: code.trim(),
        userId: userId,
        userName: userName,
      );

      if (result['success'] == true) {
        if (result['already_member'] == true) {
          setState(() {
            _error = 'You are already a member of this ${result['chat_type']}';
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _preview = result;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result['message'] ?? 'Invalid invitation';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _joinGroup() async {
    if (_preview == null) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? authProvider.mockUserId;
      final userName = authProvider.phoneNumber ?? 'User';

      if (userId == null) return;

      final result = await InvitationService.joinWithInvitation(
        invitationId: _preview!['invitation_id'] as String,
        userId: userId,
        userName: userName,
      );

      setState(() => _isLoading = false);

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Joined ${result['chat_name']} successfully!')),
          );
          // Refresh chat list
          Provider.of<ChatProvider>(context, listen: false).loadChats();
          Navigator.pop(context, true);
        }
      } else {
        setState(() => _error = result['message'] ?? 'Failed to join');
      }
    } catch (e) {
      setState(() {
        _error = 'Error joining: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: const Text('Join Group'),
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Code input
            if (_preview == null) ...[
              const Text(
                'Enter Invitation Code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Paste the invitation link or enter the code to join a group or channel.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _codeController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g., my-awesome-group',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.link, color: Colors.white54),
                  suffixIcon: _codeController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _codeController.clear();
                          setState(() {
                            _error = null;
                            _preview = null;
                          });
                        },
                      )
                    : null,
                ),
                onSubmitted: (value) => _processInvitation(value),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading
                    ? null
                    : () => _processInvitation(_codeController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Check Invitation'),
                ),
              ),
            ],

            // Preview
            if (_preview != null) ...[
              _buildPreviewCard(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _joinGroup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Join'),
                    ),
                  ),
                ],
              ),
            ],

            // Error
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final chatName = _preview!['chat_name'] ?? 'Unknown';
    final chatType = _preview!['chat_type'] ?? 'group';
    final isChannel = chatType == 'channel';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8B5CF6).withOpacity(0.2),
            const Color(0xFF06B6D4).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isChannel ? Icons.campaign : Icons.group,
              size: 48,
              color: const Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            chatName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isChannel ? Colors.orange.withOpacity(0.2) : const Color(0xFF8B5CF6).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isChannel ? 'CHANNEL' : 'GROUP',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isChannel ? Colors.orange : const Color(0xFF8B5CF6),
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isChannel
              ? 'You will be able to view messages posted by admins.'
              : 'You will be able to chat with all members of this group.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people, size: 16, color: Colors.white.withOpacity(0.5)),
              const SizedBox(width: 6),
              Text(
                'Members will be shown after joining',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

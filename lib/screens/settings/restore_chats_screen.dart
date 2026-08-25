import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;

class RestoreChatsScreen extends StatefulWidget {
  const RestoreChatsScreen({super.key});

  @override
  State<RestoreChatsScreen> createState() => _RestoreChatsScreenState();
}

class _RestoreChatsScreenState extends State<RestoreChatsScreen> {
  bool _isRestoring = false;
  String _statusMessage = '';
  double _progress = 0;
  int _totalChats = 0;
  int _restoredChats = 0;
  int _restoredMessages = 0;

  Future<void> _pickBackupFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.single.path;
      if (filePath == null) return;

      final file = File(filePath);
      if (!await file.exists()) {
        _showError('Backup file not found');
        return;
      }

      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate backup structure
      if (!backupData.containsKey('chats') || !backupData.containsKey('user_id')) {
        _showError('Invalid backup file format');
        return;
      }

      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;

      if (currentUserId == null) {
        _showError('Not authenticated');
        return;
      }

      // Optional: warn if backup is from different user
      final backupUserId = backupData['user_id'] as String?;
      if (backupUserId != null && backupUserId != currentUserId) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => _buildGlassDialog(
            title: 'Different Account',
            content: 'This backup belongs to a different account. Restore anyway?',
            confirmText: 'Restore',
            confirmColor: Colors.orange,
          ),
        );
        if (proceed != true) return;
      }

      final chats = backupData['chats'] as List<dynamic>;
      if (chats.isEmpty) {
        _showError('No chats found in backup');
        return;
      }

      setState(() {
        _isRestoring = true;
        _statusMessage = 'Preparing restore...';
        _totalChats = chats.length;
        _restoredChats = 0;
        _restoredMessages = 0;
        _progress = 0;
      });

      await _restoreChats(chats, currentUserId);

    } catch (e) {
      _showError('Failed to read backup: $e');
    }
  }

  Future<void> _restoreChats(List<dynamic> chats, String userId) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    int batchCount = 0;
    const maxBatchSize = 500;

    try {
      for (int i = 0; i < chats.length; i++) {
        final chat = chats[i] as Map<String, dynamic>;
        final chatId = chat['chat_id'] as String? ?? 'restored_${DateTime.now().millisecondsSinceEpoch}_$i';
        final participants = (chat['participants'] as List<dynamic>?)?.cast<String>() ?? [userId];
        
        // Ensure current user is in participants
        if (!participants.contains(userId)) {
          participants.add(userId);
        }

        // Create/merge chat document
        final chatRef = firestore.collection('chats').doc(chatId);
        batch.set(chatRef, {
          'participants': participants,
          'restored_at': FieldValue.serverTimestamp(),
          'is_restored': true,
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        batchCount++;

        // Restore messages
        final messages = chat['messages'] as List<dynamic>? ?? [];
        for (final msg in messages) {
          final msgData = msg as Map<String, dynamic>;
          final msgRef = chatRef.collection('messages').doc();
          
          // Convert ISO string timestamp back to Timestamp if present
          final timestampStr = msgData['timestamp'] as String?;
          final timestamp = timestampStr != null 
              ? Timestamp.fromDate(DateTime.parse(timestampStr))
              : FieldValue.serverTimestamp();

          batch.set(msgRef, {
            'sender_id': msgData['sender_id'] ?? userId,
            'text': msgData['text'] ?? '',
            'type': msgData['type'] ?? 'text',
            'media_url': msgData['media_url'],
            'timestamp': timestamp,
            'restored': true,
          });
          batchCount++;

          if (batchCount >= maxBatchSize) {
            await batch.commit();
            batchCount = 0;
          }

          _restoredMessages++;
        }

        _restoredChats++;
        
        if (mounted) {
          setState(() {
            _progress = (_restoredChats / _totalChats);
            _statusMessage = 'Restoring chat $_restoredChats of $_totalChats...';
          });
        }
      }

      // Commit remaining
      if (batchCount > 0) {
        await batch.commit();
      }

      if (mounted) {
        setState(() {
          _isRestoring = false;
          _statusMessage = 'Restore complete!';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restored $_restoredChats chats with $_restoredMessages messages'),
            backgroundColor: const Color(0xFF8B5CF6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _isRestoring = false;
          _statusMessage = 'Restore failed';
        });
      }
      _showError('Restore failed: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
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
              Color(0xFF0A0A0F),
              Color(0xFF1a103c),
              Color(0xFF0d1b2a),
              Color(0xFF0A0A0F),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white.withOpacity(0.7),
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Restore Chats',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Info Card
                    _buildGlassInfoCard(
                      icon: Icons.restore_page_outlined,
                      title: 'Restore from Backup',
                      description: 'Select a JSON backup file to restore your chat history. The backup file should be one you previously exported from AURA Chat.',
                    ),

                    const SizedBox(height: 24),

                    // How it works
                    _buildSectionHeader('How It Works'),
                    _buildStepTile(
                      number: '1',
                      title: 'Select Backup File',
                      description: 'Choose the .json backup file from your device storage or email downloads.',
                    ),
                    _buildStepTile(
                      number: '2',
                      title: 'Verify & Restore',
                      description: 'We\'ll validate the backup and restore all chats and messages to your account.',
                    ),
                    _buildStepTile(
                      number: '3',
                      title: 'Done',
                      description: 'Your restored chats will appear in your chat list with a restored tag.',
                    ),

                    const SizedBox(height: 32),

                    // Restore Button or Progress
                    if (_isRestoring) ...[
                      _buildProgressCard(),
                    ] else ...[
                      _buildGlassActionButton(
                        icon: Icons.folder_open_outlined,
                        title: 'Select Backup File',
                        subtitle: 'Browse for .json backup file',
                        onTap: _pickBackupFile,
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Warning
                    _buildGlassWarningCard(
                      title: 'Important',
                      description: 'Restoring will merge backup chats with your existing chats. Messages with the same content may appear duplicated. Media files (photos, videos) are not included in the backup — only text and metadata.',
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassInfoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF8B5CF6).withOpacity(0.8),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStepTile({
    required String number,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.06),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      number,
                      style: const TextStyle(
                        color: Color(0xFF8B5CF6),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: -5,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF8B5CF6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(0.3),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$_restoredChats / $_totalChats chats • $_restoredMessages messages',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassWarningCard({
    required String title,
    required String description,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.orange.withOpacity(0.08),
                Colors.orange.withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.orange.withOpacity(0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassDialog({
    required String title,
    required String content,
    required String confirmText,
    required Color confirmColor,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 48,
                  color: confirmColor,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: confirmColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(confirmText),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

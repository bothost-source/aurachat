import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/settings_provider.dart';
 import 'package:dio/dio.dart'; 

class ChatScreen extends StatefulWidget {
  final String? chatId;
  final String? chatName;
  final String? chatAvatar;
  final bool? isGroup;

  const ChatScreen({
    super.key,
    this.chatId,
    this.chatName,
    this.chatAvatar,
    this.isGroup,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _showEmojiPicker = false;
  bool _isRecording = false;
  bool _isPlayingAudio = false;
  String? _currentlyPlayingAudioId;
  List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _messageSubscription;
  bool _isLoading = true;
  String? _replyingTo;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    _messageSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (widget.chatId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('messages')
          .select('*, users(username, avatar_url)')
          .eq('chat_id', widget.chatId!)
          .order('created_at', ascending: true);

      setState(() {
        _messages = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint('Load messages error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToMessages() {
    if (widget.chatId == null) return;

    final supabase = Supabase.instance.client;
    _messageSubscription = supabase
        .channel('messages:${widget.chatId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: widget.chatId!,
          ),
          callback: (payload) {
            setState(() {
              _messages.add(payload.newRecord);
            });
            _scrollToBottom();
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() => _showEmojiPicker = false);

    await _sendMessage(
      type: 'text',
      content: text,
    );
  }

  Future<void> _sendMessage({
    required String type,
    required String content,
    String? mediaUrl,
    String? fileName,
    String? fileSize,
  }) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supabase = Supabase.instance.client;
      final userId = authProvider.user?.id;

      if (userId == null || widget.chatId == null) return;

      final message = {
        'id': const Uuid().v4(),
        'chat_id': widget.chatId!,
        'sender_id': userId,
        'type': type,
        'content': content,
        'media_url': mediaUrl,
        'file_name': fileName,
        'file_size': fileSize,
        'reply_to': _replyingTo,
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
      };

      // Optimistic update
      setState(() {
        _messages.add({
          ...message,
          'users': {
            'username': authProvider.userName,
            'avatar_url': authProvider.userPhotoUrl,
          }
        });
        _replyingTo = null;
      });

      _scrollToBottom();

      await supabase.from('messages').insert(message);
    } catch (e) {
      debugPrint('Send message error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      await _uploadAndSendMedia(
        file: File(pickedFile.path),
        type: 'image',
      );
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      await _uploadAndSendMedia(
        file: File(pickedFile.path),
        type: 'image',
      );
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;

      if (file.path != null) {
        await _uploadAndSendMedia(
          file: File(file.path!),
          type: 'file',
          fileName: file.name,
          fileSize: _formatFileSize(file.size),
        );
      }
    }
  }

  Future<void> _uploadAndSendMedia({
    required File file,
    required String type,
    String? fileName,
    String? fileSize,
  }) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supabase = Supabase.instance.client;
      final userId = authProvider.user?.id;

      if (userId == null) return;

      // Show uploading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Uploading...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      final fileBytes = await file.readAsBytes();
      final ext = file.path.split('.').last;
      final uploadName = 'chat_media/${widget.chatId}/${const Uuid().v4()}.$ext';

      await supabase.storage.from('chat_media').uploadBinary(
        uploadName,
        fileBytes,
        fileOptions: FileOptions(contentType: _getMimeType(ext)),
      );

      final mediaUrl = supabase.storage.from('chat_media').getPublicUrl(uploadName);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      await _sendMessage(
        type: type,
        content: fileName ?? 'Media',
        mediaUrl: mediaUrl,
        fileName: fileName,
        fileSize: fileSize,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${const Uuid().v4()}.m4a';

      await _audioRecorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint('Recording error: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);

      if (path != null) {
        await _uploadAndSendMedia(
          file: File(path),
          type: 'audio',
          fileName: 'Voice Message',
          fileSize: 'Audio',
        );
      }
    } catch (e) {
      debugPrint('Stop recording error: $e');
    }
  }

  Future<void> _playAudio(String messageId, String audioUrl) async {
    try {
      if (_currentlyPlayingAudioId == messageId) {
        await _audioPlayer.stop();
        setState(() {
          _isPlayingAudio = false;
          _currentlyPlayingAudioId = null;
        });
      } else {
        await _audioPlayer.setUrl(audioUrl);
        await _audioPlayer.play();

        setState(() {
          _isPlayingAudio = true;
          _currentlyPlayingAudioId = messageId;
        });

        _audioPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            setState(() {
              _isPlayingAudio = false;
              _currentlyPlayingAudioId = null;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Play audio error: $e');
    }
  }

  Future<void> _openFile(String url, String? fileName) async {
    try {
      final dir = await getTemporaryDirectory();
      final ext = fileName?.split('.').last ?? 'file';
      final localPath = '${dir.path}/${const Uuid().v4()}.$ext';

      // Download file
      final dio = Dio();
      await dio.download(url, localPath);

      await OpenFilex.open(localPath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open file: $e')),
      );
    }
  }

  void _showImageViewer(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PhotoView(
              imageProvider: NetworkImage(imageUrl),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: widget.chatAvatar != null
                  ? NetworkImage(widget.chatAvatar!)
                  : null,
              child: widget.chatAvatar == null
                  ? Icon(
                      widget.isGroup == true ? Icons.group : Icons.person,
                      size: 20,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chatName ?? 'Chat',
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Online',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 80,
                              color: Theme.of(context).primaryColor.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                color: Colors.grey.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start the conversation!',
                              style: TextStyle(
                                color: Colors.grey.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message['sender_id'] == authProvider.user?.id;
                          final showAvatar = !isMe && (index == 0 || 
                              _messages[index - 1]['sender_id'] != message['sender_id']);

                          return _buildMessageBubble(
                            context,
                            message: message,
                            isMe: isMe,
                            showAvatar: showAvatar,
                          );
                        },
                      ),
          ),

          // Reply indicator
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).cardColor,
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replying to message',
                      style: TextStyle(
                        color: Colors.grey.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),

          // Emoji Picker
         if (_showEmojiPicker)
  SizedBox(
    height: 250,
    child: EmojiPicker(
      onEmojiSelected: (category, emoji) {
        _messageController.text += emoji.emoji;
      },
      config: Config(                          // ✅ Add config: Config(
        emojiViewConfig: EmojiViewConfig(       // ✅ EmojiViewConfig inside Config
          columns: 7,                           // ✅ Fix: 7, (not 7))
          emojiSizeMax: 32,
          verticalSpacing: 0,
          horizontalSpacing: 0,
          gridPadding: EdgeInsets.zero,
          initCategory: Category.RECENT,
          bgColor: Theme.of(context).scaffoldBackgroundColor,
          indicatorColor: Theme.of(context).primaryColor,
          iconColor: Colors.grey,
          iconColorSelected: Theme.of(context).primaryColor,
          backspaceColor: Theme.of(context).primaryColor,
          skinToneDialogBgColor: Theme.of(context).cardColor,
          skinToneIndicatorColor: Colors.grey,
          enableSkinTones: true,
          showRecentsTab: true,
          recentsLimit: 28,
          replaceEmojiOnLimitExceed: false,
          noRecents: const Text(
            'No Recents',
            style: TextStyle(fontSize: 20, color: Colors.black26),
            textAlign: TextAlign.center,
          ),
          loadingIndicator: const SizedBox.shrink(),
          tabIndicatorAnimDuration: kTabScrollDuration,
          categoryIcons: const CategoryIcons(),
          buttonMode: ButtonMode.MATERIAL,
          checkPlatformCompatibility: true,
        ),                                     // ✅ Close EmojiViewConfig
      ),                                       // ✅ Close Config
    ),
  ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Attachment menu
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showAttachmentMenu(context),
                  ),

                  // Emoji toggle
                  IconButton(
                    icon: Icon(
                      _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _showEmojiPicker = !_showEmojiPicker;
                      });
                      if (_showEmojiPicker) {
                        FocusScope.of(context).unfocus();
                      }
                    },
                  ),

                  // Text field or recording indicator
                  Expanded(
                    child: _isRecording
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.mic, color: Colors.red),
                                const SizedBox(width: 8),
                                Text(
                                  'Recording...',
                                  style: TextStyle(color: Colors.red.withOpacity(0.7)),
                                ),
                              ],
                            ),
                          )
                        : TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Message',
                              filled: true,
                              fillColor: Theme.of(context).scaffoldBackgroundColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendTextMessage(),
                            onTap: () {
                              if (_showEmojiPicker) {
                                setState(() => _showEmojiPicker = false);
                              }
                            },
                          ),
                  ),

                  // Send or Record button
                  GestureDetector(
                    onTap: _messageController.text.trim().isEmpty
                        ? null
                        : _sendTextMessage,
                    onLongPressStart: _messageController.text.trim().isEmpty
                        ? (_) => _startRecording()
                        : null,
                    onLongPressEnd: _messageController.text.trim().isEmpty
                        ? (_) => _stopRecording()
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _messageController.text.trim().isEmpty
                            ? (_isRecording ? Colors.red : Theme.of(context).primaryColor.withOpacity(0.5))
                            : Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _messageController.text.trim().isEmpty
                            ? (_isRecording ? Icons.stop : Icons.mic)
                            : Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context, {
    required Map<String, dynamic> message,
    required bool isMe,
    required bool showAvatar,
  }) {
    final type = message['type'] ?? 'text';
    final content = message['content'] ?? '';
    final mediaUrl = message['media_url'];
    final createdAt = DateTime.parse(message['created_at']);
    final user = message['users'];

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 4,
          left: isMe ? 64 : (showAvatar ? 8 : 40),
          right: isMe ? 8 : 64,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe && showAvatar)
              CircleAvatar(
                radius: 16,
                backgroundImage: user?['avatar_url'] != null
                    ? NetworkImage(user['avatar_url'])
                    : null,
                child: user?['avatar_url'] == null
                    ? Text((user?['username'] ?? 'U')[0].toUpperCase())
                    : null,
              ),
            if (!isMe && !showAvatar)
              const SizedBox(width: 32),

            Flexible(
              child: Container(
                padding: type == 'text' 
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                    : const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isMe
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16).copyWith(
                    bottomRight: isMe ? const Radius.circular(4) : null,
                    bottomLeft: !isMe ? const Radius.circular(4) : null,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reply preview
                    if (message['reply_to'] != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Replying to...',
                          style: TextStyle(
                            fontSize: 12,
                            color: isMe ? Colors.white70 : Colors.grey,
                          ),
                        ),
                      ),

                    // Message content based on type
                    if (type == 'text')
                      Text(
                        content,
                        style: TextStyle(
                          color: isMe ? Colors.white : null,
                        ),
                      )
                    else if (type == 'image' && mediaUrl != null)
                      GestureDetector(
                        onTap: () => _showImageViewer(mediaUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: mediaUrl,
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 200,
                              height: 200,
                              color: Colors.grey.withOpacity(0.3),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 200,
                              height: 200,
                              color: Colors.grey.withOpacity(0.3),
                              child: const Icon(Icons.error),
                            ),
                          ),
                        ),
                      )
                    else if (type == 'audio' && mediaUrl != null)
                      _buildAudioPlayer(
                        messageId: message['id'],
                        audioUrl: mediaUrl,
                        isMe: isMe,
                      )
                    else if (type == 'file')
                      _buildFileMessage(
                        content: content,
                        mediaUrl: mediaUrl,
                        fileName: message['file_name'],
                        fileSize: message['file_size'],
                        isMe: isMe,
                      ),

                    const SizedBox(height: 4),

                    // Time and read status
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('HH:mm').format(createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white.withOpacity(0.7)
                                : Colors.grey,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message['is_read'] == true
                                ? Icons.done_all
                                : Icons.done,
                            size: 14,
                            color: message['is_read'] == true
                                ? Colors.blue
                                : Colors.white.withOpacity(0.7),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayer({
    required String messageId,
    required String audioUrl,
    required bool isMe,
  }) {
    final isPlaying = _currentlyPlayingAudioId == messageId && _isPlayingAudio;

    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: isMe ? Colors.white : Theme.of(context).primaryColor,
            ),
            onPressed: () => _playAudio(messageId, audioUrl),
          ),
          Expanded(
            child: Container(
              height: 30,
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withOpacity(0.2)
                    : Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: Text(
                  'Voice Message',
                  style: TextStyle(
                    fontSize: 12,
                    color: isMe ? Colors.white : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileMessage({
    required String content,
    required String? mediaUrl,
    required String? fileName,
    required String? fileSize,
    required bool isMe,
  }) {
    return GestureDetector(
      onTap: mediaUrl != null ? () => _openFile(mediaUrl, fileName) : null,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withOpacity(0.2)
              : Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.insert_drive_file,
              color: isMe ? Colors.white : Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName ?? content,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isMe ? Colors.white : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (fileSize != null)
                    Text(
                      fileSize,
                      style: TextStyle(
                        fontSize: 12,
                        color: isMe
                            ? Colors.white.withOpacity(0.7)
                            : Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.download,
              color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentButton(
                  icon: Icons.photo,
                  label: 'Gallery',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage();
                  },
                ),
                _buildAttachmentButton(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _takePhoto();
                  },
                ),
                _buildAttachmentButton(
                  icon: Icons.insert_drive_file,
                  label: 'Document',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _pickFile();
                  },
                ),
                _buildAttachmentButton(
                  icon: Icons.location_on,
                  label: 'Location',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _getMimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }
}

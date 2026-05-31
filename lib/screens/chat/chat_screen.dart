import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../themes/app_theme.dart';
import '../../providers/chat_provider.dart';
import '../../services/connectivity.dart';
import '../../services/ai_moderation_service.dart';
import '../../models/chat_model.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showEmoji = false;
  bool _isRecording = false;
  final ImagePicker _picker = ImagePicker();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onTextChanged() {
    setState(() {});
    if (_messageController.text.isNotEmpty) {
      context.read<ChatProvider>().setTyping(true);
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      context.read<ChatProvider>().setTyping(true);
    } else {
      context.read<ChatProvider>().setTyping(false);
    }
  }

  // Send message with moderation
  Future<void> _sendMessage(String content, [MessageType type = MessageType.text]) async {
    if (content.trim().isEmpty) return;

    final chatProvider = context.read<ChatProvider>();

    // Check connectivity
    final connectivity = ConnectivityService().currentState;
    if (connectivity == NetworkState.offline) {
      chatProvider.sendMessage(content.trim(), type: type);
      _messageController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message queued — will send when online'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Send with moderation check
    final result = await chatProvider.sendMessage(content.trim(), type: type);

    if (result != null && result.isFlagged) {
      _handleModerationResult(result);
    }

    if (result == null || result.action != ModerationAction.block) {
      _messageController.clear();

      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _handleModerationResult(ModerationResult result) {
    switch (result.action) {
      case ModerationAction.block:
        _showBanDialog(result);
        break;
      case ModerationAction.restrict:
        _showRestrictedSnack(result);
        break;
      case ModerationAction.warn:
        _showWarningSnack(result);
        break;
      case ModerationAction.allow:
        break;
    }
  }

  void _showBanDialog(ModerationResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSecondary,
        icon: const Icon(Icons.block, color: Colors.red, size: 48),
        title: const Text('Message Blocked', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              result.reason,
              style: const TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: FutureBuilder<UserStrikeStatus>(
                future: context.read<ChatProvider>().checkMyStrikes(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  return Text(
                    snapshot.data!.statusText,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('I Understand', style: TextStyle(color: AppTheme.primaryGreen)),
          ),
        ],
      ),
    );
  }

  void _showRestrictedSnack(ModerationResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Message flagged: ${result.reason}'),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade800,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showWarningSnack(ModerationResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Warning: ${result.reason}'),
        backgroundColor: Colors.blue.shade800,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Retry failed message
  void _retryMessage(String messageId) {
    context.read<ChatProvider>().retryFailedMessage(messageId);
  }

  // Report message
  void _showReportDialog(MessageModel message) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSecondary,
        title: const Text('Report Message', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Report this message from ${message.senderName ?? 'Unknown'}?',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Reason for report (optional)',
                hintStyle: TextStyle(color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.bgInput,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textTertiary)),
          ),
          TextButton(
            onPressed: () {
              context.read<ChatProvider>().reportMessage(
                messageId: message.id,
                reason: 'User reported',
                details: reasonController.text.isNotEmpty ? reasonController.text : null,
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report submitted')),
              );
            },
            child: const Text('Report', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final chat = chatProvider.selectedChat;
    final messages = chatProvider.messages;
    final typingUsers = chatProvider.typingUsers;

    if (chat == null) {
      return const Scaffold(body: Center(child: Text('No chat selected')));
    }

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: _buildChatAppBar(chat, typingUsers),
      body: Column(
        children: [
          // AI Moderation Banner
          if (chatProvider.aiModerationEnabled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.accentBlue.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppTheme.accentBlue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Moderation is active',
                      style: TextStyle(fontSize: 11, color: AppTheme.accentBlue, fontWeight: FontWeight.w500),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => chatProvider.toggleAIModeration(),
                    child: Text(
                      'Disable',
                      style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                    ),
                  ),
                ],
              ),
            ),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[messages.length - 1 - index];
                final isMe = message.senderId == 'me';
                final showAvatar = !isMe && (index == messages.length - 1 || 
                    messages[messages.length - index].senderId != message.senderId);
                return _buildMessageBubble(message, isMe, showAvatar);
              },
            ),
          ),

          // Typing indicator
          if (typingUsers.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.bgElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTypingDots(),
                        const SizedBox(width: 6),
                        Text(
                          chatProvider.typingText,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Input Area
          _buildInputArea(chatProvider),
        ],
      ),
    );
  }

  Widget _buildTypingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [0, 1, 2].map((i) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppTheme.textTertiary.withOpacity(0.6 + (i * 0.2)),
            shape: BoxShape.circle,
          ),
        );
      }).toList(),
    );
  }

  AppBar _buildChatAppBar(ChatModel chat, List<String> typingUsers) {
    final participant = chat.participants.isNotEmpty ? chat.participants.first : null;
    final isOnline = participant?.status == UserStatus.online;

    return AppBar(
      backgroundColor: AppTheme.bgSecondary,
      elevation: 0,
      leadingWidth: 40,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: InkWell(
        onTap: () {
          if (chat.isGroup || chat.isChannel) {
            _showGroupInfo(chat);
          } else {
            Navigator.pushNamed(context, '/public_profile');
          }
        },
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.divider),
              ),
              child: chat.isSelfChat
                  ? const Icon(Icons.bookmark, color: AppTheme.primaryGreen, size: 20)
                  : Center(
                      child: Text(
                        chat.displayName.isNotEmpty ? chat.displayName[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          chat.displayName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (participant?.isVerified ?? false) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: const BoxDecoration(color: AppTheme.verifiedBlue, shape: BoxShape.circle),
                          child: const Icon(Icons.check, size: 10, color: Colors.white),
                        ),
                      ],
                    ],
                  ),
                  if (typingUsers.isNotEmpty)
                    const Text(
                      'typing...',
                      style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen),
                    )
                  else if (chat.isSelfChat)
                    const Text('Your personal space', style: TextStyle(fontSize: 12, color: AppTheme.textTertiary))
                  else if (chat.isGroup)
                    Text(
                      '${chat.memberCount ?? 0} members, ${chat.onlineCount} online',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                    )
                  else if (chat.isChannel)
                    Text(
                      '${chat.subscriberCount ?? 0} subscribers, ${chat.onlineCount} online',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                    )
                  else if (isOnline)
                    const Text('online', style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen))
                  else if (participant?.lastSeen != null)
                    Text('last seen ${participant!.lastSeen!.hour}:${participant.lastSeen!.minute.toString().padLeft(2, '0')}', 
                      style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary))
                  else
                    const Text('offline', style: TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam, color: AppTheme.textPrimary),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.call, color: AppTheme.textPrimary),
          onPressed: () {},
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppTheme.textPrimary),
          color: AppTheme.bgModal,
          onSelected: (value) {
            switch (value) {
              case 'view_contact':
                if (!chat.isGroup && !chat.isChannel) {
                  Navigator.pushNamed(context, '/public_profile');
                }
                break;
              case 'media':
                break;
              case 'search':
                break;
              case 'mute':
                break;
              case 'wallpaper':
                break;
              case 'report':
                break;
              case 'block':
                break;
            }
          },
          itemBuilder: (context) => [
            if (!chat.isGroup && !chat.isChannel)
              _buildMenuItem('view_contact', 'View Contact', Icons.person),
            _buildMenuItem('media', 'Media, Links, Docs', Icons.folder),
            _buildMenuItem('search', 'Search', Icons.search),
            _buildMenuItem('mute', 'Mute Notifications', Icons.notifications_off),
            _buildMenuItem('wallpaper', 'Wallpaper', Icons.wallpaper),
            _buildMenuItem('report', 'Report', Icons.report, color: AppTheme.error),
            _buildMenuItem('block', 'Block', Icons.block, color: AppTheme.error),
          ],
        ),
      ],
    );
  }

  void _showGroupInfo(ChatModel chat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgModal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  chat.isGroup ? Icons.group : Icons.campaign,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                chat.displayName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (chat.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  chat.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              if (chat.isGroup)
                Text(
                  '${chat.memberCount ?? 0} members • ${chat.onlineCount} online',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textTertiary,
                  ),
                )
              else
                Text(
                  '${chat.subscriberCount ?? 0} subscribers • ${chat.onlineCount} online',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textTertiary,
                  ),
                ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: chat.members.length + chat.subscribers.length,
                  itemBuilder: (context, index) {
                    final members = [...chat.members, ...chat.subscribers];
                    if (index >= members.length) return const SizedBox.shrink();

                    final member = members[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.bgElevated,
                        child: Text(
                          member.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        member.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        member.role == MemberRole.admin
                            ? 'Admin'
                            : member.role == MemberRole.moderator
                                ? 'Moderator'
                                : 'Member',
                        style: TextStyle(
                          color: member.role == MemberRole.admin
                              ? AppTheme.primaryGreen
                              : AppTheme.textSecondary,
                        ),
                      ),
                      trailing: member.isOnline
                          ? Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppTheme.online,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, String text, IconData icon, {Color? color}) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, color: color ?? AppTheme.textSecondary, size: 20),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(color: color ?? AppTheme.textPrimary, fontSize: 14)),
      ]),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe, bool showAvatar) {
    final isRestricted = message.isRestricted || message.contentFlag != ContentFlag.none;
    final isFailed = message.status == MessageStatus.failed;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(
            left: isMe ? 60 : 4,
            right: isMe ? 4 : 60,
            bottom: 4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe && showAvatar)
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.bgElevated,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      message.senderName?.isNotEmpty == true ? message.senderName![0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                    ),
                  ),
                )
              else if (!isMe)
                const SizedBox(width: 34),

              Flexible(
                child: GestureDetector(
                  onTap: isFailed ? () => _retryMessage(message.id) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isFailed
                          ? Colors.red.withOpacity(0.1)
                          : isRestricted
                              ? AppTheme.warning.withOpacity(0.1)
                              : isMe
                                  ? AppTheme.sentMessage
                                  : AppTheme.receivedMessage,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isFailed)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, size: 12, color: Colors.red),
                                const SizedBox(width: 4),
                                const Text(
                                  'Tap to retry',
                                  style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),

                        if (isRestricted)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber, size: 12, color: AppTheme.warning),
                                const SizedBox(width: 4),
                                Text(
                                  message.restrictionNote ?? 'Restricted by AI',
                                  style: TextStyle(fontSize: 11, color: AppTheme.warning, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),

                        if (message.isReply && message.replyToMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: const Border(left: BorderSide(color: AppTheme.primaryGreen, width: 3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.replyToMessage!.senderName ?? 'Unknown',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  message.replyToMessage!.content,
                                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                        if (message.isForwarded)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.forward, size: 12, color: AppTheme.textTertiary),
                                const SizedBox(width: 4),
                                Text(
                                  'Forwarded from ${message.forwardFromName ?? 'Unknown'}',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                                ),
                              ],
                            ),
                          ),

                        Text(
                          isRestricted ? '⚠️ This content has been restricted' : message.content,
                          style: TextStyle(
                            fontSize: 15,
                            color: isRestricted ? AppTheme.warning : AppTheme.textPrimary,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message.formattedTime,
                              style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                            ),
                            if (message.isEdited) ...[
                              const SizedBox(width: 4),
                              Text('edited', style: TextStyle(fontSize: 10, color: AppTheme.textTertiary, fontStyle: FontStyle.italic)),
                            ],
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              if (message.status == MessageStatus.sending)
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.textTertiary,
                                  ),
                                )
                              else
                                Icon(
                                  message.status == MessageStatus.read ? Icons.done_all : Icons.done,
                                  size: 14,
                                  color: message.status == MessageStatus.read ? AppTheme.accentCyan : AppTheme.textTertiary,
                                ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(MessageModel message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgModal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.reply, color: AppTheme.textSecondary),
              title: const Text('Reply', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.forward, color: AppTheme.textSecondary),
              title: const Text('Forward', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: AppTheme.textSecondary),
              title: const Text('Copy', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.red),
              title: const Text('Report', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(ChatProvider chatProvider) {
    final isOffline = ConnectivityService().currentState == NetworkState.offline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOffline)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, size: 14, color: Colors.orange.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'Waiting for network...',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: Icon(_showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined, color: AppTheme.textTertiary),
                  onPressed: () => setState(() => _showEmoji = !_showEmoji),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.bgInput,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            focusNode: _focusNode,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                            maxLines: 5,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: isOffline ? 'Message (will queue)' : 'Message',
                              hintStyle: TextStyle(color: AppTheme.textTertiary),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.attach_file, color: AppTheme.textTertiary),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    if (_messageController.text.trim().isNotEmpty) {
                      _sendMessage(_messageController.text.trim());
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: _messageController.text.trim().isNotEmpty
                          ? AppGradients.primary
                          : const LinearGradient(colors: [AppTheme.bgElevated, AppTheme.bgElevated]),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _messageController.text.trim().isNotEmpty ? Icons.send : Icons.mic,
                      color: _messageController.text.trim().isNotEmpty ? Colors.white : AppTheme.primaryGreen,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

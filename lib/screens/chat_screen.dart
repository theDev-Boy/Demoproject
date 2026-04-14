import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../widgets/avatar_widget.dart';
import '../config/app_colors.dart';
import '../config/app_typography.dart';
import '../services/database_service.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _showEmoji = false;
  bool _isTyping = false;
  bool _isRecording = false;
  String? _editingMessageId;

  // Partner data
  UserModel? _partner;
  String _partnerId = '';

  @override
  void initState() {
    super.initState();
    _loadPartnerInfo();
    _msgCtrl.addListener(() {
      // Show send button reactively
      setState(() {});
    });
  }

  @override
  void dispose() {
    // Clear typing status on leave
    final auth = context.read<AuthProvider>();
    context.read<ChatProvider>().setTyping(widget.chatId, auth.firebaseUser!.uid, false);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPartnerInfo() async {
    final auth = context.read<AuthProvider>();
    final myUid = auth.firebaseUser!.uid;

    // Parse partner UID from chatId (format: uid1_uid2, sorted)
    final parts = widget.chatId.split('_');
    _partnerId = parts.firstWhere((id) => id != myUid, orElse: () => parts.first);

    final partner = await DatabaseService().getUser(_partnerId);
    if (mounted && partner != null) {
      setState(() => _partner = partner);
    }
  }

  void _sendMessage() {
    if (_msgCtrl.text.trim().isEmpty) return;

    final auth = context.read<AuthProvider>();
    final chat = context.read<ChatProvider>();

    if (_editingMessageId != null) {
      // Edit existing message
      chat.editMessage(widget.chatId, _editingMessageId!, _msgCtrl.text.trim());
      _editingMessageId = null;
    } else {
      // Send new message
      final msg = MessageModel(
        id: '',
        senderId: auth.firebaseUser!.uid,
        text: _msgCtrl.text.trim(),
        type: _isOnlyEmoji(_msgCtrl.text.trim()) ? MessageType.emoji : MessageType.text,
        timestamp: DateTime.now(),
      );
      chat.sendMessage(widget.chatId, msg);
    }

    _msgCtrl.clear();
    _updateTyping(false);

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isOnlyEmoji(String text) {
    if (text.isEmpty) return false;
    final cleaned = text.replaceAll(RegExp(r'\s'), '');
    if (cleaned.isEmpty) return false;
    // Simple heuristic: if all characters are emoji (non-ASCII above a threshold)
    final runes = cleaned.runes.toList();
    return runes.every((r) => r > 0x1F000 || (r >= 0x2600 && r <= 0x27BF) || (r >= 0x2300 && r <= 0x23FF));
  }

  void _updateTyping(bool typing) {
    if (_isTyping == typing) return;
    _isTyping = typing;
    final auth = context.read<AuthProvider>();
    context.read<ChatProvider>().setTyping(widget.chatId, auth.firebaseUser!.uid, typing);
  }

  void _startAudioCall() {
    if (_partner == null) return;
    context.push('/audio-call', extra: {
      'partnerUid': _partnerId,
      'partnerName': _partner!.name,
      'partnerAvatar': _partner!.avatarUrl,
      'isOutgoing': true,
    });
  }

  void _startVideoCall() {
    if (_partner == null) return;
    // Place a direct video call
    final myUid = context.read<AuthProvider>().firebaseUser!.uid;
    final myName = context.read<AuthProvider>().userModel?.name ?? 'User';
    FirebaseDatabase.instance.ref('direct_calls').child(_partnerId).set({
      'callerId': myUid,
      'callerName': myName,
      'timestamp': ServerValue.timestamp,
    });
    context.push('/call');
  }

  void _showPartnerProfile() {
    if (_partner == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarWidget(name: _partner!.name, avatarCode: _partner!.avatarUrl, radius: 50),
            const SizedBox(height: 16),
            Text(_partner!.name, style: AppTypography.headlineMedium),
            const SizedBox(height: 4),
            Text(_partner!.email, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: _partner!.isOnline ? AppColors.success : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _partner!.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: _partner!.isOnline ? AppColors.success : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _profileAction(Icons.call_rounded, 'Audio Call', _startAudioCall),
                _profileAction(Icons.videocam_rounded, 'Video Call', _startVideoCall),
              ],
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 12),
          ],
        ),
      ),
    );
  }

  Widget _profileAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final myUid = auth.firebaseUser!.uid;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap: _showPartnerProfile,
          child: StreamBuilder<ChatModel?>(
            stream: chatProvider.getChatMeta(widget.chatId),
            builder: (context, snapshot) {
              final chat = snapshot.data;
              final isPartnerTyping = chat?.typingStatus[_partnerId] == true;

              return Row(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      AvatarWidget(
                        name: _partner?.name ?? '...',
                        avatarCode: _partner?.avatarUrl ?? '',
                        radius: 18,
                      ),
                      if (_partner != null)
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: _partner!.isOnline ? AppColors.success : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).appBarTheme.backgroundColor ?? Colors.white,
                              width: 1.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _partner?.name ?? 'Loading...',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isPartnerTyping
                              ? 'typing...'
                              : (_partner?.isOnline == true ? 'Online' : 'Offline'),
                          style: TextStyle(
                            fontSize: 12,
                            color: isPartnerTyping
                                ? AppColors.primary
                                : (_partner?.isOnline == true ? AppColors.success : AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_rounded),
            onPressed: _startVideoCall,
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded),
            onPressed: _startAudioCall,
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'clear') {
                context.read<ChatProvider>().clearChat(widget.chatId);
              } else if (val == 'block') {
                context.read<ChatProvider>().blockUser(myUid, _partnerId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User blocked'), backgroundColor: AppColors.error),
                );
                context.pop();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'clear', child: Text('Clear Chat')),
              const PopupMenuItem(
                value: 'block',
                child: Text('Block User', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          // Edit mode banner
          if (_editingMessageId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.primary.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Editing message', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600))),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() {
                        _editingMessageId = null;
                        _msgCtrl.clear();
                      });
                    },
                  ),
                ],
              ),
            ),

          // Messages
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: chatProvider.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                final messages = snapshot.data!;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.waving_hand_rounded, size: 48, color: AppColors.primary.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        Text('Say hello! 👋', style: AppTypography.headlineSmall),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length + 1, // +1 for typing indicator
                  itemBuilder: (context, index) {
                    // Typing indicator at the end
                    if (index == messages.length) {
                      return StreamBuilder<ChatModel?>(
                        stream: chatProvider.getChatMeta(widget.chatId),
                        builder: (context, metaSnap) {
                          final isPartnerTyping = metaSnap.data?.typingStatus[_partnerId] == true;
                          if (!isPartnerTyping) return const SizedBox.shrink();

                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF2A2A2A)
                                    : Colors.grey[200],
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildTypingDots(),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }

                    final msg = messages[index];
                    final isMe = msg.senderId == myUid;
                    return _buildMessageBubble(msg, isMe);
                  },
                );
              },
            ),
          ),

          // Emoji picker
          if (_showEmoji)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  _msgCtrl.text += emoji.emoji;
                  _msgCtrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: _msgCtrl.text.length),
                  );
                },
                config: const Config(
                  emojiViewConfig: EmojiViewConfig(
                    columns: 7,
                    emojiSizeMax: 32,
                  ),
                ),
              ),
            ),

          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildTypingDots() {
    return SizedBox(
      width: 40,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 600 + (i * 200)),
            builder: (context, value, child) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.4 + 0.6 * value),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMe) {
    final isEmoji = msg.type == MessageType.emoji;
    final isCallEvent = msg.type == MessageType.callEvent;
    final timeStr = DateFormat.jm().format(msg.timestamp);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Call event display
    if (isCallEvent) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            msg.text,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(msg, isMe),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: isEmoji
                    ? const EdgeInsets.all(4)
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: isEmoji
                    ? null
                    : BoxDecoration(
                        color: isMe
                            ? AppColors.primary
                            : (isDark ? const Color(0xFF2A2A2A) : Colors.grey[100]),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMe ? 18 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 18),
                        ),
                      ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      msg.text,
                      style: TextStyle(
                        color: isEmoji
                            ? null
                            : (isMe ? Colors.white : (isDark ? Colors.white : Colors.black87)),
                        fontSize: isEmoji ? 42 : 15,
                        height: 1.3,
                      ),
                    ),
                    if (!isEmoji) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (msg.isEdited)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                'edited',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: isMe ? Colors.white60 : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe ? Colors.white60 : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(MessageModel msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                ),
                if (isMe)
                  ListTile(
                    leading: const Icon(Icons.edit_rounded, color: AppColors.primary),
                    title: const Text('Edit Message'),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _editingMessageId = msg.id;
                        _msgCtrl.text = msg.text;
                      });
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.orange),
                  title: const Text('Delete for Me'),
                  onTap: () {
                    context.read<ChatProvider>().deleteMessage(widget.chatId, msg.id, everyone: false);
                    Navigator.pop(ctx);
                  },
                ),
                if (isMe)
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                    title: const Text('Delete for Everyone'),
                    onTap: () {
                      context.read<ChatProvider>().deleteMessage(widget.chatId, msg.id, everyone: true);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasText = _msgCtrl.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Emoji toggle
          IconButton(
            icon: Icon(
              _showEmoji ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
              color: AppColors.textSecondary,
            ),
            onPressed: () => setState(() => _showEmoji = !_showEmoji),
          ),

          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: _isRecording
                  ? _buildRecordingUI()
                  : TextField(
                      controller: _msgCtrl,
                      maxLines: 5,
                      minLines: 1,
                      onChanged: (val) => _updateTyping(val.isNotEmpty),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 6),

          // Send or Mic button
          hasText || _editingMessageId != null
              ? GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                  ),
                )
              : GestureDetector(
                  onLongPressStart: (_) => setState(() => _isRecording = true),
                  onLongPressEnd: (_) {
                    setState(() => _isRecording = false);
                    // TODO: Send recorded voice message
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isRecording ? AppColors.error : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildRecordingUI() {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        const Text('Recording...', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 14)),
        const Spacer(),
        const Text('Release to send', style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

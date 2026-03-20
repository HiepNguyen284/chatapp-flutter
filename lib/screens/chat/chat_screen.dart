import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/chat_rooms_provider.dart';
import '../../models/user_with_avatar_model.dart';
import '../../services/message_service.dart';
import '../../services/realtime_service.dart';
import '../../services/user_service.dart';
import '../../widgets/message_bubble.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    this.peerUsername,
  });

  final int roomId;
  final String roomName;
  final String? peerUsername;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(
        messageService: context.read<MessageService>(),
        realtimeService: context.read<RealtimeService>(),
        roomId: roomId,
        currentUsername: context.read<AuthProvider>().username,
      )
        ..loadMessages()
        ..startRealtime(),
      child: _ChatView(
        roomId: roomId,
        roomName: roomName,
        peerUsername: peerUsername,
      ),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView({
    required this.roomId,
    required this.roomName,
    required this.peerUsername,
  });

  final int roomId;
  final String roomName;
  final String? peerUsername;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  List<XFile> _pickedFiles = [];
  ChatRoomsProvider? _chatRoomsProvider;
  StreamSubscription<PresenceUpdateEvent>? _presenceSub;
  StreamSubscription<TypingStatusEvent>? _typingSub;
  StreamSubscription<ReadStatusEvent>? _readSub;
  Timer? _typingDebounce;
  Timer? _typingVisibleTimer;
  Timer? _typingDotsTicker;
  bool _isTypingSent = false;
  bool _isPeerTyping = false;
  String? _typingSender;
  int _typingDots = 1;
  String? _myUsername;
  final Map<String, DateTime> _readAtByUser = {};
  final Map<String, UserWithAvatarModel> _readerByUsername = {};
  bool _isPresenceLoading = false;
  bool? _isPeerOnline;
  DateTime? _lastSeenAt;

  @override
  void initState() {
    super.initState();
    _myUsername = context.read<AuthProvider>().username;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ChatRoomsProvider>();
      _chatRoomsProvider = provider;
      provider.markRoomOpened(widget.roomId);
    });

    _loadPresence();
    _subscribePresence();
    _subscribeTyping();
    _subscribeReadStatus();
  }

  @override
  void dispose() {
    _chatRoomsProvider?.markRoomClosed(widget.roomId);
    _typingDebounce?.cancel();
    _typingVisibleTimer?.cancel();
    _typingDotsTicker?.cancel();
    if (_isTypingSent) {
      unawaited(context.read<ChatProvider>().setTypingStatus(false));
    }
    _presenceSub?.cancel();
    _typingSub?.cancel();
    _readSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeReadStatus() {
    _readSub = context.read<RealtimeService>().roomReadStream(widget.roomId).listen((event) {
      final reader = event.reader;
      final username = reader?.username ?? '';
      if (!mounted || username.isEmpty || username == _myUsername) {
        return;
      }

      setState(() {
        final readAt = event.readAt?.toLocal();
        if (readAt != null) {
          _readAtByUser[username] = readAt;
        }
        if (reader != null) {
          _readerByUsername[username] = reader;
        }
      });
    });
  }

  void _subscribeTyping() {
    _typingSub = context.read<RealtimeService>().roomTypingStream(widget.roomId).listen((event) {
      if (!mounted || event.sender == _myUsername) {
        return;
      }

      _typingVisibleTimer?.cancel();
      if (event.typing) {
        _startTypingDots();
      } else {
        _stopTypingDots();
      }
      setState(() {
        _isPeerTyping = event.typing;
        _typingSender = event.typing ? event.sender : null;
      });

      if (event.typing) {
        _typingVisibleTimer = Timer(const Duration(seconds: 4), () {
          if (!mounted) {
            return;
          }

          setState(() {
            _isPeerTyping = false;
            _typingSender = null;
          });
          _stopTypingDots();
        });
      }
    });
  }

  void _startTypingDots() {
    if (_typingDotsTicker != null) {
      return;
    }

    _typingDotsTicker = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (!mounted || !_isPeerTyping) {
        return;
      }

      setState(() {
        _typingDots = _typingDots == 3 ? 1 : _typingDots + 1;
      });
    });
  }

  void _stopTypingDots() {
    _typingDotsTicker?.cancel();
    _typingDotsTicker = null;
    _typingDots = 1;
  }

  String _typingDisplayName() {
    final sender = _typingSender;
    if (sender == null || sender.isEmpty) {
      return widget.roomName;
    }

    if (widget.peerUsername != null && sender == widget.peerUsername) {
      return widget.roomName;
    }

    return sender;
  }

  void _onTextChanged(String value) {
    final hasText = value.trim().isNotEmpty;

    if (!hasText) {
      _typingDebounce?.cancel();
      if (_isTypingSent) {
        _isTypingSent = false;
        unawaited(context.read<ChatProvider>().setTypingStatus(false));
      }
      return;
    }

    if (!_isTypingSent) {
      _isTypingSent = true;
      unawaited(context.read<ChatProvider>().setTypingStatus(true));
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 1200), () {
      if (!_isTypingSent) {
        return;
      }

      _isTypingSent = false;
      unawaited(context.read<ChatProvider>().setTypingStatus(false));
    });
  }

  Future<void> _loadPresence() async {
    final peer = widget.peerUsername;
    if (peer == null || peer.isEmpty) {
      return;
    }

    setState(() {
      _isPresenceLoading = true;
    });

    try {
      final presence = await context.read<UserService>().getPresence(peer);
      if (!mounted) {
        return;
      }

      setState(() {
        _isPeerOnline = presence.online;
        _lastSeenAt = presence.lastSeenAt?.toLocal();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPeerOnline = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPresenceLoading = false;
        });
      }
    }
  }

  void _subscribePresence() {
    final peer = widget.peerUsername;
    if (peer == null || peer.isEmpty) {
      return;
    }

    _presenceSub = context.read<RealtimeService>().presenceStream.listen((event) {
      final presence = event.presence;
      if (presence == null || presence.username != peer || !mounted) {
        return;
      }

      setState(() {
        _isPeerOnline = presence.online;
        _lastSeenAt = presence.lastSeenAt?.toLocal();
      });
    });
  }

  String? _presenceLabel() {
    if (widget.peerUsername == null || widget.peerUsername!.isEmpty) {
      return null;
    }

    if (_isPresenceLoading && _isPeerOnline == null) {
      return 'Loading status...';
    }

    if (_isPeerOnline == true) {
      return 'Online';
    }

    final seenAt = _lastSeenAt;
    if (seenAt == null) {
      return 'Offline';
    }

    return 'Last seen ${_formatLastSeen(seenAt)}';
  }

  String _formatLastSeen(DateTime value) {
    final seenAt = value.toLocal();
    final now = DateTime.now();
    final isToday =
        seenAt.year == now.year && seenAt.month == now.month && seenAt.day == now.day;
    if (isToday) {
      return 'today at ${DateFormat('HH:mm').format(seenAt)}';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = seenAt.year == yesterday.year &&
        seenAt.month == yesterday.month &&
        seenAt.day == yesterday.day;
    if (isYesterday) {
      return 'yesterday at ${DateFormat('HH:mm').format(seenAt)}';
    }

    return DateFormat('dd/MM/yyyy HH:mm').format(seenAt);
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) {
      return;
    }

    setState(() {
      _pickedFiles = [..._pickedFiles, image];
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _pickedFiles.isEmpty) {
      return;
    }

    final sent = await context.read<ChatProvider>().sendMessage(
          text: text,
          attachments: _pickedFiles,
        );

    if (!mounted) {
      return;
    }

    if (!sent) {
      final error = context.read<ChatProvider>().error ?? 'Send failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    if (_isTypingSent) {
      _isTypingSent = false;
      unawaited(context.read<ChatProvider>().setTypingStatus(false));
    }
    _typingDebounce?.cancel();

    _controller.clear();
    setState(() {
      _pickedFiles = [];
    });

    await Future.delayed(const Duration(milliseconds: 150));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _confirmRecall(int messageId) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Delete message'),
            onTap: () async {
              Navigator.pop(context);
              final deleted = await this.context.read<ChatProvider>().recallMessage(
                    messageId: messageId,
                  );
              if (!mounted) {
                return;
              }

              if (!deleted) {
                final error = this.context.read<ChatProvider>().error ?? 'Delete failed';
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text(error)),
                );
              }
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final myUsername = context.watch<AuthProvider>().username;
    final presenceLabel = _presenceLabel();
    final typingLabel = _isPeerTyping
      ? '${_typingDisplayName()} đang nhập${'.' * _typingDots}'
      : null;
    final isOnline = _isPeerOnline == true;
    final messages = chat.messages;

    int? lastOwnIndex;
    for (var i = messages.length - 1; i >= 0; i--) {
      final item = messages[i];
      if (myUsername != null && item.sender == myUsername) {
        lastOwnIndex = i;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(radius: 17, child: Icon(Icons.person, size: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.roomName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (presenceLabel != null)
                    Text(
                      presenceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isOnline
                                ? const Color(0xFF0A8F47)
                                : Colors.black54,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: chat.loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chat.isLoading && chat.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: chat.messages.length,
                    itemBuilder: (context, index) {
                      final item = messages[index];
                      final isMine =
                          myUsername != null && item.sender == myUsername;

                      final seenByMerged = <String, UserWithAvatarModel>{};
                      for (final viewer in item.seenBy) {
                        final username = viewer.username ?? '';
                        if (username.isEmpty || username == myUsername) {
                          continue;
                        }
                        seenByMerged[username] = viewer;
                      }

                      final sentOn = item.sentOn;
                      if (sentOn != null) {
                        _readAtByUser.forEach((username, readAt) {
                          if (username == myUsername || sentOn.isAfter(readAt)) {
                            return;
                          }

                          seenByMerged[username] =
                              _readerByUsername[username] ??
                              UserWithAvatarModel(
                                id: null,
                                username: username,
                                avatar: null,
                              );
                        });
                      }

                      final seenByUsers = seenByMerged.values.toList();
                      seenByUsers.sort(
                        (a, b) => (a.username ?? '').compareTo(b.username ?? ''),
                      );

                      String? deliveryStatus;
                      if (isMine && index == lastOwnIndex) {
                        deliveryStatus = seenByUsers.isNotEmpty ? 'Đã xem' : 'Đã gửi';
                      }

                      return MessageBubble(
                        message: item,
                        isMine: isMine,
                        deliveryStatus: deliveryStatus,
                        seenByUsers: isMine ? seenByUsers : const [],
                        onLongPress: () {
                          if (item.id != null && isMine) {
                            _confirmRecall(item.id!);
                          }
                        },
                      );
                    },
                  ),
          ),
          if (_pickedFiles.isNotEmpty)
            SizedBox(
              height: 74,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _pickedFiles.length,
                itemBuilder: (context, index) {
                  final file = _pickedFiles[index];
                  return Stack(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        margin: const EdgeInsets.only(left: 8, bottom: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _PickedFilePreview(file: file),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _pickedFiles = _pickedFiles
                                  .where((f) => f.path != file.path)
                                  .toList();
                            });
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: typingLabel == null ? 0 : 22,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: typingLabel == null
                ? null
                : Text(
                    typingLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF168AFF),
                          fontStyle: FontStyle.italic,
                        ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image_rounded),
                    color: const Color(0xFF168AFF),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 5,
                      onChanged: _onTextChanged,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Aa',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: chat.isSending ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF168AFF),
                    ),
                    icon: chat.isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickedFilePreview extends StatelessWidget {
  const _PickedFilePreview({required this.file});

  final XFile file;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ColoredBox(
            color: Color(0xFFE5E7EB),
            child: Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
        );
      },
    );
  }
}

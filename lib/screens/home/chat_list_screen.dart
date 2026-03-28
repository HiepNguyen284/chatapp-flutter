import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_rooms_provider.dart';
import '../../widgets/chat_room_tile.dart';
import '../chat/chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  ChatRoomsProvider? _provider;
  bool _isNoticeCallbackScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ChatRoomsProvider>();
      _provider = provider;
      provider.loadRooms();
      provider.startRealtime();
    });
  }

  @override
  void dispose() {
    _provider?.stopRealtime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatRoomsProvider>();
    final currentUsername = context.watch<AuthProvider>().username;
    provider.setCurrentUsername(currentUsername);
    _showPendingSystemNotice(provider);

    if (provider.isLoading && provider.rooms.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.rooms.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(provider.error!, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: provider.loadRooms,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadRooms,
      child: ListView(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              readOnly: true,
              decoration: InputDecoration(
                hintText: 'Search in chats',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: provider.loadRooms,
                  icon: const Icon(Icons.refresh),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...provider.rooms.map(
            (room) => ChatRoomTile(
              room: room,
              currentUsername: currentUsername,
              unreadCount: provider.unreadCountFor(room.id),
              isPeerOnline: provider.isPeerOnlineFor(room.id),
              onTap: () {
                provider.markRoomRead(room.id);
                final displayName = room.displayNameFor(currentUsername);
                final peerUsername = room.duoPeerFor(currentUsername);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      roomId: room.id,
                      roomName: displayName,
                      peerUsername: peerUsername,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _showPendingSystemNotice(ChatRoomsProvider provider) {
    if (_isNoticeCallbackScheduled || provider.pendingSystemNotice == null) {
      return;
    }

    _isNoticeCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isNoticeCallbackScheduled = false;
      if (!mounted) {
        return;
      }

      final notice = context.read<ChatRoomsProvider>().consumePendingSystemNotice();
      if (notice == null) {
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF8A3A13),
          content: Row(
            children: [
              const Icon(Icons.group_off_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(notice.message)),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }
}

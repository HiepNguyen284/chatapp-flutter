import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_room_model.dart';
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
  final _searchController = TextEditingController();
  String _searchQuery = '';

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
    _searchController.dispose();
    _provider?.stopRealtime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatRoomsProvider>();
    final currentUsername = context.watch<AuthProvider>().username;
    provider.setCurrentUsername(currentUsername);
    _showPendingSystemNotice(provider);
    final filteredRooms = _filterRooms(
      provider.rooms,
      currentUsername: currentUsername,
    );
    final pinnedRooms =
        filteredRooms.where((room) => provider.isPinned(room.id)).toList();
    final regularRooms =
        filteredRooms.where((room) => !provider.isPinned(room.id)).toList();
    final hasSearchQuery = _searchQuery.trim().isNotEmpty;

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
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search in chats',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: () {
                    if (hasSearchQuery) {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                      return;
                    }

                    provider.loadRooms();
                  },
                  icon: Icon(
                    hasSearchQuery ? Icons.close_rounded : Icons.refresh,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (filteredRooms.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Text(
                hasSearchQuery
                    ? 'No conversations found for "${_searchQuery.trim()}".'
                    : 'No conversations yet.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
            ),
          if (pinnedRooms.isNotEmpty)
            _sectionLabel(context, 'Pinned conversations'),
          ...pinnedRooms.map(
            (room) => _buildRoomTile(
              context: context,
              provider: provider,
              room: room,
              currentUsername: currentUsername,
            ),
          ),
          if (pinnedRooms.isNotEmpty && regularRooms.isNotEmpty)
            _sectionLabel(context, 'All conversations'),
          ...regularRooms.map(
            (room) => _buildRoomTile(
              context: context,
              provider: provider,
              room: room,
              currentUsername: currentUsername,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _buildRoomTile({
    required BuildContext context,
    required ChatRoomsProvider provider,
    required ChatRoomModel room,
    required String? currentUsername,
  }) {
    final isPinned = provider.isPinned(room.id);
    return ChatRoomTile(
      room: room,
      currentUsername: currentUsername,
      unreadCount: provider.unreadCountFor(room.id),
      isPeerOnline: provider.isPeerOnlineFor(room.id),
      isPinned: isPinned,
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
      onLongPress: () => _showRoomActions(
        context: context,
        provider: provider,
        room: room,
        isPinned: isPinned,
      ),
    );
  }

  List<ChatRoomModel> _filterRooms(
    List<ChatRoomModel> rooms, {
    required String? currentUsername,
  }) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return rooms;
    }

    return rooms.where((room) {
      final roomName = room.displayNameFor(currentUsername).toLowerCase();
      if (roomName.contains(query)) {
        return true;
      }

      final peerUsername =
          (room.duoPeerFor(currentUsername) ?? '').toLowerCase();
      if (peerUsername.contains(query)) {
        return true;
      }

      final latestPreview =
          room.latestPreviewFor(currentUsername).toLowerCase();
      if (latestPreview.contains(query)) {
        return true;
      }

      return room.membersUsername.any(
        (username) => username.toLowerCase().contains(query),
      );
    }).toList();
  }

  Future<void> _showRoomActions({
    required BuildContext context,
    required ChatRoomsProvider provider,
    required ChatRoomModel room,
    required bool isPinned,
  }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                ),
                title:
                    Text(isPinned ? 'Unpin conversation' : 'Pin conversation'),
                onTap: () => Navigator.of(sheetContext).pop('toggle_pin'),
              ),
            ],
          ),
        );
      },
    );

    if (action != 'toggle_pin' || !context.mounted) {
      return;
    }

    bool isNowPinned;
    try {
      isNowPinned = await provider.togglePinnedRoom(room.id);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Update pin failed: $error'),
          ),
        );
      return;
    }

    if (!context.mounted) {
      return;
    }

    final label = room.displayNameFor(context.read<AuthProvider>().username);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            isNowPinned ? 'Pinned "$label" to the top.' : 'Unpinned "$label".',
          ),
          duration: const Duration(seconds: 2),
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

      final notice =
          context.read<ChatRoomsProvider>().consumePendingSystemNotice();
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

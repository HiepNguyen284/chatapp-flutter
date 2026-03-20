import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_room_model.dart';
import '../../models/user_with_avatar_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_rooms_provider.dart';
import '../../services/invitation_service.dart';
import '../../services/user_service.dart';
import '../../widgets/app_avatar.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _searchController = TextEditingController();
  final Set<String> _selectedUsernames = {};

  Timer? _debounce;
  List<UserWithAvatarModel> _searchResults = const [];
  bool _isSearching = false;
  bool _isSubmitting = false;
  int? _baseRoomId;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchUsers(query);
    });
  }

  Future<void> _searchUsers(String query) async {
    final userService = context.read<UserService>();
    final roomsProvider = context.read<ChatRoomsProvider>();
    final authProvider = context.read<AuthProvider>();

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = const [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final users = await userService.searchUsers(query: trimmed);
      final rooms = roomsProvider.rooms;
      ChatRoomModel? selectedBaseRoom;
      for (final room in rooms) {
        if (room.id == _baseRoomId) {
          selectedBaseRoom = room;
          break;
        }
      }

      final currentUsername = authProvider.username;
      final memberSet = {
        ...?selectedBaseRoom?.membersUsername,
        if (currentUsername != null) currentUsername,
      };

      final filtered = users.where((user) {
        final username = user.username;
        if (username == null || username.isEmpty) {
          return false;
        }
        return !memberSet.contains(username);
      }).toList();

      if (!mounted) {
        return;
      }
      setState(() {
        _searchResults = filtered;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _createGroup() async {
    if (_baseRoomId == null || _selectedUsernames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select base room and members')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final invitationService = context.read<InvitationService>();
    final failed = <String>[];

    for (final username in _selectedUsernames) {
      try {
        await invitationService.sendInvitation(
          receiverUserName: username,
          chatGroupId: _baseRoomId,
        );
      } catch (_) {
        failed.add(username);
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (failed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitations sent. Group will appear when users accept.'),
        ),
      );
      Navigator.pop(context, true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Some invitations failed: ${failed.join(', ')}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatRoomsProvider = context.watch<ChatRoomsProvider>();
    final currentUsername = context.watch<AuthProvider>().username;

    final baseRooms = chatRoomsProvider.rooms
        .where((room) => room.type == ChatRoomType.duo)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: DropdownButtonFormField<int>(
              value: _baseRoomId,
              items: baseRooms
                  .map(
                    (room) => DropdownMenuItem<int>(
                      value: room.id,
                      child: Text(room.displayNameFor(currentUsername)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _baseRoomId = value;
                  _selectedUsernames.clear();
                });
                _searchUsers(_searchController.text);
              },
              decoration: const InputDecoration(
                labelText: 'Base chat (DUO)',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search username to add',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_selectedUsernames.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selectedUsernames
                    .map(
                      (username) => InputChip(
                        label: Text(username),
                        onDeleted: () {
                          setState(() {
                            _selectedUsernames.remove(username);
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                final username = user.username;
                final selected =
                    username != null && _selectedUsernames.contains(username);

                return ListTile(
                  leading: AppAvatar(
                    url: user.avatar?.source,
                    name: username ?? 'U',
                  ),
                  title: Text(username ?? 'Unknown user'),
                  trailing: IconButton(
                    onPressed: username == null
                        ? null
                        : () {
                            setState(() {
                              if (selected) {
                                _selectedUsernames.remove(username);
                              } else {
                                _selectedUsernames.add(username);
                              }
                            });
                          },
                    icon: Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.add_circle_outline_rounded,
                      color: selected ? const Color(0xFF168AFF) : null,
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: FilledButton(
                onPressed: _isSubmitting ? null : _createGroup,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send invitations to create group'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

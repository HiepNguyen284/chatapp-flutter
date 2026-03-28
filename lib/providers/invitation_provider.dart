import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/invitation_model.dart';
import '../models/user_with_avatar_model.dart';
import '../services/invitation_service.dart';
import '../services/realtime_service.dart';

class GroupAddedNotificationModel {
  const GroupAddedNotificationModel({
    required this.roomId,
    required this.roomName,
    required this.addedBy,
    required this.createdAt,
    required this.isRead,
  });

  final int? roomId;
  final String roomName;
  final String addedBy;
  final DateTime createdAt;
  final bool isRead;

  GroupAddedNotificationModel copyWith({
    int? roomId,
    String? roomName,
    String? addedBy,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return GroupAddedNotificationModel(
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      addedBy: addedBy ?? this.addedBy,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

class InvitationProvider extends ChangeNotifier {
  InvitationProvider(this._invitationService, this._realtimeService);

  final InvitationService _invitationService;
  final RealtimeService _realtimeService;

  StreamSubscription<InvitationModel>? _invitationSub;
  StreamSubscription<InvitationReplyEvent>? _invitationReplySub;
  StreamSubscription<GroupAddedEvent>? _groupAddedSub;
  StreamSubscription<UserWithAvatarModel>? _profileSub;

  bool _isLoading = false;
  String? _error;
  List<InvitationModel> _items = const [];
  List<GroupAddedNotificationModel> _groupAddedNotifications = const [];
  bool _isInvitesViewActive = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<InvitationModel> get items => _items;
  List<GroupAddedNotificationModel> get groupAddedNotifications =>
      _groupAddedNotifications;
  int get pendingCount =>
      _items.where((item) => item.isPending).length + unreadGroupAddedCount;
  int get unreadGroupAddedCount =>
      _groupAddedNotifications.where((item) => !item.isRead).length;

  Future<void> startRealtime() async {
    await _realtimeService.connect();

    _invitationSub ??= _realtimeService.invitationStream.listen((item) {
      _items = [
        item,
        ..._items.where((invitation) => invitation.id != item.id)
      ];
      notifyListeners();
    });

    _invitationReplySub ??=
        _realtimeService.invitationReplyStream.listen((event) {
      if (event.chatRoom != null) {
        _items = _items.where((item) => item.isPending).toList();
        notifyListeners();
      }
      loadInvitations();
    });

    _groupAddedSub ??= _realtimeService.groupAddedStream.listen((event) {
      final rawRoomName = (event.roomName ?? '').trim();
      final rawAddedBy = (event.addedBy ?? '').trim();
      final roomName = rawRoomName.isEmpty ? 'Group chat' : rawRoomName;
      final addedBy = rawAddedBy.isEmpty ? 'Someone' : rawAddedBy;
      final now = DateTime.now();

      final hasNearDuplicate = _groupAddedNotifications.any((item) {
        if (item.roomId != event.roomId ||
            item.roomName != roomName ||
            item.addedBy != addedBy) {
          return false;
        }
        return now.difference(item.createdAt).inSeconds.abs() <= 3;
      });
      if (hasNearDuplicate) {
        return;
      }

      final entry = GroupAddedNotificationModel(
        roomId: event.roomId,
        roomName: roomName,
        addedBy: addedBy,
        createdAt: now,
        isRead: _isInvitesViewActive,
      );

      _groupAddedNotifications = [entry, ..._groupAddedNotifications];
      notifyListeners();
    });

    _profileSub ??= _realtimeService.profileStream.listen((profile) {
      applyUserProfileUpdate(profile);
    });
  }

  void setInvitesViewActive(bool active) {
    if (_isInvitesViewActive == active) {
      return;
    }

    _isInvitesViewActive = active;
    if (active) {
      markAllGroupAddedNotificationsRead();
    }
  }

  void markAllGroupAddedNotificationsRead() {
    final hasUnread = _groupAddedNotifications.any((item) => !item.isRead);
    if (!hasUnread) {
      return;
    }

    _groupAddedNotifications = _groupAddedNotifications
        .map((item) => item.isRead ? item : item.copyWith(isRead: true))
        .toList();
    notifyListeners();
  }

  void removeGroupAddedNotification(GroupAddedNotificationModel target) {
    final before = _groupAddedNotifications.length;
    _groupAddedNotifications = _groupAddedNotifications
        .where((item) => !identical(item, target))
        .toList();
    if (_groupAddedNotifications.length != before) {
      notifyListeners();
    }
  }

  void stopRealtime() {
    _invitationSub?.cancel();
    _invitationSub = null;

    _invitationReplySub?.cancel();
    _invitationReplySub = null;

    _groupAddedSub?.cancel();
    _groupAddedSub = null;

    _profileSub?.cancel();
    _profileSub = null;
  }

  Future<void> loadInvitations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _items = await _invitationService.listInvitations();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reply({
    required int invitationId,
    required bool accept,
  }) async {
    try {
      await _invitationService.replyInvitation(
        invitationId: invitationId,
        accept: accept,
      );
      await loadInvitations();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void applyUserProfileUpdate(UserWithAvatarModel profile) {
    final username = (profile.username ?? '').trim();
    if (username.isEmpty || _items.isEmpty) {
      return;
    }

    var changed = false;
    final next = _items.map((item) {
      final sender = item.sender;
      final receiver = item.receiver;

      final nextSender =
          (sender?.username ?? '').trim() == username ? profile : sender;
      final nextReceiver =
          (receiver?.username ?? '').trim() == username ? profile : receiver;

      if (nextSender == sender && nextReceiver == receiver) {
        return item;
      }

      changed = true;
      return InvitationModel(
        id: item.id,
        sender: nextSender,
        receiver: nextReceiver,
        chatRoomId: item.chatRoomId,
        status: item.status,
      );
    }).toList();

    if (!changed) {
      return;
    }

    _items = next;
    notifyListeners();
  }

  @override
  void dispose() {
    stopRealtime();
    super.dispose();
  }
}

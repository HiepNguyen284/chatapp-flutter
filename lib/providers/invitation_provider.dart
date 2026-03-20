import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/invitation_model.dart';
import '../services/invitation_service.dart';
import '../services/realtime_service.dart';

class InvitationProvider extends ChangeNotifier {
  InvitationProvider(this._invitationService, this._realtimeService);

  final InvitationService _invitationService;
  final RealtimeService _realtimeService;

  StreamSubscription<InvitationModel>? _invitationSub;
  StreamSubscription<InvitationReplyEvent>? _invitationReplySub;

  bool _isLoading = false;
  String? _error;
  List<InvitationModel> _items = const [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<InvitationModel> get items => _items;
  int get pendingCount => _items.where((item) => item.isPending).length;

  Future<void> startRealtime() async {
    await _realtimeService.connect();

    _invitationSub ??= _realtimeService.invitationStream.listen((item) {
      _items = [item, ..._items.where((invitation) => invitation.id != item.id)];
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
  }

  void stopRealtime() {
    _invitationSub?.cancel();
    _invitationSub = null;

    _invitationReplySub?.cancel();
    _invitationReplySub = null;
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

  @override
  void dispose() {
    stopRealtime();
    super.dispose();
  }
}

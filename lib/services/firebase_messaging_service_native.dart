import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import '../models/fcm_notification_payload.dart';
import 'local_notification_service.dart';

class FirebaseMessagingService {
  FirebaseMessagingService({
    required this.localNotificationService,
    required this.apiClient,
  });

  final LocalNotificationService localNotificationService;
  final ApiClient apiClient;

  final StreamController<FcmNotificationPayload> _tapController =
      StreamController<FcmNotificationPayload>.broadcast();

  Stream<FcmNotificationPayload> get tapStream => _tapController.stream;

  Future<void> initialize() async {
    // Don't block the app - run FCM init in background
    unawaited(_initializeAsync());
  }

  Future<void> _initializeAsync() async {
    try {
      print('FCM: Requesting permission...');
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print('FCM: Permission granted');
    } catch (e) {
      print('FCM: Permission request failed (non-fatal): $e');
    }

    try {
      print('FCM: Getting token...');
      final token = await FirebaseMessaging.instance.getToken();
      print('FCM: Token = $token');
      if (token != null) {
        await _sendTokenToBackend(token);
      } else {
        print('FCM: getToken() returned null');
      }
    } catch (e) {
      print('FCM: Failed to get token: $e');
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      print('FCM: Token refreshed');
      _sendTokenToBackend(newToken);
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    try {
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      print('FCM: getInitialMessage failed: $e');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      print('FCM: Sending token to backend...');
      await apiClient.postJson(
        '/api/v1/users/fcm-token/',
        {'token': token},
      );
      print('FCM: Token registered successfully');
    } catch (e) {
      print('FCM: Failed to register FCM token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('FCM: Foreground message: ${message.data}');
    final data = message.data;
    final type = data['type'] as String?;
    final title =
        message.notification?.title ?? data['title'] ?? 'New notification';
    final body = message.notification?.body ?? data['body'] ?? '';

    switch (type) {
      case 'message':
        final roomId = int.tryParse(data['roomId'] ?? '0');
        if (roomId != null && roomId > 0) {
          localNotificationService.showMessageNotification(
            roomId: roomId,
            title: title,
            body: body,
          );
        }
        break;
      case 'invitation':
      case 'group_invitation':
        final invitationId = int.tryParse(data['invitationId'] ?? '0');
        if (invitationId != null && invitationId > 0) {
          localNotificationService.showInvitationNotification(
            invitationId: invitationId,
            title: title,
            body: body,
          );
        }
        break;
      case 'group_added':
      case 'group_member_removed':
        final roomId = int.tryParse(data['roomId'] ?? '0');
        if (roomId != null && roomId > 0) {
          localNotificationService.showGroupAddedNotification(
            roomId: roomId,
            title: title,
            body: body,
          );
        }
        break;
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final payload = FcmNotificationPayload.fromData(data);
    _tapController.add(payload);
  }

  void dispose() => _tapController.close();
}

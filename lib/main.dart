import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'firebase_init_stub.dart'
    if (dart.library.io) 'firebase_init_native.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/chatbot_service.dart';
import 'services/chat_room_service.dart';
import 'services/group_chat_service.dart';
import 'services/invitation_service.dart';
import 'services/local_notification_service.dart';
import 'services/message_service.dart';
import 'services/realtime_service.dart';
import 'services/token_storage_service.dart';
import 'services/unread_state_service.dart';
import 'services/user_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    try {
      await initFirebase();
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
    }
  }

  final localNotificationService = LocalNotificationService();
  await localNotificationService.requestPermissions();

  final tokenStorage = TokenStorageService();
  final apiClient = ApiClient(tokenStorage: tokenStorage);

  final authService = AuthService(apiClient);
  final chatbotService = ChatbotService(apiClient);
  final chatRoomService = ChatRoomService(apiClient);
  final groupChatService = GroupChatService(apiClient);
  final messageService = MessageService(apiClient);
  final invitationService = InvitationService(apiClient);
  final userService = UserService(apiClient);
  final realtimeService = RealtimeService(tokenStorage, apiClient);
  final unreadStateService = UnreadStateService();

  runApp(
    MultiProvider(
      providers: createAppProviders(
        apiClient: apiClient,
        authService: authService,
        chatbotService: chatbotService,
        chatRoomService: chatRoomService,
        groupChatService: groupChatService,
        userService: userService,
        invitationService: invitationService,
        messageService: messageService,
        realtimeService: realtimeService,
        unreadStateService: unreadStateService,
        tokenStorage: tokenStorage,
        localNotificationService: localNotificationService,
      ),
      child: const MessengerApp(),
    ),
  );
}

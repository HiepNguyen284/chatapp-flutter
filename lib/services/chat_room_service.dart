import 'dart:convert';

import '../models/chat_room_model.dart';
import 'api_client.dart';

class ChatRoomService {
  const ChatRoomService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ChatRoomModel>> listChatRooms() async {
    final response = await _apiClient.get('/api/v1/chatrooms/');

    if (response.statusCode != 200) {
      throw Exception('Load chatrooms failed: ${response.body}');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return body
        .whereType<Map<String, dynamic>>()
        .map(ChatRoomModel.fromJson)
        .toList();
  }

  Future<void> removeFriend({required int roomId}) async {
    final response = await _apiClient.delete('/api/v1/chatrooms/$roomId/friend/');

    if (response.statusCode != 204) {
      throw Exception('Remove friend failed: ${response.body}');
    }
  }
}

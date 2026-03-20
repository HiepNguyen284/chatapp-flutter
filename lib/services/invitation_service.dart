import 'dart:convert';

import '../models/chat_room_model.dart';
import '../models/invitation_model.dart';
import 'api_client.dart';

class InvitationReplyResult {
  const InvitationReplyResult({
    required this.newChatRoom,
  });

  final ChatRoomModel? newChatRoom;

  factory InvitationReplyResult.fromJson(Map<String, dynamic> json) {
    final roomJson = json['newChatRoom'];
    return InvitationReplyResult(
      newChatRoom: roomJson is Map<String, dynamic>
          ? ChatRoomModel.fromJson(roomJson)
          : null,
    );
  }
}

class InvitationService {
  const InvitationService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<InvitationModel>> listInvitations() async {
    final response = await _apiClient.get('/api/v1/invitations/');
    if (response.statusCode != 200) {
      throw Exception('Load invitations failed: ${response.body}');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return body
        .whereType<Map<String, dynamic>>()
        .map(InvitationModel.fromJson)
        .toList();
  }

  Future<void> sendInvitation({
    required String receiverUserName,
    int? chatGroupId,
  }) async {
    final body = <String, dynamic>{
      'receiverUserName': receiverUserName,
      if (chatGroupId != null) 'chatGroupId': chatGroupId,
    };

    final response = await _apiClient.postJson(
      '/api/v1/invitations/',
      body,
    );

    if (response.statusCode != 201) {
      throw Exception('Send invitation failed: ${response.body}');
    }
  }

  Future<InvitationReplyResult?> replyInvitation({
    required int invitationId,
    required bool accept,
  }) async {
    final response = await _apiClient.patchJson(
      '/api/v1/invitations/$invitationId',
      {'accept': accept},
    );

    if (response.statusCode == 204 && response.body.isEmpty) {
      return null;
    }

    if (response.statusCode != 204) {
      throw Exception('Reply invitation failed: ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return InvitationReplyResult.fromJson(body);
  }
}

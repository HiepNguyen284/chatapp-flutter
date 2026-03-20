import 'dart:convert';

import '../models/user_presence_model.dart';
import '../models/user_with_avatar_model.dart';
import 'api_client.dart';

class UserService {
  const UserService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<UserWithAvatarModel>> searchUsers({
    required String query,
    int limit = 10,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/users/search/',
      query: {
        'q': query,
        'limit': limit,
      },
      authRequired: false,
    );

    if (response.statusCode != 200) {
      throw Exception('Search user failed: ${response.body}');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return body
        .whereType<Map<String, dynamic>>()
        .map(UserWithAvatarModel.fromJson)
        .toList();
  }

  Future<UserPresenceModel> getPresence(String username) async {
    final response = await _apiClient.get(
      '/api/v1/users/$username/presence/',
    );

    if (response.statusCode != 200) {
      throw Exception('Load presence failed: ${response.body}');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return UserPresenceModel.fromJson(body);
  }
}

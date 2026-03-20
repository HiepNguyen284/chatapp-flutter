import 'dart:convert';

import '../models/token_pair_model.dart';
import '../models/user_credentials.dart';
import 'api_client.dart';

class AuthService {
  const AuthService(this._apiClient);

  final ApiClient _apiClient;

  Future<void> register(UserCredentials credentials) async {
    try {
      final response = await _apiClient.postJson(
        '/api/v1/users/register/',
        credentials.toJson(),
        authRequired: false,
      );

      if (response.statusCode != 201) {
        throw Exception(_buildAuthError('Register failed', response.body));
      }
    } catch (e) {
      throw Exception(_friendlyNetworkError(e));
    }
  }

  Future<TokenPairModel> login(UserCredentials credentials) async {
    try {
      final response = await _apiClient.postJson(
        '/api/v1/users/token/',
        credentials.toJson(),
        authRequired: false,
      );

      if (response.statusCode != 200) {
        throw Exception(_buildAuthError('Login failed', response.body));
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return TokenPairModel.fromJson(body);
    } catch (e) {
      throw Exception(_friendlyNetworkError(e));
    }
  }

  String _buildAuthError(String prefix, String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final detail = data['detail'] ?? data['message'] ?? data['error'];
        if (detail != null && detail.toString().trim().isNotEmpty) {
          return '$prefix: ${detail.toString().trim()}';
        }
      }
    } catch (_) {
      // Keep fallback below when response is plain text or invalid json.
    }

    final trimmed = body.trim();
    return trimmed.isEmpty ? prefix : '$prefix: $trimmed';
  }

  String _friendlyNetworkError(Object error) {
    final raw = error.toString();
    final lowered = raw.toLowerCase();

    if (lowered.contains('xmlhttprequest error') ||
        lowered.contains('failed host lookup') ||
        lowered.contains('connection refused')) {
      return 'Khong ket noi duoc toi server. Kiem tra backend dang chay va URL API_BASE_URL.';
    }

    return raw;
  }
}

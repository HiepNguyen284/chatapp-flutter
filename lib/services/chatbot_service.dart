import 'dart:convert';

import '../models/chatbot_conversation_model.dart';
import '../models/chatbot_message_model.dart';
import '../models/chatbot_stream_event_model.dart';
import 'api_client.dart';

class ChatbotService {
  const ChatbotService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ChatbotConversationModel>> listConversations() async {
    final response = await _apiClient.get('/api/v1/chatbot/conversations');
    if (response.statusCode != 200) {
      throw Exception('Load chatbot conversations failed: ${response.body}');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return body
        .whereType<Map<String, dynamic>>()
        .map(ChatbotConversationModel.fromJson)
        .toList();
  }

  Future<ChatbotConversationModel> createConversation({String? title}) async {
    final response = await _apiClient.postJson(
      '/api/v1/chatbot/conversations',
      {
        if ((title ?? '').trim().isNotEmpty) 'title': title!.trim(),
      },
    );

    if (response.statusCode != 201) {
      throw Exception('Create chatbot conversation failed: ${response.body}');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw Exception('Create chatbot conversation failed: invalid response');
    }

    return ChatbotConversationModel.fromJson(body);
  }

  Future<List<ChatbotMessageModel>> listMessages({
    required int conversationId,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/chatbot/conversations/$conversationId/messages',
    );

    if (response.statusCode != 200) {
      throw Exception('Load chatbot messages failed: ${response.body}');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return body
        .whereType<Map<String, dynamic>>()
        .map(ChatbotMessageModel.fromJson)
        .toList();
  }

  Future<void> deleteConversation({required int conversationId}) async {
    final response = await _apiClient.delete(
      '/api/v1/chatbot/conversations/$conversationId',
    );

    if (response.statusCode != 204) {
      throw Exception('Delete chatbot conversation failed: ${response.body}');
    }
  }

  Future<Stream<ChatbotStreamEventModel>> streamAssistantResponse({
    required int conversationId,
    required String message,
    bool useMcp = false,
    String? mcpSessionId,
    String? mcpMetadata,
    String? model,
  }) async {
    final response = await _apiClient.postJsonStream(
      '/api/v1/chatbot/conversations/$conversationId/stream',
      {
        'message': message.trim(),
        if ((model ?? '').trim().isNotEmpty) 'model': model!.trim(),
        'useMcp': useMcp,
        if ((mcpSessionId ?? '').trim().isNotEmpty)
          'mcpSessionId': mcpSessionId!.trim(),
        if ((mcpMetadata ?? '').trim().isNotEmpty)
          'mcpMetadata': mcpMetadata!.trim(),
      },
    );

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw Exception('Stream chatbot response failed: $body');
    }

    return _parseSse(response.stream);
  }

  Stream<ChatbotStreamEventModel> _parseSse(Stream<List<int>> byteStream) async* {
    final lines = byteStream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    String? eventName;
    final dataLines = <String>[];

    ChatbotStreamEventModel? parseEvent(String? name, List<String> rawDataLines) {
      if (name == null || rawDataLines.isEmpty) {
        return null;
      }

      final payloadRaw = rawDataLines.join('\n').trim();
      if (payloadRaw.isEmpty) {
        return null;
      }

      Map<String, dynamic>? payload;
      try {
        final decoded = jsonDecode(payloadRaw);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        }
      } catch (_) {
        // Keep raw payload fallback when event data is not strict JSON.
      }

      switch (name) {
        case 'token':
          final token = (payload?['token'] ?? payloadRaw).toString();
          if (token.isEmpty) {
            return null;
          }
          return ChatbotStreamEventModel.token(token);
        case 'done':
          final content = (payload?['content'] ?? '').toString();
          return ChatbotStreamEventModel.done(content);
        case 'error':
          final message = (payload?['message'] ?? payloadRaw).toString();
          return ChatbotStreamEventModel.error(message);
        default:
          return ChatbotStreamEventModel.unknown();
      }
    }

    await for (final line in lines) {
      if (line.isEmpty) {
        final event = parseEvent(eventName, dataLines);
        if (event != null) {
          yield event;
        }

        eventName = null;
        dataLines.clear();
        continue;
      }

      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
        continue;
      }

      if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }

    final trailingEvent = parseEvent(eventName, dataLines);
    if (trailingEvent != null) {
      yield trailingEvent;
    }
  }
}

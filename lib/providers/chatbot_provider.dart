import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chatbot_conversation_model.dart';
import '../models/chatbot_message_model.dart';
import '../models/chatbot_stream_event_model.dart';
import '../services/chatbot_service.dart';

class ChatbotProvider extends ChangeNotifier {
  ChatbotProvider(this._chatbotService);

  final ChatbotService _chatbotService;

  bool _isLoadingConversations = false;
  bool _isLoadingMessages = false;
  bool _isCreatingConversation = false;
  bool _isDeletingConversation = false;
  bool _isStreaming = false;
  String? _error;

  List<ChatbotConversationModel> _conversations = const [];
  List<ChatbotMessageModel> _messages = const [];

  int? _activeConversationId;
  String _streamingAssistantText = '';

  bool _useMcp = false;
  String _mcpSessionId = '';
  String _mcpMetadata = '';

  bool get isLoadingConversations => _isLoadingConversations;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isCreatingConversation => _isCreatingConversation;
  bool get isDeletingConversation => _isDeletingConversation;
  bool get isStreaming => _isStreaming;
  String? get error => _error;

  List<ChatbotConversationModel> get conversations => _conversations;
  List<ChatbotMessageModel> get messages => _messages;

  int? get activeConversationId => _activeConversationId;
  String get streamingAssistantText => _streamingAssistantText;

  bool get useMcp => _useMcp;
  String get mcpSessionId => _mcpSessionId;
  String get mcpMetadata => _mcpMetadata;

  Future<void> bootstrap() async {
    await loadConversations();

    if (_conversations.isEmpty) {
      await createConversation(openConversationAfterCreate: true);
      return;
    }

    if (_activeConversationId == null) {
      await openConversation(_conversations.first.id);
    }
  }

  Future<void> loadConversations() async {
    _isLoadingConversations = true;
    _error = null;
    notifyListeners();

    try {
      final loaded = await _chatbotService.listConversations();
      _conversations = loaded;

      if (_activeConversationId != null &&
          !_conversations.any((item) => item.id == _activeConversationId)) {
        _activeConversationId = null;
        _messages = const [];
      }
    } catch (e) {
      _error = _friendlyError(
        e,
        fallback: 'Không thể tải danh sách hội thoại chatbot',
      );
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  Future<void> createConversation({
    String? title,
    bool openConversationAfterCreate = true,
  }) async {
    _isCreatingConversation = true;
    _error = null;
    notifyListeners();

    try {
      final created = await _chatbotService.createConversation(title: title);
      _conversations = [created, ..._conversations];

      if (openConversationAfterCreate) {
        await openConversation(created.id);
      }
    } catch (e) {
      _error = _friendlyError(
        e,
        fallback: 'Không thể tạo hội thoại chatbot mới',
      );
    } finally {
      _isCreatingConversation = false;
      notifyListeners();
    }
  }

  Future<bool> deleteConversation(int conversationId) async {
    if (_isStreaming || _isDeletingConversation) {
      return false;
    }

    _isDeletingConversation = true;
    _error = null;
    notifyListeners();

    final deletingActive = _activeConversationId == conversationId;

    try {
      await _chatbotService.deleteConversation(conversationId: conversationId);

      _conversations = _conversations
          .where((item) => item.id != conversationId)
          .toList(growable: false);

      if (deletingActive) {
        _activeConversationId = null;
        _messages = const [];
        _streamingAssistantText = '';
      }

      if (_conversations.isEmpty) {
        await createConversation(openConversationAfterCreate: true);
      } else if (deletingActive || _activeConversationId == null) {
        await openConversation(_conversations.first.id);
      }

      await loadConversations();
      return true;
    } catch (e) {
      _error = _friendlyError(
        e,
        fallback: 'Không thể xóa hội thoại chatbot',
      );
      notifyListeners();
      return false;
    } finally {
      _isDeletingConversation = false;
      notifyListeners();
    }
  }

  Future<void> openConversation(int conversationId) async {
    _activeConversationId = conversationId;
    _isLoadingMessages = true;
    _error = null;
    notifyListeners();

    try {
      final loaded = await _chatbotService.listMessages(
        conversationId: conversationId,
      );
      _messages = loaded;
      _streamingAssistantText = '';

      final conversation = _conversations
          .where((item) => item.id == conversationId)
          .cast<ChatbotConversationModel?>()
          .firstWhere((item) => item != null, orElse: () => null);

      _useMcp = conversation?.mcpEnabled ?? false;
      _mcpSessionId = conversation?.mcpSessionId ?? '';
      if (!_useMcp) {
        _mcpMetadata = '';
      }
    } catch (e) {
      _error = _friendlyError(
        e,
        fallback: 'Không thể tải nội dung hội thoại chatbot',
      );
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  void setUseMcp(bool value) {
    _useMcp = value;
    if (!value) {
      _mcpMetadata = '';
    }
    notifyListeners();
  }

  void setMcpSessionId(String value) {
    _mcpSessionId = value.trim();
    notifyListeners();
  }

  void setMcpMetadata(String value) {
    _mcpMetadata = value.trim();
    notifyListeners();
  }

  String _friendlyError(
    Object error, {
    required String fallback,
  }) {
    var raw = error.toString().trim();
    if (raw.isEmpty) {
      return fallback;
    }

    if (raw.startsWith('Exception:')) {
      raw = raw.substring('Exception:'.length).trim();
    }

    final jsonStart = raw.indexOf('{');
    if (jsonStart >= 0) {
      final jsonPayload = raw.substring(jsonStart).trim();
      try {
        final decoded = jsonDecode(jsonPayload);
        if (decoded is Map<String, dynamic>) {
          final title = (decoded['title'] ?? '').toString().trim();
          final detail = (decoded['detail'] ?? '').toString().trim();

          if (title.isNotEmpty && detail.isNotEmpty && detail != title) {
            return '$title: $detail';
          }
          if (title.isNotEmpty) {
            return title;
          }
          if (detail.isNotEmpty) {
            return detail;
          }
        }
      } catch (_) {
        // Keep raw text fallback when payload is not valid JSON.
      }
    }

    return raw;
  }

  Future<bool> sendMessage(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty || _isStreaming) {
      return false;
    }

    _error = null;
    _streamingAssistantText = '';

    if (_activeConversationId == null) {
      await createConversation(openConversationAfterCreate: true);
    }

    final conversationId = _activeConversationId;
    if (conversationId == null) {
      _error = 'Không thể tạo hội thoại chatbot';
      notifyListeners();
      return false;
    }

    _messages = [..._messages, ChatbotMessageModel.localUser(normalized)];
    _isStreaming = true;
    notifyListeners();

    try {
      final eventStream = await _chatbotService.streamAssistantResponse(
        conversationId: conversationId,
        message: normalized,
        useMcp: _useMcp,
        mcpSessionId: _mcpSessionId,
        mcpMetadata: _mcpMetadata,
      );

      await for (final event in eventStream) {
        switch (event.type) {
          case ChatbotStreamEventType.token:
            _streamingAssistantText += event.token ?? '';
            notifyListeners();
            break;
          case ChatbotStreamEventType.done:
            final content = (event.content ?? '').trim();
            if (content.isNotEmpty) {
              _streamingAssistantText = content;
            }
            notifyListeners();
            break;
          case ChatbotStreamEventType.error:
            _error = _friendlyError(
              event.errorMessage ?? '',
              fallback: 'Không thể nhận phản hồi từ chatbot',
            );
            notifyListeners();
            break;
          case ChatbotStreamEventType.unknown:
            break;
        }
      }

      await openConversation(conversationId);
      await loadConversations();

      return _error == null;
    } catch (e) {
      _error = _friendlyError(
        e,
        fallback: 'Không thể gửi tin nhắn tới chatbot',
      );
      notifyListeners();
      return false;
    } finally {
      _isStreaming = false;
      _streamingAssistantText = '';
      notifyListeners();
    }
  }
}

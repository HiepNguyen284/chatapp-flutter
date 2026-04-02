enum ChatbotRole {
  user,
  assistant,
  system,
  tool,
  unknown,
}

ChatbotRole parseChatbotRole(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'user':
      return ChatbotRole.user;
    case 'assistant':
      return ChatbotRole.assistant;
    case 'system':
      return ChatbotRole.system;
    case 'tool':
      return ChatbotRole.tool;
    default:
      return ChatbotRole.unknown;
  }
}

class ChatbotMessageModel {
  const ChatbotMessageModel({
    required this.id,
    required this.role,
    required this.content,
    required this.createdOn,
    this.isLocal = false,
  });

  final int? id;
  final ChatbotRole role;
  final String content;
  final DateTime? createdOn;
  final bool isLocal;

  bool get isUser => role == ChatbotRole.user;
  bool get isAssistant => role == ChatbotRole.assistant;

  factory ChatbotMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatbotMessageModel(
      id: (json['id'] as num?)?.toInt(),
      role: parseChatbotRole(json['role']?.toString()),
      content: (json['content'] ?? '').toString(),
      createdOn: DateTime.tryParse((json['createdOn'] ?? '').toString()),
    );
  }

  factory ChatbotMessageModel.localUser(String content) {
    return ChatbotMessageModel(
      id: null,
      role: ChatbotRole.user,
      content: content,
      createdOn: DateTime.now(),
      isLocal: true,
    );
  }
}

enum ChatbotStreamEventType {
  token,
  done,
  error,
  unknown,
}

class ChatbotStreamEventModel {
  const ChatbotStreamEventModel({
    required this.type,
    this.token,
    this.content,
    this.errorMessage,
  });

  final ChatbotStreamEventType type;
  final String? token;
  final String? content;
  final String? errorMessage;

  factory ChatbotStreamEventModel.token(String token) {
    return ChatbotStreamEventModel(
      type: ChatbotStreamEventType.token,
      token: token,
    );
  }

  factory ChatbotStreamEventModel.done(String content) {
    return ChatbotStreamEventModel(
      type: ChatbotStreamEventType.done,
      content: content,
    );
  }

  factory ChatbotStreamEventModel.error(String message) {
    return ChatbotStreamEventModel(
      type: ChatbotStreamEventType.error,
      errorMessage: message,
    );
  }

  factory ChatbotStreamEventModel.unknown() {
    return const ChatbotStreamEventModel(
      type: ChatbotStreamEventType.unknown,
    );
  }
}

class ChatbotConversationModel {
  const ChatbotConversationModel({
    required this.id,
    required this.title,
    required this.preview,
    required this.mcpEnabled,
    required this.mcpSessionId,
    required this.createdOn,
    required this.updatedOn,
  });

  final int id;
  final String title;
  final String preview;
  final bool mcpEnabled;
  final String? mcpSessionId;
  final DateTime? createdOn;
  final DateTime? updatedOn;

  factory ChatbotConversationModel.fromJson(Map<String, dynamic> json) {
    return ChatbotConversationModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      preview: (json['preview'] ?? '').toString(),
      mcpEnabled: json['mcpEnabled'] == true,
      mcpSessionId: (json['mcpSessionId'] ?? '').toString().trim().isEmpty
          ? null
          : json['mcpSessionId'].toString(),
      createdOn: DateTime.tryParse((json['createdOn'] ?? '').toString()),
      updatedOn: DateTime.tryParse((json['updatedOn'] ?? '').toString()),
    );
  }
}

import 'attachment_model.dart';
import 'user_with_avatar_model.dart';

class MessageReceiveModel {
  const MessageReceiveModel({
    required this.id,
    required this.sender,
    required this.message,
    required this.sentOn,
    required this.attachments,
    required this.seenBy,
  });

  final int? id;
  final String? sender;
  final String? message;
  final DateTime? sentOn;
  final List<AttachmentModel> attachments;
  final List<UserWithAvatarModel> seenBy;

  factory MessageReceiveModel.fromJson(Map<String, dynamic> json) {
    final attachmentsRaw = json['attachments'] as List<dynamic>? ?? const [];
    final seenByRaw = json['seenBy'] as List<dynamic>? ?? const [];
    return MessageReceiveModel(
      id: json['id'] as int?,
      sender: json['sender'] as String?,
      message: json['message'] as String?,
      sentOn: DateTime.tryParse((json['sentOn'] ?? '').toString()),
      attachments: attachmentsRaw
          .whereType<Map<String, dynamic>>()
          .map(AttachmentModel.fromJson)
          .toList(),
      seenBy: seenByRaw
          .whereType<Map<String, dynamic>>()
          .map(UserWithAvatarModel.fromJson)
          .toList(),
    );
  }
}

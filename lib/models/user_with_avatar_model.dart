import 'attachment_model.dart';

class UserWithAvatarModel {
  const UserWithAvatarModel({
    required this.id,
    required this.username,
    required this.avatar,
  });

  final int? id;
  final String? username;
  final AttachmentModel? avatar;

  factory UserWithAvatarModel.fromJson(Map<String, dynamic> json) {
    final avatarJson = json['avatar'];
    return UserWithAvatarModel(
      id: json['id'] as int?,
      username: json['username'] as String?,
      avatar: avatarJson is Map<String, dynamic>
          ? AttachmentModel.fromJson(avatarJson)
          : null,
    );
  }
}

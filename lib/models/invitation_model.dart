import 'user_with_avatar_model.dart';

enum InvitationStatus { pending, accepted, rejected, unknown }

InvitationStatus parseInvitationStatus(String? raw) {
  switch (raw) {
    case 'PENDING':
      return InvitationStatus.pending;
    case 'ACCEPTED':
      return InvitationStatus.accepted;
    case 'REJECTED':
      return InvitationStatus.rejected;
    default:
      return InvitationStatus.unknown;
  }
}

class InvitationModel {
  const InvitationModel({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.chatRoomId,
    required this.status,
  });

  final int id;
  final UserWithAvatarModel? sender;
  final UserWithAvatarModel? receiver;
  final int? chatRoomId;
  final InvitationStatus status;

  factory InvitationModel.fromJson(Map<String, dynamic> json) {
    final senderJson = json['sender'];
    final receiverJson = json['receiver'];
    return InvitationModel(
      id: (json['id'] ?? 0) as int,
      sender: senderJson is Map<String, dynamic>
          ? UserWithAvatarModel.fromJson(senderJson)
          : null,
      receiver: receiverJson is Map<String, dynamic>
          ? UserWithAvatarModel.fromJson(receiverJson)
          : null,
      chatRoomId: json['chatRoomId'] as int?,
      status: parseInvitationStatus(json['status'] as String?),
    );
  }

  String get statusLabel {
    switch (status) {
      case InvitationStatus.pending:
        return 'Pending';
      case InvitationStatus.accepted:
        return 'Accepted';
      case InvitationStatus.rejected:
        return 'Rejected';
      case InvitationStatus.unknown:
        return 'Unknown';
    }
  }

  bool get isPending => status == InvitationStatus.pending;

  bool get isFriendInvitation => chatRoomId == null;

  String get invitationKindLabel =>
      isFriendInvitation ? 'friend request' : 'group invitation';
}

class FcmNotificationPayload {
  final String type;
  final String? roomId;
  final String? invitationId;
  final String? senderUsername;

  FcmNotificationPayload({
    required this.type,
    this.roomId,
    this.invitationId,
    this.senderUsername,
  });

  factory FcmNotificationPayload.fromData(Map<String, dynamic> data) {
    return FcmNotificationPayload(
      type: data['type'] ?? 'unknown',
      roomId: data['roomId']?.toString(),
      invitationId: data['invitationId']?.toString(),
      senderUsername: data['senderUsername'],
    );
  }
}

class UserPresenceModel {
  const UserPresenceModel({
    required this.username,
    required this.online,
    required this.lastSeenAt,
  });

  final String username;
  final bool online;
  final DateTime? lastSeenAt;

  factory UserPresenceModel.fromJson(Map<String, dynamic> json) {
    return UserPresenceModel(
      username: (json['username'] ?? '').toString(),
      online: json['online'] == true,
      lastSeenAt: DateTime.tryParse((json['lastSeenAt'] ?? '').toString()),
    );
  }
}

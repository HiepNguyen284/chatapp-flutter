class TokenPairModel {
  const TokenPairModel({
    required this.access,
    required this.refresh,
  });

  final String access;
  final String refresh;

  factory TokenPairModel.fromJson(Map<String, dynamic> json) {
    return TokenPairModel(
      access: (json['access'] ?? '').toString(),
      refresh: (json['refresh'] ?? '').toString(),
    );
  }
}

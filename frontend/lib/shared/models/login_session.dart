class LoginSession {
  final String id;
  final String userId;
  final String? ip;
  final String? userAgent;
  final DateTime createdAt;

  const LoginSession({
    required this.id,
    required this.userId,
    this.ip,
    this.userAgent,
    required this.createdAt,
  });

  factory LoginSession.fromJson(Map<String, dynamic> json) {
    return LoginSession(
      id: json['id'] as String,
      userId: json['userId'] as String,
      ip: json['ip'] as String?,
      userAgent: json['userAgent'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'ip': ip,
        'userAgent': userAgent,
        'createdAt': createdAt.toIso8601String(),
      };
}

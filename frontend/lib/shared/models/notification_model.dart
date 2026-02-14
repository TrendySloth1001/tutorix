class NotificationModel {
  final String id;
  final String? coachingId;
  final String? userId;
  final String type;
  final String title;
  final String message;
  final bool read;
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    this.coachingId,
    this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.read,
    this.data,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      coachingId: json['coachingId'],
      userId: json['userId'],
      type: json['type'],
      title: json['title'],
      message: json['message'],
      read: json['read'] ?? false,
      data: json['data'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  NotificationModel copyWith({bool? read}) {
    return NotificationModel(
      id: id,
      coachingId: coachingId,
      userId: userId,
      type: type,
      title: title,
      message: message,
      read: read ?? this.read,
      data: data,
      createdAt: createdAt,
    );
  }
}

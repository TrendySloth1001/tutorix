/// A notice / announcement sent to a batch by a teacher.
class BatchNoticeModel {
  final String id;
  final String batchId;
  final String title;
  final String message;
  final String priority; // low, normal, high, urgent
  final String sentById;
  final NoticeSender? sentBy;
  final DateTime? createdAt;

  const BatchNoticeModel({
    required this.id,
    required this.batchId,
    required this.title,
    required this.message,
    this.priority = 'normal',
    required this.sentById,
    this.sentBy,
    this.createdAt,
  });

  factory BatchNoticeModel.fromJson(Map<String, dynamic> json) {
    return BatchNoticeModel(
      id: json['id'] as String,
      batchId: json['batchId'] as String? ?? '',
      title: json['title'] as String,
      message: json['message'] as String,
      priority: json['priority'] as String? ?? 'normal',
      sentById: json['sentById'] as String? ?? '',
      sentBy: json['sentBy'] != null
          ? NoticeSender.fromJson(json['sentBy'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  /// Whether this is a high/urgent notice.
  bool get isImportant => priority == 'high' || priority == 'urgent';

  /// Color-meaningful label for priority.
  String get priorityLabel {
    switch (priority) {
      case 'urgent':
        return 'Urgent';
      case 'high':
        return 'High';
      case 'low':
        return 'Low';
      default:
        return 'Normal';
    }
  }
}

class NoticeSender {
  final String id;
  final String? name;
  final String? picture;

  const NoticeSender({required this.id, this.name, this.picture});

  factory NoticeSender.fromJson(Map<String, dynamic> json) {
    return NoticeSender(
      id: json['id'] as String,
      name: json['name'] as String?,
      picture: json['picture'] as String?,
    );
  }
}

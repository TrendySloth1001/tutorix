/// A notice / announcement sent to a batch by a teacher.
class BatchNoticeModel {
  final String id;
  final String batchId;
  final String title;
  final String message;
  final String priority; // low, normal, high, urgent
  final String
  type; // general, timetable_update, event, exam, holiday, assignment
  final String sentById;
  final NoticeSender? sentBy;
  final DateTime? createdAt;

  // Structured data
  final DateTime? date;
  final String? startTime;
  final String? endTime;
  final String? day;
  final String? location;

  const BatchNoticeModel({
    required this.id,
    required this.batchId,
    required this.title,
    required this.message,
    this.priority = 'normal',
    this.type = 'general',
    required this.sentById,
    this.sentBy,
    this.createdAt,
    this.date,
    this.startTime,
    this.endTime,
    this.day,
    this.location,
  });

  factory BatchNoticeModel.fromJson(Map<String, dynamic> json) {
    return BatchNoticeModel(
      id: json['id'] as String,
      batchId: json['batchId'] as String? ?? '',
      title: json['title'] as String,
      message: json['message'] as String,
      priority: json['priority'] as String? ?? 'normal',
      type: json['type'] as String? ?? 'general',
      sentById: json['sentById'] as String? ?? '',
      sentBy: json['sentBy'] != null
          ? NoticeSender.fromJson(json['sentBy'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : null,
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      day: json['day'] as String?,
      location: json['location'] as String?,
    );
  }

  /// Whether this is a high/urgent notice.
  bool get isImportant => priority == 'high' || priority == 'urgent';

  /// Whether this notice has structured time/date data.
  bool get hasScheduleInfo =>
      date != null || startTime != null || endTime != null || day != null;

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

  /// Human-readable type label.
  String get typeLabel {
    switch (type) {
      case 'timetable_update':
        return 'Timetable Update';
      case 'event':
        return 'Event';
      case 'exam':
        return 'Exam';
      case 'holiday':
        return 'Holiday';
      case 'assignment':
        return 'Assignment';
      default:
        return 'General';
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

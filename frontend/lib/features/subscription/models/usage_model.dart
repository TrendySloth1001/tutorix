/// Current resource usage for a coaching entity.
///
/// Backend returns structured objects per dimension:
///   { students: { used, limit, percent }, storage: { usedBytes, limitBytes, percent }, ... }
/// We extract flat used-counts for simplicity since plan limits are on PlanModel.
class UsageModel {
  final int students;
  final int parents;
  final int teachers;
  final int admins;
  final int batches;
  final int assessmentsThisMonth;
  final int storageBytes;

  const UsageModel({
    this.students = 0,
    this.parents = 0,
    this.teachers = 0,
    this.admins = 0,
    this.batches = 0,
    this.assessmentsThisMonth = 0,
    this.storageBytes = 0,
  });

  String get storageLabel {
    if (storageBytes == 0) return '0 MB';
    final mb = storageBytes / (1024 * 1024);
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
    return '${mb.toStringAsFixed(0)} MB';
  }

  /// Parse a dimension object like { used: 5, limit: 10, percent: 50 }.
  /// Returns the 'used' count.
  static int _used(dynamic v) {
    if (v is Map) return (v['used'] as num?)?.toInt() ?? 0;
    if (v is num) return v.toInt();
    return 0;
  }

  /// Parse storage object { usedBytes, limitBytes, percent }.
  static int _storageUsed(dynamic v) {
    if (v is Map) return (v['usedBytes'] as num?)?.toInt() ?? 0;
    if (v is num) return v.toInt();
    return 0;
  }

  factory UsageModel.fromJson(Map<String, dynamic> json) {
    return UsageModel(
      students: _used(json['students']),
      parents: _used(json['parents']),
      teachers: _used(json['teachers']),
      admins: _used(json['admins']),
      batches: _used(json['batches']),
      assessmentsThisMonth: _used(json['assessmentsThisMonth']),
      storageBytes: _storageUsed(json['storage']),
    );
  }
}

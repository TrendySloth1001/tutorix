/// Academic board (CBSE, ICSE, State boards, etc.)
class AcademicBoard {
  final String id;
  final String name;
  final String fullName;

  const AcademicBoard({
    required this.id,
    required this.name,
    required this.fullName,
  });

  factory AcademicBoard.fromJson(Map<String, dynamic> json) {
    return AcademicBoard(
      id: json['id'] as String,
      name: json['name'] as String,
      fullName: json['fullName'] as String,
    );
  }
}

/// Academic class (Nursery to Class 12, UG, etc.)
class AcademicClass {
  final String id;
  final String name;
  final String group;
  final int order;
  final bool requiresStream;
  final bool isCompetitiveOnly;

  const AcademicClass({
    required this.id,
    required this.name,
    required this.group,
    required this.order,
    this.requiresStream = false,
    this.isCompetitiveOnly = false,
  });

  factory AcademicClass.fromJson(Map<String, dynamic> json) {
    return AcademicClass(
      id: json['id'] as String,
      name: json['name'] as String,
      group: json['group'] as String,
      order: json['order'] as int,
      requiresStream: json['requiresStream'] == true,
      isCompetitiveOnly: json['isCompetitiveOnly'] == true,
    );
  }
}

/// Academic stream (Science PCM, PCB, Commerce, Arts)
class AcademicStream {
  final String id;
  final String name;
  final String description;
  final List<String> forClasses;

  const AcademicStream({
    required this.id,
    required this.name,
    required this.description,
    required this.forClasses,
  });

  factory AcademicStream.fromJson(Map<String, dynamic> json) {
    return AcademicStream(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      forClasses: (json['forClasses'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }
}

/// Competitive exam (JEE, NEET, CA, etc.)
class CompetitiveExam {
  final String id;
  final String name;
  final String category;
  final String description;

  const CompetitiveExam({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
  });

  factory CompetitiveExam.fromJson(Map<String, dynamic> json) {
    return CompetitiveExam(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
    );
  }
}

/// Academic subject
class AcademicSubject {
  final String id;
  final String name;
  final dynamic forStreams; // 'all' or List<String>
  final dynamic forClasses; // 'all' or List<String>

  const AcademicSubject({
    required this.id,
    required this.name,
    required this.forStreams,
    required this.forClasses,
  });

  factory AcademicSubject.fromJson(Map<String, dynamic> json) {
    return AcademicSubject(
      id: json['id'] as String,
      name: json['name'] as String,
      forStreams: json['forStreams'],
      forClasses: json['forClasses'],
    );
  }

  /// Check if this subject is available for a given class and stream
  bool isAvailableFor(String classId, String? streamId) {
    // Check class match
    final classMatch =
        forClasses == 'all' ||
        (forClasses is List && (forClasses as List).contains(classId));

    if (!classMatch) return false;
    if (streamId == null) return true;

    // Check stream match
    return forStreams == 'all' ||
        (forStreams is List && (forStreams as List).contains(streamId));
  }
}

/// All academic master data
class AcademicMasters {
  final List<AcademicBoard> boards;
  final List<AcademicClass> classes;
  final List<AcademicStream> streams;
  final List<CompetitiveExam> competitiveExams;
  final List<AcademicSubject> subjects;

  const AcademicMasters({
    required this.boards,
    required this.classes,
    required this.streams,
    required this.competitiveExams,
    required this.subjects,
  });

  factory AcademicMasters.fromJson(Map<String, dynamic> json) {
    return AcademicMasters(
      boards: (json['boards'] as List<dynamic>)
          .map((e) => AcademicBoard.fromJson(e))
          .toList(),
      classes: (json['classes'] as List<dynamic>)
          .map((e) => AcademicClass.fromJson(e))
          .toList(),
      streams: (json['streams'] as List<dynamic>)
          .map((e) => AcademicStream.fromJson(e))
          .toList(),
      competitiveExams: (json['competitiveExams'] as List<dynamic>)
          .map((e) => CompetitiveExam.fromJson(e))
          .toList(),
      subjects: (json['subjects'] as List<dynamic>)
          .map((e) => AcademicSubject.fromJson(e))
          .toList(),
    );
  }

  /// Get classes grouped by their group (Pre-Primary, Primary, etc.)
  Map<String, List<AcademicClass>> get classesGrouped {
    final grouped = <String, List<AcademicClass>>{};
    for (final cls in classes) {
      grouped.putIfAbsent(cls.group, () => []).add(cls);
    }
    return grouped;
  }

  /// Get competitive exams grouped by category
  Map<String, List<CompetitiveExam>> get examsByCategory {
    final grouped = <String, List<CompetitiveExam>>{};
    for (final exam in competitiveExams) {
      grouped.putIfAbsent(exam.category, () => []).add(exam);
    }
    return grouped;
  }

  /// Get subjects filtered for a specific class and optional stream
  List<AcademicSubject> getSubjectsFor(String classId, [String? streamId]) {
    return subjects.where((s) => s.isAvailableFor(classId, streamId)).toList();
  }

  /// Get streams available for a specific class
  List<AcademicStream> getStreamsFor(String classId) {
    return streams.where((s) => s.forClasses.contains(classId)).toList();
  }
}

/// Coaching category (Coaching Institute, Tuition, School, etc.)
class CoachingCategory {
  final String id;
  final String name;
  final String description;
  final String icon;

  const CoachingCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });

  factory CoachingCategory.fromJson(Map<String, dynamic> json) {
    return CoachingCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
    );
  }
}

/// Coaching subject
class CoachingSubject {
  final String id;
  final String name;
  final String category;

  const CoachingSubject({
    required this.id,
    required this.name,
    required this.category,
  });

  factory CoachingSubject.fromJson(Map<String, dynamic> json) {
    return CoachingSubject(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
    );
  }
}

/// Working day option
class WorkingDay {
  final String id;
  final String name;
  final String short;

  const WorkingDay({required this.id, required this.name, required this.short});

  factory WorkingDay.fromJson(Map<String, dynamic> json) {
    return WorkingDay(
      id: json['id'] as String,
      name: json['name'] as String,
      short: json['short'] as String,
    );
  }
}

/// Indian state
class IndianState {
  final String id;
  final String name;

  const IndianState({required this.id, required this.name});

  factory IndianState.fromJson(Map<String, dynamic> json) {
    return IndianState(id: json['id'] as String, name: json['name'] as String);
  }
}

/// All coaching master data
class CoachingMasters {
  final List<CoachingCategory> categories;
  final List<CoachingSubject> subjects;
  final List<WorkingDay> workingDays;
  final List<IndianState> states;

  const CoachingMasters({
    required this.categories,
    required this.subjects,
    required this.workingDays,
    required this.states,
  });

  factory CoachingMasters.fromJson(Map<String, dynamic> json) {
    return CoachingMasters(
      categories: (json['categories'] as List<dynamic>)
          .map((e) => CoachingCategory.fromJson(e))
          .toList(),
      subjects: (json['subjects'] as List<dynamic>)
          .map((e) => CoachingSubject.fromJson(e))
          .toList(),
      workingDays: (json['workingDays'] as List<dynamic>)
          .map((e) => WorkingDay.fromJson(e))
          .toList(),
      states: (json['states'] as List<dynamic>)
          .map((e) => IndianState.fromJson(e))
          .toList(),
    );
  }

  /// Get subjects grouped by category
  Map<String, List<CoachingSubject>> get subjectsByCategory {
    final grouped = <String, List<CoachingSubject>>{};
    for (final subject in subjects) {
      grouped.putIfAbsent(subject.category, () => []).add(subject);
    }
    return grouped;
  }
}

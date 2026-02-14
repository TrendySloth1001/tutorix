class CoachingModel {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? logo;
  final String status;
  final String ownerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Owner info (optional)
  final String? ownerName;
  final String? ownerPicture;
  
  // Stats (optional - may not be present on all endpoints)
  final int memberCount;
  final int teacherCount;
  final int studentCount;
  
  // User's role in this coaching (for joined coachings)
  final String? myRole;

  const CoachingModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.logo,
    this.status = 'active',
    required this.ownerId,
    this.createdAt,
    this.updatedAt,
    this.ownerName,
    this.ownerPicture,
    this.memberCount = 0,
    this.teacherCount = 0,
    this.studentCount = 0,
    this.myRole,
  });

  factory CoachingModel.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'] as Map<String, dynamic>?;
    return CoachingModel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      logo: json['logo'] as String?,
      status: json['status'] as String? ?? 'active',
      ownerId: json['ownerId'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      ownerName: owner?['name'] as String?,
      ownerPicture: owner?['picture'] as String?,
      memberCount: json['memberCount'] as int? ?? 0,
      teacherCount: json['teacherCount'] as int? ?? 0,
      studentCount: json['studentCount'] as int? ?? 0,
      myRole: json['myRole'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'description': description,
    'logo': logo,
    'status': status,
    'ownerId': ownerId,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'memberCount': memberCount,
    'teacherCount': teacherCount,
    'studentCount': studentCount,
    'myRole': myRole,
  };
}

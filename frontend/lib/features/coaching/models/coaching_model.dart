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
  });

  factory CoachingModel.fromJson(Map<String, dynamic> json) {
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
      };
}

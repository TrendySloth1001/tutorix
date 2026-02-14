import 'coaching_address.dart';

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

  // Onboarding and profile fields
  final String? tagline;
  final String? aboutUs;
  final String? contactEmail;
  final String? contactPhone;
  final String? whatsappPhone;
  final String? websiteUrl;
  final String? category;
  final List<String> subjects;
  final int? foundedYear;
  final bool isVerified;
  final bool onboardingComplete;

  // Address and branches
  final CoachingAddress? address;
  final List<CoachingBranch> branches;

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
    this.tagline,
    this.aboutUs,
    this.contactEmail,
    this.contactPhone,
    this.whatsappPhone,
    this.websiteUrl,
    this.category,
    this.subjects = const [],
    this.foundedYear,
    this.isVerified = false,
    this.onboardingComplete = false,
    this.address,
    this.branches = const [],
  });

  factory CoachingModel.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'] as Map<String, dynamic>?;
    final addressJson = json['address'] as Map<String, dynamic>?;
    final branchesJson = json['branches'] as List<dynamic>?;

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
      tagline: json['tagline'] as String?,
      aboutUs: json['aboutUs'] as String?,
      contactEmail: json['contactEmail'] as String?,
      contactPhone: json['contactPhone'] as String?,
      whatsappPhone: json['whatsappPhone'] as String?,
      websiteUrl: json['websiteUrl'] as String?,
      category: json['category'] as String?,
      subjects:
          (json['subjects'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      foundedYear: json['foundedYear'] as int?,
      isVerified: json['isVerified'] as bool? ?? false,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      address: addressJson != null
          ? CoachingAddress.fromJson(addressJson)
          : null,
      branches:
          branchesJson
              ?.map((e) => CoachingBranch.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
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
    'tagline': tagline,
    'aboutUs': aboutUs,
    'contactEmail': contactEmail,
    'contactPhone': contactPhone,
    'whatsappPhone': whatsappPhone,
    'websiteUrl': websiteUrl,
    'category': category,
    'subjects': subjects,
    'foundedYear': foundedYear,
    'isVerified': isVerified,
    'onboardingComplete': onboardingComplete,
    'address': address?.toJson(),
    'branches': branches.map((b) => b.toJson()).toList(),
  };

  /// Returns true if this coaching needs onboarding
  bool get needsOnboarding => !onboardingComplete;

  /// Returns true if the current user is the owner
  bool isOwner(String userId) => ownerId == userId;
}

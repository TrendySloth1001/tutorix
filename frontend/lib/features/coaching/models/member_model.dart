/// A member of a coaching (teacher, student, or admin).
class MemberModel {
  final String id;
  final String coachingId;
  final String role; // ADMIN, TEACHER, STUDENT
  final String? userId;
  final String? wardId;
  final String status; // active, pending, suspended
  final MemberUser? user;
  final MemberWard? ward;
  final DateTime? createdAt;

  const MemberModel({
    required this.id,
    required this.coachingId,
    required this.role,
    this.userId,
    this.wardId,
    this.status = 'active',
    this.user,
    this.ward,
    this.createdAt,
  });

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    return MemberModel(
      id: json['id'] as String,
      coachingId: json['coachingId'] as String,
      role: json['role'] as String? ?? 'STUDENT',
      userId: json['userId'] as String?,
      wardId: json['wardId'] as String?,
      status: json['status'] as String? ?? 'active',
      user: json['user'] != null
          ? MemberUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      ward: json['ward'] != null
          ? MemberWard.fromJson(json['ward'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  /// Display name: user name, ward name, or fallback.
  String get displayName {
    if (user != null) return user!.name ?? 'Unknown';
    if (ward != null) return ward!.name;
    return 'Unknown';
  }

  /// Display picture URL.
  String? get displayPicture {
    if (user != null) return user!.picture;
    if (ward != null) return ward!.picture;
    return null;
  }

  /// Subtitle for member tile.
  String get subtitle {
    if (user != null) return user!.email ?? '';
    if (ward != null && ward!.parent != null) {
      return 'Parent: ${ward!.parent!.name ?? ward!.parent!.email ?? ''}';
    }
    return '';
  }
}

class MemberUser {
  final String id;
  final String? name;
  final String? email;
  final String? picture;

  const MemberUser({
    required this.id,
    this.name,
    this.email,
    this.picture,
  });

  factory MemberUser.fromJson(Map<String, dynamic> json) {
    return MemberUser(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      picture: json['picture'] as String?,
    );
  }
}

class MemberWard {
  final String id;
  final String name;
  final String? picture;
  final String? parentId;
  final MemberUser? parent;

  const MemberWard({
    required this.id,
    required this.name,
    this.picture,
    this.parentId,
    this.parent,
  });

  factory MemberWard.fromJson(Map<String, dynamic> json) {
    return MemberWard(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unknown',
      picture: json['picture'] as String?,
      parentId: json['parentId'] as String?,
      parent: json['parent'] != null
          ? MemberUser.fromJson(json['parent'] as Map<String, dynamic>)
          : null,
    );
  }
}

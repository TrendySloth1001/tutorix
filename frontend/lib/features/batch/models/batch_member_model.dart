/// A member of a batch (teacher or student).
class BatchMemberModel {
  final String id;
  final String batchId;
  final String memberId;
  final String role; // TEACHER, STUDENT
  final DateTime? createdAt;

  // Nested member → user / ward info
  final BatchMemberUser? user;
  final BatchMemberWard? ward;
  final String? memberRole; // CoachingMember role (ADMIN, TEACHER, STUDENT)

  const BatchMemberModel({
    required this.id,
    required this.batchId,
    required this.memberId,
    required this.role,
    this.createdAt,
    this.user,
    this.ward,
    this.memberRole,
  });

  factory BatchMemberModel.fromJson(Map<String, dynamic> json) {
    final member = json['member'] as Map<String, dynamic>?;
    BatchMemberUser? user;
    BatchMemberWard? ward;
    String? memberRole;

    if (member != null) {
      memberRole = member['role'] as String?;
      final userJson = member['user'] as Map<String, dynamic>?;
      if (userJson != null) {
        user = BatchMemberUser.fromJson(userJson);
      }
      final wardJson = member['ward'] as Map<String, dynamic>?;
      if (wardJson != null) {
        ward = BatchMemberWard.fromJson(wardJson);
      }
    }

    return BatchMemberModel(
      id: json['id'] as String,
      batchId: json['batchId'] as String? ?? '',
      memberId: json['memberId'] as String? ?? '',
      role: json['role'] as String? ?? 'STUDENT',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      user: user,
      ward: ward,
      memberRole: memberRole,
    );
  }

  String get displayName {
    if (user != null) return user!.name ?? 'Unknown';
    if (ward != null) return ward!.name;
    return 'Unknown';
  }

  String? get displayPicture {
    if (user != null) return user!.picture;
    if (ward != null) return ward!.picture;
    return null;
  }

  String get subtitle {
    if (user != null) return user!.email ?? '';
    return '';
  }
}

class BatchMemberUser {
  final String id;
  final String? name;
  final String? email;
  final String? picture;

  const BatchMemberUser({
    required this.id,
    this.name,
    this.email,
    this.picture,
  });

  factory BatchMemberUser.fromJson(Map<String, dynamic> json) {
    return BatchMemberUser(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      picture: json['picture'] as String?,
    );
  }
}

class BatchMemberWard {
  final String id;
  final String name;
  final String? picture;

  const BatchMemberWard({required this.id, required this.name, this.picture});

  factory BatchMemberWard.fromJson(Map<String, dynamic> json) {
    return BatchMemberWard(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unknown',
      picture: json['picture'] as String?,
    );
  }
}

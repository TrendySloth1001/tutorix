/// Represents an invitation to join a coaching.
class InvitationModel {
  final String id;
  final String coachingId;
  final String role;
  final String? userId;
  final String? wardId;
  final String? invitePhone;
  final String? inviteEmail;
  final String? inviteName;
  final String status; // PENDING, ACCEPTED, DECLINED, EXPIRED
  final String invitedById;
  final String? message;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? respondedAt;

  // Resolved relations
  final InvitationUser? user;
  final InvitationWard? ward;
  final InvitationUser? invitedBy;

  const InvitationModel({
    required this.id,
    required this.coachingId,
    required this.role,
    this.userId,
    this.wardId,
    this.invitePhone,
    this.inviteEmail,
    this.inviteName,
    this.status = 'PENDING',
    required this.invitedById,
    this.message,
    this.createdAt,
    this.expiresAt,
    this.respondedAt,
    this.user,
    this.ward,
    this.invitedBy,
  });

  factory InvitationModel.fromJson(Map<String, dynamic> json) {
    return InvitationModel(
      id: json['id'] as String,
      coachingId: json['coachingId'] as String,
      role: json['role'] as String? ?? 'STUDENT',
      userId: json['userId'] as String?,
      wardId: json['wardId'] as String?,
      invitePhone: json['invitePhone'] as String?,
      inviteEmail: json['inviteEmail'] as String?,
      inviteName: json['inviteName'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      invitedById: json['invitedById'] as String,
      message: json['message'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'] as String)
          : null,
      user: json['user'] != null
          ? InvitationUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      ward: json['ward'] != null
          ? InvitationWard.fromJson(json['ward'] as Map<String, dynamic>)
          : null,
      invitedBy: json['invitedBy'] != null
          ? InvitationUser.fromJson(json['invitedBy'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Display name of the invitee.
  String get displayName {
    if (user != null) return user!.name ?? user!.email ?? 'Unknown';
    if (ward != null) return ward!.name;
    return inviteName ?? inviteEmail ?? invitePhone ?? 'Unknown';
  }

  /// Whether this is a pending invitation (not yet on platform).
  bool get isUnresolved => userId == null && wardId == null;

  bool get isPending => status == 'PENDING';
}

class InvitationUser {
  final String id;
  final String? name;
  final String? email;
  final String? picture;

  const InvitationUser({
    required this.id,
    this.name,
    this.email,
    this.picture,
  });

  factory InvitationUser.fromJson(Map<String, dynamic> json) {
    return InvitationUser(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      picture: json['picture'] as String?,
    );
  }
}

class InvitationWard {
  final String id;
  final String name;
  final String? picture;

  const InvitationWard({
    required this.id,
    required this.name,
    this.picture,
  });

  factory InvitationWard.fromJson(Map<String, dynamic> json) {
    return InvitationWard(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unknown',
      picture: json['picture'] as String?,
    );
  }
}

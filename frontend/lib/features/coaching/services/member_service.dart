import '../../../core/constants/api_constants.dart';
import '../../../shared/services/api_client.dart';
import '../models/member_model.dart';
import '../models/invitation_model.dart';

/// Service for managing coaching members and invitations.
class MemberService {
  final ApiClient _api = ApiClient.instance;

  /// GET /coaching/:id/members — fetch all members grouped by role.
  Future<List<MemberModel>> getMembers(String coachingId) async {
    final data = await _api.getAuthenticated(
      ApiConstants.coachingMembers(coachingId),
    );
    final list = data['members'] as List<dynamic>;
    return list
        .map((e) => MemberModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// DELETE /coaching/:id/members/:memberId
  Future<bool> removeMember(String coachingId, String memberId) async {
    return _api.deleteAuthenticated(
      ApiConstants.removeMember(coachingId, memberId),
    );
  }

  /// PATCH /coaching/:id/members/:memberId — update role
  Future<MemberModel> updateMemberRole(
    String coachingId,
    String memberId,
    String role,
  ) async {
    final data = await _api.patchAuthenticated(
      ApiConstants.updateMemberRole(coachingId, memberId),
      body: {'role': role},
    );
    return MemberModel.fromJson(data['member'] as Map<String, dynamic>);
  }

  /// GET /coaching/:id/invitations — all invitations for the coaching.
  Future<List<InvitationModel>> getInvitations(String coachingId) async {
    final raw = await _api.getAuthenticatedRaw(
      ApiConstants.coachingInvitations(coachingId),
    );
    // The endpoint may return a list directly or wrapped in { invitations: [...] }
    final List<dynamic> list;
    if (raw is List) {
      list = raw;
    } else if (raw is Map<String, dynamic>) {
      list = raw['invitations'] as List<dynamic>? ?? [];
    } else {
      list = [];
    }
    return list
        .map((e) => InvitationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// DELETE /coaching/:id/invitations/:invitationId — cancel invitation
  Future<bool> cancelInvitation(String coachingId, String invitationId) async {
    return _api.deleteAuthenticated(
      ApiConstants.cancelInvitation(coachingId, invitationId),
    );
  }
}

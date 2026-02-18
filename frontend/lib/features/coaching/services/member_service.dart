import '../../../core/constants/api_constants.dart';
import '../../../core/services/cache_manager.dart';
import '../../../shared/services/api_client.dart';
import '../models/member_model.dart';
import '../models/invitation_model.dart';

/// Service for managing coaching members and invitations.
class MemberService {
  final ApiClient _api = ApiClient.instance;
  final CacheManager _cache = CacheManager.instance;

  /// GET /coaching/:id/members — fetch all members grouped by role.
  /// Stream: emits cached list first, then fresh from network.
  Stream<List<MemberModel>> watchMembers(String coachingId) {
    final key = 'members:$coachingId';
    return _cache.swr<List<MemberModel>>(
      key,
      () => _api.getAuthenticated(ApiConstants.coachingMembers(coachingId)),
      (raw) {
        final list = (raw['members'] as List<dynamic>?) ?? [];
        return list
            .map(
              (e) => MemberModel.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      },
    );
  }

  Future<List<MemberModel>> getMembers(String coachingId) =>
      watchMembers(coachingId).last;

  /// DELETE /coaching/:id/members/:memberId
  Future<bool> removeMember(String coachingId, String memberId) async {
    final ok = await _api.deleteAuthenticated(
      ApiConstants.removeMember(coachingId, memberId),
    );
    if (ok) await _cache.invalidate('members:$coachingId');
    return ok;
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
    await _cache.invalidate('members:$coachingId');
    return MemberModel.fromJson(data['member'] as Map<String, dynamic>);
  }

  /// GET /coaching/:id/members/:memberId/academic-history
  Future<List<Map<String, dynamic>>> getMemberAcademicHistory(
    String coachingId,
    String memberId,
  ) async {
    final data = await _api.getAuthenticatedRaw(
      ApiConstants.memberAcademicHistory(coachingId, memberId),
    );
    // The backend returns { results: [...] }
    if (data is Map && data.containsKey('results')) {
      return (data['results'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// GET /coaching/:id/invitations — all invitations for the coaching.
  /// Stream: emits cached list first, then fresh from network.
  Stream<List<InvitationModel>> watchInvitations(String coachingId) {
    final key = 'invitations:$coachingId';
    return _cache.swr<List<InvitationModel>>(
      key,
      () => _api.getAuthenticatedRaw(
        ApiConstants.coachingInvitations(coachingId),
      ),
      (raw) {
        final List<dynamic> list;
        if (raw is List) {
          list = raw;
        } else if (raw is Map) {
          list = (raw['invitations'] as List<dynamic>?) ?? [];
        } else {
          list = [];
        }
        return list
            .map(
              (e) =>
                  InvitationModel.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      },
    );
  }

  Future<List<InvitationModel>> getInvitations(String coachingId) =>
      watchInvitations(coachingId).last;

  /// DELETE /coaching/:id/invitations/:invitationId — cancel invitation
  Future<bool> cancelInvitation(String coachingId, String invitationId) async {
    final ok = await _api.deleteAuthenticated(
      ApiConstants.cancelInvitation(coachingId, invitationId),
    );
    if (ok) await _cache.invalidate('invitations:$coachingId');
    return ok;
  }
}

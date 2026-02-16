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
  Future<List<MemberModel>> getMembers(String coachingId) async {
    final key = 'members:$coachingId';
    try {
      final data = await _api.getAuthenticated(
        ApiConstants.coachingMembers(coachingId),
      );
      await _cache.put(key, data);
      final list = data['members'] as List<dynamic>;
      return list
          .map((e) => MemberModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      final cached = await _cache.get(key);
      if (cached != null) {
        final list = (cached['members'] as List<dynamic>);
        return list
            .map(
              (e) => MemberModel.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      }
      rethrow;
    }
  }

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

  /// GET /coaching/:id/invitations — all invitations for the coaching.
  Future<List<InvitationModel>> getInvitations(String coachingId) async {
    final key = 'invitations:$coachingId';
    try {
      final raw = await _api.getAuthenticatedRaw(
        ApiConstants.coachingInvitations(coachingId),
      );
      // Cache the raw response.
      await _cache.put(key, raw);
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
    } catch (e) {
      final cached = await _cache.get(key);
      if (cached != null) {
        final List<dynamic> list;
        if (cached is List) {
          list = cached;
        } else if (cached is Map) {
          list = (cached['invitations'] as List<dynamic>?) ?? [];
        } else {
          list = [];
        }
        return list
            .map(
              (e) =>
                  InvitationModel.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      }
      rethrow;
    }
  }

  /// DELETE /coaching/:id/invitations/:invitationId — cancel invitation
  Future<bool> cancelInvitation(String coachingId, String invitationId) async {
    final ok = await _api.deleteAuthenticated(
      ApiConstants.cancelInvitation(coachingId, invitationId),
    );
    if (ok) await _cache.invalidate('invitations:$coachingId');
    return ok;
  }
}

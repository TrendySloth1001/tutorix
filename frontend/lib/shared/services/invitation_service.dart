import '../../core/constants/api_constants.dart';
import 'api_client.dart';

/// Handles coaching invitations — sending, listing, responding, cancelling.
class InvitationService {
  final ApiClient _api = ApiClient.instance;

  /// Lookup a user by phone or email for a coaching.
  Future<Map<String, dynamic>> lookupContact(
    String coachingId,
    String contact,
  ) async {
    final data = await _api.postAuthenticated(
      ApiConstants.inviteLookup(coachingId),
      body: {'contact': contact},
    );
    return data;
  }

  /// Send an invitation to join a coaching.
  Future<Map<String, dynamic>> sendInvitation({
    required String coachingId,
    required String role,
    String? userId,
    String? wardId,
    String? invitePhone,
    String? inviteEmail,
    String? inviteName,
    String? message,
  }) async {
    final body = <String, dynamic>{'role': role};
    if (userId != null) body['userId'] = userId;
    if (wardId != null) body['wardId'] = wardId;
    if (invitePhone != null) body['invitePhone'] = invitePhone;
    if (inviteEmail != null) body['inviteEmail'] = inviteEmail;
    if (inviteName != null) body['inviteName'] = inviteName;
    if (message != null) body['message'] = message;

    final data = await _api.postAuthenticated(
      ApiConstants.inviteSend(coachingId),
      body: body,
    );
    return data;
  }

  /// Get all invitations for a coaching (admin view).
  Future<List<Map<String, dynamic>>> getCoachingInvitations(
    String coachingId,
  ) async {
    final data = await _api.getAuthenticated(
      ApiConstants.coachingInvitations(coachingId),
    );
    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  }

  /// Get pending invitations for the current user.
  Future<List<Map<String, dynamic>>> getMyInvitations() async {
    final data = await _api.getAuthenticated(ApiConstants.userInvitations);
    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  }

  /// Respond to an invitation (accept/decline).
  Future<Map<String, dynamic>> respondToInvitation(
    String invitationId,
    bool accept,
  ) async {
    final data = await _api.postAuthenticated(
      ApiConstants.respondInvitation(invitationId),
      body: {'accept': accept},
    );
    return data;
  }

  /// Cancel an invitation (admin action).
  Future<void> cancelInvitation(
    String coachingId,
    String invitationId,
  ) async {
    await _api.deleteAuthenticated(
      ApiConstants.cancelInvitation(coachingId, invitationId),
    );
  }
}

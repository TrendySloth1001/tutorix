import '../../../core/constants/api_constants.dart';
import '../../../shared/services/api_client.dart';
import '../models/academic_masters.dart';
import '../models/academic_profile.dart';

class AcademicService {
  final ApiClient _api = ApiClient.instance;

  // Cache for master data (rarely changes)
  static AcademicMasters? _mastersCache;

  /// GET /academic/masters
  /// Fetches all academic master data (boards, classes, streams, exams, subjects)
  Future<AcademicMasters> getMasters({bool forceRefresh = false}) async {
    if (!forceRefresh && _mastersCache != null) {
      return _mastersCache!;
    }

    final data = await _api.getPublic(ApiConstants.academicMasters);
    _mastersCache = AcademicMasters.fromJson(data);
    return _mastersCache!;
  }

  /// GET /academic/profile
  /// Get current user's academic profile
  Future<AcademicProfile?> getProfile() async {
    try {
      final data = await _api.getAuthenticated(ApiConstants.academicProfile);
      return AcademicProfile.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// POST /academic/profile
  /// Save/update user's academic profile
  Future<AcademicProfile> saveProfile({
    String? schoolName,
    String? board,
    String? classId,
    String? stream,
    List<String>? subjects,
    List<String>? competitiveExams,
    int? targetYear,
  }) async {
    final body = <String, dynamic>{};
    if (schoolName != null) body['schoolName'] = schoolName;
    if (board != null) body['board'] = board;
    if (classId != null) body['classId'] = classId;
    if (stream != null) body['stream'] = stream;
    if (subjects != null) body['subjects'] = subjects;
    if (competitiveExams != null) body['competitiveExams'] = competitiveExams;
    if (targetYear != null) body['targetYear'] = targetYear;

    final data = await _api.postAuthenticated(
      ApiConstants.academicProfile,
      body: body,
    );
    return AcademicProfile.fromJson(data);
  }

  /// PATCH /academic/remind-later
  /// Set "remind me later" with 2-day buffer
  Future<void> remindLater() async {
    await _api.patchAuthenticated(ApiConstants.academicRemindLater, body: {});
  }

  /// GET /academic/onboarding-status
  /// Check if user needs to complete academic onboarding
  Future<OnboardingStatus> getOnboardingStatus() async {
    final data = await _api.getAuthenticated(
      ApiConstants.academicOnboardingStatus,
    );
    return OnboardingStatus.fromJson(data);
  }
}

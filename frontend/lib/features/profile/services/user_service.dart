import '../../../core/constants/api_constants.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/models/login_session.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/services/secure_storage_service.dart';

class UserService {
  final ApiClient _api = ApiClient.instance;
  final SecureStorageService _storage = SecureStorageService.instance;

  /// GET /user/me
  Future<UserModel?> getMe() async {
    final token = await _storage.getToken();
    if (token == null) return null;

    final data = await _api.getAuthenticated(ApiConstants.userMe);
    return UserModel.fromJson(data['user']);
  }

  /// PATCH /user/me
  Future<UserModel?> updateProfile({
    String? name,
    String? phone,
    String? picture,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;

    if (picture != null) {
      body['picture'] = picture;
    } else if (name == null && phone == null) {
      body['picture'] = null;
    }

    final data = await _api.patchAuthenticated(ApiConstants.userMe, body: body);

    final user = UserModel.fromJson(data['user']);
    await _storage.cacheUserProfile(user.toJson());
    return user;
  }

  /// PATCH /user/me — update privacy settings
  Future<UserModel?> updatePrivacy({
    bool? showEmailInSearch,
    bool? showPhoneInSearch,
    bool? showWardsInSearch,
  }) async {
    final body = <String, dynamic>{};
    if (showEmailInSearch != null) {
      body['showEmailInSearch'] = showEmailInSearch;
    }
    if (showPhoneInSearch != null) {
      body['showPhoneInSearch'] = showPhoneInSearch;
    }
    if (showWardsInSearch != null) {
      body['showWardsInSearch'] = showWardsInSearch;
    }

    final data = await _api.patchAuthenticated(ApiConstants.userMe, body: body);
    final user = UserModel.fromJson(data['user']);
    await _storage.cacheUserProfile(user.toJson());
    return user;
  }

  /// PATCH /user/me/roles
  Future<UserModel?> updateRoles({
    bool? isAdmin,
    bool? isTeacher,
    bool? isParent,
    bool? isWard,
  }) async {
    final body = <String, dynamic>{
      'isAdmin': ?isAdmin,
      'isTeacher': ?isTeacher,
      'isParent': ?isParent,
      'isWard': ?isWard,
    };

    final data = await _api.patchAuthenticated(
      ApiConstants.userMeRoles,
      body: body,
    );

    final user = UserModel.fromJson(data['user']);
    await _storage.cacheUserProfile(user.toJson());
    return user;
  }

  /// POST /user/me/onboarding
  Future<UserModel?> completeOnboarding() async {
    final data = await _api.postAuthenticated(ApiConstants.userMeOnboarding);
    final user = UserModel.fromJson(data['user']);
    await _storage.cacheUserProfile(user.toJson());
    return user;
  }

  /// GET /user/me/sessions
  Future<List<LoginSession>> getSessions() async {
    final data = await _api.getAuthenticated(ApiConstants.userMeSessions);
    final list = data['sessions'] as List<dynamic>;
    return list
        .map((e) => LoginSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

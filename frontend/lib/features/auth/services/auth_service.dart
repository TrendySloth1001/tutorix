import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/device_info_helper.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/services/secure_storage_service.dart';

class AuthService {
  final ApiClient _api = ApiClient.instance;
  final SecureStorageService _storage = SecureStorageService.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<void> _ensureGoogleInitialized() async {
    await _googleSignIn.initialize(serverClientId: ApiConstants.googleClientId);
  }

  /// Trigger Google OAuth → send idToken to backend → return [UserModel].
  Future<UserModel?> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();

      final googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );

      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) throw Exception('Failed to get ID Token');

      final deviceInfo = await DeviceInfoHelper.getDeviceDescription();

      final data = await _api.postPublic(
        ApiConstants.googleAuth,
        body: {'idToken': idToken, 'deviceInfo': deviceInfo},
        extraHeaders: {'User-Agent': deviceInfo, 'X-Device-Info': deviceInfo},
      );

      final user = UserModel.fromJson(data['user']);

      await _storage.saveToken(data['token'] as String);
      await _storage.cacheUserProfile(user.toJson());

      return user;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _ensureGoogleInitialized();
    await _googleSignIn.signOut();
    await _storage.clearAll();
  }

  Future<String?> getToken() => _storage.getToken();

  Future<UserModel?> getCachedUser() async {
    final json = await _storage.getCachedUserProfile();
    if (json == null) return null;
    return UserModel.fromJson(json);
  }

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null;
  }
}

import 'dart:io';
import '../../../core/constants/api_constants.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/services/secure_storage_service.dart';

class UploadService {
  final ApiClient _api = ApiClient.instance;
  final SecureStorageService _storage = SecureStorageService.instance;

  /// Upload a new avatar image. Returns the updated [UserModel].
  Future<UserModel?> uploadAvatar(File file) async {
    final data = await _api.uploadFile(
      ApiConstants.uploadAvatar,
      fieldName: 'avatar',
      filePath: file.path,
    );

    final user = UserModel.fromJson(data['user']);
    await _storage.cacheUserProfile(user.toJson());
    return user;
  }
}

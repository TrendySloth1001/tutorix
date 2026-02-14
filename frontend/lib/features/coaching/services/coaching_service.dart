import '../../../core/constants/api_constants.dart';
import '../../../shared/services/api_client.dart';
import '../models/coaching_model.dart';

class CoachingService {
  final ApiClient _api = ApiClient.instance;

  /// POST /coaching
  Future<CoachingModel?> createCoaching({
    required String name,
    String? description,
    String? logo,
  }) async {
    final data = await _api.postAuthenticated(
      ApiConstants.coaching,
      body: {'name': name, 'description': description, 'logo': logo},
    );
    return CoachingModel.fromJson(data['coaching']);
  }

  /// GET /coaching/my
  Future<List<CoachingModel>> getMyCoachings() async {
    final data = await _api.getAuthenticated(ApiConstants.coachingMy);
    final list = data['coachings'] as List<dynamic>;
    return list
        .map((e) => CoachingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /coaching/:id
  Future<CoachingModel?> getCoachingById(String id) async {
    try {
      final data = await _api.getPublic(ApiConstants.coachingById(id));
      return CoachingModel.fromJson(data['coaching']);
    } catch (_) {
      return null;
    }
  }

  /// PATCH /coaching/:id
  Future<CoachingModel?> updateCoaching({
    required String id,
    String? name,
    String? description,
    String? logo,
  }) async {
    final data = await _api.patchAuthenticated(
      ApiConstants.coachingById(id),
      body: {'name': ?name, 'description': ?description, 'logo': ?logo},
    );
    return CoachingModel.fromJson(data['coaching']);
  }

  /// DELETE /coaching/:id
  Future<bool> deleteCoaching(String id) =>
      _api.deleteAuthenticated(ApiConstants.coachingById(id));

  /// GET /coaching/check-slug/:slug
  Future<bool> isSlugAvailable(String slug) async {
    try {
      final data = await _api.getPublic(ApiConstants.checkSlug(slug));
      return data['available'] as bool;
    } catch (_) {
      return false;
    }
  }

  /// POST /upload/logo — upload coaching logo image, returns URL.
  Future<String> uploadLogo(String filePath) async {
    final data = await _api.uploadFile(
      ApiConstants.uploadLogo,
      fieldName: 'file',
      filePath: filePath,
    );
    return data['url'] as String;
  }
}

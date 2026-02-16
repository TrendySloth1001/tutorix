import '../../../core/constants/api_constants.dart';
import '../../../core/services/cache_manager.dart';
import '../../../shared/services/api_client.dart';
import '../models/coaching_model.dart';

class CoachingService {
  final ApiClient _api = ApiClient.instance;
  final CacheManager _cache = CacheManager.instance;

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
    // Invalidate coaching lists so they refresh.
    await Future.wait([
      _cache.invalidate('coaching:my'),
      _cache.invalidate('coaching:joined'),
    ]);
    return CoachingModel.fromJson(data['coaching']);
  }

  /// GET /coaching/my
  Future<List<CoachingModel>> getMyCoachings() async {
    const key = 'coaching:my';
    try {
      final data = await _api.getAuthenticated(ApiConstants.coachingMy);
      await _cache.put(key, data);
      final list = data['coachings'] as List<dynamic>;
      return list
          .map((e) => CoachingModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      final cached = await _cache.get(key);
      if (cached != null) {
        final list = (cached['coachings'] as List<dynamic>);
        return list
            .map((e) => CoachingModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      rethrow;
    }
  }

  /// GET /coaching/joined
  Future<List<CoachingModel>> getJoinedCoachings() async {
    const key = 'coaching:joined';
    try {
      final data = await _api.getAuthenticated(ApiConstants.coachingJoined);
      await _cache.put(key, data);
      final list = data['coachings'] as List<dynamic>;
      return list
          .map((e) => CoachingModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      final cached = await _cache.get(key);
      if (cached != null) {
        final list = (cached['coachings'] as List<dynamic>);
        return list
            .map((e) => CoachingModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      rethrow;
    }
  }

  /// GET /coaching/:id
  Future<CoachingModel?> getCoachingById(String id) async {
    final key = 'coaching:$id';
    try {
      final data = await _api.getPublic(ApiConstants.coachingById(id));
      await _cache.put(key, data);
      return CoachingModel.fromJson(data['coaching']);
    } catch (_) {
      final cached = await _cache.get(key);
      if (cached != null) {
        return CoachingModel.fromJson(
            Map<String, dynamic>.from(cached['coaching'] as Map));
      }
      return null;
    }
  }

  /// PATCH /coaching/:id
  Future<CoachingModel?> updateCoaching({
    required String id,
    String? name,
    String? description,
    String? logo,
    String? coverImage,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (logo != null) body['logo'] = logo;
    if (coverImage != null) body['coverImage'] = coverImage;

    final data = await _api.patchAuthenticated(
      ApiConstants.coachingById(id),
      body: body,
    );
    // Invalidate coaching lists + this coaching detail.
    await Future.wait([
      _cache.invalidate('coaching:my'),
      _cache.invalidate('coaching:joined'),
      _cache.invalidate('coaching:$id'),
    ]);
    return CoachingModel.fromJson(data['coaching']);
  }

  /// DELETE /coaching/:id
  Future<bool> deleteCoaching(String id) async {
    final ok = await _api.deleteAuthenticated(ApiConstants.coachingById(id));
    if (ok) {
      await Future.wait([
        _cache.invalidate('coaching:my'),
        _cache.invalidate('coaching:joined'),
        _cache.invalidatePrefix('coaching:$id'),
      ]);
    }
    return ok;
  }

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

  /// POST /upload/cover — upload coaching cover image, returns URL.
  Future<String> uploadCover(String filePath) async {
    final data = await _api.uploadFile(
      ApiConstants.uploadCover,
      fieldName: 'file',
      filePath: filePath,
    );
    return data['url'] as String;
  }
}

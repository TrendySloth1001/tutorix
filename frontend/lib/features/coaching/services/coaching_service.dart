import '../../../core/constants/api_constants.dart';
import '../../../core/services/cache_manager.dart';
import '../../../core/services/error_logger_service.dart';
import '../../../shared/services/api_client.dart';
import '../models/coaching_model.dart';

class CoachingService {
  final ApiClient _api = ApiClient.instance;
  final CacheManager _cache = CacheManager.instance;

  // ── Helpers ─────────────────────────────────────────────────────────

  List<CoachingModel> _parseList(dynamic data) {
    final list = (data['coachings'] as List<dynamic>?) ?? [];
    return list
        .map((e) => CoachingModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── CREATE ──────────────────────────────────────────────────────────

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
    await Future.wait([
      _cache.invalidate('coaching:my'),
      _cache.invalidate('coaching:joined'),
    ]);
    return CoachingModel.fromJson(data['coaching']);
  }

  // ── READ (SWR) ─────────────────────────────────────────────────────

  /// Stream that emits cached list first, then fresh from network.
  Stream<List<CoachingModel>> watchMyCoachings() {
    const key = 'coaching:my';
    return _cache.swr<List<CoachingModel>>(
      key,
      () => _api.getAuthenticated(ApiConstants.coachingMy),
      (raw) => _parseList(raw),
    );
  }

  /// Future variant — returns the last (freshest) value from the stream.
  Future<List<CoachingModel>> getMyCoachings() => watchMyCoachings().last;

  /// Stream that emits cached list first, then fresh from network.
  Stream<List<CoachingModel>> watchJoinedCoachings() {
    const key = 'coaching:joined';
    return _cache.swr<List<CoachingModel>>(
      key,
      () => _api.getAuthenticated(ApiConstants.coachingJoined),
      (raw) => _parseList(raw),
    );
  }

  /// Future variant.
  Future<List<CoachingModel>> getJoinedCoachings() =>
      watchJoinedCoachings().last;

  /// Stream a single coaching.
  Stream<CoachingModel?> watchCoachingById(String id) {
    final key = 'coaching:$id';
    return _cache.swr<CoachingModel?>(
      key,
      () => _api.getPublic(ApiConstants.coachingById(id)),
      (raw) {
        if (raw == null || raw['coaching'] == null) return null;
        return CoachingModel.fromJson(
          Map<String, dynamic>.from(raw['coaching'] as Map),
        );
      },
    );
  }

  /// Future variant.
  Future<CoachingModel?> getCoachingById(String id) =>
      watchCoachingById(id).last;

  // ── UPDATE / DELETE ─────────────────────────────────────────────────

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
    } catch (e) {
      ErrorLoggerService.instance.debug('Slug check failed for "$slug": $e', category: LogCategory.api);
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

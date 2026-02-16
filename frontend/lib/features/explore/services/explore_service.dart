import 'dart:async';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/cache_manager.dart';
import '../../../shared/services/api_client.dart';
import '../../coaching/models/coaching_model.dart';

/// A coaching with its distance from the user.
class NearbyCoaching {
  final CoachingModel coaching;
  final double distanceKm;

  const NearbyCoaching({required this.coaching, required this.distanceKm});

  factory NearbyCoaching.fromJson(Map<String, dynamic> json) {
    return NearbyCoaching(
      coaching: CoachingModel.fromJson(json),
      distanceKm: (json['distance'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ExploreService {
  final ApiClient _api = ApiClient.instance;
  final CacheManager _cache = CacheManager.instance;

  // ── Nearby (SWR) ────────────────────────────────────────────────────

  Stream<List<NearbyCoaching>> watchNearby({
    required double lat,
    required double lng,
    double radiusKm = 20,
    int page = 1,
    int limit = 50,
  }) {
    final key = 'explore:$lat:$lng:$radiusKm:$page';
    final url =
        '${ApiConstants.coachingExplore}?lat=$lat&lng=$lng&radius=$radiusKm&page=$page&limit=$limit';
    return _cache.swr<List<NearbyCoaching>>(key, () => _api.getPublic(url), (
      raw,
    ) {
      final list = (raw['coachings'] as List<dynamic>?) ?? [];
      return list
          .map(
            (e) => NearbyCoaching.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    });
  }

  Future<List<NearbyCoaching>> getNearby({
    required double lat,
    required double lng,
    double radiusKm = 20,
    int page = 1,
    int limit = 50,
  }) => watchNearby(
    lat: lat,
    lng: lng,
    radiusKm: radiusKm,
    page: page,
    limit: limit,
  ).last;

  /// Search coachings by name (real-time, no caching).
  Future<List<SearchResult>> searchCoachings(String query) async {
    if (query.trim().isEmpty) return [];
    final url =
        '${ApiConstants.coachingSearch}?q=${Uri.encodeComponent(query.trim())}&limit=15';
    final raw = await _api.getPublic(url);
    final list = (raw['results'] as List<dynamic>?) ?? [];
    return list
        .map((e) => SearchResult.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── Saved / Bookmarked ──────────────────────────────────────────────

  /// Get the user's saved coachings.
  Future<List<SearchResult>> getSavedCoachings() async {
    final raw = await _api.getAuthenticated(ApiConstants.coachingSaved);
    final list = (raw['saved'] as List<dynamic>?) ?? [];
    return list
        .map((e) => SearchResult.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Save a coaching (bookmark).
  Future<void> saveCoaching(String coachingId) async {
    await _api.postAuthenticated(
      ApiConstants.coachingSave(coachingId),
      body: {},
    );
  }

  /// Unsave a coaching (un-bookmark).
  Future<void> unsaveCoaching(String coachingId) async {
    await _api.deleteAuthenticated(ApiConstants.coachingSave(coachingId));
  }
}

/// Lightweight search result (no full CoachingModel needed).
class SearchResult {
  final String id;
  final String name;
  final String slug;
  final String? logo;
  final String? category;
  final bool isVerified;
  final String? city;
  final String? state;
  final double? latitude;
  final double? longitude;
  final int memberCount;

  const SearchResult({
    required this.id,
    required this.name,
    required this.slug,
    this.logo,
    this.category,
    this.isVerified = false,
    this.city,
    this.state,
    this.latitude,
    this.longitude,
    this.memberCount = 0,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      logo: json['logo'] as String?,
      category: json['category'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      city: json['city'] as String?,
      state: json['state'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      memberCount: json['memberCount'] as int? ?? 0,
    );
  }
}

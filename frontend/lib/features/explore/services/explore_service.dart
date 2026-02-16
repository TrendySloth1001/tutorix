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
}

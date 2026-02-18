import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/error_logger_service.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../coaching/screens/coaching_profile_screen.dart';
import '../../coaching/services/coaching_service.dart';
import '../services/explore_service.dart';

/// Explore screen with an interactive map, nearby coaching cards,
/// real-time search overlay, and saved coachings section.
class ExploreScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel>? onUserUpdated;

  const ExploreScreen({super.key, required this.user, this.onUserUpdated});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with TickerProviderStateMixin {
  final ExploreService _exploreService = ExploreService();
  final CoachingService _coachingService = CoachingService();
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  // Location
  LatLng? _userLocation;
  bool _locationLoading = true;
  String _locationStatus = 'Checking location permission...';
  bool _usingFallbackLocation = false;

  // Nearby coachings
  List<NearbyCoaching> _nearby = [];
  bool _nearbyLoading = true;
  StreamSubscription? _nearbySub;

  // Search
  List<SearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _searchOverlayVisible = false;
  Timer? _debounce;
  late final AnimationController _searchAnimController;
  late final Animation<double> _searchFadeAnim;
  late final Animation<Offset> _searchSlideAnim;

  // Radius filter (km)
  double _radiusKm = 20;

  // Selected coaching on map
  NearbyCoaching? _selectedCoaching;

  // Card tap-to-locate-then-open: track which card was last tapped
  String? _highlightedCardId;

  // Map card expand/collapse
  bool _mapExpanded = true;

  @override
  void initState() {
    super.initState();
    _searchAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _searchFadeAnim = CurvedAnimation(
      parent: _searchAnimController,
      curve: Curves.easeOut,
    );
    _searchSlideAnim =
        Tween<Offset>(begin: const Offset(0, -0.05), end: Offset.zero).animate(
          CurvedAnimation(parent: _searchAnimController, curve: Curves.easeOut),
        );
    _searchController.addListener(_onSearchChanged);
    _searchFocus.addListener(_onSearchFocusChanged);
    _determineLocation();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nearbySub?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _searchAnimController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ── Location ──────────────────────────────────────────────────────

  Future<void> _determineLocation() async {
    try {
      if (mounted) {
        setState(() => _locationStatus = 'Checking location permission...');
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        if (mounted) {
          setState(() => _locationStatus = 'Requesting location access...');
        }
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _setLocation(const LatLng(28.6139, 77.2090), fallback: true);
        return;
      }
      if (mounted) {
        setState(() => _locationStatus = 'Getting your location...');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _setLocation(LatLng(pos.latitude, pos.longitude));
    } catch (e) {
      ErrorLoggerService.instance.warn(
        'Location fetch failed, using fallback Delhi coordinates',
        category: LogCategory.system,
        error: e.toString(),
      );
      _setLocation(const LatLng(28.6139, 77.2090), fallback: true);
    }
  }

  void _setLocation(LatLng loc, {bool fallback = false}) {
    if (!mounted) return;
    setState(() {
      _userLocation = loc;
      _locationLoading = false;
      _usingFallbackLocation = fallback;
    });
    _loadNearby();
  }

  void _recenterMap() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 13);
      setState(() => _selectedCoaching = null);
    }
  }

  void _zoomIn() {
    final z = _mapController.camera.zoom;
    if (z < 18) _mapController.move(_mapController.camera.center, z + 1);
  }

  void _zoomOut() {
    final z = _mapController.camera.zoom;
    if (z > 4) _mapController.move(_mapController.camera.center, z - 1);
  }

  void _fitAllMarkers() {
    final points = _nearby
        .where(
          (nc) =>
              nc.coaching.address?.latitude != null &&
              nc.coaching.address?.longitude != null,
        )
        .map(
          (nc) => LatLng(
            nc.coaching.address!.latitude!,
            nc.coaching.address!.longitude!,
          ),
        )
        .toList();
    if (_userLocation != null) points.add(_userLocation!);
    if (points.length < 2) return;
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(48),
        maxZoom: 16,
      ),
    );
  }

  // ── Nearby ────────────────────────────────────────────────────────

  void _loadNearby() {
    final loc = _userLocation;
    if (loc == null) return;
    setState(() => _nearbyLoading = true);
    _nearbySub?.cancel();
    _nearbySub = _exploreService
        .watchNearby(lat: loc.latitude, lng: loc.longitude, radiusKm: _radiusKm)
        .listen(
          (list) {
            if (!mounted) return;
            setState(() {
              _nearby = list;
              _nearbyLoading = false;
            });
          },
          onError: (error, stackTrace) {
            if (!mounted) return;
            // Log error to backend for admin debugging
            ErrorLoggerService.instance.logError(
              message: 'Explore nearby coachings failed',
              error: error.toString(),
              stackTrace: stackTrace.toString(),
              metadata: {
                'lat': loc.latitude,
                'lng': loc.longitude,
                'radius': _radiusKm,
              },
            );
            // Also log to console for local debugging
            if (kDebugMode) {
              print(' Explore nearby error: $error');
            }
            print('Stack trace: $stackTrace');
            setState(() => _nearbyLoading = false);
            // Show error to user
            AppAlert.error(
              context,
              'Failed to load nearby coachings. Please try again.',
            );
          },
        );
  }

  // ── Search ────────────────────────────────────────────────────────

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    _debounce?.cancel();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await _exploreService.searchCoachings(query);
        if (!mounted) return;
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      } catch (error, stackTrace) {
        ErrorLoggerService.instance.logError(
          message: 'Search coachings failed',
          error: error.toString(),
          stackTrace: stackTrace.toString(),
          metadata: {'query': query},
        );
        print('❌ Search error: $error');
        print('Stack trace: $stackTrace');
        if (!mounted) return;
        setState(() => _isSearching = false);
        AppAlert.error(context, 'Search failed. Please try again.');
      }
    });
  }

  void _onSearchFocusChanged() {
    if (_searchFocus.hasFocus) {
      _showSearchOverlay();
    }
  }

  void _showSearchOverlay() {
    setState(() => _searchOverlayVisible = true);
    _searchAnimController.forward();
  }

  void _hideSearchOverlay() {
    _searchAnimController.reverse().then((_) {
      if (mounted) setState(() => _searchOverlayVisible = false);
    });
    _searchFocus.unfocus();
    _searchController.clear();
  }

  void _onSearchResultTapped(SearchResult result) {
    _hideSearchOverlay();
    // If the coaching has coordinates, fly the map there and select it
    if (result.latitude != null && result.longitude != null) {
      final target = LatLng(result.latitude!, result.longitude!);
      _mapController.move(target, 15);
      // Try to match with a nearby coaching to select it
      final match = _nearby.where((n) => n.coaching.id == result.id);
      if (match.isNotEmpty) {
        setState(() => _selectedCoaching = match.first);
      } else {
        // Not in nearby list — navigate directly
        _navigateToCoaching(result.id);
      }
    } else {
      _navigateToCoaching(result.id);
    }
  }

  // ── Navigation ────────────────────────────────────────────────────

  Future<void> _navigateToCoaching(String coachingId) async {
    try {
      final full = await _coachingService.getCoachingById(coachingId);
      if (!mounted || full == null) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              CoachingProfileScreen(coaching: full, user: widget.user),
        ),
      );
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, 'Could not load coaching details');
      }
    }
  }

  void _onMarkerTapped(NearbyCoaching nc) {
    setState(() {
      _selectedCoaching = nc;
      _highlightedCardId = nc.coaching.id;
    });
    final addr = nc.coaching.address;
    if (addr?.latitude != null && addr?.longitude != null) {
      _mapController.move(LatLng(addr!.latitude!, addr.longitude!), 15);
    }
    // Expand the map if collapsed so user can see the pin
    if (!_mapExpanded) setState(() => _mapExpanded = true);
  }

  /// Card tap UX: first tap → show on map, second tap on same card → open profile.
  void _onCardTapped(NearbyCoaching nc) {
    if (_highlightedCardId == nc.coaching.id) {
      // Second tap on the same card → open
      _navigateToCoaching(nc.coaching.id);
    } else {
      // First tap → highlight & show on map
      _onMarkerTapped(nc);
    }
  }

  Future<void> _openDirections(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) AppAlert.error(context, 'Could not open maps');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────

  /// Returns the full URL for a coaching image. The backend already
  /// stores absolute URLs, so we only need to handle null/empty cases.
  String _getFullUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return url; // fallback
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // Main scrollable content (with pull-to-refresh)
          _locationLoading
              ? _buildLocationLoading(theme)
              : RefreshIndicator(
                  onRefresh: _refresh,
                  displacement: 80,
                  child: CustomScrollView(
                    slivers: [
                      // Top spacing for search bar
                      SliverToBoxAdapter(
                        child: SizedBox(height: topPadding + 72),
                      ),

                      // Fallback location banner
                      if (_usingFallbackLocation)
                        SliverToBoxAdapter(child: _buildFallbackBanner(theme)),

                      // Map card
                      SliverToBoxAdapter(child: _buildMapCard(theme)),

                      // Selected coaching card (inline, not floating)
                      if (_selectedCoaching != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: _buildSelectedCard(theme),
                          ),
                        ),

                      // Section header
                      SliverToBoxAdapter(child: _buildSectionHeader(theme)),

                      // Nearby coaching cards or empty/loading state
                      if (_nearbyLoading)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        )
                      else if (_nearby.isEmpty)
                        SliverToBoxAdapter(child: _buildEmptyState(theme))
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          sliver: SliverList.separated(
                            itemCount: _nearby.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) => _NearbyCoachingCard(
                              nearby: _nearby[i],
                              theme: theme,
                              getFullUrl: _getFullUrl,
                              isHighlighted:
                                  _highlightedCardId == _nearby[i].coaching.id,
                              onTap: () => _onCardTapped(_nearby[i]),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

          // Floating search bar
          if (!_locationLoading)
            Positioned(
              top: topPadding + 12,
              left: 16,
              right: 16,
              child: _buildSearchBar(theme),
            ),

          // Search overlay
          if (_searchOverlayVisible) _buildSearchOverlay(theme),
        ],
      ),
    );
  }

  // ── Location loading ─────────────────────────────────────────────

  Widget _buildLocationLoading(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _locationStatus,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We need your location to find\nnearby coachings',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackBanner(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Showing results for New Delhi. Enable location for accurate results.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _locationLoading = true;
                    _usingFallbackLocation = false;
                  });
                  _determineLocation();
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    'Retry',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Map card ──────────────────────────────────────────────────────

  /// Pull-to-refresh handler: refreshes location and nearby results.
  Future<void> _refresh() async {
    // Clear selections
    setState(() {
      _highlightedCardId = null;
      _selectedCoaching = null;
      _nearbyLoading = true;
    });

    if (_userLocation == null) {
      await _determineLocation();
    } else {
      // reload nearby using current lat/lng and current radius
      _loadNearby();
    }

    // small delay so the RefreshIndicator animation is visible
    await Future.delayed(const Duration(milliseconds: 250));
  }

  Widget _buildMapCard(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surface,
        child: Column(
          children: [
            // Header row: title + count + radius chip + chevron
            InkWell(
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(20),
                bottom: _mapExpanded ? Radius.zero : const Radius.circular(20),
              ),
              onTap: () => setState(() => _mapExpanded = !_mapExpanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                child: Row(
                  children: [
                    // Map icon + title
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.map_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Explore Map',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_nearby.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '·',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.3,
                          ),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_nearby.length} found',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Radius chip (always visible as a summary)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.45,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.radar_rounded,
                            size: 13,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_radiusKm.round()} km',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _mapExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Radius slider — appears below header when map is expanded
            AnimatedCrossFade(
              firstChild: Container(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.25,
                      ),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Radius',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.45,
                        ),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor: theme.colorScheme.primary
                              .withValues(alpha: 0.12),
                          thumbColor: theme.colorScheme.primary,
                          overlayColor: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          trackHeight: 2.5,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                        ),
                        child: Slider(
                          value: _radiusKm,
                          min: 5,
                          max: 50,
                          divisions: 9,
                          onChanged: (v) => setState(() => _radiusKm = v),
                          onChangeEnd: (_) => _loadNearby(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 38,
                      child: Text(
                        '${_radiusKm.round()}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: _mapExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 200),
              sizeCurve: Curves.easeInOut,
            ),

            // Map body
            AnimatedCrossFade(
              firstChild: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                child: SizedBox(
                  height: 280,
                  child: Stack(
                    children: [
                      _buildMap(theme),

                      // Map control buttons
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _MapControlButton(
                              icon: Icons.my_location_rounded,
                              tooltip: 'My location',
                              theme: theme,
                              onTap: _recenterMap,
                            ),
                            const SizedBox(height: 6),
                            _MapControlButton(
                              icon: Icons.add_rounded,
                              tooltip: 'Zoom in',
                              theme: theme,
                              onTap: _zoomIn,
                            ),
                            const SizedBox(height: 6),
                            _MapControlButton(
                              icon: Icons.remove_rounded,
                              tooltip: 'Zoom out',
                              theme: theme,
                              onTap: _zoomOut,
                            ),
                            if (_nearby.length >= 2) ...[
                              const SizedBox(height: 6),
                              _MapControlButton(
                                icon: Icons.fit_screen_rounded,
                                tooltip: 'Fit all',
                                theme: theme,
                                onTap: _fitAllMarkers,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: _mapExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 300),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(ThemeData theme) {
    final center = _userLocation ?? const LatLng(28.6139, 77.2090);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13,
        minZoom: 4,
        maxZoom: 18,
        onTap: (_, pos) {
          if (_selectedCoaching != null) {
            setState(() => _selectedCoaching = null);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.tutorix.app',
        ),
        MarkerLayer(
          markers: [
            // User location marker
            if (_userLocation != null)
              Marker(
                point: _userLocation!,
                width: 28,
                height: 28,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            // Coaching markers
            ..._nearby.map((nc) => _buildCoachingMarker(nc, theme)),
          ],
        ),
      ],
    );
  }

  Marker _buildCoachingMarker(NearbyCoaching nc, ThemeData theme) {
    final addr = nc.coaching.address;
    if (addr?.latitude == null || addr?.longitude == null) {
      return Marker(point: const LatLng(0, 0), child: const SizedBox.shrink());
    }
    final isSelected = _selectedCoaching?.coaching.id == nc.coaching.id;
    final size = isSelected ? 48.0 : 38.0;
    final logoUrl = _getFullUrl(nc.coaching.logo);

    return Marker(
      point: LatLng(addr!.latitude!, addr.longitude!),
      width: size,
      height: size + 8,
      child: GestureDetector(
        onTap: () => _onMarkerTapped(nc),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.15),
                    blurRadius: isSelected ? 10 : 6,
                    spreadRadius: isSelected ? 1 : 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: logoUrl.isNotEmpty
                    ? Image.network(
                        logoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.school_rounded,
                          size: size * 0.5,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : Icon(
                        Icons.school_rounded,
                        size: size * 0.5,
                        color: theme.colorScheme.primary,
                      ),
              ),
            ),
            if (isSelected)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────

  Widget _buildSearchBar(ThemeData theme) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        decoration: InputDecoration(
          hintText: 'Search coachings...',
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: theme.colorScheme.primary,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: _hideSearchOverlay,
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  // ── Search overlay ────────────────────────────────────────────────

  Widget _buildSearchOverlay(ThemeData theme) {
    final topPad = MediaQuery.of(context).padding.top + 80;

    return Positioned.fill(
      child: GestureDetector(
        onTap: _hideSearchOverlay,
        child: Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: SlideTransition(
            position: _searchSlideAnim,
            child: FadeTransition(
              opacity: _searchFadeAnim,
              child: Container(
                margin: EdgeInsets.only(
                  top: topPad,
                  left: 16,
                  right: 16,
                  bottom: 120,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _buildSearchContent(theme),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchContent(ThemeData theme) {
    if (_isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_searchController.text.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_rounded,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              'Search for coachings by name',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              'No coachings found',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      shrinkWrap: true,
      itemCount: _searchResults.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: 68,
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
      ),
      itemBuilder: (_, i) => _buildSearchResultTile(_searchResults[i], theme),
    );
  }

  Widget _buildSearchResultTile(SearchResult result, ThemeData theme) {
    final logoUrl = _getFullUrl(result.logo);
    final location = [
      result.city,
      result.state,
    ].where((s) => s != null && s.isNotEmpty).join(', ');

    return ListTile(
      onTap: () => _onSearchResultTapped(result),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: theme.colorScheme.primaryContainer.withValues(
          alpha: 0.5,
        ),
        backgroundImage: logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
        child: logoUrl.isEmpty
            ? Icon(
                Icons.school_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              )
            : null,
      ),
      title: Text(
        result.name,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: location.isNotEmpty
          ? Text(
              location,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: result.isVerified
          ? Icon(
              Icons.verified_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  // ── Selected coaching card (inline) ────────────────────────────────

  Widget _buildSelectedCard(ThemeData theme) {
    final nc = _selectedCoaching!;
    final coaching = nc.coaching;
    final logoUrl = _getFullUrl(coaching.logo);
    final addr = coaching.address;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      shadowColor: theme.colorScheme.primary.withValues(alpha: 0.2),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() => _selectedCoaching = null);
          _navigateToCoaching(coaching.id);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              // Logo
              CircleAvatar(
                radius: 26,
                backgroundColor: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.5,
                ),
                backgroundImage: logoUrl.isNotEmpty
                    ? NetworkImage(logoUrl)
                    : null,
                child: logoUrl.isEmpty
                    ? Icon(
                        Icons.school_rounded,
                        size: 24,
                        color: theme.colorScheme.primary,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            coaching.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (coaching.isVerified) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (coaching.category != null)
                      Text(
                        coaching.category!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    Text(
                      '${nc.distanceKm.toStringAsFixed(1)} km away',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Directions button
              if (addr?.latitude != null && addr?.longitude != null)
                IconButton(
                  onPressed: () =>
                      _openDirections(addr!.latitude!, addr.longitude!),
                  icon: Icon(
                    Icons.directions_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  tooltip: 'Directions',
                ),
              // Dismiss
              IconButton(
                onPressed: () => setState(() => _selectedCoaching = null),
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────

  Widget _buildSectionHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Text(
            'Nearby',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          if (!_nearbyLoading && _nearby.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_nearby.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off_rounded,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              'No coachings found nearby',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try searching or zooming out',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Nearby Coaching Card — cover image + logo style
// ═══════════════════════════════════════════════════════════════════════

class _NearbyCoachingCard extends StatelessWidget {
  final NearbyCoaching nearby;
  final ThemeData theme;
  final String Function(String?) getFullUrl;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _NearbyCoachingCard({
    required this.nearby,
    required this.theme,
    required this.getFullUrl,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final coaching = nearby.coaching;
    final logoUrl = getFullUrl(coaching.logo);
    final coverUrl = getFullUrl(coaching.coverImage);
    final hasLogo = logoUrl.isNotEmpty;
    final hasCover = coverUrl.isNotEmpty;
    final location = [
      coaching.address?.city,
      coaching.address?.state,
    ].where((s) => s != null && s.isNotEmpty).join(', ');

    return Material(
      color: Colors.transparent,
      elevation: isHighlighted ? 8 : 6,
      shadowColor: isHighlighted
          ? theme.colorScheme.primary.withValues(alpha: 0.35)
          : Colors.black.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isHighlighted
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.08),
              width: isHighlighted ? 2.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ─── Cover image background ───
                if (hasCover)
                  Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPlaceholderBg(theme),
                  )
                else
                  _buildPlaceholderBg(theme),

                // ─── Gradient overlay ───
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.7),
                        Colors.black.withValues(alpha: 0.9),
                      ],
                      stops: const [0.0, 0.3, 0.65, 1.0],
                    ),
                  ),
                ),

                // ─── Distance badge (top-right) ───
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.near_me_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${nearby.distanceKm.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── Locate-on-map / "tap again" hint (top-left) ───
                if (isHighlighted)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.85,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Tap again to open',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ─── Bottom content: logo + info ───
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Logo
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: hasLogo
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.network(
                                  logoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildLogoPlaceholder(theme),
                                ),
                              )
                            : _buildLogoPlaceholder(theme),
                      ),
                      const SizedBox(width: 12),

                      // Name + category/location + members
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name row
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    coaching.name,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.3,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.5,
                                              ),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (coaching.isVerified) ...[
                                  const SizedBox(width: 5),
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 16,
                                    color: Colors.blue.shade300,
                                  ),
                                ],
                              ],
                            ),

                            const SizedBox(height: 3),

                            // Category / location row
                            Row(
                              children: [
                                if (coaching.category != null &&
                                    coaching.category!.isNotEmpty) ...[
                                  Text(
                                    coaching.category!,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (location.isNotEmpty)
                                    Text(
                                      '  •  ',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.4,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                                if (location.isNotEmpty)
                                  Flexible(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.location_on_rounded,
                                          size: 13,
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Flexible(
                                          child: Text(
                                            location,
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.75,
                                              ),
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 4),

                            // Members stat
                            Row(
                              children: [
                                Icon(
                                  Icons.people_rounded,
                                  size: 13,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${coaching.memberCount} members',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (coaching.branches.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  Icon(
                                    Icons.account_tree_rounded,
                                    size: 13,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${coaching.branches.length} ${coaching.branches.length == 1 ? 'branch' : 'branches'}',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.75,
                                      ),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Arrow indicator
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderBg(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.15),
            theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            theme.colorScheme.secondary.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.school_rounded,
          size: 40,
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
    );
  }

  Widget _buildLogoPlaceholder(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.school_rounded,
        size: 24,
        color: Colors.white.withValues(alpha: 0.7),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Map control button
// ═══════════════════════════════════════════════════════════════════════

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final ThemeData theme;
  final VoidCallback onTap;

  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        shape: const CircleBorder(),
        color: theme.colorScheme.surface,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              icon,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

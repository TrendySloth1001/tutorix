import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // Selected coaching on map
  NearbyCoaching? _selectedCoaching;

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
    _searchSlideAnim = Tween<Offset>(
      begin: const Offset(0, -0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _searchAnimController,
      curve: Curves.easeOut,
    ));
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
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        // Fallback: New Delhi
        _setLocation(const LatLng(28.6139, 77.2090));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _setLocation(LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      _setLocation(const LatLng(28.6139, 77.2090));
    }
  }

  void _setLocation(LatLng loc) {
    if (!mounted) return;
    setState(() {
      _userLocation = loc;
      _locationLoading = false;
    });
    _loadNearby();
  }

  // ── Nearby ────────────────────────────────────────────────────────

  void _loadNearby() {
    final loc = _userLocation;
    if (loc == null) return;
    _nearbySub?.cancel();
    _nearbySub = _exploreService
        .watchNearby(lat: loc.latitude, lng: loc.longitude)
        .listen((list) {
      if (!mounted) return;
      setState(() {
        _nearby = list;
        _nearbyLoading = false;
      });
    }, onError: (_) {
      if (!mounted) return;
      setState(() => _nearbyLoading = false);
    });
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
      } catch (_) {
        if (!mounted) return;
        setState(() => _isSearching = false);
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
      final match = _nearby.where(
        (n) => n.coaching.id == result.id,
      );
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
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CoachingProfileScreen(
          coaching: full,
          user: widget.user,
        ),
      ));
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, 'Could not load coaching details');
      }
    }
  }

  void _onMarkerTapped(NearbyCoaching nc) {
    setState(() => _selectedCoaching = nc);
    final addr = nc.coaching.address;
    if (addr?.latitude != null && addr?.longitude != null) {
      _mapController.move(
        LatLng(addr!.latitude!, addr.longitude!),
        15,
      );
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

    return Scaffold(
      body: Stack(
        children: [
          // Main content
          _locationLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Map
                    Expanded(flex: 5, child: _buildMap(theme)),
                    // Bottom list
                    Expanded(flex: 4, child: _buildBottomPanel(theme)),
                  ],
                ),

          // Search bar (floating)
          if (!_locationLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: _buildSearchBar(theme),
            ),

          // Search overlay
          if (_searchOverlayVisible) _buildSearchOverlay(theme),

          // Selected coaching popup
          if (_selectedCoaching != null && !_searchOverlayVisible)
            _buildSelectedPopup(theme),
        ],
      ),
    );
  }

  // ── Map ───────────────────────────────────────────────────────────

  Widget _buildMap(ThemeData theme) {
    final center = _userLocation ?? const LatLng(28.6139, 77.2090);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13,
        minZoom: 4,
        maxZoom: 18,
        onTap: (_, __) {
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
                        errorBuilder: (_, __, ___) => Icon(
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 68,
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
      ),
      itemBuilder: (_, i) => _buildSearchResultTile(_searchResults[i], theme),
    );
  }

  Widget _buildSearchResultTile(SearchResult result, ThemeData theme) {
    final logoUrl = _getFullUrl(result.logo);
    final location = [result.city, result.state]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

    return ListTile(
      onTap: () => _onSearchResultTapped(result),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor:
            theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        backgroundImage:
            logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
        child: logoUrl.isEmpty
            ? Icon(Icons.school_rounded,
                size: 20, color: theme.colorScheme.primary)
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
          ? Icon(Icons.verified_rounded,
              size: 18, color: theme.colorScheme.primary)
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  // ── Selected coaching popup ───────────────────────────────────────

  Widget _buildSelectedPopup(ThemeData theme) {
    final nc = _selectedCoaching!;
    final coaching = nc.coaching;
    final logoUrl = _getFullUrl(coaching.logo);
    final addr = coaching.address;

    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.40 + 12,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        shadowColor: Colors.black.withValues(alpha: 0.2),
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
            ),
            child: Row(
              children: [
                // Logo
                CircleAvatar(
                  radius: 26,
                  backgroundColor: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.5),
                  backgroundImage:
                      logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
                  child: logoUrl.isEmpty
                      ? Icon(Icons.school_rounded,
                          size: 24, color: theme.colorScheme.primary)
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
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (coaching.isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified_rounded,
                                size: 16, color: theme.colorScheme.primary),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (coaching.category != null)
                        Text(
                          coaching.category!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
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
                    icon: Icon(Icons.directions_rounded,
                        color: theme.colorScheme.primary),
                    tooltip: 'Directions',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Bottom panel ──────────────────────────────────────────────────

  Widget _buildBottomPanel(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: _nearbyLoading
          ? const Center(child: CircularProgressIndicator())
          : _nearby.isEmpty
              ? _buildEmptyState(theme)
              : _buildNearbyList(theme),
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

  Widget _buildNearbyList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Row(
            children: [
              Text(
                'Nearby',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.5),
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
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _nearby.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) =>
                _NearbyCoachingCard(
                  nearby: _nearby[i],
                  theme: theme,
                  getFullUrl: _getFullUrl,
                  onTap: () {
                    _onMarkerTapped(_nearby[i]);
                  },
                  onOpen: () => _navigateToCoaching(_nearby[i].coaching.id),
                ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Nearby Coaching Card
// ═══════════════════════════════════════════════════════════════════════

class _NearbyCoachingCard extends StatelessWidget {
  final NearbyCoaching nearby;
  final ThemeData theme;
  final String Function(String?) getFullUrl;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  const _NearbyCoachingCard({
    required this.nearby,
    required this.theme,
    required this.getFullUrl,
    required this.onTap,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final coaching = nearby.coaching;
    final logoUrl = getFullUrl(coaching.logo);
    final location = [coaching.address?.city, coaching.address?.state]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

    return Material(
      borderRadius: BorderRadius.circular(14),
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Logo
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                backgroundImage:
                    logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
                child: logoUrl.isEmpty
                    ? Icon(Icons.school_rounded,
                        size: 22, color: theme.colorScheme.primary)
                    : null,
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            coaching.name,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (coaching.isVerified) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.verified_rounded,
                              size: 15, color: theme.colorScheme.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (location.isNotEmpty)
                      Text(
                        location,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Distance + map pin
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${nearby.distanceKm.toStringAsFixed(1)} km',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

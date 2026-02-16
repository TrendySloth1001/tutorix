import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../coaching/models/coaching_model.dart';
import '../../coaching/screens/coaching_profile_screen.dart';
import '../../coaching/services/coaching_service.dart';
import '../services/explore_service.dart';

class ExploreScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel>? onUserUpdated;

  const ExploreScreen({super.key, required this.user, this.onUserUpdated});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with TickerProviderStateMixin {
  final ExploreService _service = ExploreService();
  final MapController _mapController = MapController();

  // Location state
  LatLng? _userLocation;
  bool _locationLoading = true;
  String? _locationError;

  // Data
  List<NearbyCoaching> _coachings = [];
  bool _dataLoading = false;
  StreamSubscription? _dataSub;

  // Radius
  double _radiusKm = 20;
  static const List<double> _radiusOptions = [5, 10, 20, 50, 100];

  // Map
  bool _mapExpanded = false;
  NearbyCoaching? _selectedCoaching;

  // Search
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<SearchResult> _searchResults = [];
  bool _searchLoading = false;
  bool _showSearch = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ── Location ──────────────────────────────────────────────────────────

  Future<void> _fetchLocation() async {
    setState(() {
      _locationLoading = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationLoading = false;
          _locationError = 'Location services are disabled';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationLoading = false;
            _locationError = 'Location permission denied';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationLoading = false;
          _locationError = 'Location permission permanently denied';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _locationLoading = false;
      });
      _loadNearby();
    } catch (e) {
      setState(() {
        _locationLoading = false;
        _locationError = 'Could not get your location';
      });
    }
  }

  // ── Data ───────────────────────────────────────────────────────────────

  void _loadNearby() {
    if (_userLocation == null) return;
    _dataSub?.cancel();
    setState(() => _dataLoading = _coachings.isEmpty);

    _dataSub = _service
        .watchNearby(
          lat: _userLocation!.latitude,
          lng: _userLocation!.longitude,
          radiusKm: _radiusKm,
        )
        .listen(
          (list) {
            if (!mounted) return;
            setState(() {
              _coachings = list;
              _dataLoading = false;
            });
          },
          onError: (e) {
            if (!mounted) return;
            setState(() => _dataLoading = false);
            AppAlert.error(context, e);
          },
        );
  }

  void _onRadiusChanged(double radius) {
    setState(() {
      _radiusKm = radius;
      _selectedCoaching = null;
    });
    _loadNearby();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
        _showSearch = false;
      });
      return;
    }
    setState(() {
      _showSearch = true;
      _searchLoading = true;
    });
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await _service.searchCoachings(query);
        if (!mounted) return;
        setState(() {
          _searchResults = results;
          _searchLoading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _searchLoading = false);
      }
    });
  }

  void _dismissSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _showSearch = false;
      _searchResults = [];
    });
  }

  void _openCoachingProfile(CoachingModel coaching) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CoachingProfileScreen(
          coaching: coaching,
          user: widget.user,
        ),
      ),
    );
  }

  /// Fetch full coaching by ID and navigate to profile
  void _openCoachingById(String id) async {
    try {
      final coaching = await CoachingService().getCoachingById(id);
      if (!mounted || coaching == null) return;
      _openCoachingProfile(coaching);
    } catch (_) {}
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 70,
            floating: true,
            pinned: true,
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'Explore',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),

          // ── Search Bar ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onChanged: _onSearchChanged,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Search coachings by name…',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? GestureDetector(
                            onTap: _dismissSearch,
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),

          // ── Content ────────────────────────────────────────────────
          if (_locationLoading)
            const SliverFillRemaining(child: _LocationLoadingView())
          else if (_locationError != null)
            SliverFillRemaining(
              child: _LocationErrorView(
                error: _locationError!,
                onRetry: _fetchLocation,
                onOpenSettings: () => Geolocator.openAppSettings(),
              ),
            )
          else ...[
            // Map card
            SliverToBoxAdapter(
              child: _MapCard(
                userLocation: _userLocation!,
                coachings: _coachings,
                radiusKm: _radiusKm,
                mapController: _mapController,
                expanded: _mapExpanded,
                selectedCoaching: _selectedCoaching,
                onToggleExpand: () =>
                    setState(() => _mapExpanded = !_mapExpanded),
                onMarkerTap: (c) => setState(() => _selectedCoaching = c),
                onDismissSelection: () =>
                    setState(() => _selectedCoaching = null),
                onOpenCoaching: _openCoachingProfile,
              ),
            ),

            // Radius chips
            SliverToBoxAdapter(
              child: _RadiusSelector(
                current: _radiusKm,
                options: _radiusOptions,
                onChanged: _onRadiusChanged,
              ),
            ),

            // Section header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.near_me_rounded,
                      size: 18,
                      color: theme.colorScheme.primary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Nearby Coachings',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!_dataLoading)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_coachings.length}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // List
            if (_dataLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_coachings.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyNearbyView(radiusKm: _radiusKm),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                sliver: SliverList.builder(
                  itemCount: _coachings.length,
                  itemBuilder: (context, index) {
                    final item = _coachings[index];
                    return _NearbyCoachingCard(
                      item: item,
                      isSelected:
                          _selectedCoaching?.coaching.id == item.coaching.id,
                      onTap: () {
                        setState(() => _selectedCoaching = item);
                        final addr = item.coaching.address;
                        if (addr?.latitude != null && addr?.longitude != null) {
                          _mapController.move(
                            LatLng(addr!.latitude!, addr.longitude!),
                            14,
                          );
                          if (!_mapExpanded) {
                            setState(() => _mapExpanded = true);
                          }
                        }
                      },
                      onOpen: () => _openCoachingProfile(item.coaching),
                    );
                  },
                ),
              ),
          ],
        ],
      ),

          // ── Search results overlay ────────────────────────────────
          if (_showSearch)
            _SearchOverlay(
              results: _searchResults,
              loading: _searchLoading,
              query: _searchController.text,
              onResultTap: (result) {
                _dismissSearch();
                _openCoachingById(result.id);
              },
              onDismiss: _dismissSearch,
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MAP CARD
// ═══════════════════════════════════════════════════════════════════════════

class _MapCard extends StatelessWidget {
  final LatLng userLocation;
  final List<NearbyCoaching> coachings;
  final double radiusKm;
  final MapController mapController;
  final bool expanded;
  final NearbyCoaching? selectedCoaching;
  final VoidCallback onToggleExpand;
  final ValueChanged<NearbyCoaching> onMarkerTap;
  final VoidCallback onDismissSelection;
  final ValueChanged<CoachingModel>? onOpenCoaching;

  const _MapCard({
    required this.userLocation,
    required this.coachings,
    required this.radiusKm,
    required this.mapController,
    required this.expanded,
    required this.selectedCoaching,
    required this.onToggleExpand,
    required this.onMarkerTap,
    required this.onDismissSelection,
    this.onOpenCoaching,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mapHeight = expanded ? 380.0 : 220.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        height: mapHeight + (selectedCoaching != null ? 86 : 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Map
            SizedBox(
              height: mapHeight,
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: userLocation,
                  initialZoom: _zoomForRadius(radiusKm),
                  minZoom: 4,
                  maxZoom: 18,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onTap: (_, _) => onDismissSelection(),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.tutorix.app',
                    maxZoom: 19,
                  ),

                  // Radius circle
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: userLocation,
                        radius: radiusKm * 1000,
                        useRadiusInMeter: true,
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.06,
                        ),
                        borderColor: theme.colorScheme.primary.withValues(
                          alpha: 0.25,
                        ),
                        borderStrokeWidth: 1.5,
                      ),
                    ],
                  ),

                  // Coaching markers
                  MarkerLayer(
                    markers: [
                      // User marker
                      Marker(
                        point: userLocation,
                        width: 36,
                        height: 36,
                        child: _UserLocationDot(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      // Coaching markers
                      ...coachings.map((c) {
                        final addr = c.coaching.address;
                        if (addr?.latitude == null || addr?.longitude == null) {
                          return null;
                        }
                        final isSelected =
                            selectedCoaching?.coaching.id == c.coaching.id;
                        return Marker(
                          point: LatLng(addr!.latitude!, addr.longitude!),
                          width: isSelected ? 44 : 36,
                          height: isSelected ? 54 : 44,
                          child: GestureDetector(
                            onTap: () => onMarkerTap(c),
                            child: _CoachingMarkerPin(
                              coaching: c.coaching,
                              isSelected: isSelected,
                            ),
                          ),
                        );
                      }).nonNulls,
                    ],
                  ),
                ],
              ),
            ),

            // Expand / collapse
            Positioned(
              top: 12,
              right: 12,
              child: _MapActionButton(
                icon: expanded
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                onTap: onToggleExpand,
              ),
            ),

            // Re-center
            Positioned(
              top: 12,
              left: 12,
              child: _MapActionButton(
                icon: Icons.my_location_rounded,
                onTap: () =>
                    mapController.move(userLocation, _zoomForRadius(radiusKm)),
              ),
            ),

            // Selected coaching preview
            if (selectedCoaching != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _MapPreviewCard(
                  item: selectedCoaching!,
                  onOpen: onOpenCoaching != null
                      ? () => onOpenCoaching!(selectedCoaching!.coaching)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _zoomForRadius(double km) {
    if (km <= 5) return 13;
    if (km <= 10) return 12;
    if (km <= 20) return 11;
    if (km <= 50) return 10;
    return 9;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MAP HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _UserLocationDot extends StatelessWidget {
  final Color color;
  const _UserLocationDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 10,
              spreadRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}

String? _getFullUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return path;
  final cleanPath = path.startsWith('/') ? path.substring(1) : path;
  return '${ApiConstants.baseUrl}/$cleanPath';
}

class _CoachingMarkerPin extends StatelessWidget {
  final CoachingModel coaching;
  final bool isSelected;

  const _CoachingMarkerPin({required this.coaching, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pinSize = isSelected ? 44.0 : 36.0;
    final logoSize = isSelected ? 30.0 : 22.0;
    final borderColor = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.surface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pin head with logo
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: pinSize,
          height: pinSize,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(pinSize / 2).copyWith(
              bottomRight: Radius.circular(isSelected ? 4 : pinSize / 2),
            ),
            border: Border.all(color: borderColor, width: isSelected ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: (isSelected ? theme.colorScheme.primary : Colors.black)
                    .withValues(alpha: isSelected ? 0.35 : 0.18),
                blurRadius: isSelected ? 14 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(logoSize / 2),
              child: _getFullUrl(coaching.logo) != null
                  ? Image.network(
                      _getFullUrl(coaching.logo)!,
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.school_rounded,
                        size: logoSize * 0.55,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : Icon(
                      Icons.school_rounded,
                      size: logoSize * 0.55,
                      color: theme.colorScheme.primary,
                    ),
            ),
          ),
        ),
        // Pin tail triangle
        CustomPaint(
          size: const Size(12, 8),
          painter: _PinTailPainter(
            color: borderColor,
            strokeWidth: isSelected ? 3 : 2,
          ),
        ),
      ],
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  _PinTailPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinTailPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

class _MapActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: theme.colorScheme.primary),
      ),
    );
  }
}

class _MapPreviewCard extends StatelessWidget {
  final NearbyCoaching item;
  final VoidCallback? onOpen;
  const _MapPreviewCard({required this.item, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coaching = item.coaching;

    return GestureDetector(
      onTap: onOpen,
      child: Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _getFullUrl(coaching.logo) != null
                  ? Image.network(
                      _getFullUrl(coaching.logo)!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.school_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : Icon(
                      Icons.school_rounded,
                      color: theme.colorScheme.primary,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  coaching.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (coaching.address?.city != null) coaching.address!.city,
                    '${item.distanceKm} km away',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Directions button
          _DirectionsButton(
            lat: coaching.address?.latitude,
            lng: coaching.address?.longitude,
            label: coaching.name,
            compact: true,
          ),
        ],
      ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  RADIUS SELECTOR
// ═══════════════════════════════════════════════════════════════════════════

class _RadiusSelector extends StatelessWidget {
  final double current;
  final List<double> options;
  final ValueChanged<double> onChanged;

  const _RadiusSelector({
    required this.current,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: options.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final r = options[index];
            final selected = r == current;
            return GestureDetector(
              onTap: () => onChanged(r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withValues(alpha: 0.15),
                    width: selected ? 1.5 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.25,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  '${r.toInt()} km',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.primary.withValues(alpha: 0.7),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  NEARBY COACHING CARD — Cover image + overlapping logo
// ═══════════════════════════════════════════════════════════════════════════

class _NearbyCoachingCard extends StatelessWidget {
  final NearbyCoaching item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onOpen;

  const _NearbyCoachingCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coaching = item.coaching;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.3)
                  : theme.colorScheme.primary.withValues(alpha: 0.05),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    (isSelected ? theme.colorScheme.primary : theme.shadowColor)
                        .withValues(alpha: isSelected ? 0.12 : 0.06),
                blurRadius: isSelected ? 18 : 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cover image area ─────────────────────────────────
              SizedBox(
                height: 100,
                width: double.infinity,
                child: Stack(
                  children: [
                    // Cover image or gradient placeholder
                    Positioned.fill(
                      child: _getFullUrl(coaching.coverImage) != null
                          ? Image.network(
                              _getFullUrl(coaching.coverImage)!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _CoverPlaceholder(theme: theme),
                            )
                          : _CoverPlaceholder(theme: theme),
                    ),
                    // Gradient overlay for readability
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.05),
                              Colors.black.withValues(alpha: 0.45),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Distance badge (top right)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.near_me_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${item.distanceKm} km',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Verified badge (top left)
                    if (coaching.isVerified)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                size: 13,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Verified',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Content area ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo (overlapping the cover slightly)
                    Transform.translate(
                      offset: const Offset(0, -28),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: _getFullUrl(coaching.logo) != null
                              ? Image.network(
                                  _getFullUrl(coaching.logo)!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.school_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 24,
                                  ),
                                )
                              : Icon(
                                  Icons.school_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 24,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name
                          Text(
                            coaching.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          // Category + City
                          Text(
                            [
                              if (coaching.category != null) coaching.category!,
                              if (coaching.address?.city != null)
                                coaching.address!.city,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.secondary.withValues(
                                alpha: 0.65,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Stats + Directions + View
                          Row(
                            children: [
                              _StatChip(
                                icon: Icons.group_rounded,
                                label: '${coaching.memberCount}',
                                theme: theme,
                              ),
                              if (coaching.subjects.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: _StatChip(
                                    icon: Icons.menu_book_rounded,
                                    label: coaching.subjects.length > 2
                                        ? '${coaching.subjects.take(2).join(", ")}…'
                                        : coaching.subjects.join(", "),
                                    theme: theme,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              _DirectionsButton(
                                lat: coaching.address?.latitude,
                                lng: coaching.address?.longitude,
                                label: coaching.name,
                                compact: false,
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: onOpen,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'View',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  final ThemeData theme;
  const _CoverPlaceholder({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.15),
            theme.colorScheme.tertiary.withValues(alpha: 0.25),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.school_rounded,
          size: 36,
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  DIRECTIONS BUTTON — opens native maps
// ═══════════════════════════════════════════════════════════════════════════

class _DirectionsButton extends StatelessWidget {
  final double? lat;
  final double? lng;
  final String label;
  final bool compact;

  const _DirectionsButton({
    required this.lat,
    required this.lng,
    required this.label,
    this.compact = false,
  });

  Future<void> _openMaps(BuildContext context) async {
    if (lat == null || lng == null) {
      AppAlert.error(context, 'Location not available for this coaching');
      return;
    }
    // Google Maps universal link — works on both Android (opens app) & iOS (opens in browser or app)
    final gMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    // Apple Maps (iOS fallback)
    final aMapsUrl = Uri.parse(
      'https://maps.apple.com/?daddr=$lat,$lng&dirflg=d',
    );

    try {
      // Launch directly — canLaunchUrl fails on Android 11+ without <queries>
      await launchUrl(gMapsUrl, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        // Fallback to Apple Maps (iOS)
        await launchUrl(aMapsUrl, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (context.mounted) {
          AppAlert.error(context, 'Could not open maps application');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (compact) {
      // Small icon-only button for map preview card
      return GestureDetector(
        onTap: () => _openMaps(context),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
      );
    }

    // Pill button for list cards
    return GestureDetector(
      onTap: () => _openMaps(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_rounded,
              size: 14,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              'Directions',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeData theme;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: theme.colorScheme.secondary.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 11,
              color: theme.colorScheme.secondary.withValues(alpha: 0.65),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  EMPTY / ERROR / LOADING STATES
// ═══════════════════════════════════════════════════════════════════════════

class _LocationLoadingView extends StatelessWidget {
  const _LocationLoadingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Getting your location…',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us find coachings near you',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.secondary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  const _LocationErrorView({
    required this.error,
    required this.onRetry,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPermanent = error.contains('permanently');

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_off_rounded,
              size: 56,
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Location Needed',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isPermanent
                ? 'Location permission was permanently denied. Please enable it from your device settings to discover nearby coachings.'
                : error,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.secondary.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          if (isPermanent)
            FilledButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: const Text('Open Settings'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )
          else
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyNearbyView extends StatelessWidget {
  final double radiusKm;
  const _EmptyNearbyView({required this.radiusKm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.explore_off_rounded,
              size: 56,
              color: theme.colorScheme.primary.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'No Coachings Found',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'No coaching institutes found within ${radiusKm.toInt()} km. Try expanding the search radius.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.secondary.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SEARCH OVERLAY
// ═══════════════════════════════════════════════════════════════════════════

class _SearchOverlay extends StatelessWidget {
  final List<SearchResult> results;
  final bool loading;
  final String query;
  final ValueChanged<SearchResult> onResultTap;
  final VoidCallback onDismiss;

  const _SearchOverlay({
    required this.results,
    required this.loading,
    required this.query,
    required this.onResultTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Position below the app bar + search bar
    return Positioned(
      top: MediaQuery.of(context).padding.top + 70 + 56,
      left: 16,
      right: 16,
      bottom: 0,
      child: GestureDetector(
        onTap: onDismiss,
        behavior: HitTestBehavior.opaque,
        child: Align(
          alignment: Alignment.topCenter,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            shadowColor: Colors.black26,
            color: theme.colorScheme.surface,
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : results.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 32,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 36,
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.2),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No results for "$query"',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: results.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            indent: 68,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.06),
                          ),
                          itemBuilder: (context, index) {
                            final r = results[index];
                            return _SearchResultTile(
                              result: r,
                              onTap: () => onResultTap(r),
                            );
                          },
                        ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _SearchResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Logo
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _getFullUrl(result.logo) != null
                    ? Image.network(
                        _getFullUrl(result.logo)!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.school_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : Icon(
                        Icons.school_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
              ),
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
                          result.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (result.isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (result.category != null) result.category!,
                      if (result.city != null) result.city!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

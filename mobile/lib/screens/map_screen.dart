// ignore_for_file: unused_field, unnecessary_brace_in_string_interps

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile/models/route_option.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../models/event_model.dart';
import '../services/event_service.dart';
import 'event_form_screen.dart';
import 'event_detail_screen.dart';

enum MapState { loading, loaded, error }

enum LocationState { loading, loaded, error, denied }

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final EventService _eventService = EventService();
  final MapController _mapController = MapController();

  MapState _mapState = MapState.loading;
  LocationState _locationState = LocationState.loading;

  List<Event> _events = [];
  List<Marker> _markers = [];
  List<LatLng> _routePoints = [];
  LatLng? _currentUserLocation;
  LatLng? _selectedEventLocation;
  String _errorMessage = '';

  late AnimationController _pulseController;
  late AnimationController _routeController;
  Timer? _routeAnimationTimer;
  int _currentRouteIndex = 0;

  static const double _defaultZoom = 10.0;
  static const double _detailZoom = 15.0;
  static const LatLng _defaultCenter = LatLng(40.76, 29.93);
  static const Duration _animationDuration = Duration(milliseconds: 300);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeMap();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _routeController.dispose();
    _routeAnimationTimer?.cancel();
    super.dispose();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _routeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  Future<void> _initializeMap() async {
    await Future.wait([_loadEvents(), _getCurrentLocation()]);
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _locationState = LocationState.loading;
      });

      final status = await Permission.location.request();

      if (!status.isGranted) {
        setState(() {
          _locationState = LocationState.denied;
          _errorMessage = 'Konum izni gerekli';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final userLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentUserLocation = userLocation;
        _locationState = LocationState.loaded;
      });

      // İlk kez açıldığında kullanıcı konumuna git
      if (_events.isEmpty) {
        _animateToLocation(userLocation, _detailZoom);
      }
    } catch (e) {
      setState(() {
        _locationState = LocationState.error;
        _errorMessage = 'Konum alınamadı: ${e.toString()}';
      });
    }
  }

  Future<void> _loadEvents() async {
    try {
      setState(() {
        _mapState = MapState.loading;
        _errorMessage = '';
      });

      final events = await _eventService.getEvents();

      setState(() {
        _events = events;
        _markers = _buildEventMarkers(events);
        _mapState = MapState.loaded;
      });
    } catch (e) {
      setState(() {
        _mapState = MapState.error;
        _errorMessage = 'Etkinlikler yüklenirken hata: ${e.toString()}';
      });
    }
  }

  List<Marker> _buildEventMarkers(List<Event> events) {
    return events.map((event) {
      return Marker(
        width: 30.0,
        height: 30.0,
        point: LatLng(event.coordinates[1], event.coordinates[0]),
        child: GestureDetector(
          onTap: () => _showEventDetails(event),
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale =
                  1.0 + (math.sin(_pulseController.value * 2 * math.pi) * 0.1);
              return Transform.scale(
                scale: scale,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary,
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 12,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }).toList();
  }

  Future<void> _calculateRoute(LatLng destination) async {
    if (_currentUserLocation == null) {
      _showSnackBar('Konum bilgisi bulunamadı', isError: true);
      return;
    }

    setState(() {
      _selectedEventLocation = destination;
      _routePoints = [];
      _currentRouteIndex = 0;
    });

    _showSnackBar('Rota hesaplanıyor...', duration: Duration(seconds: 1));

    try {
      final url =
          'http://router.project-osrm.org/route/v1/driving/'
          '${_currentUserLocation!.longitude},${_currentUserLocation!.latitude};'
          '${destination.longitude},${destination.latitude}?overview=full&geometries=geojson';

      final response = await http
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final coordinates =
            data['routes'][0]['geometry']['coordinates'] as List;
        final duration = data['routes'][0]['duration'] as num;
        final distance = data['routes'][0]['distance'] as num;

        final newRoutePoints =
            coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();

        setState(() {
          _routePoints = newRoutePoints;
        });

        _showRouteInfo([
          RouteOption(
            title: 'Yaya',
            duration: const Duration(minutes: 20),
            distance: 1.5,
            color: Colors.blue,
          ),
          RouteOption(
            title: 'Bisiklet',
            duration: const Duration(minutes: 10),
            distance: 2.0,
            color: Colors.green,
          ),
        ]);
        _startRouteAnimation();
        _fitBoundsToRoute();
        print('Rota Koordinatları: $newRoutePoints');
      } else {
        _showSnackBar(
          'Rota hesaplanamadı: ${response.statusCode}',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Rota hesaplanırken hata: $e', isError: true);
    }
  }

  void _startRouteAnimation() {
    _routeAnimationTimer?.cancel();
    _currentRouteIndex = 0;

    _routeAnimationTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (_currentRouteIndex < _routePoints.length - 1) {
        setState(() {
          _currentRouteIndex++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _fitBoundsToRoute() {
    if (_routePoints.isEmpty || _currentUserLocation == null) return;

    final bounds = LatLngBounds.fromPoints([
      _currentUserLocation!,
      _selectedEventLocation!,
      ..._routePoints,
    ]);

    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  void _showRouteInfo(List<RouteOption> routes) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      elevation: 8,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık
              Text(
                'Rota Seçenekleri',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),

              // Rotalar
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: routes.length,
                itemBuilder: (context, index) {
                  final route = routes[index];
                  final hours = route.duration.inHours;
                  final minutes = route.duration.inMinutes % 60;
                  final timeText =
                      hours > 0
                          ? '${hours} saat ${minutes} dakika'
                          : '${minutes} dakika';
                  final distanceText =
                      '${route.distance.toStringAsFixed(1)} km';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        // Renk Noktası
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: route.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Bilgi
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                route.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.directions_car,
                                    size: 16,
                                    color: route.color,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    timeText,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.straighten,
                                    size: 16,
                                    color: route.color,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    distanceText,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Kapat Butonu
              TextButton.icon(
                onPressed: Navigator.of(context).pop,
                icon: const Icon(Icons.close, color: Colors.grey),
                label: const Text(
                  'Kapat',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEventDetails(Event event) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (context) => EventDetailScreen(event: event)),
    );

    if (!mounted) return;

    if (result == true) {
      await _loadEvents();
    } else if (result is LatLng) {
      await _calculateRoute(result);
    }
  }

  void _animateToLocation(LatLng location, double zoom) {
    _mapController.move(location, zoom);
  }

  void _centerToUserLocation() {
    if (_currentUserLocation != null) {
      _animateToLocation(_currentUserLocation!, _detailZoom);
    } else {
      _showSnackBar('Konum bilgisi bulunamadı', isError: true);
    }
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(
      _mapController.camera.center,
      math.min(currentZoom + 1, 18.0),
    );
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(
      _mapController.camera.center,
      math.max(currentZoom - 1, 1.0),
    );
  }

  void _clearRoute() {
    setState(() {
      _routePoints = [];
      _selectedEventLocation = null;
      _currentRouteIndex = 0;
    });
    _routeAnimationTimer?.cancel();
  }

  void _showSnackBar(
    String message, {
    bool isError = false,
    Duration? duration,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 2),
        action:
            isError
                ? SnackBarAction(
                  label: 'Yeniden Dene',
                  onPressed: () => _initializeMap(),
                )
                : null,
      ),
    );
  }

  Future<void> _refreshMap() async {
    _clearRoute();
    await _initializeMap();
    _showSnackBar('Harita yenilendi');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Etkinlik Haritası'),
        elevation: 0,
        actions: [
          if (_routePoints.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: _clearRoute,
              tooltip: 'Rotayı Temizle',
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshMap,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildMap(colorScheme),
          _buildLoadingOverlay(),
          _buildControlButtons(colorScheme),
          _buildLocationInfo(),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(colorScheme),
    );
  }

  Widget _buildMap(ColorScheme colorScheme) {
    if (_mapState == MapState.error) {
      return _buildErrorWidget();
    }

    final allMarkers = <Marker>[
      ..._markers,
      if (_currentUserLocation != null) _buildUserLocationMarker(colorScheme),
    ];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentUserLocation ?? _defaultCenter,
        initialZoom: _defaultZoom,
        minZoom: 1.0,
        maxZoom: 18.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.app',
          maxZoom: 19,
        ),
        if (_routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints.take(_currentRouteIndex + 1).toList(),
                strokeWidth: 4.0,
                color: colorScheme.primary,
                borderStrokeWidth: 2.0,
                borderColor: Colors.white,
                gradientColors: [colorScheme.primary, colorScheme.secondary],
              ),
            ],
          ),
        MarkerLayer(markers: allMarkers),
      ],
    );
  }

  Marker _buildUserLocationMarker(ColorScheme colorScheme) {
    return Marker(
      width: 60.0,
      height: 60.0,
      point: _currentUserLocation!,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 40 + (_pulseController.value * 20),
                height: 40 + (_pulseController.value * 20),
                decoration: BoxDecoration(
                  color: Colors.lightBlue,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    if (_mapState != MapState.loading &&
        _locationState != LocationState.loading) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.black,
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Harita yükleniyor...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButtons(ColorScheme colorScheme) {
    return Positioned(
      left: 16,
      bottom: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildControlButton(
            icon: Icons.my_location_rounded,
            onPressed: _centerToUserLocation,
            heroTag: 'my_location',
            tooltip: 'Konumuma Git',
          ),
          const SizedBox(height: 8),
          _buildControlButton(
            icon: Icons.add_rounded,
            onPressed: _zoomIn,
            heroTag: 'zoom_in',
            tooltip: 'Yakınlaştır',
          ),
          const SizedBox(height: 8),
          _buildControlButton(
            icon: Icons.remove_rounded,
            onPressed: _zoomOut,
            heroTag: 'zoom_out',
            tooltip: 'Uzaklaştır',
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String heroTag,
    required String tooltip,
    Color? backgroundColor,
  }) {
    return FloatingActionButton.small(
      heroTag: heroTag,
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      tooltip: tooltip,
      child: Icon(icon),
    );
  }

  Widget _buildLocationInfo() {
    if (_locationState == LocationState.denied) {
      return Positioned(
        top: 16,
        left: 16,
        right: 16,
        child: Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(
                  Icons.location_off_rounded,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Konum izni verilmedi. Ayarlardan izin verebilirsiniz.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => openAppSettings(),
                  child: const Text('Ayarlar'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Bir hata oluştu',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(_errorMessage),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _refreshMap,
                child: const Text('Yeniden Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(ColorScheme colorScheme) {
    return FloatingActionButton.extended(
      heroTag: 'add_event',
      onPressed: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (context) => const EventFormScreen()),
        );

        if (result == true) {
          await _loadEvents();
          _showSnackBar('Yeni etkinlik eklendi');
        }
      },
      icon: const Icon(Icons.edit_calendar_rounded),
      label: const Text(
        'Etkinlik Ekle',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: Colors.white,
        ),
      ),
      backgroundColor: const Color(0xFF10B981),
      foregroundColor: Colors.white,
      elevation: 6,
      hoverElevation: 8,
      highlightElevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      isExtended: true,
    );
  }
}

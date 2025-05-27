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

---------------

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import 'event_form_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final Event event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final EventService _eventService = EventService();
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Etkinlik Detayı'),
        elevation: 0,
        actions: [
          _buildActionButton(
            icon: Icons.directions_rounded,
            onPressed: _handleDirections,
            tooltip: 'Yol Tarifi',
          ),
          _buildActionButton(
            icon: Icons.edit_rounded,
            onPressed: _handleEdit,
            tooltip: 'Düzenle',
          ),
          _buildActionButton(
            icon: Icons.delete_rounded,
            onPressed: _isDeleting ? null : _handleDelete,
            tooltip: 'Sil',
            isDestructive: true,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEventImage(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEventHeader(theme),
                  const SizedBox(height: 24),
                  _buildEventDates(dateFormat, colorScheme),
                  const SizedBox(height: 16),
                  _buildDescription(theme, colorScheme),
                  const SizedBox(height: 16),
                  _buildContactInfo(colorScheme),
                  const SizedBox(height: 16),
                  _buildLocationInfo(colorScheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    bool isDestructive = false,
  }) {
    return IconButton(
      icon: Icon(icon),
      onPressed: onPressed,
      tooltip: tooltip,
      style:
          isDestructive
              ? IconButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              )
              : null,
    );
  }

  Widget _buildEventImage() {
    if (widget.event.imageUrl.isEmpty) return const SizedBox.shrink();

    return Hero(
      tag: 'event-image-${widget.event.id}',
      child: Container(
        width: double.infinity,
        height: 240,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          widget.event.imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value:
                    loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.red[500],
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported_rounded, size: 48),
                    SizedBox(height: 8),
                    Text('Resim yüklenemedi'),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEventHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.event.eventTitle,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.category_rounded,
                size: 16,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 6),
              Text(
                widget.event.category,
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventDates(DateFormat dateFormat, ColorScheme colorScheme) {
    return _buildInfoCard(
      icon: Icons.calendar_today_rounded,
      title: 'Etkinlik Tarihleri',
      colorScheme: colorScheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateRow(
            icon: Icons.play_arrow_rounded,
            label: 'Başlangıç',
            date: dateFormat.format(widget.event.startDate),
          ),
          const SizedBox(height: 4),
          _buildDateRow(
            icon: Icons.stop_rounded,
            label: 'Bitiş',
            date: dateFormat.format(widget.event.endDate),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow({
    required IconData icon,
    required String label,
    required String date,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text('$label: $date'),
      ],
    );
  }

  Widget _buildDescription(ThemeData theme, ColorScheme colorScheme) {
    colorScheme = colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Açıklama',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline, width: 1),
          ),
          child: Text(widget.event.decs, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }

  Widget _buildContactInfo(ColorScheme colorScheme) {
    return _buildInfoCard(
      icon: Icons.person_rounded,
      title: 'İletişim Bilgileri',
      colorScheme: colorScheme,
      child: Column(
        children: [
          _buildContactRow(
            icon: Icons.person_outline_rounded,
            label: 'İsim',
            value: widget.event.name,
          ),
          const SizedBox(height: 8),
          _buildContactRow(
            icon: Icons.phone_rounded,
            label: 'Telefon',
            value: widget.event.phone,
          ),
          const SizedBox(height: 8),
          _buildContactRow(
            icon: Icons.location_on_rounded,
            label: 'Adres',
            value: widget.event.address,
            isExpanded: true,
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    bool isExpanded = false,
  }) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        if (isExpanded)
          Expanded(child: Text('$label: $value'))
        else
          Text('$label: $value'),
      ],
    );

    return content;
  }

  Widget _buildLocationInfo(ColorScheme colorScheme) {
    return _buildInfoCard(
      icon: Icons.map_rounded,
      title: 'Konum Bilgileri',
      colorScheme: colorScheme,
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.my_location_rounded,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text('Enlem: ${widget.event.coordinates[1].toStringAsFixed(6)}'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.place_rounded, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text('Boylam: ${widget.event.coordinates[0].toStringAsFixed(6)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required ColorScheme colorScheme,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  void _handleDirections() {
    Navigator.pop(
      context,
      LatLng(widget.event.coordinates[1], widget.event.coordinates[0]),
    );
  }

  Future<void> _handleEdit() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EventFormScreen(event: widget.event),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await _showDeleteConfirmation();
    if (!confirmed || !mounted) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await _eventService.deleteEvent(widget.event.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Etkinlik başarıyla silindi'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Etkinlik silinemedi: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool> _showDeleteConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            icon: Icon(
              Icons.warning_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 32,
            ),
            title: const Text('Etkinliği Sil'),
            content: const Text(
              'Bu etkinliği silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('İptal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Sil'),
              ),
            ],
          ),
    );

    return result ?? false;
  }
}


----------

// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unused_field, unnecessary_brace_in_string_interps
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../models/event_model.dart';
import '../services/event_service.dart';

class EventFormScreen extends StatefulWidget {
  final Event? event;
  const EventFormScreen({super.key, this.event});

  @override
  _EventFormScreenState createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eventService = EventService();
  final MapController _mapController = MapController();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _categoryController;
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late DateTime _startDate;
  late DateTime _endDate;
  late LatLng _selectedLocation;
  XFile? _imageFile;
  String _imageUrl = '';
  bool _isLoading = false;
  bool _isUploading = false;
  String _uploadStatus = '';
  final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
  String baseUrl = 'http://10.0.2.2:5117/api/Events';

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController = TextEditingController(text: widget.event!.eventTitle);
      _descController = TextEditingController(text: widget.event!.decs);
      _categoryController = TextEditingController(text: widget.event!.category);
      _nameController = TextEditingController(text: widget.event!.name);
      _addressController = TextEditingController(text: widget.event!.address);
      _phoneController = TextEditingController(text: widget.event!.phone);
      _startDate = widget.event!.startDate;
      _endDate = widget.event!.endDate;
      _selectedLocation = LatLng(
        widget.event!.coordinates[1],
        widget.event!.coordinates[0],
      );
      _imageUrl = widget.event!.imageUrl;
    } else {
      _titleController = TextEditingController();
      _descController = TextEditingController();
      _categoryController = TextEditingController();
      _nameController = TextEditingController();
      _addressController = TextEditingController();
      _phoneController = TextEditingController();
      _startDate = DateTime.now();
      _endDate = DateTime.now().add(const Duration(hours: 1));
      _selectedLocation = const LatLng(40.76, 29.93);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _categoryController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_startDate),
      );
      if (pickedTime != null) {
        setState(() {
          _startDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(hours: 1));
          }
        });
      }
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate:
          _endDate.isAfter(_startDate)
              ? _endDate
              : _startDate.add(const Duration(hours: 1)),
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_endDate),
      );
      if (pickedTime != null) {
        setState(() {
          _endDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
        _imageUrl = '';
      });
    }
  }

  Future<void> _saveEvent() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _isUploading = true;
        _uploadStatus = 'Etkinlik bilgileri hazırlanıyor...';
      });

      try {
        final formData = FormData();

        formData.fields.addAll([
          MapEntry("EventTitle", _titleController.text),
          MapEntry("Decs", _descController.text),
          MapEntry("StartDate", _startDate.toIso8601String()),
          MapEntry("EndDate", _endDate.toIso8601String()),
          MapEntry("Category", _categoryController.text),
          MapEntry("Coordinates[0]", _selectedLocation.longitude.toString()),
          MapEntry("Coordinates[1]", _selectedLocation.latitude.toString()),
          MapEntry("Name", _nameController.text),
          MapEntry("Address", _addressController.text),
          MapEntry("Phone", _phoneController.text),
        ]);

        if (_imageFile != null) {
          setState(() {
            _uploadStatus = 'Resim yükleniyor...';
          });

          formData.files.add(
            MapEntry(
              "ImageFile",
              await MultipartFile.fromFile(
                _imageFile!.path,
                filename: _imageFile!.name,
              ),
            ),
          );
        }

        setState(() {
          _uploadStatus = 'Sunucuya veri gönderiliyor...';
        });

        Response response;

        if (widget.event == null) {
          response = await Dio().post(
            baseUrl,
            data: formData,
            onSendProgress: (int sent, int total) {
              setState(() {
                _uploadStatus =
                    'Yükleniyor: ${((sent / total) * 100).toStringAsFixed(0)}%';
              });
            },
          );
        } else {
          response = await Dio().put(
            '${baseUrl}/${widget.event!.id}',
            data: formData,
            onSendProgress: (int sent, int total) {
              setState(() {
                _uploadStatus =
                    'Yükleniyor: ${((sent / total) * 100).toStringAsFixed(0)}%';
              });
            },
          );
        }

        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Hata: $e')));
        }
      } finally {
        setState(() {
          _isLoading = false;
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    IconData? prefixIcon,
    AutovalidateMode? autovalidateMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        autovalidateMode: autovalidateMode,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon:
              prefixIcon != null
                  ? Icon(prefixIcon, color: const Color(0xFF6366F1))
                  : null,
          labelStyle: const TextStyle(color: Color(0xFF6B7280)),
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF6366F1), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateFormat.format(date),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        title: Text(
          widget.event == null ? 'Etkinlik Ekle' : 'Etkinlik Düzenle',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          _isLoading && !_isUploading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Etkinlik Bilgileri Bölümü
                      _buildSection(
                        title: '📋 Etkinlik Bilgileri',
                        children: [
                          _buildTextField(
                            controller: _titleController,
                            label: 'Etkinlik Başlığı',
                            prefixIcon: Icons.event,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Lütfen etkinlik başlığını girin';
                              }
                              return null;
                            },
                          ),
                          _buildTextField(
                            controller: _descController,
                            label: 'Açıklama',
                            prefixIcon: Icons.description,
                            maxLines: 3,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Lütfen açıklama girin';
                              }
                              return null;
                            },
                          ),
                          _buildTextField(
                            controller: _categoryController,
                            label: 'Kategori',
                            prefixIcon: Icons.category,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Lütfen kategori girin';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),

                      // Tarih ve Zaman Bölümü
                      _buildSection(
                        title: '📅 Tarih ve Zaman',
                        children: [
                          _buildDateSelector(
                            label: 'Başlangıç Tarihi',
                            date: _startDate,
                            onTap: () => _selectStartDate(context),
                            icon: Icons.schedule,
                          ),
                          _buildDateSelector(
                            label: 'Bitiş Tarihi',
                            date: _endDate,
                            onTap: () => _selectEndDate(context),
                            icon: Icons.schedule_send,
                          ),
                        ],
                      ),

                      // İletişim Bilgileri Bölümü
                      _buildSection(
                        title: '📞 İletişim Bilgileri',
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            label: 'İsim',
                            prefixIcon: Icons.person,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Lütfen isim girin';
                              }
                              return null;
                            },
                          ),
                          _buildTextField(
                            controller: _phoneController,
                            label: 'Telefon',
                            prefixIcon: Icons.phone,
                            keyboardType: TextInputType.phone,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Lütfen telefon numarası girin';
                              }
                              if (!RegExp(
                                r'^\+?[0-9]{10,15}$',
                              ).hasMatch(value)) {
                                return 'Lütfen geçerli bir telefon numarası girin';
                              }
                              return null;
                            },
                          ),
                          _buildTextField(
                            controller: _addressController,
                            label: 'Adres',
                            prefixIcon: Icons.location_on,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Lütfen adres girin';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),

                      // Etkinlik Resmi Bölümü
                      _buildSection(
                        title: '🎨 Etkinlik Resmi',
                        children: [
                          if (_imageUrl.isNotEmpty && _imageFile == null)
                            Container(
                              width: double.infinity,
                              height: 200,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  _imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.error,
                                              color: Colors.grey,
                                              size: 48,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Resim yüklenemedi',
                                              style: TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            )
                          else if (_imageFile != null)
                            Container(
                              width: double.infinity,
                              height: 200,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(_imageFile!.path),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              height: 200,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                  style: BorderStyle.solid,
                                  width: 2,
                                ),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_outlined,
                                    size: 48,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Resim seçilmedi',
                                    style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Resim Seçme Butonu
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(
                                Icons.image,
                                color: Colors.white,
                              ),
                              label: const Text(
                                "Resim Seç",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Konum Bölümü
                      _buildSection(
                        title: '📍 Etkinlik Konumu',
                        children: [
                          const Text(
                            'Haritaya tıklayarak etkinlik konumunu seçin:',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 300,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: FlutterMap(
                                    mapController: _mapController,
                                    options: MapOptions(
                                      initialCenter: _selectedLocation,
                                      initialZoom: 13.0,
                                      onTap: (tapPosition, latLng) {
                                        setState(() {
                                          _selectedLocation = latLng;
                                        });
                                      },
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate:
                                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                        userAgentPackageName: 'com.example.app',
                                      ),
                                      MarkerLayer(
                                        markers: [
                                          Marker(
                                            width: 80.0,
                                            height: 80.0,
                                            point: _selectedLocation,
                                            child: const Icon(
                                              Icons.location_on,
                                              color: Color(0xFFEF4444),
                                              size: 40.0,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Zoom Controls
                                Positioned(
                                  top: 16,
                                  right: 16,
                                  child: Column(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.1,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  final currentZoom =
                                                      _mapController
                                                          .camera
                                                          .zoom;
                                                  _mapController.move(
                                                    _mapController
                                                        .camera
                                                        .center,
                                                    currentZoom + 1,
                                                  );
                                                },
                                                borderRadius:
                                                    const BorderRadius.only(
                                                      topLeft: Radius.circular(
                                                        8,
                                                      ),
                                                      topRight: Radius.circular(
                                                        8,
                                                      ),
                                                    ),
                                                child: Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration:
                                                      const BoxDecoration(
                                                        border: Border(
                                                          bottom: BorderSide(
                                                            color: Color(
                                                              0xFFE5E7EB,
                                                            ),
                                                            width: 1,
                                                          ),
                                                        ),
                                                      ),
                                                  child: const Icon(
                                                    Icons.add,
                                                    color: Color(0xFF374151),
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  final currentZoom =
                                                      _mapController
                                                          .camera
                                                          .zoom;
                                                  _mapController.move(
                                                    _mapController
                                                        .camera
                                                        .center,
                                                    currentZoom - 1,
                                                  );
                                                },
                                                borderRadius:
                                                    const BorderRadius.only(
                                                      bottomLeft:
                                                          Radius.circular(8),
                                                      bottomRight:
                                                          Radius.circular(8),
                                                    ),
                                                child: const SizedBox(
                                                  width: 44,
                                                  height: 44,
                                                  child: Icon(
                                                    Icons.remove,
                                                    color: Color(0xFF374151),
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
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
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.my_location,
                                  color: Color(0xFF6366F1),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Seçilen Konum: ${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}',
                                    style: const TextStyle(
                                      color: Color(0xFF374151),
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Kaydet Butonu
                      Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 24),
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveEvent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            widget.event == null
                                ? '✨ Etkinlik Ekle'
                                : '🔄 Etkinliği Güncelle',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

          // Yükleme göstergesi overlay'i
          if (_isUploading)
            Container(
              color: Colors.black.withOpacity(0.7),
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFF6366F1),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _uploadStatus,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF374151),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

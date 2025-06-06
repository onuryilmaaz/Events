// ignore_for_file: unused_field, unnecessary_brace_in_string_interps, curly_braces_in_flow_control_structures, prefer_final_fields

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../models/event_model.dart';
import '../services/event_service.dart';
import 'event_form_screen.dart';
import 'event_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

enum MapState { loading, loaded, error }

enum LocationState { loading, loaded, error, denied }

enum RouteType { driving, walking, cycling }

class RouteInfo {
  final List<LatLng> points;
  final Duration duration;
  final double distance;
  final RouteType type;
  final Color color;
  final String title;
  final IconData icon;

  RouteInfo({
    required this.points,
    required this.duration,
    required this.distance,
    required this.type,
    required this.color,
    required this.title,
    required this.icon,
  });
}

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
  bool _showRouteCompletionCard = false;
  String _completedRouteDistance = '';
  String _completedRouteDuration = '';
  String _completedRouteType = '';

  List<Event> _events = [];
  List<Marker> _markers = [];
  List<RouteInfo> _alternativeRoutes = [];
  RouteInfo? _selectedRoute;
  Event? _selectedEvent;
  List<LatLng> _routePoints = [];
  LatLng? _currentUserLocation;
  LatLng? _selectedEventLocation;
  String _errorMessage = '';

  late AnimationController _pulseController;
  late AnimationController _routeController;
  late AnimationController _bottomSheetController;
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
    _bottomSheetController.dispose();
    super.dispose();
  }

  // Map ekranı için animasyonları başlatır
  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _routeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _bottomSheetController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  // Map ekranını başlatır ve gerekli verileri yükler
  Future<void> _initializeMap() async {
    await Future.wait([_loadEvents(), _getCurrentLocation()]);
  }

  // Kullanıcının mevcut konumunu alır ve haritayı bu konuma odaklar
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

  // Etkinlikleri yükler ve harita üzerindeki işaretçileri oluşturur
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

  // Rota süresini formatlar
  String _formatRouteDuration(Duration d) {
    if (d.inSeconds < 0) return "N/A";
    if (d.inHours > 0) {
      final hours = d.inHours;
      final minutes = d.inMinutes % 60;
      if (minutes == 0) return "$hours saat";
      return "$hours saat $minutes dakika";
    } else if (d.inMinutes > 0) {
      final minutes = d.inMinutes;
      final seconds = d.inSeconds % 60;
      if (seconds == 0 || minutes >= 10) {
        return "$minutes dakika";
      }
      return "$minutes dakika $seconds saniye";
    } else if (d.inSeconds > 0) {
      return "${d.inSeconds} saniye";
    } else {
      return "Çok kısa";
    }
  }

  // Etkinlik işaretçilerini oluşturur
  List<Marker> _buildEventMarkers(List<Event> events) {
    return events.map((event) {
      return Marker(
        width: 30.0,
        height: 30.0,
        point: LatLng(event.coordinates[1], event.coordinates[0]),
        child: GestureDetector(
          onTap: () => _showEventBottomSheet(event),
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

  // Rota üzerindeki yön okları için marker'lar oluşturur
  List<Marker> _buildRouteArrowMarkers(
    List<LatLng> routePoints,
    Color arrowColor,
  ) {
    if (routePoints.length < 2) return [];

    List<Marker> arrowMarkers = [];
    const int step = 30;

    for (int i = 0; i < routePoints.length - 1; i += step) {
      if (i + 1 < routePoints.length) {
        final startPoint = routePoints[i];
        final endPoint = routePoints[i + 1];
        final bearing = _getBearing(startPoint, endPoint);

        arrowMarkers.add(
          Marker(
            width: 25.0,
            height: 25.0,
            point: startPoint,
            rotate: true,
            child: Transform.rotate(
              angle: _degreesToRadians(bearing),
              child: Icon(
                Icons.navigation_rounded,
                size: 25,
                color: Colors.amber,
              ),
            ),
          ),
        );
      }
    }
    return arrowMarkers;
  }

  // Etkinlik alt sayfasını gösterir
  void _showEventBottomSheet(Event event) {
    setState(() {
      _selectedEvent = event;
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEventBottomSheet(event),
    ).then((_) {
      setState(() {
        _selectedEvent = null;
      });
    });
  }

  // Etkinlik tarihlerini gösteren satır
  Widget _buildDateRow({
    required IconData icon,
    required String label,
    required String date,
  }) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Colors.deepPurple),
        const SizedBox(width: 8),
        Text('$label: $date'),
      ],
    );
  }

  // Etkinlik alt sayfasını oluşturur
  Widget _buildEventBottomSheet(Event event) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                spreadRadius: 0,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withAlpha(51),
                              spreadRadius: 2,
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Etkinlik fotoğrafı
                            if (event.imageUrl.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.network(
                                      event.imageUrl,
                                      width: double.infinity,
                                      height: 200,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (
                                        context,
                                        child,
                                        loadingProgress,
                                      ) {
                                        if (loadingProgress == null)
                                          return child;
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Center(
                                                child: Text(
                                                  "Görsel yüklenemedi",
                                                ),
                                              ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 14),
                            // Başlık
                            Text(
                              event.eventTitle,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Tarih ve saat
                            _buildDateRow(
                              icon: Icons.not_started_outlined,
                              label: 'Başlangıç',
                              date: dateFormat.format(event.startDate),
                            ),
                            const SizedBox(height: 8),
                            _buildDateRow(
                              icon: Icons.not_started_outlined,
                              label: 'Bitiş',
                              date: dateFormat.format(event.endDate),
                            ),
                            const SizedBox(height: 20),
                            // Telefon numarası
                            Row(
                              children: [
                                Icon(
                                  Icons.phone,
                                  size: 22,
                                  color: Colors.deepPurple,
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap:
                                      () => {
                                        Navigator.pop(context),
                                        _launchWhatsApp(event.phone),
                                      }, // Buraya _launchWhatsApp fonksiyonunu çağırıyoruz
                                  child: Text(
                                    event.phone,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color:
                                          Colors
                                              .blue, // Telefon numarasının tıklanabilir olduğunu belirtmek için renk verilebilir
                                      // Altı çizili yapmak tıklanabilir olduğunu vurgular
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Açıklama
                            Text(
                              event.decs,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF555555),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Konum
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 22,
                                  color: Colors.deepPurple,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    event.address,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Koordinatlar
                            Row(
                              children: [
                                Icon(
                                  Icons.map,
                                  size: 22,
                                  color: Colors.deepPurple,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Lat: ${event.coordinates[1].toStringAsFixed(6)}, Lng: ${event.coordinates[0].toStringAsFixed(6)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Etkinlik türü
                            Row(
                              children: [
                                Icon(
                                  Icons.category,
                                  size: 22,
                                  color: Colors.deepPurple,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    event.category,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Etkinlik sahibi
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 22,
                                  color: Colors.deepPurple,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    event.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Aksiyon butonları
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showEventDetails(event);
                              },
                              icon: const Icon(Icons.info_outline),
                              label: const Text('Detaylar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                final eventLocation = LatLng(
                                  event.coordinates[1],
                                  event.coordinates[0],
                                );
                                _calculateAlternativeRoutes(eventLocation);
                              },
                              icon: const Icon(Icons.directions),
                              label: const Text('Rota Al'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Alternatif rotaları hesaplar ve kullanıcıya gösterir
  Future<void> _calculateAlternativeRoutes(LatLng destination) async {
    if (_currentUserLocation == null) {
      _showSnackBar('Konum bilgisi bulunamadı', isError: true);
      return;
    }

    setState(() {
      _selectedEventLocation = destination;
      _alternativeRoutes = [];
      _selectedRoute = null;
    });
    _showSnackBar('Rotalar hesaplanıyor...', duration: Duration(seconds: 2));

    try {
      final futures = [
        _calculateRoute(destination, RouteType.driving),
        _calculateRoute(destination, RouteType.walking),
        _calculateRoute(destination, RouteType.cycling),
      ];
      final results = await Future.wait(futures);
      final routes =
          results.where((route) => route != null).cast<RouteInfo>().toList();
      if (routes.isNotEmpty) {
        setState(() {
          _alternativeRoutes = routes;
          _selectedRoute = routes.first;
          _routePoints = [];
        });
        _showRouteSelectionBottomSheet();
      } else {
        _showSnackBar('Rota hesaplanamadı', isError: true);
      }
    } catch (e) {
      _showSnackBar('Rotalar hesaplanırken hata: $e', isError: true);
    }
  }

  // Kullanıcıya rota seçeneklerini gösteren alt sayfayı açar
  void _showRouteSelectionBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      elevation: 8,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Başlık
                  const Text(
                    'Rota Seçenekleri',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _alternativeRoutes.length,
                    itemBuilder: (context, index) {
                      final route = _alternativeRoutes[index];
                      final isSelected = _selectedRoute == route;
                      final hours = route.duration.inHours;
                      final minutes = route.duration.inMinutes % 60;
                      final timeText = _formatRouteDuration(route.duration);
                      final distanceText =
                          '${route.distance.toStringAsFixed(1)} km';
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedRoute = route;
                            _routePoints = _selectedRoute!.points;
                          });
                          setModalState(() {});
                          Navigator.pop(context);
                          _fitBoundsToRoute();

                          _showSnackBar('${route.title} rotası seçildi.');
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? route.color.withAlpha(25)
                                    : Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isSelected ? route.color : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // İkon
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: route.color.withAlpha(25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  route.icon,
                                  color: route.color,
                                  size: 20,
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isSelected
                                                ? route.color
                                                : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          timeText,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.straighten,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          distanceText,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Seçim göstergesi
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: route.color,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Aksiyon butonları
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Kapat',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            final routeToStart =
                                _selectedRoute ??
                                _alternativeRoutes.firstWhere(
                                  (route) =>
                                      route.type ==
                                      RouteType.driving, // Araç rotasını bul
                                  orElse:
                                      () =>
                                          _alternativeRoutes
                                              .first, // Bulamazsa ilk rotayı kullan
                                );
                            setState(() {
                              _selectedRoute = routeToStart;
                              _routePoints = _selectedRoute!.points;
                              //_currentRouteIndex = 0;
                            });
                            //_startRouteAnimation(); // Rotayı çizmeye başla
                            _fitBoundsToRoute(); // Harita sınırlarını rotaya göre ayarla

                            _showSnackBar(
                              '${_selectedRoute!.title} rotası başlatıldı',
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _selectedRoute?.color ?? Colors.teal,
                          ),
                          child: const Text(
                            'Rotayı Başlat',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Hesaplanan rotayı alır ve harita üzerinde gösterir
  Future<RouteInfo?> _calculateRoute(
    LatLng destination,
    RouteType routeType,
  ) async {
    try {
      String profile;
      Color color;
      String title;
      IconData icon;

      String osrmProfileUrlSegment;

      switch (routeType) {
        case RouteType.driving:
          profile = 'driving';
          osrmProfileUrlSegment = 'routed-car';
          color = Colors.blue;
          title = 'Araba';
          icon = Icons.directions_car;
          break;
        case RouteType.walking:
          profile = 'foot';
          osrmProfileUrlSegment = 'routed-foot';
          color = Colors.red;
          title = 'Yürüyüş';
          icon = Icons.directions_walk;
          break;
        case RouteType.cycling:
          profile = 'bike';
          osrmProfileUrlSegment = 'routed-bike';
          color = Colors.orange;
          title = 'Bisiklet';
          icon = Icons.directions_bike;
          break;
      }

      final url =
          'https://routing.openstreetmap.de/$osrmProfileUrlSegment/route/v1/driving/'
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
        final routePoints =
            coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
        return RouteInfo(
          points: routePoints,
          duration: Duration(seconds: duration.toInt()),
          distance: distance.toDouble() / 1000,
          type: routeType,
          color: color,
          title: title,
          icon: icon,
        );
      }
    } catch (e) {
      _showSnackBar('Rota hesaplanırken hata: ${e.toString()}', isError: true);
    }
    return null;
  }

  // Harita sınırlarını rotaya göre ayarlar
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

  // İki LatLng noktası arasındaki yönü (açıyı) hesaplar
  double _getBearing(LatLng startPoint, LatLng endPoint) {
    final double startLat = _degreesToRadians(startPoint.latitude);
    final double startLon = _degreesToRadians(startPoint.longitude);
    final double endLat = _degreesToRadians(endPoint.latitude);
    final double endLon = _degreesToRadians(endPoint.longitude);

    final double deltaLon = endLon - startLon;

    final double y = math.sin(deltaLon) * math.cos(endLat);
    final double x =
        math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(deltaLon);
    final double bearing = math.atan2(y, x);

    return (_radiansToDegrees(bearing) + 360) % 360;
  }

  // Dereceyi radyana çevirir
  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  // Radyanı dereceye çevirir
  double _radiansToDegrees(double radians) {
    return radians * 180 / math.pi;
  }

  // Etkinlik detaylarını gösterir
  void _showEventDetails(Event event) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (context) => EventDetailScreen(event: event)),
    );
    if (!mounted) return;

    if (result == true) {
      await _loadEvents();
    } else if (result is LatLng) {
      await _calculateAlternativeRoutes(result);
    }
  }

  // Haritayı belirtilen konuma ve yakınlaştırma seviyesine animasyonlu olarak taşır
  void _animateToLocation(LatLng location, double zoom) {
    _mapController.move(location, zoom);
  }

  // Kullanıcının konumuna odaklanır
  void _centerToUserLocation() {
    if (_currentUserLocation != null) {
      _animateToLocation(_currentUserLocation!, _detailZoom);
    } else {
      _showSnackBar('Konum bilgisi bulunamadı', isError: true);
    }
  }

  // Yakınlaştırma işlemini gerçekleştirir
  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(
      _mapController.camera.center,
      math.min(currentZoom + 1, 18.0),
    );
  }

  // Uzaklaştırma işlemini gerçekleştirir
  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(
      _mapController.camera.center,
      math.max(currentZoom - 1, 1.0),
    );
  }

  // Rotayı temizler ve ilgili durumları sıfırlar
  void _clearRoute() {
    setState(() {
      _routePoints = [];
      _selectedEventLocation = null;
      _selectedRoute = null;
      _alternativeRoutes = [];
      _showRouteCompletionCard = false;
    });
  }

  // WhatsApp'a yönlendirme fonksiyonu
  Future<void> _launchWhatsApp(String phoneNumber) async {
    String formattedPhoneNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (!formattedPhoneNumber.startsWith('+')) {
      formattedPhoneNumber = '+90$formattedPhoneNumber';
    }

    final Uri whatsappUri = Uri.parse(
      "whatsapp://send?phone=$formattedPhoneNumber",
    );

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
      } else {
        final Uri webWhatsappUri = Uri.parse(
          "https://wa.me/$formattedPhoneNumber",
        );
        if (await canLaunchUrl(webWhatsappUri)) {
          await launchUrl(webWhatsappUri, mode: LaunchMode.externalApplication);
        } else {
          _showSnackBar(
            'WhatsApp açılamadı. Cihazınızda WhatsApp yüklü olmayabilir.',
            isError: true,
          );
        }
      }
    } catch (e) {
      _showSnackBar(
        'WhatsApp başlatılırken hata oluştu: ${e.toString()}',
        isError: true,
      );
    }
  }

  // SnackBar gösterir
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

  // Haritayı başlatır ve gerekli durumları ayarlar
  Future<void> _refreshMap() async {
    _clearRoute();
    await _initializeMap();
    _showSnackBar('Harita yenilendi');
  }

  // Harita durumunu başlatır ve gerekli izinleri kontrol eder
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
          _buildRouteInfoPanel(colorScheme),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(colorScheme),
    );
  }

  // Haritayı oluşturur ve gerekli katmanları ekler
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
        if (_routePoints.isNotEmpty && _selectedRoute != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                strokeWidth: 7.0,
                color: _selectedRoute!.color,
                borderStrokeWidth: 2.0,
                borderColor: Colors.white,
                gradientColors: [
                  _selectedRoute!.color.withAlpha(204),
                  _selectedRoute!.color.withAlpha(127),
                ],
              ),
            ],
          ),
        MarkerLayer(markers: allMarkers),
        if (_routePoints.isNotEmpty && _selectedRoute != null)
          MarkerLayer(
            markers: _buildRouteArrowMarkers(
              _routePoints,
              _selectedRoute!.color,
            ),
          ),
      ],
    );
  }

  // Kullanıcı konumunu gösteren işaretçi
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

  // Yükleme ekranını gösterir
  Widget _buildLoadingOverlay() {
    if (_mapState != MapState.loading &&
        _locationState != LocationState.loading) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.black.withAlpha(153),
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

  // Rota bilgisi panelini oluşturur (rota aktifken görünür)
  Widget _buildRouteInfoPanel(ColorScheme colorScheme) {
    if (_selectedRoute == null || _routePoints.isEmpty) {
      return const SizedBox.shrink();
    }

    final timeText = _formatRouteDuration(_selectedRoute!.duration);
    final distanceText = '${_selectedRoute!.distance.toStringAsFixed(1)} km';
    final routeTitle = _selectedRoute!.title;
    final routeIcon = _selectedRoute!.icon;
    final routeColor = _selectedRoute!.color;

    return Positioned(
      top: 1,
      left: 1,
      right: 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(top: 8, left: 8, right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(16),
            top: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(51),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(routeIcon, color: routeColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 10),
                    Text(
                      routeTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,

                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$timeText (${distanceText})',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.clear_rounded,
                  color: colorScheme.onSurface.withAlpha(180),
                ),
                onPressed: _clearRoute,
                tooltip: 'Rotayı Temizle',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Kontrol butonlarını oluşturur
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

  // Kontrol butonlarını oluşturur
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

  // Konum bilgisi ile ilgili bilgileri gösterir
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

  // Hata durumunda gösterilecek widget
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

  // Etkinlik ekleme butonunu
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
      backgroundColor: Colors.teal,
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

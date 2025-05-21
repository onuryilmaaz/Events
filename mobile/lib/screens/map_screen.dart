import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; // Konum hizmeti için eklendi
import 'package:permission_handler/permission_handler.dart'; // İzinler için eklendi
import '../models/event_model.dart';
import '../services/event_service.dart';
import 'event_form_screen.dart';
import 'event_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final EventService _eventService = EventService();
  List<Marker> markers = [];
  bool isLoading = true;
  String error = '';

  // Kullanıcının konumu için değişkenler
  LatLng? _currentUserLocation;
  bool _isLoadingLocation = true;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _getCurrentLocation(); // Kullanıcı konumunu al
  }

  Future<void> _getCurrentLocation() async {
    var status = await Permission.location.request();

    if (status.isGranted) {
      try {
        setState(() {
          _isLoadingLocation = true;
        });

        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        setState(() {
          _currentUserLocation = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });

        if (markers.isEmpty) {
          _mapController.move(_currentUserLocation!, 13.0);
        }
      } catch (e) {
        setState(() {
          _isLoadingLocation = false;
          error = 'Konum alınamadı: $e';
        });
      }
    } else {
      setState(() {
        _isLoadingLocation = false;
        error = 'Konum izni verilmedi';
      });
    }
  }

  Future<void> _loadEvents() async {
    try {
      setState(() {
        isLoading = true;
        error = '';
        markers = [];
      });

      final events = await _eventService.getEvents();

      setState(() {
        markers =
            events.map((event) {
              return Marker(
                width: 80.0,
                height: 80.0,
                point: LatLng(
                  event.coordinates[1], // Enlem (latitude)
                  event.coordinates[0], // Boylam (longitude)
                ),
                child: GestureDetector(
                  onTap: () => _showEventDetails(event),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 40.0,
                  ),
                ),
              );
            }).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Etkinlikler yüklenirken hata oluştu: $e';
        isLoading = false;
      });
    }
  }

  void _showEventDetails(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EventDetailScreen(event: event)),
    ).then((value) {
      if (value == true) _loadEvents();
    });
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    final currentCenter = _mapController.camera.center;
    _mapController.move(currentCenter, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    final currentCenter = _mapController.camera.center;
    _mapController.move(currentCenter, currentZoom - 1);
  }

  void _centerToUserLocation() {
    if (_currentUserLocation != null) {
      _mapController.move(_currentUserLocation!, 15.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Marker> allMarkers = List.from(markers);

    if (_currentUserLocation != null) {
      allMarkers.add(
        Marker(
          width: 80.0,
          height: 80.0,
          point: _currentUserLocation!,
          child: const Icon(Icons.location_on, color: Colors.blue, size: 40.0),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Etkinlik Haritası'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadEvents();
              _getCurrentLocation();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Harita
          isLoading && _isLoadingLocation
              ? const Center(child: CircularProgressIndicator())
              : error.isNotEmpty
              ? Center(child: Text(error))
              : FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentUserLocation ?? LatLng(40.76, 29.93),
                  initialZoom: 10.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(markers: allMarkers),
                ],
              ),

          Positioned(
            left: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'my_location_button',
                  onPressed: _centerToUserLocation,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FloatingActionButton(
                      heroTag: 'zoom_in_button',
                      onPressed: _zoomIn,
                      child: const Icon(Icons.zoom_in),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      heroTag: 'zoom_out_button',
                      onPressed: _zoomOut,
                      child: const Icon(Icons.zoom_out),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_event_button',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EventFormScreen()),
          );

          if (result == true) _loadEvents();
        },
        tooltip: 'Etkinlik Ekle',
        child: const Icon(Icons.add),
      ),
    );
  }
}

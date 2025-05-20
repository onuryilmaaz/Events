// ignore_for_file: deprecated_member_use

// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import '../models/event_model.dart';
// import '../services/event_service.dart';
// import 'event_form_screen.dart';
// import 'event_detail_screen.dart';

// class MapScreen extends StatefulWidget {
//   const MapScreen({super.key});

//   @override
//   _MapScreenState createState() => _MapScreenState();
// }

// class _MapScreenState extends State<MapScreen> {
//   final MapController mapController = MapController();
//   final EventService _eventService = EventService();
//   List<Marker> markers = [];
//   bool isLoading = true;
//   String error = '';
//   late MapController mapController;

//   @override
//   void initState() {
//     super.initState();
//     mapController = MapController();
//     _loadEvents();
//   }

//   Future<void> _loadEvents() async {
//     try {
//       setState(() {
//         isLoading = true;
//         error = '';
//       });

//       final events = await _eventService.getEvents();

//       setState(() {
//         markers =
//             events.map((event) {
//               return Marker(
//                 width: 80.0,
//                 height: 80.0,
//                 point: LatLng(
//                   event.coordinates[1], // Enlem (latitude)
//                   event.coordinates[0], // Boylam (longitude)
//                 ),
//                 child: GestureDetector(
//                   onTap: () => _showEventDetails(event),
//                   child: Icon(Icons.location_on, color: Colors.red, size: 40.0),
//                 ),
//               );
//             }).toList();
//         isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         error = 'Etkinlikler yüklenirken hata oluştu: $e';
//         isLoading = false;
//       });
//     }
//   }

//   void _showEventDetails(Event event) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => EventDetailScreen(event: event)),
//     ).then((value) {
//       if (value == true) _loadEvents();
//     });
//   }

//   void _zoomIn() {
//     mapController.move(
//       mapController.camera.center,
//       mapController.camera.zoom + 1,
//     );
//   }

//   void _zoomOut() {
//     mapController.move(
//       mapController.camera.center,
//       mapController.camera.zoom - 1,
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Etkinlik Haritası'),
//         actions: [
//           IconButton(icon: const Icon(Icons.refresh), onPressed: _loadEvents),
//         ],
//       ),
//       body: Stack(
//         children: [
//           // Harita
//           isLoading
//               ? const Center(child: CircularProgressIndicator())
//               : error.isNotEmpty
//               ? Center(child: Text(error))
//               : FlutterMap(
//                 options: MapOptions(center: LatLng(40.76, 29.93), zoom: 10.0),
//                 children: [
//                   TileLayer(
//                     urlTemplate:
//                         'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
//                     userAgentPackageName: 'com.example.app',
//                   ),
//                   MarkerLayer(markers: markers),
//                 ],
//               ),

//           // Yakınlaştırma/Uzaklaştırma Düğmeleri
//           Positioned(
//             left: 16,
//             bottom: 42,
//             child: Row(
//               children: [
//                 FloatingActionButton(
//                   heroTag: 'zoom_in',
//                   mini: false,
//                   onPressed: _zoomIn,
//                   child: const Icon(Icons.zoom_in, size: 30),
//                 ),
//                 SizedBox(width: 8),
//                 const SizedBox(height: 8),
//                 FloatingActionButton(
//                   heroTag: 'zoom_out',
//                   mini: false,
//                   onPressed: _zoomOut,
//                   child: const Icon(Icons.zoom_out, size: 30),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () async {
//           final result = await Navigator.push(
//             context,
//             MaterialPageRoute(builder: (context) => const EventFormScreen()),
//           );

//           if (result == true) _loadEvents();
//         },
//         tooltip: 'Etkinlik Ekle',
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  // ✅ Sadece bir kez tanımlanmalı
  final MapController mapController = MapController();
  final EventService _eventService = EventService();
  List<Marker> markers = [];
  bool isLoading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    _loadEvents();
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
                  child: Icon(Icons.location_on, color: Colors.red, size: 40.0),
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
    mapController.move(
      mapController.camera.center,
      mapController.camera.zoom + 1,
    );
  }

  void _zoomOut() {
    mapController.move(
      mapController.camera.center,
      mapController.camera.zoom - 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Etkinlik Haritası'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadEvents),
        ],
      ),
      body: Stack(
        children: [
          // Harita
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : error.isNotEmpty
              ? Center(child: Text(error))
              : FlutterMap(
                options: MapOptions(center: LatLng(40.76, 29.93), zoom: 10.0),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),

          // Yakınlaştırma/Uzaklaştırma Düğmeleri
          Positioned(
            left: 16,
            bottom: 16,
            child: Row(
              children: [
                FloatingActionButton(
                  heroTag: 'zoom_in_button', // ✅ Benzersiz heroTag
                  onPressed: _zoomIn,
                  child: const Icon(Icons.zoom_in),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  heroTag: 'zoom_out_button', // ✅ Benzersiz heroTag
                  onPressed: _zoomOut,
                  child: const Icon(Icons.zoom_out),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_event_button', // ✅ Ana FAB da farklı bir heroTag
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

// // lib/screens/event_form/widgets/event_location_picker.dart

// import 'package:flutter/material.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:flutter_map/flutter_map.dart';

// class EventLocationPicker extends StatelessWidget {
//   final LatLng selectedLocation;
//   final void Function(LatLng) onLocationSelected;

//   const EventLocationPicker({
//     super.key,
//     required this.selectedLocation,
//     required this.onLocationSelected,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           'Haritaya tıklayarak etkinlik konumunu seçin:',
//           style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
//         ),
//         const SizedBox(height: 12),
//         Container(
//           height: 300,
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(12),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.1),
//                 blurRadius: 8,
//                 offset: const Offset(0, 2),
//               ),
//             ],
//           ),
//           child: Stack(
//             children: [
//               FlutterMap(
//                 options: MapOptions(
//                   initialCenter: selectedLocation,
//                   initialZoom: 13.0,
//                   onTap: (_, latLng) => onLocationSelected(latLng),
//                 ),
//                 children: [
//                   TileLayer(
//                     urlTemplate:
//                         'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
//                     userAgentPackageName: 'com.example.app',
//                     maxZoom: 19,
//                   ),
//                   MarkerLayer(
//                     markers: [
//                       Marker(
//                         width: 80.0,
//                         height: 80.0,
//                         point: selectedLocation,
//                         child: const Icon(
//                           Icons.location_on,
//                           color: Color(0xFFEF4444),
//                           size: 40.0,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//               Positioned(
//                 top: 16,
//                 right: 16,
//                 child: Column(
//                   children: [
//                     GestureDetector(
//                       onTap: () {
//                         final zoom = MapController().camera.zoom + 1;
//                         MapController().move(
//                           MapController().camera.center,
//                           zoom,
//                         );
//                       },
//                       child: Container(
//                         padding: const EdgeInsets.all(10),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: const Icon(Icons.add, color: Colors.grey),
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     GestureDetector(
//                       onTap: () {
//                         final zoom = MapController().camera.zoom - 1;
//                         MapController().move(
//                           MapController().camera.center,
//                           zoom,
//                         );
//                       },
//                       child: Container(
//                         padding: const EdgeInsets.all(10),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: const Icon(Icons.remove, color: Colors.grey),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 12),
//         Container(
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: Color(0xFFF3F4F6),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Row(
//             children: [
//               const Icon(Icons.my_location, color: Color(0xFF6366F1), size: 20),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   'Seçilen Konum: ${selectedLocation.latitude.toStringAsFixed(6)}, ${selectedLocation.longitude.toStringAsFixed(6)}',
//                   style: const TextStyle(
//                     color: Color(0xFF374151),
//                     fontSize: 12,
//                     fontFamily: 'monospace',
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }

// lib/screens/event_form/widgets/event_location_picker.dart

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

class EventLocationPicker extends StatefulWidget {
  final LatLng selectedLocation;
  final void Function(LatLng) onLocationSelected;
  final MapController mapController;

  const EventLocationPicker({
    super.key,
    required this.selectedLocation,
    required this.onLocationSelected,
    required this.mapController,
  });

  @override
  State<EventLocationPicker> createState() => _EventLocationPickerState();
}

class _EventLocationPickerState extends State<EventLocationPicker> {
  late MapController _mapController;
  //bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _mapController = widget.mapController;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Haritaya tıklayarak etkinlik konumunu seçin:',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
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
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: widget.selectedLocation,
                  initialZoom: 13.0,
                  onTap: (_, latLng) => widget.onLocationSelected(latLng),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                    maxZoom: 19,
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: widget.selectedLocation,
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
              Positioned(
                top: 16,
                right: 16,
                child: Column(
                  children: [
                    //Zoom Controls
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
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
                                          _mapController.camera.zoom;
                                      _mapController.move(
                                        _mapController.camera.center,
                                        currentZoom + 1,
                                      );
                                    },
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      topRight: Radius.circular(8),
                                    ),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Color(0xFFE5E7EB),
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
                                          _mapController.camera.zoom;
                                      _mapController.move(
                                        _mapController.camera.center,
                                        currentZoom - 1,
                                      );
                                    },
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(8),
                                      bottomRight: Radius.circular(8),
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
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.my_location, color: Color(0xFF6366F1), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Seçilen Konum: ${widget.selectedLocation.latitude.toStringAsFixed(6)}, ${widget.selectedLocation.longitude.toStringAsFixed(6)}',
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
    );
  }
}

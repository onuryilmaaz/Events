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
  bool _isUploading =
      false; // Resim yükleme durumunu kontrol etmek için yeni değişken
  String _uploadStatus = ''; // Yükleme durumunu göstermek için metin
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.event == null ? 'Etkinlik Ekle' : 'Etkinlik Düzenle',
        ),
      ),
      body: Stack(
        children: [
          // Ana form içeriği
          _isLoading && !_isUploading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Etkinlik Başlığı',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Lütfen etkinlik başlığını girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Açıklama',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Lütfen açıklama girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _categoryController,
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Lütfen kategori girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: Text(
                          'Başlangıç Tarihi: ${dateFormat.format(_startDate)}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () => _selectStartDate(context),
                        tileColor: Colors.grey[200],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        title: Text(
                          'Bitiş Tarihi: ${dateFormat.format(_endDate)}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () => _selectEndDate(context),
                        tileColor: Colors.grey[200],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'İletişim Bilgileri',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'İsim',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Lütfen isim girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Telefon',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Lütfen telefon numarası girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Adres',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Lütfen adres girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Etkinlik Resmi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_imageUrl.isNotEmpty && _imageFile == null)
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Text('Resim yüklenemedi'),
                                );
                              },
                            ),
                          ),
                        )
                      else if (_imageFile != null)
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
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
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(child: Text('Resim seçilmedi')),
                        ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image),
                        label: const Text("Resim Seç"),
                      ),
                      const SizedBox(height: 16),
                      const Text('Konum Seçin (Haritaya Tıklayın):'),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 300,
                        child: FlutterMap(
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
                                    color: Colors.red,
                                    size: 40.0,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Seçilen Konum: ${_selectedLocation.latitude}, ${_selectedLocation.longitude}',
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveEvent,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              widget.event == null
                                  ? 'Etkinlik Ekle'
                                  : 'Etkinliği Güncelle',
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
              color: Colors.black.withOpacity(0.5),
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        _uploadStatus,
                        style: const TextStyle(fontSize: 16),
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

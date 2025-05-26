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
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
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
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Lütfen telefon numarası girin';
                              }
                              return null;
                            },
                          ),
                          _buildTextField(
                            controller: _addressController,
                            label: 'Adres',
                            prefixIcon: Icons.location_on,
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

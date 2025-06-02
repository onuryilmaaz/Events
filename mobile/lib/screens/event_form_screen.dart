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
import 'package:http/http.dart' as http;
import 'package:flutter_debouncer/flutter_debouncer.dart';
import 'dart:convert';

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
  //
  final Debouncer _debouncer = Debouncer();
  List<dynamic> _addressSuggestions = [];
  bool _isSearchingAddress = false;
  String nominatimBaseUrl =
      'https://nominatim.openstreetmap.org/search?format=json&limit=5&addressdetails=1';
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
  // String baseUrl = 'http://10.210.210.119:9090/api/Events';

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController = TextEditingController(text: widget.event!.eventTitle);
      _descController = TextEditingController(text: widget.event!.decs);
      _categoryController = TextEditingController(text: widget.event!.category);
      _nameController = TextEditingController(text: widget.event!.name);
      _addressController = TextEditingController(text: widget.event!.address);
      _addressController.addListener(_onAddressChanged); // Yeni eklendi
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

  // Adres alanı her değiştiğinde çağrılır
  void _onAddressChanged() {
    if (_addressController.text.isEmpty) {
      setState(() {
        _addressSuggestions = [];
        _isSearchingAddress = false;
      });
      return;
    }
    _debouncer.debounce(
      const Duration(milliseconds: 500), // Gecikme süresini buraya ekleyin
      () {
        _searchAddress(_addressController.text);
      },
    );
  }

  // Başlangıç tarihi ve saat seçici için fonksiyon
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

  // Bitiş tarihi ve saat seçici için fonksiyon
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

  // Resim seçici için fonksiyon
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

  // Etkinlik bilgilerini kaydetme fonksiyonu
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

  // Nominatim API ile adres arama
  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) {
      setState(() {
        _addressSuggestions = [];
        _isSearchingAddress = false;
      });
      return;
    }

    setState(() {
      _isSearchingAddress = true;
    });

    try {
      final url = Uri.parse(
        '$nominatimBaseUrl&q=${Uri.encodeComponent(query)}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _addressSuggestions = data;
        });
      } else {
        setState(() {
          _addressSuggestions = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Adres arama hatası: ${response.statusCode}')),
        );
      }
    } catch (e) {
      setState(() {
        _addressSuggestions = [];
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Adres arama başarısız: $e')));
    } finally {
      setState(() {
        _isSearchingAddress = false;
      });
    }
  }

  // Koordinatlardan adres bilgilerini alır (Nominatim Reverse Geocoding)
  Future<void> _getAddressFromCoordinates(LatLng latLng) async {
    setState(() {
      _isSearchingAddress = true; // Yükleme göstergesi
    });

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${latLng.latitude}&lon=${latLng.longitude}&zoom=18&addressdetails=1',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['display_name'] != null) {
          setState(() {
            _addressController.text = data['display_name'];
          });
        } else {
          setState(() {
            _addressController.text = 'Adres bulunamadı.';
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Adres çözme hatası: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Adres çözme başarısız: $e')));
    } finally {
      setState(() {
        _isSearchingAddress = false; // Yükleme göstergesini kapat
      });
    }
  }

  // Bölüm başlıkları ve içerikleri için genel yapı
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

  // Metin alanları için genel yapı
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

  // Tarih seçici için genel yapı
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

  // Genel yapı için bir metot
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
                          // Adres önerilerini göstermek için yeni kısım
                          if (_isSearchingAddress)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child:
                                  LinearProgressIndicator(), // Yükleniyor göstergesi
                            ),
                          if (_addressSuggestions.isNotEmpty &&
                              !_isSearchingAddress &&
                              _addressController.text.isNotEmpty)
                            Container(
                              constraints: BoxConstraints(
                                maxHeight: 200,
                              ), // Max yükseklik sınırı
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                physics:
                                    ClampingScrollPhysics(), // Kaydırma davranışını düzeltir
                                itemCount: _addressSuggestions.length,
                                itemBuilder: (context, index) {
                                  final suggestion = _addressSuggestions[index];
                                  final displayName =
                                      suggestion['display_name'];
                                  return ListTile(
                                    title: Text(displayName),
                                    leading: Icon(Icons.location_on_outlined),
                                    onTap: () {
                                      final lat = double.parse(
                                        suggestion['lat'],
                                      );
                                      final lon = double.parse(
                                        suggestion['lon'],
                                      );
                                      setState(() {
                                        _addressController.text =
                                            displayName; // Adres alanını güncelle
                                        _selectedLocation = LatLng(
                                          lat,
                                          lon,
                                        ); // Harita konumunu güncelle
                                        _addressSuggestions =
                                            []; // Önerileri temizle
                                      });
                                      _mapController.move(
                                        _selectedLocation,
                                        _mapController.camera.zoom,
                                      ); // Haritayı yeni konuma taşı
                                    },
                                  );
                                },
                              ),
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
                                      onTap: (tapPosition, latLng) async {
                                        // async ekledik
                                        setState(() {
                                          _selectedLocation = latLng;
                                          _addressSuggestions =
                                              []; // Önerileri temizle
                                        });
                                        // Tıklanan koordinatlardan adres al
                                        await _getAddressFromCoordinates(
                                          latLng,
                                        ); // Yeni çağrı
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

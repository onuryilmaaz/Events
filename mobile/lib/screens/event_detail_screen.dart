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

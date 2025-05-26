// lib/screens/event_form/widgets/save_button.dart

import 'package:flutter/material.dart';

class SaveButton extends StatelessWidget {
  final bool isEditing;
  final VoidCallback onSave;

  const SaveButton({super.key, required this.isEditing, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          isEditing ? '🔄 Etkinliği Güncelle' : '✨ Etkinlik Ekle',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

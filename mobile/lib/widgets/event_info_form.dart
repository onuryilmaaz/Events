// lib/screens/event_form/widgets/event_info_form.dart

import 'package:flutter/material.dart';

Widget buildEventInfoForm({
  required TextEditingController titleController,
  required TextEditingController descController,
  required TextEditingController categoryController,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildTextField(
        controller: titleController,
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
        controller: descController,
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
        controller: categoryController,
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

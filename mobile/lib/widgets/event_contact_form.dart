// lib/screens/event_form/widgets/event_contact_form.dart

import 'package:flutter/material.dart';

Widget buildContactForm({
  required TextEditingController nameController,
  required TextEditingController phoneController,
  required TextEditingController addressController,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildTextField(
        controller: nameController,
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
        controller: phoneController,
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
        controller: addressController,
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

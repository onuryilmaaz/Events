// lib/screens/event_form/widgets/event_app_bar.dart

import 'package:flutter/material.dart';

AppBar buildEventAppBar({required bool isEditing}) {
  return AppBar(
    elevation: 0,
    backgroundColor: Colors.white,
    foregroundColor: const Color(0xFF1A1A1A),
    title: Text(
      isEditing ? 'Etkinlik Düzenle' : 'Etkinlik Ekle',
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
    ),
    centerTitle: true,
  );
}

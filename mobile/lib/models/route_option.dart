import 'package:flutter/material.dart';

class RouteOption {
  final String title;
  final Duration duration;
  final double distance; // km cinsinden
  final Color color;

  RouteOption({
    required this.title,
    required this.duration,
    required this.distance,
    required this.color,
  });
}

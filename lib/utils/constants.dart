import 'package:flutter/material.dart';

/// Common app colors
class AppColors {
  static const primary = Color(0xFF6C63FF);
  static const secondary = Color(0xFF4ECDC4);
  static const error = Color(0xFFFF6B6B);
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFE66D);
  
  static const background = Color(0xFF1A1A2E);
  static const surface = Color(0xFF16213E);
  static const card = Color(0xFF0F3460);
}

/// Common spacing values
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Common border radius values
class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// Animation durations
class AppDurations {
  static const fast = Duration(milliseconds: 200);
  static const normal = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 500);
}

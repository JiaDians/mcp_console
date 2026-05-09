import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadii {
  AppRadii._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

class AppBreakpoints {
  AppBreakpoints._();

  static const double compact = 720;
  static const double wide = 1024;
}

class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
}

class AppSemanticColors {
  AppSemanticColors._();

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
}

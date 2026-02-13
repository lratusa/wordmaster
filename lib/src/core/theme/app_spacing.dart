import 'package:flutter/material.dart';

/// Consistent spacing constants used throughout the app
class AppSpacing {
  AppSpacing._();

  // Base spacing values
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;

  // Card padding
  static const double cardPadding = 16.0;
  static const double cardPaddingLarge = 24.0;

  // Screen padding
  static const EdgeInsets screenPadding = EdgeInsets.all(md);

  // Section spacing
  static const double sectionGap = 20.0;

  // Button height
  static const double buttonHeight = 48.0;
  static const double buttonHeightLarge = 52.0;

  // Common EdgeInsets
  static const EdgeInsets cardInsets = EdgeInsets.all(cardPadding);
  static const EdgeInsets cardInsetsLarge = EdgeInsets.all(cardPaddingLarge);
}

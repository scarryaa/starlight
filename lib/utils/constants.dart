import 'package:flutter/services.dart';

const MethodChannel platformChannel =
    MethodChannel('io.scarryaa.starlight.file_manager');

const Color primaryColor = Color(0xFF007AFF);
const Color textColor = Color(0xFF4A4A4A);
const Color backgroundColor = Color(0xFFF5F5F7);

class CodeEditorConstants {
  static const double lineHeight = 24.0;
  static double charWidth = 8.0;
  static const double scrollbarWidth = 10.0;
  static const double clickDistanceThreshold = 10.0; // pixels
}

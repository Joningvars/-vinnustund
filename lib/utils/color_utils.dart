import 'package:flutter/material.dart';

// Utility functions for color manipulation
class ColorUtils {
  // Convert a color to a hex string
  static String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  // Convert a hex string to a color
  static Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  // Get a contrasting text color (black or white) based on background color
  static Color getContrastingTextColor(Color backgroundColor) {
    // Calculate luminance (perceived brightness)
    final double luminance =
        (0.299 * backgroundColor.red +
            0.587 * backgroundColor.green +
            0.114 * backgroundColor.blue) /
        255;

    // Return white for dark backgrounds, black for light backgrounds
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

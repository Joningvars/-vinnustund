import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timagatt/utils/theme/darkmode.dart';

const primaryBlue = Color(0xFF2196F3);
const timerGreen = Color(0xFF4CAF50);

final lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: primaryBlue,
    secondary: Colors.black87,
    surface: Colors.white,
    onSurface: Colors.black87,
    onPrimary: Colors.white,
    tertiary: timerGreen,
  ),
  scaffoldBackgroundColor: Colors.grey.shade100,
  textTheme: GoogleFonts.comfortaaTextTheme(),
  cardTheme: CardTheme(
    elevation: 0,
    color: Colors.white,
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  appBarTheme: const AppBarTheme(
    centerTitle: false,
    elevation: 0,
    backgroundColor: Colors.transparent,
    titleTextStyle: TextStyle(
      color: Colors.black,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: primaryBlue,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.grey.shade50,
    hintStyle: TextStyle(color: Colors.grey.shade500),
    labelStyle: TextStyle(color: Colors.grey.shade700),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.blue),
    ),
  ),
  dividerTheme: DividerThemeData(thickness: 0.5, color: Colors.grey.shade300),
  datePickerTheme: DatePickerThemeData(
    backgroundColor: Colors.white,
    headerBackgroundColor: primaryBlue,
    headerForegroundColor: Colors.white,
    rangeSelectionOverlayColor: MaterialStateProperty.all(
      Colors.grey.withOpacity(0.2),
    ),
  ),
);

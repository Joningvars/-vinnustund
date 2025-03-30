import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Define colors based on the image
final primaryBlue = Color.fromARGB(
  255,
  54,
  130,
  243,
); // Bright blue for buttons and accents
final darkBackground = Color(0xFF1E1E1E); // Very dark background
final cardBackground = Color(0xFF2D2D2D); // Slightly lighter for cards
final inputBackground = Color(0xFF2A2A2A); // For input fields
final timerGreen = Color(0xFF28A745); // Clean green for timer button

final darkTheme = ThemeData.dark().copyWith(
  colorScheme: ColorScheme.dark(
    primary: primaryBlue,
    secondary: Colors.white.withOpacity(0.7),
    surface: cardBackground,
    onSurface: Colors.white,
    onPrimary: Colors.white,
    tertiary: timerGreen,
  ),
  scaffoldBackgroundColor: darkBackground,
  textTheme: GoogleFonts.comfortaaTextTheme(
    ThemeData.dark().textTheme,
  ).apply(bodyColor: Colors.white, displayColor: Colors.white),
  appBarTheme: AppBarTheme(
    centerTitle: false,
    elevation: 0,
    backgroundColor: Colors.transparent,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
  ),
  cardTheme: CardTheme(
    elevation: 0,
    color: cardBackground,
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: inputBackground,
    hintStyle: TextStyle(color: Colors.grey.shade400),
    labelStyle: TextStyle(color: Colors.grey.shade300),
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey.shade800),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey.shade800),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: primaryBlue),
    ),
  ),
  textSelectionTheme: TextSelectionThemeData(
    cursorColor: Colors.white,
    selectionColor: primaryBlue.withOpacity(0.3),
    selectionHandleColor: primaryBlue,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    ),
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith<Color>((states) {
      if (states.contains(WidgetState.selected)) {
        return primaryBlue;
      }
      return Colors.grey.shade700;
    }),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  ),
  dividerTheme: DividerThemeData(thickness: 0.5, color: Colors.grey.shade800),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: cardBackground,
    selectedItemColor: primaryBlue,
    unselectedItemColor: Colors.grey.shade500,
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: primaryBlue),
  ),
  iconTheme: IconThemeData(color: Colors.white),
  dropdownMenuTheme: DropdownMenuThemeData(
    menuStyle: MenuStyle(
      backgroundColor: MaterialStateProperty.all(darkBackground),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      padding: MaterialStateProperty.all(
        const EdgeInsets.symmetric(vertical: 8),
      ),
    ),
    textStyle: const TextStyle(color: Colors.white),
  ),
  datePickerTheme: DatePickerThemeData(
    backgroundColor: const Color(0xFF1E1E1E),
    headerBackgroundColor: Colors.blue,
    headerForegroundColor: Colors.white,
    dayStyle: const TextStyle(color: Colors.white),
    yearStyle: const TextStyle(color: Colors.white),
    todayBackgroundColor: MaterialStateProperty.all(
      Colors.blue.withOpacity(0.2),
    ),
    todayForegroundColor: MaterialStateProperty.all(Colors.white),
  ),
);

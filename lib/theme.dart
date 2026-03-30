import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const bg       = Color(0xFF07071A);
  static const surface  = Color(0xFF10102A);
  static const card     = Color(0xFF141430);
  static const accent   = Color(0xFF7C6AF7);
  static const accent2  = Color(0xFFF7C26A);
  static const danger   = Color(0xFFFF5F6D);
  static const success  = Color(0xFF43E97B);
  static const muted    = Color(0xFF7070A0);
  static const border   = Color(0x18FFFFFF);

  static const accentGlow  = Color(0x407C6AF7);
  static const successGlow = Color(0x4043E97B);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      surface: surface,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      const TextTheme(
        bodyMedium: TextStyle(color: Colors.white),
      ),
    ).apply(bodyColor: Colors.white, displayColor: Colors.white),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 4,
        color: Colors.white,
      ),
    ),
  );

  // Gradient backgrounds
  static const bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D0B2E), Color(0xFF07071A), Color(0xFF0A1020)],
    stops: [0.0, 0.5, 1.0],
  );

  static LinearGradient accentGradient = LinearGradient(
    colors: [accent, Color(0xFF9B6AF7)],
  );
}

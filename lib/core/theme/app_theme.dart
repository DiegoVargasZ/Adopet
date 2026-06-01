// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const Color primary   = Color(0xFFF2994A); // Naranja
  static const Color accent    = Color(0xFF6FCF97); // Verde
  static const Color secondary = accent;

  static const Color bg       = Color(0xFFFFFFFF); // Blanco
  static const Color surface  = Color(0xFFF2EDE4); // Beige
  static const Color border   = Color(0xFFD0C9C0); // Beige oscuro
  static const Color textMain = Color(0xFF111111);
  static const Color textSub  = Color(0xFF828282); // Gris

  static final ThemeData light = ThemeData(
    useMaterial3: true,

    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
    ).copyWith(
      primary:   primary,
      secondary: accent,
      surface:   bg,
    ),

    scaffoldBackgroundColor: bg,

    // ── AppBar ────────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      foregroundColor: textMain,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: textMain,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: textMain, size: 22),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),

    // ── Botón primario — oscuro, plano ────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    ),

    // ── Botón outlined — borde fino ───────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textMain,
        minimumSize: const Size(double.infinity, 50),
        side: const BorderSide(color: border, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),

    // ── TextButton ────────────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: textMain,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),

    // ── Inputs — borde fino, sin fondo gris ───────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: textSub, fontSize: 14),
      labelStyle: const TextStyle(color: textSub, fontSize: 14),
    ),

    // ── Divisores ─────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: border,
      space: 1,
      thickness: 1,
    ),

    // ── Cards — sin sombra, borde sutil ───────────────────────
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: border),
      ),
      margin: EdgeInsets.zero,
    ),

    // ── Snackbar ──────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      backgroundColor: primary,
      contentTextStyle:
          const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
    ),

    // ── ListTile ──────────────────────────────────────────────
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 20),
      minLeadingWidth: 24,
    ),

    // ── TabBar ────────────────────────────────────────────────
    tabBarTheme: const TabBarThemeData(
      labelColor: primary,
      unselectedLabelColor: textSub,
      indicatorColor: primary,
      dividerColor: border,
      labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 14),
    ),

    // ── Chip ──────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      labelStyle: const TextStyle(color: textMain, fontSize: 13),
      side: const BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
  );
}

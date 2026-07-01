/// lib/core/theme/app_theme.dart
///
/// Dark theme exactly matching the WaziBot web dashboard:
///   Background  #0B0D0B  (near-black, green-tinted)
///   Cards       #111911
///   Primary     #25D366  (WaziBot signature WhatsApp-green)
///   Borders     #1E2D1E
library;

import 'package:flutter/material.dart';

class WaziBotColors {
  WaziBotColors._();

  // ── Brand — matches web dashboard exactly ─────────────────────────────────
  static const Color primary = Color(0xFF25D366);      // WaziBot green
  static const Color primaryDark = Color(0xFF1DAB52);
  static const Color primaryLight = Color(0xFF4FDE84);
  static const Color onPrimary = Colors.black;

  // ── Dark surface system (web dashboard exact) ─────────────────────────────
  static const Color darkBg = Color(0xFF0B0D0B);       // near-black
  static const Color darkSurface = Color(0xFF111911);  // card surface
  static const Color darkCard = Color(0xFF161E16);     // elevated card
  static const Color darkBorder = Color(0xFF1E2D1E);   // subtle border
  static const Color darkDivider = Color(0xFF243024);

  // ── Light surfaces ────────────────────────────────────────────────────────
  static const Color lightBg = Color(0xFFF2F5F2);
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2EAE2);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF25D366);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Text hierarchy (dark) ─────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFE8F5E9);
  static const Color textSecondary = Color(0xFF9CB09C);
  static const Color textMuted = Color(0xFF5E7A5E);

  // ── Chart palette ─────────────────────────────────────────────────────────
  static const List<Color> chartPalette = [
    Color(0xFF25D366),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
  ];
}

class AppTheme {
  AppTheme._();

  // ── DARK (default — matches web dashboard) ────────────────────────────────
  static ThemeData darkTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: WaziBotColors.primary,
      onPrimary: WaziBotColors.onPrimary,
      primaryContainer: Color(0xFF0A2E18),
      onPrimaryContainer: WaziBotColors.primaryLight,
      secondary: Color(0xFF3B82F6),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF0F2340),
      onSecondaryContainer: Color(0xFF93C5FD),
      tertiary: Color(0xFFF59E0B),
      onTertiary: Colors.black,
      tertiaryContainer: Color(0xFF2E1E00),
      onTertiaryContainer: Color(0xFFFCD34D),
      error: WaziBotColors.error,
      onError: Colors.white,
      errorContainer: Color(0xFF3B0808),
      onErrorContainer: Color(0xFFFCA5A5),
      surface: WaziBotColors.darkSurface,
      onSurface: WaziBotColors.textPrimary,
      surfaceContainerHighest: WaziBotColors.darkCard,
      onSurfaceVariant: WaziBotColors.textSecondary,
      outline: WaziBotColors.darkBorder,
      outlineVariant: WaziBotColors.darkDivider,
      shadow: Colors.black,
      scrim: Colors.black87,
      inverseSurface: Color(0xFFE8F5E9),
      onInverseSurface: Color(0xFF0B0D0B),
      inversePrimary: WaziBotColors.primaryDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: WaziBotColors.darkBg,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: WaziBotColors.darkSurface,
        foregroundColor: WaziBotColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: WaziBotColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: WaziBotColors.textSecondary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: WaziBotColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: WaziBotColors.primary.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
                color: WaziBotColors.primary, size: 22);
          }
          return const IconThemeData(
              color: WaziBotColors.textMuted, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: WaziBotColors.primary);
          }
          return const TextStyle(
              fontSize: 11, color: WaziBotColors.textMuted);
        }),
      ),
      cardTheme: CardThemeData(
        color: WaziBotColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(
              color: WaziBotColors.darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: WaziBotColors.darkDivider,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WaziBotColors.darkCard,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: WaziBotColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: WaziBotColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
              color: WaziBotColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: WaziBotColors.error),
        ),
        labelStyle:
            const TextStyle(color: WaziBotColors.textSecondary),
        hintStyle:
            const TextStyle(color: WaziBotColors.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WaziBotColors.primary,
          foregroundColor: Colors.black,
          elevation: 0,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WaziBotColors.primary,
          side: const BorderSide(color: WaziBotColors.primary),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: WaziBotColors.primary,
          textStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: WaziBotColors.darkCard,
        selectedColor:
            WaziBotColors.primary.withValues(alpha: 0.2),
        labelStyle: const TextStyle(fontSize: 12),
        side: const BorderSide(color: WaziBotColors.darkBorder),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: WaziBotColors.darkCard,
        contentTextStyle: const TextStyle(
            color: WaziBotColors.textPrimary),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: WaziBotColors.primary,
        unselectedLabelColor: WaziBotColors.textMuted,
        indicatorColor: WaziBotColors.primary,
        dividerColor: WaziBotColors.darkBorder,
        labelStyle: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            TextStyle(fontSize: 12),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: WaziBotColors.textPrimary),
        displayMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: WaziBotColors.textPrimary),
        displaySmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: WaziBotColors.textPrimary),
        headlineLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: WaziBotColors.textPrimary),
        headlineMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: WaziBotColors.textPrimary),
        headlineSmall: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: WaziBotColors.textPrimary),
        titleLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: WaziBotColors.textPrimary),
        titleMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: WaziBotColors.textPrimary),
        titleSmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: WaziBotColors.textPrimary),
        bodyLarge: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: WaziBotColors.textPrimary),
        bodyMedium: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: WaziBotColors.textPrimary),
        bodySmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: WaziBotColors.textSecondary),
        labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: WaziBotColors.textPrimary),
        labelMedium: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: WaziBotColors.textSecondary),
        labelSmall: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: WaziBotColors.textMuted),
      ),
    );
  }

  // ── LIGHT ─────────────────────────────────────────────────────────────────
  static ThemeData lightTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: WaziBotColors.primaryDark,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFB8F0CE),
      onPrimaryContainer: Color(0xFF003D18),
      secondary: Color(0xFF1D4ED8),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFDBEAFE),
      onSecondaryContainer: Color(0xFF1E3A5F),
      tertiary: Color(0xFFD97706),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFFEF3C7),
      onTertiaryContainer: Color(0xFF3D2900),
      error: WaziBotColors.error,
      onError: Colors.white,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF4A1010),
      surface: WaziBotColors.lightSurface,
      onSurface: Color(0xFF0D1F0D),
      surfaceContainerHighest: WaziBotColors.lightCard,
      onSurfaceVariant: Color(0xFF3D5C3D),
      outline: WaziBotColors.lightBorder,
      outlineVariant: Color(0xFFE2EAE2),
      shadow: Color(0xFF000000),
      scrim: Colors.black54,
      inverseSurface: Color(0xFF111911),
      onInverseSurface: Color(0xFFE8F5E9),
      inversePrimary: WaziBotColors.primaryLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: WaziBotColors.lightBg,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: WaziBotColors.lightSurface,
        foregroundColor: Color(0xFF0D1F0D),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0D1F0D),
        ),
      ),
      cardTheme: CardThemeData(
        color: WaziBotColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(
              color: WaziBotColors.lightBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
    );
  }
}

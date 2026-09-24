import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette et thèmes Lavpro (clair & sombre).
class AppColors {
  static const primary = Color(0xFF2563EB);
  static const cyan = Color(0xFF06B6D4);
  static const eco = Color(0xFF10B981);
  static const lime = Color(0xFF84CC16);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
  static const violet = Color(0xFF8B5CF6);
  static const pink = Color(0xFFEC4899);
  static const ink = Color(0xFF0B1220);

  static const gradient = LinearGradient(
    colors: [primary, cyan], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const ecoGradient = LinearGradient(
    colors: [eco, lime], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const warmGradient = LinearGradient(
    colors: [amber, red], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const violetGradient = LinearGradient(
    colors: [violet, pink], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const nightGradient = LinearGradient(
    colors: [Color(0xFF0B1220), Color(0xFF1E3A8A)], begin: Alignment.topLeft, end: Alignment.bottomRight);
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: b,
      primary: AppColors.primary,
      secondary: AppColors.cyan,
      tertiary: AppColors.eco,
      surface: dark ? const Color(0xFF111827) : Colors.white,
    );
    final bg = dark ? const Color(0xFF0A0F1C) : const Color(0xFFF4F7FB);
    final text = GoogleFonts.plusJakartaSansTextTheme(ThemeData(brightness: b).textTheme);
    final border = dark ? const Color(0xFF1F2A3D) : const Color(0xFFE5EAF2);
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.8),
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.5),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.3),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20, fontWeight: FontWeight.w800, color: dark ? Colors.white : AppColors.ink),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: border)),
      ),
      dividerTheme: DividerThemeData(color: border, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF0F1626) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.6)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        side: BorderSide(color: border),
        labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: AppColors.primary.withValues(alpha: .12),
        elevation: 0,
        height: 70,
        labelTextStyle: WidgetStatePropertyAll(GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }
}

extension ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get muted => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get borderColor => isDark ? const Color(0xFF1F2A3D) : const Color(0xFFE5EAF2);
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Application-wide theme configuration.
class AppTheme {
  AppTheme._();

  // ── Brand Colors ─────────────────────────────────────────────────
  static const Color primaryBlue = Color(0xFF1A73E8);
  static const Color primaryDark = Color(0xFF1557B0);
  static const Color accentCyan = Color(0xFF00BCD4);

  // ── Surface Colors ───────────────────────────────────────────────
  static const Color scaffoldBg = Color(0xFFF5F7FA);
  static const Color cardBg = Colors.white;
  static const Color surfaceGrey = Color(0xFFF0F2F5);

  // ── Text Colors ──────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1D26);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // ── Stage Colors — every stage gets its own unique pastel hue ─────
  // Well-known stages have hand-picked colours; all others are
  // auto-generated from the stage name so they are always unique.
  static const Map<String, Color> _knownStageColors = {
    'RAW (UNQUALIFIED)': Color(0xFF90A4AE), // blue-grey
    'RAW':               Color(0xFF90A4AE),
    'NEW':               Color(0xFFF48FB1), // blush pink
    'DISCUSSION':        Color(0xFF64B5F6), // sky blue
    'DEMO':              Color(0xFFCE93D8), // soft lilac
    'PROPOSAL':          Color(0xFFFFD54F), // golden amber
    'INTERNAL REVIEWS':  Color(0xFF4DB6AC), // turquoise
    'NEGOTIATION':       Color(0xFFFF8A65), // warm peach
    'WON':               Color(0xFF81C784), // mint green
    'LOST':              Color(0xFFE57373), // soft coral
  };

  /// Returns a unique pastel colour for any stage string.
  /// Hand-picked colours are used for known stages; all other stage
  /// names are hashed to a stable hue in the pastel HSL range so that
  /// every distinct name always gets a different colour.
  static Color stageColor(String stage) {
    if (stage.isEmpty) return const Color(0xFF90A4AE);

    final known = _knownStageColors[stage.toUpperCase()];
    if (known != null) return known;

    // Hash-based pastel: spread hue evenly, fix saturation + lightness
    // in the pastel sweet-spot so the result is always soft and readable.
    final hash = stage.toUpperCase().hashCode.abs();
    // Multiply prime and mod to spread hashes that differ by 1 char
    final hue = ((hash * 2654435761) % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.52, 0.68).toColor();
  }

  // Keep for backward-compat with any code that reads stageColors directly
  static Map<String, Color> get stageColors => _knownStageColors;

  // ── Theme Data ───────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
        primary: primaryBlue,
        onPrimary: Colors.white,
        surface: cardBg,
        onSurface: textPrimary,
        surfaceContainerHighest: surfaceGrey,
      ),
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(color: textPrimary),
        bodyMedium: textTheme.bodyMedium?.copyWith(color: textSecondary),
        bodySmall: textTheme.bodySmall?.copyWith(color: textTertiary),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: primaryBlue,
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceGrey,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        labelStyle: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 14,
        ),
        hintStyle: GoogleFonts.inter(
          color: textTertiary,
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceGrey,
        selectedColor: primaryBlue.withValues(alpha: 0.12),
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E7EB),
        thickness: 1,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: GoogleFonts.inter(fontSize: 14),
      ),
    );
  }
}

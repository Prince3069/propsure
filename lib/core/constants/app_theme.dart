import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── ABUJA-INSPIRED COLOR PALETTE ───────────────────────────────────────────
class AppColors {
  // ── Primary (Deep Forest Green - Abuja inspired) ──
  static const Color primary = Color(0xFF0F4C3A);
  static const Color primaryLight = Color(0xFF1B7A5A);
  static const Color primaryDark = Color(0xFF0A3327);
  static const Color primaryPale = Color(0xFFE8F5EE);
  static const Color primaryPale2 = Color(0xFFD4EBE0);

  // ── Accent (Nigerian Gold) ──
  static const Color gold = Color(0xFFD4A02B);
  static const Color goldLight = Color(0xFFF5E6B8);
  static const Color goldDark = Color(0xFFB8860B);

  // ── Surface & Background (Warm Cream) ──
  static const Color surface = Color(0xFFF8F6F0);
  static const Color bg = Color(0xFFF0EDE6);
  static const Color card = Color(0xFFFFFFFF);

  // ── Text ──
  static const Color text = Color(0xFF1A1A2E);
  static const Color text2 = Color(0xFF4A4A5A);
  static const Color text3 = Color(0xFF8A8A9A);

  // ── Status ──
  static const Color success = Color(0xFF0F8B5E);
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // ── Borders ──
  static const Color border = Color(0xFFE5E0D8);
  static const Color border2 = Color(0xFFD5D0C8);

  // ── Status Pill Colors ──
  static const Color statusRented = Color(0xFF7C3AED);
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusExpired = Color(0xFF9CA3AF);

  // ── Misc ──
  static const Color goldStar = Color(0xFFF59E0B);
}

// ─── SHADOWS ──────────────────────────────────────────────────────────────────
class AppShadows {
  static List<BoxShadow> get sm => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get md => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get lg => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 32,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get gold => [
        BoxShadow(
          color: AppColors.gold.withValues(alpha: 0.25),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

  // Card shadow (legacy compatibility)
  static List<BoxShadow> get card => sm;
}

// ─── RADIUS ───────────────────────────────────────────────────────────────────
class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double full = 99;
}

// ─── APP THEME ────────────────────────────────────────────────────────────────
// NOTE: We deliberately use ONE font family (Plus Jakarta Sans) across every
// text style, at varying weights. The old Syne+Outfit pairing made every
// screen title look like a shouty display headline — Plus Jakarta Sans reads
// clean and professional at both large and small sizes, which is what you
// want for a trust-driven property platform. Use AppFonts.display only for
// the actual wordmark/logo, never for routine screen titles.
class AppFonts {
  static TextStyle display({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w800,
    Color? color,
    double? letterSpacing,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,

      // ── Colors ──
      primaryColor: AppColors.primary,
      hintColor: AppColors.gold,
      scaffoldBackgroundColor: AppColors.bg,
      cardColor: AppColors.card,
      dividerColor: AppColors.border,

      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.gold,
        surface: AppColors.surface,
        background: AppColors.surface, // Fixed: replaced 'bg' with 'surface'
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.text,
        onBackground:
            AppColors.text, // Fixed: replaced 'onBackground' with 'onSurface'
        onError: Colors.white,
      ),

      // ── App Bar ──
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),

      // ── Buttons ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),

      // ── Input Decorations (floating label, CarPlaza-style form fields) ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.plusJakartaSans(
            color: AppColors.text3, fontSize: 13, fontWeight: FontWeight.w500),
        floatingLabelStyle: GoogleFonts.plusJakartaSans(
            color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700),
        hintStyle: GoogleFonts.plusJakartaSans(
            color: AppColors.text3, fontSize: 13),
        prefixIconColor: AppColors.primary,
        suffixIconColor: AppColors.text3,
      ),

      // ── Text (single family, Plus Jakarta Sans, weight does the work) ──
      textTheme: TextTheme(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
          letterSpacing: -0.4,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 25,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
          letterSpacing: -0.3,
        ),
        displaySmall: GoogleFonts.plusJakartaSans(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        headlineSmall: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        titleSmall: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.text,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.text2,
          height: 1.55,
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.text3,
          height: 1.45,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        labelMedium: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.text2,
        ),
        labelSmall: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.text3,
        ),
      ),

      // ── Cards ──
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),

      // ── Chips ──
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bg,
        selectedColor: AppColors.primary,
        labelStyle: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        side: const BorderSide(color: AppColors.border),
      ),

      // ── Navigation Bar ──
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      // ── Tab Bar ── (Fixed: Changed TabBarTheme to TabBarThemeData)
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.text3,
        indicatorColor: AppColors.primary,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),

      // ── Divider ──
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),

      // ── Bottom Sheet ──
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),

      // ── Dialog ── (Fixed: Changed DialogTheme to DialogThemeData)
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}

// ─── BREAKPOINTS ──────────────────────────────────────────────────────────────
class AppBreakpoints {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1024;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  static int gridCols(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1200) return 4;
    if (w >= 800) return 3;
    if (w >= 500) return 2;
    return 1;
  }
}
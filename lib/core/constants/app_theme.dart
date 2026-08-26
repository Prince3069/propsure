import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF11895A);
  static const Color primaryLight = Color(0xFF35B779);
  static const Color primaryDark = Color(0xFF075235);
  static const Color primaryPale = Color(0xFFEEF7F2);
  static const Color primaryPale2 = Color(0xFFE0F0E8);
  static const Color gold = Color(0xFFF5A623);
  static const Color goldDark = Color(0xFFD4881C);
  static const Color bg = Color(0xFFF7FBF8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFDCEBE2);
  static const Color border2 = Color(0xFFB8D5C4);
  static const Color text = Color(0xFF0D1F17);
  static const Color text2 = Color(0xFF4A6358);
  static const Color text3 = Color(0xFF8AA89A);
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
  static const Color info = Color(0xFF2563EB);
  static const Color statusActive = Color(0xFF16A34A);
  static const Color statusRented = Color(0xFF7C3AED);
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusExpired = Color(0xFF6B7280);
}

class AppBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  static bool isMobile(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width < mobile;
  static bool isTablet(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    return w >= mobile && w < desktop;
  }

  static bool isDesktop(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width >= desktop;
  static int gridCols(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    if (w >= desktop) return 3;
    if (w >= mobile) return 2;
    return 1;
  }
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double full = 999;
}

class AppShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4))
      ];
  static List<BoxShadow> get sm => [
        BoxShadow(
            color: AppColors.text.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2))
      ];
  static List<BoxShadow> get md => [
        BoxShadow(
            color: AppColors.text.withOpacity(0.09),
            blurRadius: 16,
            offset: const Offset(0, 4))
      ];
  static List<BoxShadow> get lg => [
        BoxShadow(
            color: AppColors.text.withOpacity(0.12),
            blurRadius: 32,
            offset: const Offset(0, 8))
      ];
}

class AppTheme {
  static ThemeData get light {
    return ThemeData.light(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.gold,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: _textTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: AppColors.border,
        titleTextStyle: GoogleFonts.syne(
            fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle:
              GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle:
              GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.error)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.outfit(color: AppColors.text3, fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.text,
        contentTextStyle: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.text3,
      ),
      dividerTheme: const DividerThemeData(
          color: AppColors.border, thickness: 1, space: 1),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primary),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final p = brightness == Brightness.dark ? Colors.white : AppColors.text;
    final s = brightness == Brightness.dark ? Colors.white70 : AppColors.text2;
    return TextTheme(
      displayLarge: GoogleFonts.syne(
          fontSize: 48,
          fontWeight: FontWeight.w800,
          color: p,
          letterSpacing: -1.5),
      displayMedium: GoogleFonts.syne(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: p,
          letterSpacing: -1),
      headlineLarge:
          GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w700, color: p),
      headlineMedium:
          GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w600, color: p),
      headlineSmall:
          GoogleFonts.syne(fontSize: 17, fontWeight: FontWeight.w600, color: p),
      titleLarge:
          GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w600, color: p),
      titleMedium: GoogleFonts.outfit(
          fontSize: 14, fontWeight: FontWeight.w600, color: p),
      titleSmall: GoogleFonts.outfit(
          fontSize: 13, fontWeight: FontWeight.w500, color: p),
      bodyLarge: GoogleFonts.outfit(
          fontSize: 15, fontWeight: FontWeight.w400, color: s, height: 1.6),
      bodyMedium: GoogleFonts.outfit(
          fontSize: 13, fontWeight: FontWeight.w400, color: s, height: 1.5),
      bodySmall: GoogleFonts.outfit(
          fontSize: 11, fontWeight: FontWeight.w400, color: s),
      labelLarge: GoogleFonts.outfit(
          fontSize: 13, fontWeight: FontWeight.w600, color: p),
      labelMedium: GoogleFonts.outfit(
          fontSize: 11, fontWeight: FontWeight.w500, color: s),
      labelSmall: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: s,
          letterSpacing: 0.3),
    );
  }
}

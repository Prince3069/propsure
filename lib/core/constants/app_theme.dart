import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── DESIGN TOKENS ───────────────────────────────────────────────────────────
// One palette, one type family (Plus Jakarta Sans), an 8-point spacing rhythm.
// Contrast ratios (measured, WCAG): text on ivory 15.8:1, secondary 8.1:1,
// tertiary 4.9:1, green on ivory 9.2:1, white on green 9.9:1.
class AppColors {
  // Brand
  static const Color primary = Color(0xFF0F4C3A); // forest green
  static const Color primaryLight = Color(0xFF1B6B52);
  static const Color primaryDark = Color(0xFF0A3327);
  static const Color primaryPale = Color(0xFFE4F0E9); // tinted icon circles
  static const Color primaryPale2 = Color(0xFFD6E9DE); // success pill fill
  static const Color gold = Color(0xFFD4A02B); // restrained accent
  static const Color goldLight = Color(0xFFFFF3D6);
  static const Color goldDark = Color(0xFF8A5A00); // text on gold tints

  // Surfaces
  static const Color surface = Color(0xFFF8F6F0); // warm ivory scaffold
  static const Color bg = surface;
  static const Color card = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFFEFEDE7); // neutral pill / disabled fill

  // Text
  static const Color text = Color(0xFF1A1A2E); // charcoal
  static const Color text2 = Color(0xFF4A4A58);
  static const Color text3 = Color(0xFF6B6B78);

  // Status
  static const Color success = Color(0xFF0F7A55);
  static const Color error = Color(0xFFC62828);
  static const Color errorPale = Color(0xFFFDECEC);
  static const Color warning = Color(0xFFB7791F);
  static const Color warningPale = goldLight;
  static const Color info = Color(0xFF2F5D8A);

  // Lines
  static const Color border = Color(0xFFE6E2D8); // hairline
  static const Color border2 = Color(0xFFD3CEC2);

  // Legacy status colors (kept so older call sites still compile)
  static const Color statusRented = Color(0xFF5B4BA8);
  static const Color statusPending = warning;
  static const Color statusExpired = Color(0xFF8A8A96);
  static const Color goldStar = gold;
}

class AppSpace {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24; // main gutter
  static const double x8 = 32;
  static const double x10 = 40;
  static const double gutter = 24;
  static const double tap = 48; // minimum control height (Android-friendly)
}

class AppShadows {
  static List<BoxShadow> get sm => [
        BoxShadow(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2)),
      ];
  static List<BoxShadow> get md => [
        BoxShadow(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4)),
      ];
  static List<BoxShadow> get lg => md;
  static List<BoxShadow> get gold => sm;
  static List<BoxShadow> get card => sm;
}

class AppRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 14;
  static const double lg = 18; // cards
  static const double xl = 24;
  static const double sheet = 28; // green header bottoms
  static const double full = 99;
}

/// Semantic type scale. Nothing below 12 logical pixels.
class AppText {
  static TextStyle _base(double size, FontWeight w,
          {Color color = AppColors.text, double? height, double? letter}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: w,
        color: color,
        height: height,
        letterSpacing: letter,
      );

  static TextStyle get display => _base(34, FontWeight.w800, height: 1.08, letter: -1.0);
  static TextStyle get h1 => _base(28, FontWeight.w800, height: 1.12, letter: -0.6);
  static TextStyle get h2 => _base(22, FontWeight.w800, height: 1.2, letter: -0.3);
  static TextStyle get h3 => _base(18, FontWeight.w700, height: 1.25);
  static TextStyle get title => _base(16, FontWeight.w700, height: 1.3);
  static TextStyle get body => _base(15, FontWeight.w500, color: AppColors.text, height: 1.45);
  static TextStyle get bodyMuted => _base(15, FontWeight.w500, color: AppColors.text2, height: 1.45);
  static TextStyle get small => _base(13.5, FontWeight.w500, color: AppColors.text2, height: 1.4);
  static TextStyle get caption => _base(12.5, FontWeight.w500, color: AppColors.text3, height: 1.35);
  static TextStyle get label => _base(14, FontWeight.w700);
  static TextStyle get button => _base(16, FontWeight.w700, letter: 0.1);
  static TextStyle get price => _base(26, FontWeight.w800, color: AppColors.primary, letter: -0.5);
}

/// Kept for call sites that used the old display helper.
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
    final text = GoogleFonts.plusJakartaSansTextTheme().apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    );
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      scaffoldBackgroundColor: AppColors.surface,
      primaryColor: AppColors.primary,
      dividerColor: AppColors.border,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.gold,
        onSecondary: AppColors.text,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        error: AppColors.error,
        onError: Colors.white,
      ),
      textTheme: text.copyWith(
        displayLarge: AppText.display,
        headlineLarge: AppText.h1,
        headlineMedium: AppText.h2,
        headlineSmall: AppText.h3,
        titleLarge: AppText.h3,
        titleMedium: AppText.title,
        titleSmall: AppText.label,
        bodyLarge: AppText.body,
        bodyMedium: AppText.bodyMuted,
        bodySmall: AppText.small,
        labelLarge: AppText.label,
        labelMedium: AppText.small,
        labelSmall: AppText.caption,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: AppText.title,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, AppSpace.tap + 4),
          textStyle: AppText.button,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(64, AppSpace.tap + 4),
          textStyle: AppText.button,
          side: const BorderSide(color: AppColors.primary, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(48, AppSpace.tap),
          textStyle: AppText.label,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.primary, 2),
        errorBorder: border(AppColors.error, 1.5),
        focusedErrorBorder: border(AppColors.error, 2),
        hintStyle: AppText.bodyMuted.copyWith(color: AppColors.text3),
        labelStyle: AppText.small,
        floatingLabelStyle: AppText.small.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
        prefixIconColor: AppColors.text2,
        suffixIconColor: AppColors.text2,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card,
        selectedColor: AppColors.primary,
        labelStyle: AppText.label,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.text,
        contentTextStyle: AppText.small.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : const Color(0xFFC9C5BA),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.text3,
        indicatorColor: AppColors.primary,
        labelStyle: AppText.label,
        unselectedLabelStyle: AppText.label.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── BREAKPOINTS ─────────────────────────────────────────────────────────────
class AppBreakpoints {
  static bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < 600;
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= 600 && w < 1024;
  }

  static bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= 1024;

  static int gridCols(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1200) return 4;
    if (w >= 800) return 3;
    if (w >= 500) return 2;
    return 1;
  }
}

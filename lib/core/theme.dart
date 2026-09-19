import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand palette — pulled directly from the original web app's CSS
/// (global.css / dashboard.css) so the Flutter build matches it closely.
class AppColors {
  static const Color primary = Color(0xFF667EEA); // indigo
  static const Color primaryDark = Color(0xFF764BA2); // purple
  static const Color accent = Color(0xFFFFCC00); // active-tab gold
  static const Color success = Color(0xFF27AE60);
  static const Color danger = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);
  static const Color info = Color(0xFF3498DB);

  // Header / button gradient — 90deg #667eea -> #764ba2 (global.css .bg-gradient-header, .btn-primary)
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primary, primaryDark],
  );

  // Page body gradient — 135deg #a1c4fd -> #c2e9fb (global.css body background)
  static const LinearGradient bodyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA1C4FD), Color(0xFFC2E9FB)],
  );

  // Auth card gradient — 135deg #ffffff -> #f0f4ff (auth.css .auth-card)
  static const LinearGradient authCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.white, Color(0xFFF0F4FF)],
  );

  // Action-button gradients (dashboard.css .btn-complete/cancel/reschedule/edit-action)
  static const LinearGradient completeGradient = LinearGradient(
      colors: [Color(0xFF2ECC71), Color(0xFF27AE60)]);
  static const LinearGradient cancelGradient = LinearGradient(
      colors: [Color(0xFFE74C3C), Color(0xFFC0392B)]);
  static const LinearGradient rescheduleGradient = LinearGradient(
      colors: [Color(0xFFF39C12), Color(0xFFE67E22)]);
  static const LinearGradient editGradient =
      LinearGradient(colors: [Color(0xFF3498DB), Color(0xFF2980B9)]);
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    );
    final base = _base(scheme, Colors.transparent);
    // Poppins everywhere, matching the original web app's font.
    return base.copyWith(textTheme: GoogleFonts.poppinsTextTheme(base.textTheme));
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    );
    final base = _base(scheme, const Color(0xFF121318));
    return base.copyWith(textTheme: GoogleFonts.poppinsTextTheme(base.textTheme));
  }

  static ThemeData _base(ColorScheme scheme, Color scaffold) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD1D9E6), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
      chipTheme: const ChipThemeData(showCheckmark: false),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2C3E50),
        actionTextColor: AppColors.accent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

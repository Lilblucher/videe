import 'package:flutter/material.dart';

/// Flat, dark design system: #07080a ground, no gradients, no glow except
/// the hex download-progress ring. 4px corners. Hairline row dividers.
/// One solid accent action per screen. Space Grotesk for text, JetBrains
/// Mono for meta/numbers/labels.
class AppColors {
  static const bg = Color(0xFF07080A);
  static const surface = Color(0xFF0D0E11);
  static const hairline = Color(0xFF16181C);
  static const border = Color(0xFF23262C);
  static const inputBorder = Color(0xFF26282E);

  static const accent = Color(0xFF2597E8);
  static const accentBright = Color(0xFF15A6DE);
  static const accentText = Color(0xFF7CC7F2);
  static const onAccent = Color(0xFF07080A);

  static const text = Color(0xFFF3F4F6);
  static const textTitle = Color(0xFFE9EAEC);
  static const textMuted = Color(0xFF9CA3AF);
  static const textDim = Color(0xFF6B7280);
  static const textFaint = Color(0xFF5B6068);

  static const success = Color(0xFF4EC9B0);
  static const error = Color(0xFFF44747);
  static const warning = Color(0xFFDCDCAA);

  // Back-compat aliases so existing call sites keep compiling while
  // screens are migrated one at a time to the new tokens above.
  static const primary = accent;
  static const secondary = accentBright;
  static const background = bg;
  static const card = surface;
  static const surfaceLight = surface;
  static const textPrimary = text;
  static const textSecondary = textMuted;
  static const divider = hairline;
}

class AppRadius {
  static const control = 4.0;
  static const phone = 28.0;
}

class AppText {
  static TextStyle sans({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.text,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontFamily: 'Space Grotesk',
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle mono({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textDim,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.accentBright,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.sans(
          size: 20,
          weight: FontWeight.w700,
          color: AppColors.text,
          letterSpacing: -0.02,
        ),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      textTheme: base.textTheme.apply(
        fontFamily: 'Space Grotesk',
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      iconTheme: const IconThemeData(color: AppColors.textMuted),
      dividerTheme: const DividerThemeData(color: AppColors.hairline),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintStyle: AppText.mono(size: 13, color: AppColors.textFaint),
        contentPadding: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Space Grotesk',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.accent.withValues(alpha: 0.15),
        labelStyle: AppText.sans(size: 13, color: AppColors.text),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    );
  }
}

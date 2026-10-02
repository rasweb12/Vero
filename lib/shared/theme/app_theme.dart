import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _buildTheme(
    brightness: Brightness.light,
    background: AppColors.backgroundLight,
    surface: AppColors.surfaceLight,
    outline: AppColors.borderLight,
    onSurface: AppColors.textStrong,
    onSurfaceVariant: AppColors.textSoft,
  );

  static ThemeData get dark => _buildTheme(
    brightness: Brightness.dark,
    background: AppColors.backgroundDark,
    surface: AppColors.surfaceDark,
    outline: AppColors.borderDark,
    onSurface: const Color(0xFFE5E7EB),
    onSurfaceVariant: const Color(0xFF9CA3AF),
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color outline,
    required Color onSurface,
    required Color onSurfaceVariant,
  }) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: background,
          onSurface: onSurface,
          onSurfaceVariant: onSurfaceVariant,
          outline: outline,
          error: AppColors.danger,
        );

    final textTheme = _textTheme(onSurface, onSurfaceVariant);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: background,
        foregroundColor: onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          side: BorderSide(color: outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: textTheme.labelLarge,
        ),
      ),
    );
  }

  static TextTheme _textTheme(Color strong, Color soft) {
    return TextTheme(
      headlineLarge: TextStyle(
        color: strong,
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.12,
      ),
      headlineMedium: TextStyle(
        color: strong,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.18,
      ),
      titleLarge: TextStyle(
        color: strong,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      titleMedium: TextStyle(
        color: strong,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      bodyLarge: TextStyle(
        color: strong,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        color: soft,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.45,
      ),
      labelLarge: TextStyle(
        color: strong,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      labelMedium: TextStyle(
        color: soft,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    ).apply(fontFamily: 'Inter');
  }
}

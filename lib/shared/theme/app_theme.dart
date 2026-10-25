import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.brand,
      onPrimary: AppColors.textOnBrand,
      surface: AppColors.surface,
      error: AppColors.error,
    );

    const defaultRadius = 14.0;

    const defaultShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(
        Radius.circular(defaultRadius),
      ),
    );

    const outline = OutlineInputBorder(
      borderRadius: BorderRadius.all(
        Radius.circular(defaultRadius),
      ),
      borderSide: BorderSide(
        color: AppColors.border,
      ),
    );

    return ThemeData(
      useMaterial3: true,

      colorScheme: colorScheme,

      scaffoldBackgroundColor: AppColors.background,

      visualDensity: VisualDensity.standard,

      // =====================================================
      // SCROLLBAR
      // =====================================================

      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.resolveWith<double?>(
          (states) {
            if (states.contains(WidgetState.dragged)) {
              return 5;
            }

            if (states.contains(WidgetState.hovered)) {
              return 4;
            }

            return 3;
          },
        ),

        radius: const Radius.circular(8),

        thumbColor: WidgetStateProperty.resolveWith<Color?>(
          (states) {
            if (states.contains(WidgetState.dragged)) {
              return AppColors.brand;
            }

            if (states.contains(WidgetState.hovered)) {
              return AppColors.brand.withValues(alpha: 0.75);
            }

            return AppColors.brand.withValues(alpha: 0.45);
          },
        ),

        trackColor: const WidgetStatePropertyAll<Color?>(
          Colors.transparent,
        ),

        trackBorderColor: const WidgetStatePropertyAll<Color?>(
          Colors.transparent,
        ),

        crossAxisMargin: 2,
        mainAxisMargin: 4,
        interactive: true,
      ),

      // =====================================================
      // APP BAR
      // =====================================================

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),

      // =====================================================
      // TYPOGRAPHY
      // =====================================================

      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 32,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
          color: AppColors.textPrimary,
        ),

        headlineMedium: TextStyle(
          fontSize: 26,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          color: AppColors.textPrimary,
        ),

        headlineSmall: TextStyle(
          fontSize: 22,
          height: 1.25,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
          color: AppColors.textPrimary,
        ),

        titleLarge: TextStyle(
          fontSize: 18,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),

        titleMedium: TextStyle(
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),

        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.5,
          color: AppColors.textPrimary,
        ),

        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: AppColors.textSecondary,
        ),

        bodySmall: TextStyle(
          fontSize: 12,
          height: 1.4,
          color: AppColors.textSecondary,
        ),

        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),

      // =====================================================
      // INPUT FIELDS
      // =====================================================

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),

        border: outline,
        enabledBorder: outline,

        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(defaultRadius),
          ),
          borderSide: BorderSide(
            color: AppColors.brand,
            width: 1.5,
          ),
        ),

        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(defaultRadius),
          ),
          borderSide: BorderSide(
            color: AppColors.error,
          ),
        ),

        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(defaultRadius),
          ),
          borderSide: BorderSide(
            color: AppColors.error,
            width: 1.5,
          ),
        ),

        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
        ),

        hintStyle: const TextStyle(
          color: AppColors.textSecondary,
        ),
      ),

      // =====================================================
      // FILLED BUTTONS
      // =====================================================

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          shape: defaultShape,
          backgroundColor: AppColors.brand,
          foregroundColor: AppColors.textOnBrand,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // =====================================================
      // OUTLINED BUTTONS
      // =====================================================

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          shape: defaultShape,
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(
            color: AppColors.border,
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // =====================================================
      // TEXT BUTTONS
      // =====================================================

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: AppColors.brand,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // =====================================================
      // DIVIDERS
      // =====================================================

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // =====================================================
      // NAVIGATION BAR
      // =====================================================

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.brandSoft,
        elevation: 0,
        height: 72,
        labelBehavior:
            NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // =====================================================
      // SNACKBARS
      // =====================================================

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(
          color: AppColors.textOnBrand,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      // =====================================================
      // DIALOGS
      // =====================================================

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: AppColors.textSecondary,
        ),
      ),

      // =====================================================
      // PROGRESS INDICATORS
      // =====================================================

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand,
      ),
    );
  }
}
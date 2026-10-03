import 'package:flutter/material.dart';

/// Colores del design system. `primary` cumple contraste AA (≥ 4.5:1) con
/// texto blanco; `brandOrange` es solo decorativo.
abstract final class AppColors {
  static const brandOrange = Color(0xFFF97316);
  static const primary = Color(0xFFC2410C);
  static const primaryDark = Color(0xFF9A3412);
  static const credit = Color(0xFF047857);
  static const debit = Color(0xFFB91C1C);
  static const warningContainer = Color(0xFFFEF3C7);
  static const onWarningContainer = Color(0xFF78350F);
}

/// Medidas compartidas.
abstract final class AppSizes {
  /// Mínimo táctil (FR-033).
  static const minTouchTarget = 48.0;
  static const spacing = 16.0;
  static const radius = 12.0;
}

abstract final class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.brandOrange)
        .copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          error: AppColors.debit,
        );
    return _build(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandOrange,
      brightness: Brightness.dark,
    );
    return _build(scheme);
  }

  static ThemeData _build(ColorScheme scheme) {
    const buttonMinSize = Size(64, AppSizes.minTouchTarget);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSizes.radius),
    );
    // Los estilos de texto no fijan tamaños absolutos fuera de la escala de
    // Material 3, por lo que respetan el tamaño de texto del sistema.
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: buttonMinSize, shape: shape),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: buttonMinSize,
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonMinSize,
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: buttonMinSize),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppSizes.minTouchTarget),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius),
        ),
      ),
      cardTheme: CardThemeData(shape: shape, margin: EdgeInsets.zero),
    );
  }
}

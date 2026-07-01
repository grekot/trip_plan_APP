import 'package:flutter/material.dart';
import 'models/enums.dart';

class AppTheme {
  /// Domyślny kolor wiodący (zielony) używany gdy plan nie podaje własnego w
  /// `trip.practical.theme.primaryColor`.
  static const Color defaultSeed = Color(0xFF1E6B52);

  static ThemeData light({Color seedColor = defaultSeed}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  static ThemeData dark({Color seedColor = defaultSeed}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
    );
  }
}

class TypeStyling {
  static IconData iconFor(ItemType t) {
    switch (t) {
      case ItemType.drive:
        return Icons.directions_car;
      case ItemType.sightseeing:
        return Icons.photo_camera;
      case ItemType.hike:
        return Icons.terrain;
      case ItemType.meal:
        return Icons.restaurant;
      case ItemType.lodging:
        return Icons.hotel;
      case ItemType.swim:
        return Icons.pool;
      case ItemType.info:
        return Icons.info_outline;
    }
  }

  static Color colorFor(ItemType t, ColorScheme scheme) {
    switch (t) {
      case ItemType.drive:
        return scheme.tertiary;
      case ItemType.sightseeing:
        return scheme.primary;
      case ItemType.hike:
        return const Color(0xFF6A8E2C);
      case ItemType.meal:
        return const Color(0xFFB45309);
      case ItemType.lodging:
        return scheme.secondary;
      case ItemType.swim:
        return const Color(0xFF0EA5E9);
      case ItemType.info:
        return scheme.outline;
    }
  }

  /// Polska etykieta typu — przekazana z enum dla zachowania kompatybilności.
  /// Jedno źródło prawdy: `ItemType.label`.
  static String labelFor(ItemType t) => t.label;
}

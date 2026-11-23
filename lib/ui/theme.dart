import 'package:flutter/material.dart';

abstract final class StillColors {
  static const background = Color(0xFF0D0E10);
  static const surface = Color(0xFF15171A);
  static const surfaceHigh = Color(0xFF1D2025);
  static const border = Color(0xFF272B31);
  static const accent = Color(0xFFFFB35C);
  static const accentMuted = Color(0xFF7A5A32);
  static const text = Color(0xFFEDEEF0);
  static const muted = Color(0xFF9AA0A8);
  static const danger = Color(0xFFE57070);
}

ThemeData buildStillTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: StillColors.accent,
    brightness: Brightness.dark,
  ).copyWith(
    surface: StillColors.surface,
    primary: StillColors.accent,
    onPrimary: const Color(0xFF241505),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: StillColors.background,
    canvasColor: StillColors.surface,
    dividerColor: StillColors.border,
    visualDensity: VisualDensity.compact,
    splashFactory: InkSparkle.splashFactory,
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: StillColors.text,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: StillColors.text,
      ),
      bodyMedium: TextStyle(fontSize: 13, color: StillColors.text),
      bodySmall: TextStyle(fontSize: 12, color: StillColors.muted),
      labelSmall: TextStyle(fontSize: 11, color: StillColors.muted),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: StillColors.surfaceHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: StillColors.border),
      ),
      textStyle: const TextStyle(fontSize: 12, color: StillColors.text),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: StillColors.surfaceHigh,
      textStyle: TextStyle(fontSize: 13, color: StillColors.text),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: StillColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
  );
}

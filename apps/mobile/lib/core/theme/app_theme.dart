import 'package:flutter/material.dart';

import 'theme_extensions.dart';
import 'tokens.dart';

/// Los dos temas de la app. `ColorScheme` se declara rol por rol y **nunca** con
/// `ColorScheme.fromSeed`: derivar la paleta daría colores distintos a los que usa
/// Angular desde el mismo JSON. Ver ADR-0009.
///
/// Los roles que Material exige y el sistema de tokens no nombra se derivan de
/// tokens existentes; ninguno introduce un color nuevo.
abstract final class AppTheme {
  static ThemeData get light => _build(
    const ColorScheme(
      brightness: Brightness.light,
      primary: LightTokens.primary,
      onPrimary: LightTokens.onPrimary,
      primaryContainer: LightTokens.primaryContainer,
      onPrimaryContainer: LightTokens.onPrimaryContainer,
      // Sin color secundario propio todavía: cae en primary a propósito.
      secondary: LightTokens.primary,
      onSecondary: LightTokens.onPrimary,
      secondaryContainer: LightTokens.surfaceVariant,
      onSecondaryContainer: LightTokens.primary,
      tertiary: LightTokens.primary,
      onTertiary: LightTokens.onPrimary,
      error: LightTokens.danger,
      onError: LightTokens.onDanger,
      errorContainer: LightTokens.dangerContainer,
      onErrorContainer: LightTokens.onDangerContainer,
      surface: LightTokens.surface,
      onSurface: LightTokens.onSurface,
      surfaceContainerLowest: LightTokens.surface,
      surfaceContainerLow: LightTokens.background,
      surfaceContainer: LightTokens.background,
      surfaceContainerHigh: LightTokens.surfaceVariant,
      surfaceContainerHighest: LightTokens.surfaceVariant,
      onSurfaceVariant: LightTokens.textMuted,
      outline: LightTokens.border,
      outlineVariant: LightTokens.border,
      surfaceTint: LightTokens.primary,
      inverseSurface: DarkTokens.surface,
      onInverseSurface: DarkTokens.onSurface,
      inversePrimary: DarkTokens.primary,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
    ),
    LightTokens.background,
    const AppStatusColors.light(),
  );

  static ThemeData get dark => _build(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: DarkTokens.primary,
      onPrimary: DarkTokens.onPrimary,
      primaryContainer: DarkTokens.primaryContainer,
      onPrimaryContainer: DarkTokens.onPrimaryContainer,
      secondary: DarkTokens.primary,
      onSecondary: DarkTokens.onPrimary,
      secondaryContainer: DarkTokens.surfaceVariant,
      onSecondaryContainer: DarkTokens.primary,
      tertiary: DarkTokens.primary,
      onTertiary: DarkTokens.onPrimary,
      error: DarkTokens.danger,
      onError: DarkTokens.onDanger,
      errorContainer: DarkTokens.dangerContainer,
      onErrorContainer: DarkTokens.onDangerContainer,
      surface: DarkTokens.surface,
      onSurface: DarkTokens.onSurface,
      surfaceContainerLowest: DarkTokens.background,
      surfaceContainerLow: DarkTokens.background,
      surfaceContainer: DarkTokens.surface,
      surfaceContainerHigh: DarkTokens.surfaceVariant,
      surfaceContainerHighest: DarkTokens.surfaceVariant,
      onSurfaceVariant: DarkTokens.textMuted,
      outline: DarkTokens.border,
      outlineVariant: DarkTokens.border,
      surfaceTint: DarkTokens.primary,
      inverseSurface: LightTokens.surface,
      onInverseSurface: LightTokens.onSurface,
      inversePrimary: LightTokens.primary,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
    ),
    DarkTokens.background,
    const AppStatusColors.dark(),
  );

  static ThemeData _build(
    ColorScheme scheme,
    Color scaffoldBackground,
    AppStatusColors status,
  ) {
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      fontFamily: Tokens.fontFamily,
      textTheme: _textTheme,
      filledButtonTheme: _primaryActionTheme,
      inputDecorationTheme: _inputTheme(scheme),
      navigationBarTheme: _navigationBarTheme(scheme),
      tabBarTheme: _tabBarTheme(scheme),
      extensions: [const AppSpacing.standard(), status],
    );
  }

  /// La pestaña activa **no** usa `primary`: el naranja saturado está reservado
  /// a la acción primaria, y una pestaña naranja en una pantalla con CTA dejaría
  /// dos naranjas compitiendo. El par `container` destaca sin competir.
  ///
  /// El icono lleno de la pestaña activa hace que la selección no dependa solo
  /// del color, y el label va siempre visible: un icono sin etiqueta obliga a
  /// aprender qué significa.
  static NavigationBarThemeData _navigationBarTheme(ColorScheme scheme) {
    return NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: Tokens.fontFamily,
          fontSize: Tokens.fontSizeCaption,
          fontWeight: states.contains(WidgetState.selected)
              ? Tokens.weightMedium
              : Tokens.weightRegular,
          color: states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// Las tabs de un proyecto reciben el mismo tratamiento que la barra inferior,
  /// y por la misma razón: una pastilla tenue, nunca el naranja de la acción.
  static TabBarThemeData _tabBarTheme(ColorScheme scheme) {
    return TabBarThemeData(
      labelColor: scheme.onPrimaryContainer,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: scheme.outline,
      indicator: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
      ),
      labelStyle: const TextStyle(
        fontFamily: Tokens.fontFamily,
        fontSize: Tokens.fontSizeCaption,
        fontWeight: Tokens.weightMedium,
      ),
      unselectedLabelStyle: const TextStyle(
        fontFamily: Tokens.fontFamily,
        fontSize: Tokens.fontSizeCaption,
        fontWeight: Tokens.weightRegular,
      ),
    );
  }

  /// Campos con fondo, no con subrayado: al sol un subrayado de 1px desaparece
  /// y no se ve dónde tocar. El relleno hace visible el área táctil entera.
  static InputDecorationTheme _inputTheme(ColorScheme scheme) {
    OutlineInputBorder borde(Color color, double ancho) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      borderSide: BorderSide(color: color, width: ancho),
    );

    return InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Tokens.space4,
        vertical: Tokens.space5,
      ),
      border: borde(scheme.outline, 1),
      enabledBorder: borde(scheme.outline, 1),
      focusedBorder: borde(scheme.primary, 2),
      errorBorder: borde(scheme.error, 1),
      focusedErrorBorder: borde(scheme.error, 2),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(color: scheme.primary),
    );
  }

  /// El mínimo táctil de Material son 48dp. Acá la acción primaria mide 64 y
  /// ocupa el ancho: un dedo con guante de trabajo no acierta un botón de 48, y
  /// marcar asistencia es lo que no puede fallar.
  static final _primaryActionTheme = FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(Tokens.touchTargetPrimary),
      textStyle: const TextStyle(
        fontFamily: Tokens.fontFamily,
        fontSize: Tokens.fontSizeTitle,
        fontWeight: Tokens.weightMedium,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
      ),
    ),
  );

  static const _textTheme = TextTheme(
    // Cifras tabulares: el cronómetro de jornada corre en pantalla y con dígitos
    // de ancho variable el texto se mueve en cada segundo.
    displaySmall: TextStyle(
      fontSize: Tokens.fontSizeDisplay,
      fontWeight: Tokens.weightBold,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
    titleLarge: TextStyle(
      fontSize: Tokens.fontSizeTitle,
      fontWeight: Tokens.weightMedium,
    ),
    bodyLarge: TextStyle(
      fontSize: Tokens.fontSizeBody,
      fontWeight: Tokens.weightRegular,
    ),
    bodyMedium: TextStyle(
      fontSize: Tokens.fontSizeBody,
      fontWeight: Tokens.weightRegular,
    ),
    bodySmall: TextStyle(
      fontSize: Tokens.fontSizeCaption,
      fontWeight: Tokens.weightRegular,
    ),
    labelLarge: TextStyle(
      fontSize: Tokens.fontSizeBody,
      fontWeight: Tokens.weightMedium,
    ),
  );
}

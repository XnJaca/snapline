import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Espaciado y radios. Material no los expone en el tema, así que viven acá
/// para que ningún widget escriba un número suelto.
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusFull,
  });

  const AppSpacing.standard()
    : xs = Tokens.space1,
      sm = Tokens.space2,
      md = Tokens.space3,
      lg = Tokens.space4,
      xl = Tokens.space5,
      xxl = Tokens.space6,
      radiusSm = Tokens.radiusSm,
      radiusMd = Tokens.radiusMd,
      radiusLg = Tokens.radiusLg,
      radiusFull = Tokens.radiusFull;

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusFull;

  @override
  AppSpacing copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusFull,
  }) {
    return AppSpacing(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusFull: radiusFull ?? this.radiusFull,
    );
  }

  @override
  AppSpacing lerp(covariant AppSpacing? other, double t) {
    if (other == null) return this;
    return AppSpacing(
      xs: lerpDouble(xs, other.xs, t)!,
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
      xl: lerpDouble(xl, other.xl, t)!,
      xxl: lerpDouble(xxl, other.xxl, t)!,
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t)!,
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t)!,
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t)!,
      radiusFull: lerpDouble(radiusFull, other.radiusFull, t)!,
    );
  }
}

/// Solo los roles que Material 3 no tiene. Todo lo demás sale del `ColorScheme`:
/// `error` es danger, `outline` es border y `onSurfaceVariant` es el texto atenuado.
///
/// En pantalla los estados usan **siempre** el par `container` / `onContainer`:
/// fondo tenue, texto oscuro e icono. El relleno sólido está reservado a la acción
/// primaria, que es la única cosa naranja saturada de la pantalla.
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
  });

  const AppStatusColors.light()
    : warning = LightTokens.warning,
      onWarning = LightTokens.onWarning,
      warningContainer = LightTokens.warningContainer,
      onWarningContainer = LightTokens.onWarningContainer,
      success = LightTokens.success,
      onSuccess = LightTokens.onSuccess,
      successContainer = LightTokens.successContainer,
      onSuccessContainer = LightTokens.onSuccessContainer;

  const AppStatusColors.dark()
    : warning = DarkTokens.warning,
      onWarning = DarkTokens.onWarning,
      warningContainer = DarkTokens.warningContainer,
      onWarningContainer = DarkTokens.onWarningContainer,
      success = DarkTokens.success,
      onSuccess = DarkTokens.onSuccess,
      successContainer = DarkTokens.successContainer,
      onSuccessContainer = DarkTokens.onSuccessContainer;

  /// Banderas de asistencia: fuera de geocerca, sin foto, GPS simulado.
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  @override
  AppStatusColors copyWith({
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
  }) {
    return AppStatusColors(
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
    );
  }

  @override
  AppStatusColors lerp(covariant AppStatusColors? other, double t) {
    if (other == null) return this;
    return AppStatusColors(
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
    );
  }
}

extension ThemeContext on BuildContext {
  AppSpacing get spacing => Theme.of(this).extension<AppSpacing>()!;
  AppStatusColors get statusColors =>
      Theme.of(this).extension<AppStatusColors>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
}

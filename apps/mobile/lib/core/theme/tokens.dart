import 'package:flutter/material.dart';

/// Valores de `design-tokens.json` en la raíz del monorepo, traducidos a mano
/// hasta que exista el generador. Ver ADR-0009 y DEBT-0001.
///
/// Nada fuera de `core/theme` consume esta clase: los widgets leen el tema.
abstract final class Tokens {
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 24.0;
  static const space6 = 32.0;

  /// Material pide 48 como mínimo táctil; la acción primaria va a 64 porque se
  /// pulsa con guantes de trabajo.
  static const touchTargetPrimary = 64.0;
  static const touchTargetMin = 48.0;

  static const radiusSm = 4.0;
  static const radiusMd = 8.0;
  static const radiusLg = 16.0;
  static const radiusFull = 999.0;

  /// Embebida como asset, no descargada en runtime: la app tiene que verse igual
  /// sin señal. Misma familia en Angular y en el sitio público.
  static const fontFamily = 'Inter';

  /// **Solo para el wordmark.** Ningún texto de interfaz la usa: una tipografía
  /// display a tamaño de lectura cansa y compite con el contenido.
  static const fontFamilyBrand = 'BricolageGrotesque';
  static const weightBrand = FontWeight.w800;

  static const fontSizeCaption = 13.0;
  static const fontSizeBody = 16.0;
  static const fontSizeTitle = 20.0;
  static const fontSizeDisplay = 32.0;

  static const weightRegular = FontWeight.w400;
  static const weightMedium = FontWeight.w500;
  static const weightBold = FontWeight.w700;
}

/// Capa semántica del tema claro.
///
/// El naranja saturado es solo de la acción primaria. Los estados se muestran
/// con su variante `container`; nunca en relleno sólido.
abstract final class LightTokens {
  static const primary = Color(0xFFC2410C);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFFFEDD5);
  static const onPrimaryContainer = Color(0xFF7C2D12);

  static const surface = Color(0xFFFFFFFF);
  static const onSurface = Color(0xFF171717);
  static const surfaceVariant = Color(0xFFF5F5F5);
  static const background = Color(0xFFFAFAFA);
  static const onBackground = Color(0xFF171717);
  static const text = Color(0xFF171717);
  static const textMuted = Color(0xFF525252);
  static const border = Color(0xFFE5E5E5);

  static const danger = Color(0xFFDC2626);
  static const onDanger = Color(0xFFFFFFFF);
  static const dangerContainer = Color(0xFFFEE2E2);
  static const onDangerContainer = Color(0xFF7F1D1D);

  static const warning = Color(0xFFA16207);
  static const onWarning = Color(0xFFFFFFFF);
  static const warningContainer = Color(0xFFFEF9C3);
  static const onWarningContainer = Color(0xFF713F12);

  static const success = Color(0xFF15803D);
  static const onSuccess = Color(0xFFFFFFFF);
  static const successContainer = Color(0xFFDCFCE7);
  static const onSuccessContainer = Color(0xFF14532D);
}

/// Capa semántica del tema oscuro.
abstract final class DarkTokens {
  static const primary = Color(0xFFFB923C);
  static const onPrimary = Color(0xFF0A0A0A);
  static const primaryContainer = Color(0xFF7C2D12);
  static const onPrimaryContainer = Color(0xFFFFEDD5);

  static const surface = Color(0xFF171717);
  static const onSurface = Color(0xFFFAFAFA);
  static const surfaceVariant = Color(0xFF262626);
  static const background = Color(0xFF0A0A0A);
  static const onBackground = Color(0xFFFAFAFA);
  static const text = Color(0xFFFAFAFA);
  static const textMuted = Color(0xFFA3A3A3);
  static const border = Color(0xFF404040);

  static const danger = Color(0xFFF87171);
  static const onDanger = Color(0xFF0A0A0A);
  static const dangerContainer = Color(0xFF7F1D1D);
  static const onDangerContainer = Color(0xFFFEE2E2);

  static const warning = Color(0xFFFACC15);
  static const onWarning = Color(0xFF0A0A0A);
  static const warningContainer = Color(0xFF713F12);
  static const onWarningContainer = Color(0xFFFEF9C3);

  static const success = Color(0xFF4ADE80);
  static const onSuccess = Color(0xFF0A0A0A);
  static const successContainer = Color(0xFF14532D);
  static const onSuccessContainer = Color(0xFFDCFCE7);
}

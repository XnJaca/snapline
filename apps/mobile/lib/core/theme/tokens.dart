// GENERADO por packages/tokens desde design-tokens.json en la raíz.
// No editar a mano: los cambios se pierden al regenerar con `pnpm tokens:generate`.
// Ver ADR-0009 y ADR-0013.

import 'package:flutter/material.dart';

/// Escala, tipografía y medidas. Nada fuera de `core/theme` consume esta clase:
/// los widgets leen el tema.
abstract final class Tokens {
  /// En dp para Flutter y px para CSS. La escala es la misma.
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 24.0;
  static const space6 = 32.0;

  /// Material pide 48 como mínimo táctil; la acción de campo va a 64 porque se
  /// pulsa con guantes de trabajo y marcar asistencia no puede fallar (regla
  /// 9). No es la altura de todo botón sólido: un "Guardar" al pie de un
  /// formulario administrativo se pulsa sentado y con el teléfono en la mano, y
  /// a 64 se come el espacio de los campos.
  static const touchTargetField = 64.0;
  static const touchTargetPrimary = 52.0;
  static const touchTargetMin = 48.0;

  static const radiusSm = 4.0;
  static const radiusMd = 8.0;
  static const radiusLg = 16.0;
  static const radiusFull = 999.0;

  /// display es para el cronómetro de jornada y montos, que se leen a distancia
  /// y con guantes. La familia `brand` y el peso `brand` son SOLO del wordmark:
  /// ningún texto de interfaz los usa, porque una display a tamaño de lectura
  /// cansa y compite con el contenido.
  ///
  /// Las dos se embeben como asset, nunca se descargan en runtime: la app tiene
  /// que verse igual sin señal, y por eso no se usa el paquete google_fonts.
  /// Ver ADR-0009 §7.
  static const fontFamily = 'Inter';
  static const fontFamilyBrand = 'BricolageGrotesque';

  static const fontSizeCaption = 13.0;
  static const fontSizeBody = 16.0;
  static const fontSizeTitle = 20.0;
  static const fontSizeDisplay = 32.0;

  static const weightRegular = FontWeight.w400;
  static const weightMedium = FontWeight.w500;
  static const weightBold = FontWeight.w700;
  static const weightBrand = FontWeight.w800;
}

/// Capa semántica; la única que cambia entre temas. REGLA DE SISTEMA: el
/// naranja saturado es solo de la acción primaria, un botón sólido por
/// pantalla. Los estados van siempre en su variante `container` (fondo tenue +
/// texto oscuro + icono), nunca en relleno sólido. Naranja, ámbar y rojo viven
/// en 35 grados de rueda, así que la separación la da la forma y no el tono.
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

/// Capa semántica del tema oscuro. Mismos roles, otros valores.
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

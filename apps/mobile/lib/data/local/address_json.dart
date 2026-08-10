import 'dart:convert';

import '../../api/models/address_dto.dart';

/// La dirección viaja a la base local como el JSON que mandó el servidor, para
/// no perder campos que el API agregue antes de que la app los conozca. Acá se
/// traduce en las dos direcciones.
///
/// `AddressDto` es el tipo del contrato y no uno propio: la ficha de cliente pide
/// un solo modelo de dirección en los tres consumidores, y `billing_address` y
/// `site.address` comparten forma.
abstract final class AddressJson {
  /// Nunca lanza: una dirección con forma inesperada deja la pantalla sin
  /// dirección, no la tumba.
  static AddressDto? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return AddressDto.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      return null;
    }
  }

  static String? encode(AddressDto? address) =>
      address == null ? null : jsonEncode(address.toJson());

  /// Calle, ciudad y estado. Lo que entra en una card sin envolverse.
  static String oneLine(AddressDto? address) {
    if (address == null) return '';
    return [address.line1, address.city, address.state]
        .where((parte) => parte.isNotEmpty)
        .join(', ');
  }
}

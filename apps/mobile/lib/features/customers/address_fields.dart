import 'package:flutter/material.dart';
import 'package:phone_form_field/phone_form_field.dart';

import '../../api/models/address_dto.dart';
import '../../core/i18n/supported_countries.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/country_field.dart';
import '../../l10n/app_localizations.dart';

/// Los seis campos de una dirección, con su estado.
///
/// Vive acá y no dentro de un formulario en particular porque la misma dirección
/// es la de facturación del cliente y la de la propiedad. Un segundo juego de
/// campos divergiría del primero.
class AddressFormControllers {
  AddressFormControllers({AddressDto? initial})
    : line1 = TextEditingController(text: initial?.line1 ?? ''),
      line2 = TextEditingController(text: initial?.line2 ?? ''),
      city = TextEditingController(text: initial?.city ?? ''),
      state = TextEditingController(text: initial?.state ?? ''),
      postalCode = TextEditingController(text: initial?.postalCode ?? ''),
      country = ValueNotifier<IsoCode>(_pais(initial?.country));

  final TextEditingController line1;
  final TextEditingController line2;
  final TextEditingController city;
  final TextEditingController state;
  final TextEditingController postalCode;

  /// El país se elige de una lista, no se teclea: el contrato lo quiere en ISO
  /// de dos letras y "Mexico" escrito a mano no lo es.
  final ValueNotifier<IsoCode> country;

  /// Ningún campo tocado. Una dirección opcional en blanco no se manda.
  bool get isEmpty =>
      line1.text.trim().isEmpty &&
      line2.text.trim().isEmpty &&
      city.text.trim().isEmpty &&
      state.text.trim().isEmpty &&
      postalCode.text.trim().isEmpty;

  AddressDto? toDto() {
    if (isEmpty) return null;
    return AddressDto(
      line1: line1.text.trim(),
      line2: line2.text.trim().isEmpty ? null : line2.text.trim(),
      city: city.text.trim(),
      // Sin `toUpperCase()`: era del tiempo en que esto eran dos letras. Una
      // provincia es un nombre propio y «SAN JOSÉ» no es cómo se escribe.
      state: state.text.trim(),
      postalCode: postalCode.text.trim(),
      country: country.value.name,
    );
  }

  void dispose() {
    line1.dispose();
    line2.dispose();
    city.dispose();
    state.dispose();
    postalCode.dispose();
    country.dispose();
  }

  /// Lo guardado llega como ISO de dos letras. Un país que la lista no ofrece
  /// —o basura— cae en el por defecto: el selector no puede quedarse sin valor.
  static IsoCode _pais(String? guardado) {
    if (guardado == null) return SupportedCountries.initial;
    for (final iso in IsoCode.values) {
      if (iso.name == guardado.toUpperCase()) return iso;
    }
    return SupportedCountries.initial;
  }
}

/// Los campos de una dirección.
///
/// Con `optional` en `true` —la de facturación— no exige nada si está vacía,
/// pero sí completa el resto en cuanto se escribió la calle: media dirección no
/// imprime una factura.
class AddressFields extends StatelessWidget {
  const AddressFields({
    super.key,
    required this.controllers,
    this.optional = false,
  });

  final AddressFormControllers controllers;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;

    // Con la dirección opcional y en blanco no se valida nada; en cuanto hay
    // algo escrito, los obligatorios vuelven a serlo.
    String? exigir(String? valor, String mensaje) {
      if (optional && controllers.isEmpty) return null;
      return (valor == null || valor.trim().isEmpty) ? mensaje : null;
    }

    // Con la dirección obligatoria se dice en el label; con la opcional no, o
    // marcaría como obligatorio algo que se puede dejar entero en blanco.
    String etiqueta(String texto) =>
        optional ? texto : l10n.fieldRequiredLabel(texto);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controllers.line1,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: etiqueta(l10n.addressLine1)),
          validator: (v) => exigir(v, l10n.addressLine1Required),
        ),
        SizedBox(height: spacing.md),
        TextFormField(
          controller: controllers.line2,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: l10n.addressLine2),
        ),
        SizedBox(height: spacing.md),
        TextFormField(
          controller: controllers.city,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: etiqueta(l10n.addressCity)),
          validator: (v) => exigir(v, l10n.addressCityRequired),
        ),
        SizedBox(height: spacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: controllers.state,
                // Texto libre y no dos letras: la app ofrece dieciséis países y
                // fuera de Estados Unidos esto es una provincia o un
                // departamento con nombre entero — «Alajuela», «Sacatepéquez».
                // El código corto se sigue pudiendo escribir.
                textCapitalization: TextCapitalization.words,
                maxLength: 100,
                buildCounter: _sinContador,
                decoration: InputDecoration(
                  labelText: etiqueta(l10n.addressState),
                ),
                validator: (v) {
                  if (optional && controllers.isEmpty) return null;
                  return (v == null || v.trim().isEmpty)
                      ? l10n.addressStateRequired
                      : null;
                },
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: TextFormField(
                controller: controllers.postalCode,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: etiqueta(l10n.addressPostalCode),
                ),
                validator: (v) => exigir(v, l10n.addressPostalCodeRequired),
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.md),
        ValueListenableBuilder<IsoCode>(
          valueListenable: controllers.country,
          builder: (context, seleccionado, _) => CountryField(
            selected: seleccionado,
            label: l10n.addressCountry,
            onChanged: (iso) => controllers.country.value = iso,
          ),
        ),
      ],
    );
  }

  /// `maxLength` dibuja "1/2" debajo del campo y desalinea la fila. El límite
  /// sigue aplicando.
  static Widget? _sinContador(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => null;
}

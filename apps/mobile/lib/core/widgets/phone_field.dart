import 'package:flutter/material.dart';
import 'package:phone_form_field/phone_form_field.dart';

import '../i18n/supported_countries.dart';
import '../theme/theme_extensions.dart';

/// Un teléfono con su país.
///
/// El país no es decorativo: **es lo que permite validar**. Diez dígitos son un
/// número válido en Estados Unidos y no en México, y sin saber el país lo único
/// que se puede comprobar es que haya algo escrito. Los datos de validación son
/// de libphonenumber, portados a Dart puro, así que funciona sin señal.
///
/// Lo que se guarda es E.164 —`+13015550142`—, un solo formato para el mismo
/// número. El servidor ya normaliza al leer, pero seguía guardando lo que
/// llegara; mandarlo normalizado desde acá cierra la mitad que faltaba de
/// DEBT-0003.
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    required this.label,
    this.textInputAction,
  });

  final PhoneController controller;
  final String label;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return PhoneFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      textInputAction: textInputAction,
      // El botón de país siempre visible: escondido detrás del label, quien no
      // sabe que se puede cambiar teclea su número con el prefijo de otro país.
      isCountryButtonPersistent: true,
      countryButtonStyle: CountryButtonStyle(
        showDialCode: true,
        showFlag: true,
        showDropdownIcon: true,
        textStyle: context.texts.bodyLarge,
      ),
      countrySelectorNavigator: CountrySelectorNavigator.modalBottomSheet(
        countries: SupportedCountries.all,
        favorites: SupportedCountries.favorites,
        // El teclado saltando solo al abrir la hoja tapa media lista; con
        // veintidós países se encuentra el propio antes de escribirlo.
        searchAutofocus: false,
        height: MediaQuery.sizeOf(context).height * 0.7,
      ),
      // El teléfono es opcional en el dominio: vacío no es un error. Lo que no
      // se acepta es algo escrito que no sea un número de ese país, porque eso
      // sí se descubre recién cuando alguien intenta llamar.
      validator: PhoneValidator.valid(context),
      autofillHints: const [AutofillHints.telephoneNumber],
    );
  }
}

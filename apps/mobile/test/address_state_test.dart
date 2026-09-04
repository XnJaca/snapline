import 'package:flutter_test/flutter_test.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:snapline/core/i18n/supported_countries.dart';
import 'package:snapline/features/customers/address_fields.dart';

/// El estado de una dirección cambia de forma según el país.
///
/// En Estados Unidos y Canadá es un código de dos letras; en el resto, el
/// nombre entero de la provincia o el departamento. La misma regla vive en
/// `apps/api/src/common/dto/address.dto.ts` y en el panel: son dos códigos y
/// ningún endpoint los transporta, así que cada lado la declara.
void main() {
  AddressFormControllers conEstado(String estado, IsoCode pais) {
    final c = AddressFormControllers();
    c.line1.text = '412 Ellsworth Dr';
    c.city.text = 'Silver Spring';
    c.postalCode.text = '20910';
    c.state.text = estado;
    c.country.value = pais;
    return c;
  }

  test('los dos países del código corto son los que declara el API', () {
    expect(SupportedCountries.usesTwoLetterState, [IsoCode.US, IsoCode.CA]);
    expect(SupportedCountries.esCodigoDeDosLetras(IsoCode.US), isTrue);
    expect(SupportedCountries.esCodigoDeDosLetras(IsoCode.CA), isTrue);
    expect(SupportedCountries.esCodigoDeDosLetras(IsoCode.CR), isFalse);
    expect(SupportedCountries.esCodigoDeDosLetras(IsoCode.GT), isFalse);
  });

  test('donde es código, se guarda en mayúsculas', () {
    // `md` y `MD` son el mismo estado.
    final c = conEstado('md', IsoCode.US);
    addTearDown(c.dispose);

    expect(c.toDto()!.state, 'MD');
  });

  test('donde es nombre, se guarda tal cual se escribió', () {
    // «SAN JOSÉ» no es cómo se escribe: pasar un nombre propio a mayúsculas
    // rompe el dato en vez de normalizarlo.
    final c = conEstado('San José', IsoCode.CR);
    addTearDown(c.dispose);

    expect(c.toDto()!.state, 'San José');
  });

  test('un departamento largo entra entero', () {
    final c = conEstado('Sacatepéquez', IsoCode.GT);
    addTearDown(c.dispose);

    expect(c.toDto()!.state, 'Sacatepéquez');
  });
}

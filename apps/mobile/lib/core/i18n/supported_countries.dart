import 'package:phone_form_field/phone_form_field.dart';

/// Los países que la app ofrece para un teléfono o una dirección.
///
/// No son todos a propósito: una lista de 240 obliga a buscar en un selector que
/// se usa en cada alta. Estos son de donde sale la gente con la que trabaja el
/// contratista — Estados Unidos y Canadá, más América Latina, que es de donde
/// vienen sus cuadrillas y buena parte de sus clientes.
///
/// **Restringir la lista no restringe lo que se puede guardar.** Un número ya
/// cargado de otro país sigue mostrándose y validándose; lo que cambia es qué se
/// ofrece al elegir. Ampliarla es agregar una línea acá.
abstract final class SupportedCountries {
  /// Arriba del resto en el selector: es donde opera el design partner.
  static const favorites = [IsoCode.US, IsoCode.CA];

  static const latinAmerica = [
    IsoCode.MX,
    IsoCode.GT,
    IsoCode.SV,
    IsoCode.HN,
    IsoCode.NI,
    IsoCode.CR,
    IsoCode.PA,
    IsoCode.CU,
    IsoCode.DO,
    IsoCode.PR,
    IsoCode.CO,
    IsoCode.VE,
    IsoCode.EC,
    IsoCode.PE,
    IsoCode.BO,
    IsoCode.PY,
    IsoCode.UY,
    IsoCode.AR,
    IsoCode.CL,
    IsoCode.BR,
  ];

  static const all = [...favorites, ...latinAmerica];

  /// El país con el que arranca un alta. Maryland es `+1`, y que el prefijo ya
  /// esté puesto es la diferencia entre teclear diez dígitos y doce.
  static const initial = IsoCode.US;
}

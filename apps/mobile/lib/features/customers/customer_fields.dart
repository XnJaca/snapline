import 'package:flutter/material.dart';
import 'package:phone_form_field/phone_form_field.dart';

import '../../api/models/customer_source.dart';
import '../../core/i18n/supported_countries.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/help_sheet.dart';
import '../../core/widgets/phone_field.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/repositories/customer_repository.dart';
import '../../l10n/app_localizations.dart';
import 'address_fields.dart';
import 'customer_source_display.dart';

/// El estado de un formulario de cliente.
///
/// Se crea afuera y se pasa adentro para que el mismo juego de campos sirva en
/// la pantalla completa y en la hoja del alta de obra. Copiar los campos en dos
/// lugares es cómo divergen.
class CustomerFormControllers {
  CustomerFormControllers({CustomerDetail? initial})
    : displayName = TextEditingController(text: initial?.displayName ?? ''),
      firstName = TextEditingController(text: initial?.firstName ?? ''),
      lastName = TextEditingController(text: initial?.lastName ?? ''),
      companyName = TextEditingController(text: initial?.companyName ?? ''),
      email = TextEditingController(text: initial?.email ?? ''),
      phone = PhoneController(initialValue: _telefono(initial?.phone)),
      notes = TextEditingController(text: initial?.notes ?? ''),
      billingAddress = AddressFormControllers(
        initial: initial?.billingAddress,
      ),
      source = ValueNotifier<CustomerSource?>(
        initial?.source == null
            ? null
            : CustomerSource.fromJson(initial!.source!),
      );

  final TextEditingController displayName;
  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController companyName;
  final TextEditingController email;
  final PhoneController phone;
  final TextEditingController notes;
  final AddressFormControllers billingAddress;
  final ValueNotifier<CustomerSource?> source;

  /// Sin ninguno de los dos, el cliente se guarda igual —el dominio los marca
  /// opcionales— pero no va a poder entrar al portal.
  bool get hasContact =>
      email.text.trim().isNotEmpty || phone.value.nsn.trim().isNotEmpty;

  CustomerInput toInput() => CustomerInput(
    displayName: displayName.text.trim(),
    firstName: _o(firstName),
    lastName: _o(lastName),
    companyName: _o(companyName),
    email: _o(email),
    // E.164 y no lo que se tecleó: un teléfono tiene una sola forma escrita del
    // lado del servidor, y así entra con el país que se eligió.
    phone: phone.value.nsn.trim().isEmpty ? null : phone.value.international,
    billingAddress: billingAddress.toDto(),
    source: source.value?.json,
    notes: _o(notes),
  );

  static String? _o(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  /// Lo guardado viene en E.164. Si trae otra forma —una fila cargada antes de
  /// que el alta normalizara— se arranca vacío en el país por defecto en vez de
  /// tumbar el formulario: es corregible a mano y perder el dato sería peor.
  static PhoneNumber _telefono(String? guardado) {
    const vacio = PhoneNumber(
      isoCode: SupportedCountries.initial,
      nsn: '',
    );
    if (guardado == null || guardado.isEmpty) return vacio;
    try {
      return PhoneNumber.parse(guardado);
    } catch (_) {
      return vacio;
    }
  }

  void dispose() {
    displayName.dispose();
    firstName.dispose();
    lastName.dispose();
    companyName.dispose();
    email.dispose();
    phone.dispose();
    notes.dispose();
    billingAddress.dispose();
    source.dispose();
  }
}

/// Los campos de un cliente.
///
/// `minimal` es la versión que se llena parado en una obra: nombre y un
/// contacto, nada más. Pedir la ficha completa en un techo es el modo seguro de
/// que no se cargue nada, y el resto se completa después desde Clientes.
class CustomerFields extends StatefulWidget {
  const CustomerFields({
    super.key,
    required this.controllers,
    this.minimal = false,
  });

  final CustomerFormControllers controllers;
  final bool minimal;

  @override
  State<CustomerFields> createState() => _CustomerFieldsState();
}

class _CustomerFieldsState extends State<CustomerFields> {
  @override
  void initState() {
    super.initState();
    // El aviso del portal aparece y desaparece mientras se escribe.
    widget.controllers.email.addListener(_redibujar);
    widget.controllers.phone.addListener(_redibujar);
  }

  @override
  void dispose() {
    widget.controllers.email.removeListener(_redibujar);
    widget.controllers.phone.removeListener(_redibujar);
    super.dispose();
  }

  void _redibujar() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final c = widget.controllers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: c.displayName,
          textCapitalization: TextCapitalization.words,
          autofocus: widget.minimal,
          decoration: InputDecoration(
            // Lo obligatorio se dice en el label, con palabras: es el único
            // campo que impide guardar y quien lo lee tiene que saberlo antes
            // de tocar el botón, no después del error.
            labelText: l10n.fieldRequiredLabel(l10n.customerFieldDisplayName),
            helperText: l10n.customerFieldDisplayNameHelp,
            // Dos líneas de ayuda: en español el texto se envuelve y sin esto
            // el campo salta de alto al enfocarse.
            helperMaxLines: 2,
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? l10n.customerFieldDisplayNameRequired
              : null,
        ),
        SizedBox(height: spacing.md),
        PhoneField(
          controller: c.phone,
          label: l10n.customerFieldPhone,
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: spacing.md),
        TextFormField(
          controller: c.email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(labelText: l10n.customerFieldEmail),
          validator: (v) {
            final valor = v?.trim() ?? '';
            if (valor.isEmpty) return null;
            return _pareceCorreo(valor) ? null : l10n.customerFieldEmailInvalid;
          },
        ),
        if (!c.hasContact) ...[
          SizedBox(height: spacing.md),
          // Aviso, no error: el dominio los marca opcionales y el cliente se
          // guarda igual. Lo que no va a poder es entrar al portal — y "portal"
          // no dice nada por sí solo, así que el aviso trae con qué averiguarlo.
          StatusChip(
            tone: StatusTone.warning,
            label: l10n.customerNoPortalAccess,
            expand: true,
            action: HelpButton(
              title: l10n.helpPortalTitle,
              body: l10n.helpPortalBody,
            ),
          ),
        ],
        if (!widget.minimal) ..._camposCompletos(context, l10n, spacing, c),
      ],
    );
  }

  List<Widget> _camposCompletos(
    BuildContext context,
    AppLocalizations l10n,
    AppSpacing spacing,
    CustomerFormControllers c,
  ) => [
    SizedBox(height: spacing.md),
    TextFormField(
      controller: c.companyName,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(labelText: l10n.customerFieldCompanyName),
    ),
    SizedBox(height: spacing.md),
    Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: c.firstName,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l10n.customerFieldFirstName),
          ),
        ),
        SizedBox(width: spacing.md),
        Expanded(
          child: TextFormField(
            controller: c.lastName,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l10n.customerFieldLastName),
          ),
        ),
      ],
    ),
    SizedBox(height: spacing.md),
    ValueListenableBuilder<CustomerSource?>(
      valueListenable: c.source,
      builder: (context, valor, _) => DropdownButtonFormField<CustomerSource?>(
        initialValue: valor,
        decoration: InputDecoration(labelText: l10n.customerFieldSource),
        items: [
          DropdownMenuItem(value: null, child: Text(l10n.customerSourceNone)),
          for (final fuente in CustomerSource.$valuesDefined)
            DropdownMenuItem(value: fuente, child: Text(fuente.label(l10n))),
        ],
        onChanged: (nuevo) => c.source.value = nuevo,
      ),
    ),
    SizedBox(height: spacing.md),
    TextFormField(
      controller: c.notes,
      textCapitalization: TextCapitalization.sentences,
      minLines: 2,
      maxLines: 4,
      decoration: InputDecoration(labelText: l10n.customerFieldNotes),
    ),
    SizedBox(height: spacing.lg),
    Text(
      l10n.customerSectionBillingAddress,
      style: context.texts.titleSmall,
    ),
    SizedBox(height: spacing.md),
    AddressFields(controllers: c.billingAddress, optional: true),
  ];

  /// Lo mínimo para atajar un dedazo. La validación de verdad la hace el
  /// servidor con `@IsEmail()`; acá alcanza con no mandar algo sin arroba.
  static bool _pareceCorreo(String valor) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(valor);
}

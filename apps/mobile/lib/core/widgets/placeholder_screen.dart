import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../navigation/app_destination.dart';
import 'app_scaffold.dart';
import 'placeholder_list.dart';

/// Un eje que todavía no tiene su spec. Cada uno se va a reemplazar por su
/// pantalla real; hasta entonces existe para que la estructura sea navegable y
/// verificable.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.destination});

  final AppDestination destination;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: destination.label(AppLocalizations.of(context)),
      body: PlaceholderList(storageKey: destination.name),
    );
  }
}

import 'package:flutter/material.dart';

import '../brand/snapline_logo.dart';

/// Lo que se ve mientras se lee la sesión del almacenamiento seguro. Dura unos
/// milisegundos, pero sin esto la app parpadea en login antes de saber que sí
/// había sesión guardada.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: SnaplineLogo(markSize: 40)));
  }
}

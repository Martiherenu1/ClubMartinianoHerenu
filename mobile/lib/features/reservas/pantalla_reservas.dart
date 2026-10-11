/// Mis reservas (CU-08). PROVISORIA: las listas de próximas e historial y la
/// cancelación llegan en el PR `feat/mis-reservas`.
library;

import 'package:flutter/material.dart';

import '../../app/tema.dart';

class PantallaReservas extends StatelessWidget {
  const PantallaReservas({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('MIS RESERVAS', style: Tipografia.titulo(size: 22))),
      body: Center(
        child: Text('Próximamente.', style: Tipografia.texto(size: 14)),
      ),
    );
  }
}

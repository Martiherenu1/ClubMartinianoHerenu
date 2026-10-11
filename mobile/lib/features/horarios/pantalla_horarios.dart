/// Horarios de una cancha (CU-12). PROVISORIA: la grilla de franjas y la
/// reserva llegan en el próximo PR (`feat/horarios`).
library;

import 'package:flutter/material.dart';

import '../../app/tema.dart';
import '../../data/catalogo_api.dart';

class PantallaHorarios extends StatelessWidget {
  const PantallaHorarios({super.key, required this.espacio});

  final Espacio espacio;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('HORARIOS', style: Tipografia.titulo(size: 22))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(espacio.nombreCompuesto, style: Tipografia.codigo(size: 12)),
            const SizedBox(height: 8),
            Text('Próximamente.', style: Tipografia.texto(size: 14)),
          ],
        ),
      ),
    );
  }
}

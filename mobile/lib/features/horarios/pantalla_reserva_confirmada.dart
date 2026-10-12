/// "¡Reserva confirmada!": confirmación a pantalla completa. Después de un
/// momento redirige a las reservas del usuario (como en el Figma).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/tema.dart';

class PantallaReservaConfirmada extends StatefulWidget {
  const PantallaReservaConfirmada({
    super.key,
    required this.alTerminar,
    this.espera = const Duration(milliseconds: 2200),
  });

  /// Qué hacer cuando termina la espera: cerrar esta pantalla e ir a Reservas.
  final VoidCallback alTerminar;
  final Duration espera;

  @override
  State<PantallaReservaConfirmada> createState() => _PantallaReservaConfirmadaState();
}

class _PantallaReservaConfirmadaState extends State<PantallaReservaConfirmada> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.espera, widget.alTerminar);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = context.esModoOscuro;
    // Mientras se muestra, "Atrás" no hace nada: la reserva ya está hecha y la
    // pantalla se cierra sola.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: Colores.lima,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(Icons.check_rounded, size: 64, color: Colors.black),
                ),
                const SizedBox(height: 22),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: '¡RESERVA\n'),
                      TextSpan(
                        text: 'CONFIRMADA!',
                        style: TextStyle(color: context.colorAcento),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: Tipografia.titulo(
                    size: 40,
                    color: oscuro ? Colors.white : const Color(0xFF0B0C16),
                  ).copyWith(height: 1.3),
                ),
                const SizedBox(height: 8),
                Text(
                  'Redirigiendo a tus reservas…',
                  style: Tipografia.texto(size: 13, color: context.colorTextoSuave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

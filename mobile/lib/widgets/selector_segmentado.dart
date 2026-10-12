/// Selector de dos o más opciones en una barra (la opción activa en lima):
/// "1 hora / 2 horas" en horarios, "Próximas / Historial" en reservas.
library;

import 'package:flutter/material.dart';

import '../app/tema.dart';

class SelectorSegmentado extends StatelessWidget {
  const SelectorSegmentado({
    super.key,
    required this.opciones,
    required this.seleccionada,
    required this.alElegir,
    this.tamanoTexto = 14,
  });

  final List<String> opciones;
  final int seleccionada;
  final ValueChanged<int> alElegir;
  final double tamanoTexto;

  @override
  Widget build(BuildContext context) {
    final oscuro = context.esModoOscuro;
    final apagado = oscuro
        ? Colors.white.withValues(alpha: 0.42)
        : Colors.black.withValues(alpha: 0.45);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: oscuro ? Colors.white.withValues(alpha: 0.06) : Colores.superficieClara,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: oscuro ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < opciones.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == seleccionada,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => alElegir(i),
                  child: Container(
                    height: 41,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == seleccionada ? Colores.lima : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      opciones[i],
                      style: Tipografia.texto(
                        size: tamanoTexto,
                        peso: FontWeight.w900,
                        color: i == seleccionada ? Colors.black : apagado,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

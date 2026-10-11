/// Barra de navegación inferior del Figma: Inicio, Sedes, Reservas y Perfil.
library;

import 'package:flutter/material.dart';

import '../app/tema.dart';

class BarraInferior extends StatelessWidget {
  const BarraInferior({super.key, required this.indice, required this.alElegir});

  final int indice;
  final ValueChanged<int> alElegir;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'INICIO'),
    (Icons.apartment_outlined, Icons.apartment_rounded, 'SEDES'),
    (Icons.calendar_today_outlined, Icons.calendar_today_rounded, 'RESERVAS'),
    (Icons.person_outline, Icons.person_rounded, 'PERFIL'),
  ];

  @override
  Widget build(BuildContext context) {
    final oscuro = context.esModoOscuro;
    final activo = context.colorAcento;
    final inactivo = oscuro
        ? Colors.white.withValues(alpha: 0.42)
        : Colors.black.withValues(alpha: 0.5);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          height: 55,
          decoration: BoxDecoration(
            color: oscuro
                ? const Color(0xFF050508).withValues(alpha: 0.94)
                : const Color(0xFFF0F2FA).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: oscuro
                  ? Colors.white.withValues(alpha: 0.11)
                  : Colors.black.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: oscuro ? 0.5 : 0.08),
                blurRadius: oscuro ? 24 : 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _Pestana(
                    icono: i == indice ? _items[i].$2 : _items[i].$1,
                    texto: _items[i].$3,
                    activa: i == indice,
                    color: i == indice ? activo : inactivo,
                    alPresionar: () => alElegir(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  const _Pestana({
    required this.icono,
    required this.texto,
    required this.activa,
    required this.color,
    required this.alPresionar,
  });

  final IconData icono;
  final String texto;
  final bool activa;
  final Color color;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activa,
      label: texto,
      excludeSemantics: true,
      child: InkWell(
        onTap: alPresionar,
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icono, size: 19, color: color),
                const SizedBox(height: 3),
                Text(
                  texto,
                  style: Tipografia.texto(
                    size: 8,
                    peso: FontWeight.w900,
                    color: color,
                    espaciado: 0.8,
                  ),
                ),
              ],
            ),
            if (activa)
              Positioned(
                bottom: 2,
                child: Container(
                  width: 24,
                  height: 3,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

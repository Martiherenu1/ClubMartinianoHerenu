/// Etiquetas y chips que se repiten en Home, Sedes y Canchas.
library;

import 'package:flutter/material.dart';

import '../app/tema.dart';
import '../core/formato.dart';

/// Color de cada deporte en las etiquetas del Figma.
({Color fondo, Color borde, Color texto}) _coloresDeporte(String deporte) {
  Color base(int r, int g, int b) => Color.fromRGBO(r, g, b, 1);
  final (color, texto) = switch (deporte) {
    'Fútbol' => (base(0, 188, 125), const Color(0xFF009966)),
    'Tenis' => (base(255, 105, 0), const Color(0xFFF54900)),
    'Hockey' => (base(142, 81, 255), const Color(0xFF7F22FE)),
    'Vóley' => (base(246, 51, 154), const Color(0xFFE60076)),
    'Golf' => (base(0, 166, 244), const Color(0xFF0084D1)),
    _ => (base(120, 120, 130), const Color(0xFF6B6B78)),
  };
  return (
    fondo: color.withValues(alpha: 0.15),
    borde: color.withValues(alpha: 0.25),
    texto: texto,
  );
}

/// Etiqueta chica con el deporte: "⚽ Fútbol" en verde, "🎾 Tenis" en naranja…
class EtiquetaDeporte extends StatelessWidget {
  const EtiquetaDeporte(this.deporte, {super.key});

  final String deporte;

  @override
  Widget build(BuildContext context) {
    final c = _coloresDeporte(deporte);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.fondo,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.borde),
      ),
      child: Text(
        '${emojiDeporte(deporte)} $deporte',
        style: Tipografia.texto(size: 10, peso: FontWeight.w500, color: c.texto),
      ),
    );
  }
}

/// Chip redondeado de filtro por deporte ("Todos", "⚽ Fútbol"…).
class ChipDeporte extends StatelessWidget {
  const ChipDeporte({
    super.key,
    required this.texto,
    required this.seleccionado,
    required this.alPresionar,
    this.emoji,
  });

  final String texto;
  final String? emoji;
  final bool seleccionado;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final oscuro = context.esModoOscuro;
    final colorTexto = seleccionado ? Colors.black : context.colorTextoSuave;
    return Semantics(
      button: true,
      selected: seleccionado,
      label: texto,
      child: GestureDetector(
        onTap: alPresionar,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: seleccionado
                ? Colores.lima
                : (oscuro ? Colors.white.withValues(alpha: 0.07) : Colors.white.withValues(alpha: 0.92)),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: seleccionado ? Colors.transparent : context.colorBordeTarjeta,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null) ...[
                Text(emoji!, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 5),
              ],
              Text(
                texto,
                style: Tipografia.texto(size: 12, peso: FontWeight.w700, color: colorTexto),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip rectangular de filtro por tipo de cancha ("Todos", "Fútbol 5"…).
class ChipTipo extends StatelessWidget {
  const ChipTipo({
    super.key,
    required this.texto,
    required this.seleccionado,
    required this.alPresionar,
  });

  final String texto;
  final bool seleccionado;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: seleccionado,
      label: texto,
      child: GestureDetector(
        onTap: alPresionar,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: seleccionado ? Colores.lima : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: seleccionado ? Colors.transparent : context.colorBordeTarjeta,
            ),
          ),
          child: Text(
            texto,
            style: Tipografia.texto(
              size: 11,
              peso: FontWeight.w700,
              color: seleccionado ? Colors.black : context.colorTextoSuave,
            ),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta de condición de la cancha: Outdoor, Indoor, Iluminada.
class EtiquetaCondicion extends StatelessWidget {
  const EtiquetaCondicion({
    super.key,
    required this.texto,
    required this.icono,
    required this.fondo,
    required this.color,
  });

  factory EtiquetaCondicion.outdoor(BuildContext context) => EtiquetaCondicion(
        texto: 'Outdoor',
        icono: Icons.wb_sunny_outlined,
        fondo: const Color(0xFFFBBF24).withValues(alpha: 0.12),
        color: const Color(0xFFD97706),
      );

  factory EtiquetaCondicion.indoor(BuildContext context) => EtiquetaCondicion(
        texto: 'Indoor',
        icono: Icons.home_outlined,
        fondo: const Color(0xFF6366F1).withValues(alpha: 0.14),
        color: const Color(0xFF818CF8),
      );

  factory EtiquetaCondicion.iluminada(BuildContext context) => EtiquetaCondicion(
        texto: 'Iluminada',
        icono: Icons.lightbulb_outline,
        fondo: Colores.limaOscuro.withValues(alpha: 0.1),
        color: context.colorAcento,
      );

  final String texto;
  final IconData icono;
  final Color fondo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 10, color: color),
          const SizedBox(width: 4),
          Text(texto, style: Tipografia.texto(size: 10, peso: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

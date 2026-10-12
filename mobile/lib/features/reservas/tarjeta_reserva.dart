/// Tarjeta de una reserva (Mis reservas y pantalla de cancelación).
library;

import 'package:flutter/material.dart';

import '../../app/tema.dart';
import '../../core/formato.dart';
import '../../data/reservas_api.dart';
import '../../widgets/imagen_catalogo.dart';

/// Texto y color con que se muestra cada estado de una reserva.
({String texto, Color color}) estadoVisual(BuildContext context, String estado) {
  final oscuro = context.esModoOscuro;
  return switch (estado) {
    'confirmada' => (texto: 'Activa', color: context.colorAcento),
    'en_curso' => (texto: 'En curso', color: const Color(0xFFD97706)),
    'completada' => (
        texto: 'Completada',
        color: oscuro ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
      ),
    'cancelada' => (
        texto: 'Cancelada',
        color: oscuro ? const Color(0xFFF87171) : const Color(0xFFDC2626),
      ),
    _ => (texto: estado, color: context.colorTextoSuave),
  };
}

class TarjetaReserva extends StatelessWidget {
  const TarjetaReserva({
    super.key,
    required this.reserva,
    this.mostrarEstado = true,
    this.alPresionar,
    this.alCancelar,
  });

  final Reserva reserva;
  final bool mostrarEstado;

  /// Abre el detalle. Sin esto la tarjeta no es tocable.
  final VoidCallback? alPresionar;

  /// Muestra el botón "Cancelar" (solo para reservas cancelables).
  final VoidCallback? alCancelar;

  @override
  Widget build(BuildContext context) {
    final r = reserva;
    final e = r.espacio;
    final estado = estadoVisual(context, r.estado);

    final tarjeta = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colorTarjeta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorBordeTarjeta),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: FotoCancha(deporte: e.deporte, tipo: e.tipo, alto: 46),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sede ${e.sede.nombre}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Tipografia.texto(
                              size: 14,
                              peso: FontWeight.w700,
                              color: context.colorTexto,
                            ),
                          ),
                        ),
                        if (mostrarEstado)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: estado.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              estado.texto,
                              style: Tipografia.texto(
                                size: 10,
                                peso: FontWeight.w700,
                                color: estado.color,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      e.nombreCompuesto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tipografia.codigo(size: 10, color: context.colorTextoTenue),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 10,
                          color: context.colorTextoSuave,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatearFechaCorta(r.fecha),
                          style: Tipografia.texto(size: 11, color: context.colorTextoSuave),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.schedule, size: 10, color: context.colorTextoSuave),
                        const SizedBox(width: 4),
                        Text(
                          '${r.horaInicio} – ${r.horaFin}',
                          style: Tipografia.texto(size: 11, color: context.colorTextoSuave),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Divider(height: 1, color: context.colorBordeTarjeta),
          const SizedBox(height: 11),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatearPrecio(r.precioTotal),
                style: Tipografia.titulo(size: 16, color: context.colorAcento),
              ),
              if (alCancelar != null)
                Semantics(
                  button: true,
                  label: 'Cancelar reserva',
                  child: GestureDetector(
                    onTap: alCancelar,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.close, size: 11, color: Color(0xFFF87171)),
                          const SizedBox(width: 5),
                          Text(
                            'Cancelar',
                            style: Tipografia.texto(
                              size: 12,
                              peso: FontWeight.w700,
                              color: const Color(0xFFF87171),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    if (alPresionar == null) return tarjeta;
    return GestureDetector(onTap: alPresionar, child: tarjeta);
  }
}

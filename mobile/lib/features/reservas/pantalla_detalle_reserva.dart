/// Detalle de una reserva (CU-08): datos completos y, si todavía se puede,
/// el botón para cancelarla (CU-10).
///
/// Recibe el id y pide la reserva a la API: así sirve igual si se abre desde
/// la lista o desde una notificación.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/tema.dart';
import '../../core/api_client.dart';
import '../../core/formato.dart';
import '../../data/reservas_api.dart';
import '../../widgets/carga_async.dart';
import '../../widgets/imagen_catalogo.dart';
import 'pantalla_cancelar_reserva.dart';

class PantallaDetalleReserva extends StatelessWidget {
  const PantallaDetalleReserva({super.key, required this.reservaId});

  final int reservaId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CargaAsync<Reserva>(
        cargar: () => ReservasApi(context.read<ApiClient>()).obtener(reservaId),
        construir: (context, reserva) => _Detalle(reserva: reserva),
      ),
    );
  }
}

class _Detalle extends StatelessWidget {
  const _Detalle({required this.reserva});

  final Reserva reserva;

  Future<void> _cancelar(BuildContext context) async {
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    final cancelada = await navegador.push<bool>(
      MaterialPageRoute(builder: (_) => PantallaCancelarReserva(reserva: reserva)),
    );
    if (cancelada == true) {
      // La reserva ya no está activa: se vuelve a la lista, que se actualiza.
      navegador.pop();
      mensajero.showSnackBar(const SnackBar(content: Text('Reserva cancelada')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = reserva;
    final e = r.espacio;
    final arriba = MediaQuery.paddingOf(context).top;
    final estado = _estado(context, r.estado);
    final tipo = etiquetaTipo(e.tipo);
    final espacio = [
      e.deporte,
      if (!tipo.startsWith(e.deporte)) tipo,
      e.cubierto ? 'Interior' : 'Exterior',
    ].join(' · ');

    return ListView(
      padding: EdgeInsets.fromLTRB(20, arriba + 10, 20, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Icon(Icons.chevron_left, size: 30, color: context.colorTexto),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'DETALLE DE '),
              TextSpan(text: 'LA RESERVA', style: TextStyle(color: context.colorAcento)),
            ],
          ),
          style: Tipografia.titulo(size: 28, color: context.colorTexto),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.fromLTRB(9, 4, 10, 4),
            decoration: BoxDecoration(
              color: estado.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: estado.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  estado.texto,
                  style: Tipografia.texto(
                    size: 8,
                    peso: FontWeight.w900,
                    color: estado.color,
                    espaciado: 0.64,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: context.colorTarjeta,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colorBordeTarjeta),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 57,
                      height: 50,
                      child: FotoCancha(deporte: e.deporte, tipo: e.tipo, alto: 50),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sede ${e.sede.nombre}',
                          style: Tipografia.texto(
                            size: 15,
                            peso: FontWeight.w700,
                            color: context.colorTexto,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.nombreCompuesto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Tipografia.codigo(
                            size: 9.5,
                            color: context.colorTextoSuave,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const _Separador(),
              _Fila('Fecha', formatearFechaLarga(r.fecha)),
              _Fila('Horario', '${r.horaInicio} a ${r.horaFin}'),
              _Fila('Espacio', espacio),
              _Fila('Dirección', '${e.sede.direccion}, ${e.sede.nombre}'),
              const _Separador(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: Tipografia.texto(size: 11, color: context.colorTextoSuave),
                  ),
                  Text(
                    formatearPrecio(r.precioTotal),
                    style: Tipografia.texto(
                      size: 17,
                      peso: FontWeight.w700,
                      color: context.colorAcento,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (r.recordatorios.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(
            'RECORDATORIOS',
            style: Tipografia.texto(
              size: 9,
              peso: FontWeight.w900,
              color: context.colorAcento,
              espaciado: 2.2,
            ),
          ),
          const SizedBox(height: 10),
          _BloqueRecordatorios(recordatorios: r.recordatorios),
        ],
        if (r.cancelable) ...[
          const SizedBox(height: 24),
          Semantics(
            button: true,
            label: 'Cancelar reserva',
            child: GestureDetector(
              onTap: () => _cancelar(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.85),
                    width: 1.4,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.close, size: 16, color: Color(0xFFF87171)),
                    const SizedBox(width: 10),
                    Text(
                      'Cancelar reserva',
                      style: Tipografia.texto(
                        size: 13.5,
                        peso: FontWeight.w600,
                        color: const Color(0xFFF87171),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  ({String texto, Color color}) _estado(BuildContext context, String estado) =>
      switch (estado) {
        'confirmada' => (texto: 'CONFIRMADA', color: const Color(0xFF00BC7D)),
        'en_curso' => (texto: 'EN CURSO', color: const Color(0xFFD97706)),
        'completada' => (texto: 'COMPLETADA', color: const Color(0xFF4ADE80)),
        'cancelada' => (texto: 'CANCELADA', color: const Color(0xFFF87171)),
        _ => (texto: estado.toUpperCase(), color: context.colorTextoSuave),
      };
}

/// "Recordatorios" del Figma (CU-24.1): cuándo sale cada aviso y si ya salió.
class _BloqueRecordatorios extends StatelessWidget {
  const _BloqueRecordatorios({required this.recordatorios});

  final List<Recordatorio> recordatorios;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: context.colorTarjeta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorBordeTarjeta),
      ),
      child: Column(
        children: [
          for (final r in recordatorios) _FilaRecordatorio(recordatorio: r),
        ],
      ),
    );
  }
}

class _FilaRecordatorio extends StatelessWidget {
  const _FilaRecordatorio({required this.recordatorio});

  final Recordatorio recordatorio;

  @override
  Widget build(BuildContext context) {
    final r = recordatorio;
    final (texto, color) = switch (r.estado) {
      'enviado' => ('Enviado', const Color(0xFF00BC7D)),
      'no_enviado' => ('No enviado', const Color(0xFFD97706)),
      _ => ('Pendiente', context.colorTextoSuave),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: r.estado == 'enviado' ? context.colorAcento : context.colorTextoTenue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.etiqueta,
                  style: Tipografia.texto(
                    size: 13,
                    peso: FontWeight.w600,
                    color: context.colorTexto,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatearFechaYHora(r.programadoPara),
                  style: Tipografia.texto(size: 10.5, color: context.colorTextoSuave),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              texto,
              style: Tipografia.texto(size: 10, peso: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Divider(height: 1, color: context.colorBordeTarjeta),
      );
}

class _Fila extends StatelessWidget {
  const _Fila(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            etiqueta,
            style: Tipografia.texto(size: 11, color: context.colorTextoSuave),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: Tipografia.texto(
                size: 11.5,
                peso: FontWeight.w600,
                color: context.colorTexto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

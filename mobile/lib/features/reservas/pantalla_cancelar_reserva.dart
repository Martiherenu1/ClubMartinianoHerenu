/// Confirmación de cancelación (CU-10): "¿Querés cancelar la reserva?".
///
/// Devuelve `true` al volver si la reserva quedó cancelada.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/tema.dart';
import '../../core/api_client.dart';
import '../../core/errores.dart';
import '../../data/reservas_api.dart';
import '../../widgets/carga_async.dart';
import '../shell/navegacion_principal.dart';
import 'tarjeta_reserva.dart';

class PantallaCancelarReserva extends StatefulWidget {
  const PantallaCancelarReserva({super.key, required this.reserva});

  final Reserva reserva;

  @override
  State<PantallaCancelarReserva> createState() => _PantallaCancelarReservaState();
}

class _PantallaCancelarReservaState extends State<PantallaCancelarReserva> {
  bool _cancelando = false;

  Future<void> _cancelar() async {
    if (_cancelando) return;
    setState(() => _cancelando = true);
    try {
      await ReservasApi(context.read<ApiClient>()).cancelar(widget.reserva.id);
      if (!mounted) return;
      context.read<ReservasCambiadas>().avisar();
      Navigator.of(context).pop(true);
    } on ErrorApp catch (e) {
      if (!mounted) return;
      setState(() => _cancelando = false);
      await mostrarFallo(context, e);
      if (!mounted) return;
      // 409 (ya empezó, terminó o estaba cancelada): el estado cambió, se vuelve a
      // la lista para que se actualice.
      if (e is ErrorNegocio) {
        context.read<ReservasCambiadas>().avisar();
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = context.esModoOscuro;
    final arriba = MediaQuery.paddingOf(context).top;
    final colorBorde = oscuro ? Colors.white : const Color(0xFF0B0C16);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(18, arriba + 14, 18, 24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: 'Volver',
              child: GestureDetector(
                onTap: _cancelando ? null : () => Navigator.of(context).pop(false),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.colorTexto.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.chevron_left, color: context.colorTexto),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '¿Querés cancelar la reserva?',
            style: Tipografia.titulo(size: 22, color: context.colorTexto),
          ),
          const SizedBox(height: 6),
          Text(
            'El espacio quedará liberado inmediatamente para otros jugadores. '
            'Esta acción no se puede revertir.',
            style: Tipografia.texto(size: 12, color: context.colorTextoSuave),
          ),
          const SizedBox(height: 24),
          TarjetaReserva(reserva: widget.reserva, mostrarEstado: false),
          const SizedBox(height: 28),
          Semantics(
            button: true,
            child: GestureDetector(
              onTap: _cancelar,
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _cancelando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                      )
                    : Text(
                        'Cancelar reserva',
                        style: Tipografia.texto(
                          size: 14,
                          peso: FontWeight.w600,
                          color: const Color(0xFF010107),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            child: GestureDetector(
              onTap: _cancelando ? null : () => Navigator.of(context).pop(false),
              child: Container(
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorBorde),
                ),
                child: Text(
                  'Volver',
                  style: Tipografia.texto(
                    size: 14,
                    peso: FontWeight.w600,
                    color: colorBorde,
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

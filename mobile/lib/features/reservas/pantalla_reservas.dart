/// Mis reservas (CU-08): próximas e historial, con acceso al detalle y a la
/// cancelación (CU-10).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/tema.dart';
import '../../core/api_client.dart';
import '../../data/reservas_api.dart';
import '../../widgets/carga_async.dart';
import '../../widgets/selector_segmentado.dart';
import '../shell/navegacion_principal.dart';
import 'pantalla_cancelar_reserva.dart';
import 'pantalla_detalle_reserva.dart';
import 'tarjeta_reserva.dart';

class _DatosReservas {
  const _DatosReservas({required this.proximas, required this.historial});

  final List<Reserva> proximas;
  final List<Reserva> historial;
}

class PantallaReservas extends StatelessWidget {
  const PantallaReservas({super.key});

  Future<_DatosReservas> _cargar(BuildContext context) async {
    final api = ReservasApi(context.read<ApiClient>());
    // En paralelo; `Future.wait` deja pasar el error original (401, sin conexión…).
    final r = await Future.wait([
      api.listar(vista: VistaReservas.proximas),
      api.listar(vista: VistaReservas.historial),
    ]);
    return _DatosReservas(proximas: r[0], historial: r[1]);
  }

  @override
  Widget build(BuildContext context) {
    // Al crear o cancelar una reserva cambia la clave y se vuelve a pedir todo.
    final version = context.watch<ReservasCambiadas>().version;
    return CargaAsync<_DatosReservas>(
      key: ValueKey(version),
      cargar: () => _cargar(context),
      construir: (context, datos) => _ContenidoReservas(datos: datos),
    );
  }
}

class _ContenidoReservas extends StatefulWidget {
  const _ContenidoReservas({required this.datos});

  final _DatosReservas datos;

  @override
  State<_ContenidoReservas> createState() => _ContenidoReservasState();
}

class _ContenidoReservasState extends State<_ContenidoReservas> {
  int _vista = 0; // 0 = próximas, 1 = historial

  Future<void> _cancelar(Reserva reserva) async {
    final mensajero = ScaffoldMessenger.of(context);
    final cancelada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PantallaCancelarReserva(reserva: reserva)),
    );
    if (cancelada == true) {
      mensajero.showSnackBar(const SnackBar(content: Text('Reserva cancelada')));
    }
  }

  void _abrirDetalle(Reserva reserva) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => PantallaDetalleReserva(reservaId: reserva.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.datos;
    final arriba = MediaQuery.paddingOf(context).top;
    final lista = _vista == 0 ? d.proximas : d.historial;

    return ListView(
      padding: EdgeInsets.fromLTRB(18, arriba + 24, 18, 24),
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'MIS '),
              TextSpan(text: 'RESERVAS', style: TextStyle(color: context.colorAcento)),
            ],
          ),
          style: Tipografia.titulo(size: 40, color: context.colorTexto),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 18),
          child: Text(
            '${d.proximas.length} ${d.proximas.length == 1 ? 'activa' : 'activas'}'
            ' · ${d.historial.length} historial',
            style: Tipografia.texto(size: 11, color: context.colorTextoSuave),
          ),
        ),
        SelectorSegmentado(
          opciones: ['Próximas (${d.proximas.length})', 'Historial'],
          seleccionada: _vista,
          alElegir: (i) => setState(() => _vista = i),
          tamanoTexto: 13,
        ),
        const SizedBox(height: 14),
        if (lista.isEmpty)
          _SinReservas(proximas: _vista == 0)
        else
          for (final r in lista) ...[
            TarjetaReserva(
              reserva: r,
              alPresionar: () => _abrirDetalle(r),
              alCancelar: r.cancelable ? () => _cancelar(r) : null,
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _SinReservas extends StatelessWidget {
  const _SinReservas({required this.proximas});

  final bool proximas;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavegacionPrincipal>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          Text(
            proximas ? 'No tenés reservas próximas' : 'Todavía no tenés historial',
            style: Tipografia.titulo(size: 22, color: context.colorTexto),
          ),
          const SizedBox(height: 6),
          Text(
            proximas
                ? 'Elegí una sede y reservá tu cancha.'
                : 'Acá van a aparecer las reservas que ya pasaron o cancelaste.',
            textAlign: TextAlign.center,
            style: Tipografia.texto(size: 13, color: context.colorTextoSuave),
          ),
          if (proximas) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => nav.irA(Pestana.sedes),
              style: FilledButton.styleFrom(minimumSize: const Size(180, 46)),
              child: const Text('VER SEDES'),
            ),
          ],
        ],
      ),
    );
  }
}

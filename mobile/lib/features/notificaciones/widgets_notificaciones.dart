/// Piezas de interfaz de las notificaciones (CU-24), del Figma "P-24.1":
/// el modal de permiso, la campana con su panel y la tarjeta "Recordatorios
/// activos" de la Home.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/tema.dart';
import '../../core/api_client.dart';
import '../../core/formato.dart';
import '../../core/servicio_notificaciones.dart';
import '../../data/notificaciones_api.dart';
import '../shell/navegacion_principal.dart';
import 'controlador_notificaciones.dart';

/// "Activá los recordatorios": explica para qué sirven antes de pedir el permiso
/// al sistema. Devuelve `true` si el usuario quiere habilitarlos.
Future<bool> mostrarModalPermiso(BuildContext context) async {
  final acepto = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ModalPermiso(),
  );
  return acepto ?? false;
}

class _ModalPermiso extends StatelessWidget {
  const _ModalPermiso();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: context.colorBordeTarjeta),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colores.lima,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.notifications_active_outlined,
                  size: 30, color: Colors.black),
            ),
            const SizedBox(height: 18),
            Text(
              'ACTIVÁ LOS',
              textAlign: TextAlign.center,
              style: Tipografia.titulo(size: 28, color: context.colorTexto),
            ),
            Text(
              'RECORDATORIOS',
              textAlign: TextAlign.center,
              style: Tipografia.titulo(size: 28, color: context.colorAcento),
            ),
            const SizedBox(height: 10),
            Text(
              'Te avisamos 24 horas y 1 hora antes de cada reserva, para que no '
              'pierdas ningún turno.',
              textAlign: TextAlign.center,
              style: Tipografia.texto(size: 12.5, color: context.colorTextoSuave)
                  .copyWith(height: 1.5),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('HABILITAR NOTIFICACIONES'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Ahora no',
                style: Tipografia.texto(size: 13, color: context.colorTextoSuave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de la Home: dice si los recordatorios están activos y, si no, deja
/// activarlos.
class TarjetaRecordatorios extends StatelessWidget {
  const TarjetaRecordatorios({super.key});

  Future<void> _activar(BuildContext context) async {
    final controlador = context.read<ControladorNotificaciones>();
    final mensajero = ScaffoldMessenger.of(context);
    final permiso = await controlador.habilitar();
    if (permiso != PermisoNotificaciones.concedido) {
      // Android no vuelve a preguntar después de un rechazo: hay que ir a Ajustes.
      mensajero.showSnackBar(const SnackBar(
        content: Text(
          'Para recibir recordatorios, habilitá las notificaciones de la app '
          'desde los ajustes del celular.',
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final activos =
        context.watch<ControladorNotificaciones>().permiso == PermisoNotificaciones.concedido;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colorTarjeta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorBordeTarjeta),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.colorAcento.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              activos ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
              size: 19,
              color: context.colorAcento,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activos ? 'Recordatorios activos' : 'Recordatorios desactivados',
                  style: Tipografia.texto(
                    size: 13,
                    peso: FontWeight.w700,
                    color: context.colorTexto,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  activos
                      ? 'Te avisamos 24 hs y 1 hora antes de cada reserva.'
                      : 'Activalos y te avisamos 24 hs y 1 hora antes de cada reserva.',
                  style: Tipografia.texto(size: 11, color: context.colorTextoSuave),
                ),
              ],
            ),
          ),
          if (!activos)
            TextButton(
              onPressed: () => _activar(context),
              child: Text(
                'Activar',
                style: Tipografia.texto(
                  size: 12,
                  peso: FontWeight.w700,
                  color: context.colorAcento,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Campana de la cabecera de la Home. Con un punto lima cuando hay avisos que el
/// usuario todavía no vio; al tocarla abre el panel "Notificaciones".
class CampanaNotificaciones extends StatefulWidget {
  const CampanaNotificaciones({super.key});

  @override
  State<CampanaNotificaciones> createState() => _CampanaNotificacionesState();
}

class _CampanaNotificacionesState extends State<CampanaNotificaciones> {
  List<AvisoRecibido> _avisos = const [];
  DateTime? _vistoHasta;
  int? _versionCargada;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cada aviso que llega con la app abierta vuelve a pedir la lista.
    final version = context.watch<ControladorNotificaciones>().version;
    if (version != _versionCargada) {
      _versionCargada = version;
      _cargar();
    }
  }

  Future<void> _cargar() async {
    final controlador = context.read<ControladorNotificaciones>();
    final api = NotificacionesApi(context.read<ApiClient>());
    try {
      final avisos = await api.listar();
      final visto = await controlador.vistoHasta();
      if (!mounted) return;
      setState(() {
        _avisos = avisos;
        _vistoHasta = visto;
      });
    } catch (_) {
      // La campana es accesoria: si falla, se queda como estaba.
    }
  }

  bool _sinLeer(AvisoRecibido a) => _vistoHasta == null || a.instante.isAfter(_vistoHasta!);

  Future<void> _abrirPanel() async {
    final nav = context.read<NavegacionPrincipal>();
    final controlador = context.read<ControladorNotificaciones>();
    await _cargar();
    if (!mounted) return;
    final reservaId = await showDialog<int>(
      context: context,
      builder: (_) => _PanelNotificaciones(avisos: _avisos, sinLeer: _sinLeer),
    );
    // Al cerrar el panel, todo lo que estaba en la lista queda como visto.
    if (_avisos.isNotEmpty) {
      final ultimo = _avisos.map((a) => a.instante).reduce((a, b) => a.isAfter(b) ? a : b);
      await controlador.marcarVistoHasta(ultimo);
      if (mounted) setState(() => _vistoHasta = ultimo);
    }
    if (reservaId != null) nav.abrirReserva(reservaId);
  }

  @override
  Widget build(BuildContext context) {
    final haySinLeer = _avisos.any(_sinLeer);
    return Semantics(
      button: true,
      label: haySinLeer ? 'Notificaciones, hay avisos nuevos' : 'Notificaciones',
      child: GestureDetector(
        onTap: _abrirPanel,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_none, size: 19, color: Colors.white),
              ),
              if (haySinLeer)
                Positioned(
                  top: 3,
                  right: 3,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colores.lima,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelNotificaciones extends StatelessWidget {
  const _PanelNotificaciones({required this.avisos, required this.sinLeer});

  final List<AvisoRecibido> avisos;
  final bool Function(AvisoRecibido) sinLeer;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 60),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.colorBordeTarjeta),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notificaciones',
                      style: Tipografia.texto(
                        size: 15,
                        peso: FontWeight.w700,
                        color: context.colorTexto,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, size: 18, color: context.colorTextoSuave),
                  ),
                ],
              ),
            ),
            if (avisos.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                child: Text(
                  'Todavía no tenés notificaciones.',
                  style: Tipografia.texto(size: 13, color: context.colorTextoSuave),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  itemCount: avisos.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: context.colorBordeTarjeta),
                  itemBuilder: (context, i) {
                    final a = avisos[i];
                    final nuevo = sinLeer(a);
                    return InkWell(
                      onTap: () => Navigator.of(context).pop(a.reservaId),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: nuevo
                                      ? context.colorAcento
                                      : context.colorTextoTenue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.titulo,
                                    style: Tipografia.texto(
                                      size: 13,
                                      peso: FontWeight.w700,
                                      color: nuevo
                                          ? context.colorTexto
                                          : context.colorTextoSuave,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    a.cuerpo.replaceAll('\n', ' · '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Tipografia.texto(
                                      size: 11.5,
                                      color: context.colorTextoSuave,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    formatearFechaYHora(a.enviadaEn),
                                    style: Tipografia.texto(
                                      size: 10,
                                      color: context.colorTextoTenue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

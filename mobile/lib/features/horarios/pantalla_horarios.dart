/// Horarios de una cancha (CU-12) y reserva (CU-09), en una sola pantalla como
/// en el Figma: cancha, fecha, duración, grilla de franjas, resumen y botón.
///
/// Cada cambio de cancha, fecha o duración vuelve a consultar la API
/// (`GET /espacios/{id}/disponibilidad`): la disponibilidad nunca se calcula en
/// la app. Las franjas ocupadas o pasadas se ven deshabilitadas.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../app/tema.dart';
import '../../core/api_client.dart';
import '../../core/errores.dart';
import '../../core/formato.dart';
import '../../data/catalogo_api.dart';
import '../../data/disponibilidad_api.dart';
import '../../data/reservas_api.dart';
import '../../widgets/carga_async.dart';
import '../../widgets/imagen_catalogo.dart';
import '../shell/navegacion_principal.dart';
import 'pantalla_reserva_confirmada.dart';

/// Cuántos días hacia adelante se puede elegir (hoy incluido).
const diasReservables = 14;

class PantallaHorarios extends StatefulWidget {
  const PantallaHorarios({super.key, required this.espacio});

  final Espacio espacio;

  @override
  State<PantallaHorarios> createState() => _PantallaHorariosState();
}

class _PantallaHorariosState extends State<PantallaHorarios> {
  late Espacio _espacio = widget.espacio;

  /// Canchas del mismo deporte y tipo en la sede ("Cancha 1", "Cancha 2").
  late List<Espacio> _canchas = [widget.espacio];

  late final List<DateTime> _fechas = () {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    return List.generate(diasReservables, (i) => DateTime(hoy.year, hoy.month, hoy.day + i));
  }();

  late DateTime _fecha = _fechas.first;
  int _duracion = 1;
  String? _horaElegida;
  bool _reservando = false;

  /// Sube cuando hay que volver a consultar sin que cambie ningún filtro
  /// (por ejemplo, si alguien nos ganó de mano el horario).
  int _recarga = 0;

  @override
  void initState() {
    super.initState();
    _cargarCanchas();
  }

  Future<void> _cargarCanchas() async {
    try {
      final lista = await CatalogoApi(context.read<ApiClient>()).espacios(
        sedeId: widget.espacio.sede.id,
        deporte: widget.espacio.deporte,
        tipo: widget.espacio.tipo,
      );
      if (!mounted || lista.isEmpty) return;
      setState(() => _canchas = lista..sort((a, b) => a.numero.compareTo(b.numero)));
    } on ErrorApp {
      // Sin la lista alcanza con la cancha elegida; si hay un problema real,
      // la consulta de horarios lo muestra.
    }
  }

  void _cambiar(VoidCallback cambio) {
    setState(() {
      cambio();
      _horaElegida = null; // las franjas ya no son las mismas
    });
  }

  Future<void> _reservar() async {
    final hora = _horaElegida;
    if (hora == null || _reservando) return;
    setState(() => _reservando = true);
    try {
      await ReservasApi(context.read<ApiClient>()).crear(
        espacioId: _espacio.id,
        fecha: _fecha,
        horaInicio: hora,
        duracion: _duracion,
      );
      if (!mounted) return;
      setState(() => _reservando = false);

      final raiz = Navigator.of(context, rootNavigator: true);
      final local = Navigator.of(context);
      final nav = context.read<NavegacionPrincipal>();
      context.read<ReservasCambiadas>().avisar();
      await raiz.push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => PantallaReservaConfirmada(
            alTerminar: () {
              raiz.pop();
              local.popUntil((r) => r.isFirst);
              nav.irA(Pestana.reservas);
            },
          ),
        ),
      );
    } on ErrorApp catch (e) {
      if (!mounted) return;
      setState(() {
        _reservando = false;
        // Error de negocio (ej. HORARIO_OCUPADO): la franja elegida ya no sirve
        // y la grilla se actualiza. Con un error de red se conserva la elección.
        if (e is ErrorNegocio) {
          _horaElegida = null;
          _recarga++;
        }
      });
      await mostrarFallo(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final panel = context.colorPanel;
    return Scaffold(
      backgroundColor: panel,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Encabezado(espacio: _espacio),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_canchas.length > 1) ...[
                  const _Etiqueta('Seleccioná cancha', primera: true),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final c in _canchas)
                        _BotonCancha(
                          espacio: c,
                          seleccionada: c.id == _espacio.id,
                          alPresionar: () => _cambiar(() => _espacio = c),
                        ),
                    ],
                  ),
                ],
                _Etiqueta('Fecha', primera: _canchas.length <= 1),
                // Sin alto fijo: la tira toma el de sus botones.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in _fechas) ...[
                        _BotonFecha(
                          fecha: f,
                          seleccionada: f == _fecha,
                          alPresionar: () => _cambiar(() => _fecha = f),
                        ),
                        const SizedBox(width: 7),
                      ],
                    ],
                  ),
                ),
                const _Etiqueta('Duración'),
                _SelectorDuracion(
                  duracion: _duracion,
                  alElegir: (h) => _cambiar(() => _duracion = h),
                ),
                const _Etiqueta('Horario disponible'),
                // La clave vuelve a pedir la grilla cuando cambia cualquier filtro.
                CargaAsync<Disponibilidad>(
                  key: ValueKey('${_espacio.id}|${fechaIso(_fecha)}|$_duracion|$_recarga'),
                  cargar: () => DisponibilidadApi(context.read<ApiClient>()).consultar(
                    espacioId: _espacio.id,
                    fecha: _fecha,
                    duracion: _duracion,
                  ),
                  construir: (context, d) => _Resultado(
                    disponibilidad: d,
                    horaElegida: _horaElegida,
                    reservando: _reservando,
                    alElegirHora: (h) => setState(() => _horaElegida = h),
                    alReservar: _reservar,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Colores propios de esta pantalla (la hoja inferior y los botones).
extension on BuildContext {
  Color get colorPanel => esModoOscuro ? const Color(0xFF0D0D18) : Colors.white;

  Color get colorBoton => esModoOscuro
      ? Colors.white.withValues(alpha: 0.06)
      : Colores.superficieClara;

  Color get colorBordeBoton =>
      esModoOscuro ? Colors.white.withValues(alpha: 0.12) : Colors.transparent;

  Color get colorTextoBoton => esModoOscuro ? const Color(0xFFF0F1F8) : const Color(0xFF0B0C16);

  Color get colorTextoApagado => esModoOscuro
      ? Colors.white.withValues(alpha: 0.42)
      : Colors.black.withValues(alpha: 0.45);
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.espacio});

  final Espacio espacio;

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: 200 + arriba,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FotoSede(nombre: espacio.sede.nombre),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.78),
                  Colors.black.withValues(alpha: 0.42),
                  Colors.black.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
                stops: const [0, 0.45, 0.75, 1],
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            top: arriba + 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chevron_left,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      Text(
                        'Sedes',
                        style: Tipografia.texto(
                          size: 13,
                          peso: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  '${espacio.deporte} · ${etiquetaTipo(espacio.tipo)}'.toUpperCase(),
                  style: Tipografia.texto(
                    size: 10,
                    color: Colors.white.withValues(alpha: 0.6),
                    espaciado: 3,
                  ),
                ),
                Text(
                  'SEDE ${espacio.sede.nombre.toUpperCase()}',
                  style: Tipografia.titulo(size: 28, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  espacio.nombreCompuesto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Tipografia.codigo(size: 9, color: Colores.lima),
                ),
              ],
            ),
          ),
          // Borde superior redondeado de la hoja, que "sube" sobre la foto.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 28,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.colorPanel,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colorTextoApagado.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
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

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto, {this.primera = false});

  final String texto;
  final bool primera;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: primera ? 4 : 18, bottom: 8),
      child: Text(
        texto.toUpperCase(),
        style: Tipografia.texto(
          size: 10,
          color: context.colorTextoApagado,
          espaciado: 2.2,
        ),
      ),
    );
  }
}

class _BotonCancha extends StatelessWidget {
  const _BotonCancha({
    required this.espacio,
    required this.seleccionada,
    required this.alPresionar,
  });

  final Espacio espacio;
  final bool seleccionada;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: seleccionada,
      child: GestureDetector(
        onTap: alPresionar,
        child: Container(
          constraints: const BoxConstraints(minWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: seleccionada ? Colores.lima : context.colorBoton,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: seleccionada ? Colors.transparent : context.colorBordeBoton,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cancha ${espacio.numero}',
                style: Tipografia.titulo(
                  size: 18,
                  color: seleccionada ? Colors.black : context.colorTextoBoton,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                espacio.cubierto ? 'Indoor' : 'Outdoor',
                style: Tipografia.texto(
                  size: 9,
                  peso: FontWeight.w700,
                  color: seleccionada
                      ? Colors.black.withValues(alpha: 0.55)
                      : context.colorTextoApagado,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonFecha extends StatelessWidget {
  const _BotonFecha({
    required this.fecha,
    required this.seleccionada,
    required this.alPresionar,
  });

  final DateTime fecha;
  final bool seleccionada;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final color = seleccionada ? Colors.black : context.colorTextoApagado;
    return Semantics(
      button: true,
      selected: seleccionada,
      label: formatearFechaCorta(fecha),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: alPresionar,
        child: Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: seleccionada ? Colores.lima : context.colorBoton,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: seleccionada ? Colors.transparent : context.colorBordeBoton,
            ),
          ),
          child: Column(
            children: [
              Text(
                diaSemanaCorto(fecha).toUpperCase(),
                style: Tipografia.texto(size: 9, peso: FontWeight.w900, color: color),
              ),
              Text(
                '${fecha.day}',
                style: Tipografia.titulo(size: 24, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectorDuracion extends StatelessWidget {
  const _SelectorDuracion({required this.duracion, required this.alElegir});

  final int duracion;
  final ValueChanged<int> alElegir;

  @override
  Widget build(BuildContext context) {
    Widget opcion(int horas, String texto) {
      final activa = duracion == horas;
      return Expanded(
        child: Semantics(
          button: true,
          selected: activa,
          child: GestureDetector(
            onTap: () => alElegir(horas),
            child: Container(
              height: 41,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: activa ? Colores.lima : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                texto,
                style: Tipografia.texto(
                  size: 14,
                  peso: FontWeight.w900,
                  color: activa ? Colors.black : context.colorTextoApagado,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colorBoton,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colorBordeBoton),
      ),
      child: Row(children: [opcion(1, '1 hora'), opcion(2, '2 horas')]),
    );
  }
}

/// Lo que depende de la consulta: grilla, aviso de ocupados, resumen y botón.
class _Resultado extends StatelessWidget {
  const _Resultado({
    required this.disponibilidad,
    required this.horaElegida,
    required this.reservando,
    required this.alElegirHora,
    required this.alReservar,
  });

  final Disponibilidad disponibilidad;
  final String? horaElegida;
  final bool reservando;
  final ValueChanged<String> alElegirHora;
  final VoidCallback alReservar;

  @override
  Widget build(BuildContext context) {
    final d = disponibilidad;
    final hayHorarios = d.cantidadDisponibles > 0;
    Franja? elegida;
    for (final f in d.franjas) {
      if (f.horaInicio == horaElegida && f.disponible) elegida = f;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hayHorarios)
          const _SinHorarios()
        else ...[
          LayoutBuilder(
            builder: (context, c) {
              final ancho = (c.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in d.franjas)
                    SizedBox(
                      width: ancho,
                      child: _BotonFranja(
                        franja: f,
                        seleccionada: f.horaInicio == horaElegida && f.disponible,
                        alPresionar: () => alElegirHora(f.horaInicio),
                      ),
                    ),
                ],
              );
            },
          ),
          if (d.cantidadNoDisponibles > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: context.colorBoton,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: context.esModoOscuro
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Algunos horarios están ocupados · ${d.cantidadNoDisponibles} no disponibles',
                      style: Tipografia.texto(size: 10, color: context.colorTextoApagado),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 16),
            child: _Resumen(disponibilidad: d, franja: elegida),
          ),
        ],
        if (!hayHorarios) const SizedBox(height: 24),
        _BotonConfirmar(
          habilitado: elegida != null,
          cargando: reservando,
          alPresionar: alReservar,
        ),
      ],
    );
  }
}

class _BotonFranja extends StatelessWidget {
  const _BotonFranja({
    required this.franja,
    required this.seleccionada,
    required this.alPresionar,
  });

  final Franja franja;
  final bool seleccionada;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final oscuro = context.esModoOscuro;
    final libre = franja.disponible;
    final Color fondo;
    final Color texto;
    if (seleccionada) {
      fondo = Colores.lima;
      texto = Colors.black;
    } else if (libre) {
      fondo = context.colorBoton;
      texto = context.colorTextoBoton;
    } else {
      fondo = oscuro
          ? Colors.white.withValues(alpha: 0.025)
          : Colores.superficieClara.withValues(alpha: 0.5);
      texto = oscuro
          ? Colors.white.withValues(alpha: 0.2)
          : Colors.black.withValues(alpha: 0.25);
    }

    return Semantics(
      button: true,
      enabled: libre,
      selected: seleccionada,
      label: libre ? franja.rotulo : '${franja.rotulo}, no disponible',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: libre ? alPresionar : null,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: seleccionada || !libre ? Colors.transparent : context.colorBordeBoton,
            ),
          ),
          child: Text(
            franja.rotulo,
            style: GoogleFonts.barlowCondensed(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.26,
              color: texto,
            ),
          ),
        ),
      ),
    );
  }
}

class _SinHorarios extends StatelessWidget {
  const _SinHorarios();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colores.lima,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'NO HAY HORARIOS DISPONIBLES',
              textAlign: TextAlign.center,
              style: Tipografia.titulo(size: 24, color: context.colorTextoBoton),
            ),
            const SizedBox(height: 8),
            Text(
              'No quedan turnos libres para esta fecha.',
              style: Tipografia.texto(size: 13, color: context.colorTextoApagado),
            ),
            const SizedBox(height: 4),
            Text(
              'Probá seleccionando otra fecha arriba.',
              style: Tipografia.texto(size: 13, color: context.colorTextoApagado),
            ),
          ],
        ),
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.disponibilidad, required this.franja});

  final Disponibilidad disponibilidad;
  final Franja? franja;

  @override
  Widget build(BuildContext context) {
    final d = disponibilidad;
    final e = d.espacio;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorBoton,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorBordeBoton),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      etiquetaTipo(e.tipo),
                      style: Tipografia.texto(
                        size: 13,
                        peso: FontWeight.w700,
                        color: context.colorTextoBoton,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${e.deporte} · ${d.duracion}h',
                      style: Tipografia.texto(size: 11, color: context.colorTextoApagado),
                    ),
                  ],
                ),
              ),
              Text(
                '${formatearPrecio(d.precioHora)} × ${d.duracion}',
                style: Tipografia.codigo(size: 12, color: context.colorTextoApagado),
              ),
            ],
          ),
          Divider(
            height: 25,
            color: context.esModoOscuro
                ? Colors.white.withValues(alpha: 0.09)
                : Colors.black.withValues(alpha: 0.08),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total',
                      style: Tipografia.texto(size: 11, color: context.colorTextoApagado),
                    ),
                    Text(
                      formatearPrecio(d.precioTotal),
                      style: Tipografia.titulo(size: 36, color: context.colorTextoBoton),
                    ),
                  ],
                ),
              ),
              if (franja != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      franja!.rotulo,
                      style: Tipografia.titulo(size: 20, color: context.colorAcento),
                    ),
                    Text(
                      formatearFechaCorta(d.fecha),
                      style: Tipografia.texto(size: 11, color: context.colorTextoApagado),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BotonConfirmar extends StatelessWidget {
  const _BotonConfirmar({
    required this.habilitado,
    required this.cargando,
    required this.alPresionar,
  });

  final bool habilitado;
  final bool cargando;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final activo = habilitado && !cargando;
    return Semantics(
      button: true,
      enabled: activo,
      child: GestureDetector(
        onTap: activo ? alPresionar : null,
        child: Container(
          height: 54.5,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: habilitado ? Colores.lima : context.colorBoton,
            borderRadius: BorderRadius.circular(14),
            boxShadow: habilitado
                ? [
                    BoxShadow(
                      color: Colores.lima.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: cargando
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                )
              : Text(
                  habilitado ? 'CONFIRMAR RESERVA' : 'SELECCIONÁ UN HORARIO',
                  style: Tipografia.titulo(
                    size: 15,
                    color: habilitado
                        ? Colors.black
                        : (context.esModoOscuro
                            ? Colors.white.withValues(alpha: 0.18)
                            : Colors.black.withValues(alpha: 0.3)),
                  ).copyWith(letterSpacing: 1.5),
                ),
        ),
      ),
    );
  }
}

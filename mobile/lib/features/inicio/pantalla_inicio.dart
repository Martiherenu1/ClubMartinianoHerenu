/// Home: saludo, próxima reserva, filtro por deporte y sedes disponibles.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/tema.dart';
import '../../core/api_client.dart';
import '../../core/errores.dart';
import '../../core/formato.dart';
import '../../data/catalogo_api.dart';
import '../../data/reservas_api.dart';
import '../../data/usuarios_api.dart';
import '../../widgets/carga_async.dart';
import '../../widgets/etiquetas.dart';
import '../../widgets/imagen_catalogo.dart';
import '../shell/navegacion_principal.dart';

class _DatosInicio {
  const _DatosInicio({required this.usuario, required this.sedes, required this.proxima});

  final Usuario usuario;
  final List<Sede> sedes;

  /// La reserva que viene primero, o `null` si no hay ninguna.
  final Reserva? proxima;
}

class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  Future<_DatosInicio> _cargar(BuildContext context) async {
    final api = context.read<ApiClient>();
    // Los tres pedidos van en paralelo. Se usa `Future.wait` (y no `.wait` de
    // registros) porque deja pasar el error original, que la pantalla necesita
    // para distinguir "sin conexión" de "sesión vencida".
    final r = await Future.wait<Object?>([
      UsuariosApi(api).miPerfil(),
      CatalogoApi(api).sedes(),
      ReservasApi(api).listar(),
    ]);
    final reservas = r[2] as List<Reserva>;
    return _DatosInicio(
      usuario: r[0] as Usuario,
      sedes: r[1] as List<Sede>,
      proxima: reservas.isEmpty ? null : reservas.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cuando se crea o cancela una reserva, la clave cambia y la Home vuelve a
    // pedir sus datos (la próxima reserva puede ser otra).
    final version = context.watch<ReservasCambiadas>().version;
    return CargaAsync<_DatosInicio>(
      key: ValueKey(version),
      cargar: () => _cargar(context),
      construir: (context, datos) => _ContenidoInicio(datos: datos),
    );
  }
}

class _ContenidoInicio extends StatefulWidget {
  const _ContenidoInicio({required this.datos});

  final _DatosInicio datos;

  @override
  State<_ContenidoInicio> createState() => _ContenidoInicioState();
}

class _ContenidoInicioState extends State<_ContenidoInicio> {
  late List<Sede> _sedes = widget.datos.sedes;

  /// Deportes para los chips, tomados de todas las sedes (sin filtrar).
  late final List<String> _deportes = ordenarDeportes({
    for (final s in widget.datos.sedes) ...s.nombresDeportes,
  });

  String? _deporte;
  bool _filtrando = false;

  Future<void> _filtrar(String? deporte) async {
    if (deporte == _deporte) return;
    final anterior = _deporte;
    setState(() {
      _deporte = deporte;
      _filtrando = true;
    });
    try {
      final sedes = await CatalogoApi(context.read<ApiClient>()).sedes(deporte: deporte);
      if (!mounted || _deporte != deporte) return;
      setState(() {
        _sedes = sedes;
        _filtrando = false;
      });
    } on ErrorApp catch (e) {
      if (!mounted) return;
      setState(() {
        _deporte = anterior;
        _filtrando = false;
      });
      await mostrarFallo(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavegacionPrincipal>();
    final datos = widget.datos;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Cabecera(usuario: datos.usuario, alPerfil: () => nav.irA(Pestana.perfil)),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProximaReserva(
                reserva: datos.proxima,
                alPresionar: () => nav.irA(
                  datos.proxima == null ? Pestana.sedes : Pestana.reservas,
                ),
              ),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChipDeporte(
                      texto: 'Todos',
                      seleccionado: _deporte == null,
                      alPresionar: () => _filtrar(null),
                    ),
                    for (final d in _deportes) ...[
                      const SizedBox(width: 7),
                      ChipDeporte(
                        texto: d,
                        emoji: emojiDeporte(d),
                        seleccionado: _deporte == d,
                        alPresionar: () => _filtrar(d),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 18, bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SEDES DISPONIBLES',
                      style: Tipografia.titulo(size: 18, color: context.colorTexto)
                          .copyWith(letterSpacing: 0.72),
                    ),
                    GestureDetector(
                      onTap: () => nav.irA(Pestana.sedes),
                      child: Text(
                        'Ver todas →',
                        style: Tipografia.texto(
                          size: 12,
                          peso: FontWeight.w700,
                          color: context.colorAcento,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_filtrando)
                const SizedBox(
                  height: 171,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_sedes.isEmpty)
                Text(
                  'No hay sedes con ese deporte.',
                  style: Tipografia.texto(size: 13, color: context.colorTextoSuave),
                )
              else
                // Sin alto fijo: la fila toma el de la tarjeta más alta.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final sede in _sedes) ...[
                        _TarjetaSedeChica(
                          sede: sede,
                          alPresionar: () => nav.abrirSede(sede),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.usuario, required this.alPerfil});

  final Usuario usuario;
  final VoidCallback alPerfil;

  @override
  Widget build(BuildContext context) {
    final fondo = Theme.of(context).scaffoldBackgroundColor;
    final arriba = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: 240 + arriba,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/hero_home.png', fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.84),
                  Colors.black.withValues(alpha: 0.52),
                  Colors.black.withValues(alpha: 0.08),
                  fondo,
                ],
                stops: const [0, 0.48, 0.72, 1],
              ),
            ),
          ),
          Positioned(
            top: arriba + 14,
            left: 18,
            right: 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${saludoSegunHora(DateTime.now())},'.toUpperCase(),
                        style: Tipografia.texto(
                          size: 10,
                          color: Colors.white.withValues(alpha: 0.44),
                          espaciado: 3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        usuario.nombreCompleto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Tipografia.titulo(size: 20, color: Colors.white)
                            .copyWith(letterSpacing: 0.6),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Mi perfil',
                  child: GestureDetector(
                    onTap: alPerfil,
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Colores.lima,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        iniciales(usuario.nombre, usuario.apellido),
                        style: Tipografia.titulo(size: 13, color: Colors.black),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLUB MARTINIANO HEREÑU',
                  style: Tipografia.texto(
                    size: 9,
                    peso: FontWeight.w900,
                    color: Colores.lima,
                    espaciado: 3.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ZONA DEPORTIVA',
                  style: Tipografia.titulo(size: 30, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProximaReserva extends StatelessWidget {
  const _ProximaReserva({required this.reserva, required this.alPresionar});

  final Reserva? reserva;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final r = reserva;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: alPresionar,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: context.colorTarjeta,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colorBordeTarjeta),
          ),
          child: r == null ? _sinReservas(context) : _conReserva(context, r),
        ),
      ),
    );
  }

  Widget _titulo(BuildContext context, {String? derecha}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'PRÓXIMA RESERVA',
            style: Tipografia.texto(
              size: 10,
              peso: FontWeight.w900,
              color: context.colorAcento,
              espaciado: 2.5,
            ),
          ),
          if (derecha != null)
            Text(
              '$derecha →',
              style: Tipografia.texto(size: 11, color: context.colorTextoSuave),
            ),
        ],
      );

  Widget _sinReservas(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titulo(context),
          const SizedBox(height: 10),
          Text(
            'Todavía no tenés reservas próximas.',
            style: Tipografia.texto(
              size: 14,
              peso: FontWeight.w700,
              color: context.colorTexto,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Elegí una sede y reservá tu cancha →',
            style: Tipografia.texto(size: 12, color: context.colorTextoSuave),
          ),
        ],
      );

  Widget _conReserva(BuildContext context, Reserva r) {
    final e = r.espacio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo(context, derecha: cuandoEs(r.fecha, DateTime.now())),
        const SizedBox(height: 10),
        Row(
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
                  Text(
                    'Sede ${e.sede.nombre}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tipografia.texto(
                      size: 14,
                      peso: FontWeight.w700,
                      color: context.colorTexto,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    e.nombreCompuesto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tipografia.codigo(size: 10, color: context.colorTextoSuave),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  r.horaInicio,
                  style: Tipografia.titulo(size: 15, color: context.colorAcento),
                ),
                Text(
                  r.horaFin,
                  style: Tipografia.texto(size: 11, color: context.colorTextoTenue),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Divider(height: 1, color: context.colorBordeTarjeta),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formatearFechaCorta(r.fecha),
              style: Tipografia.texto(size: 11, color: context.colorTextoSuave),
            ),
            Text(
              formatearPrecio(r.precioTotal),
              style: Tipografia.texto(
                size: 13,
                peso: FontWeight.w700,
                color: context.colorTexto,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TarjetaSedeChica extends StatelessWidget {
  const _TarjetaSedeChica({required this.sede, required this.alPresionar});

  final Sede sede;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Sede ${sede.nombre}',
      child: GestureDetector(
        onTap: alPresionar,
        child: Container(
          width: 210,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.colorTarjeta,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colorBordeTarjeta),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 112,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FotoSede(nombre: sede.nombre, imagenUrl: sede.imagenUrl, alto: 112),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withValues(alpha: 0.84), Colors.transparent],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      bottom: 7,
                      child: Text(
                        sede.nombre.toUpperCase(),
                        style: Tipografia.titulo(size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 9, color: context.colorTextoSuave),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            sede.direccion,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Tipografia.texto(size: 10, color: context.colorTextoSuave),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final d in sede.nombresDeportes.take(2)) EtiquetaDeporte(d),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

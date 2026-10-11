/// Detalle de una sede (CU-13 y CU-20): sus canchas con filtros por deporte y
/// por tipo. Desde acá se pasa a la pantalla de horarios de cada cancha.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/tema.dart';
import '../../core/api_client.dart';
import '../../core/formato.dart';
import '../../data/catalogo_api.dart';
import '../../widgets/carga_async.dart';
import '../../widgets/etiquetas.dart';
import '../../widgets/imagen_catalogo.dart';
import '../horarios/pantalla_horarios.dart';
import 'tarjeta_cancha.dart';

class PantallaSede extends StatefulWidget {
  const PantallaSede({super.key, required this.sede});

  final Sede sede;

  @override
  State<PantallaSede> createState() => _PantallaSedeState();
}

class _PantallaSedeState extends State<PantallaSede> {
  /// Se muestra primero el primer deporte de la sede, como en el Figma.
  late String? _deporte =
      widget.sede.deportes.isEmpty ? null : widget.sede.nombresDeportes.first;
  String? _tipo;

  List<String> get _tipos => widget.sede.deportes
      .where((d) => d.deporte == _deporte)
      .expand((d) => d.tipos)
      .toList();

  void _elegirDeporte(String deporte) {
    if (deporte == _deporte) return;
    setState(() {
      _deporte = deporte;
      _tipo = null; // los tipos dependen del deporte
    });
  }

  void _elegirTipo(String? tipo) {
    if (tipo == _tipo) return;
    setState(() => _tipo = tipo);
  }

  @override
  Widget build(BuildContext context) {
    final sede = widget.sede;
    final fondo = Theme.of(context).scaffoldBackgroundColor;
    final arriba = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 150 + arriba,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FotoSede(nombre: sede.nombre, imagenUrl: sede.imagenUrl),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.black.withValues(alpha: 0.48),
                        Colors.black.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.55, 0.78, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: arriba + 10,
                  left: 18,
                  right: 18,
                  bottom: 12,
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
                              'Todas las sedes',
                              style: Tipografia.texto(
                                size: 13,
                                peso: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'SEDE',
                        style: Tipografia.texto(
                          size: 9,
                          peso: FontWeight.w900,
                          color: Colores.lima,
                          espaciado: 3.4,
                        ),
                      ),
                      Text(
                        sede.titulo,
                        style: Tipografia.titulo(size: 30, color: Colors.white),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 10,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            sede.direccion,
                            style: Tipografia.texto(
                              size: 11,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Filtros: primero deporte y debajo el tipo de cancha.
          Container(
            decoration: BoxDecoration(
              color: fondo,
              border: Border(bottom: BorderSide(color: context.colorBordeTarjeta)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: Row(
                    children: [
                      for (final d in sede.nombresDeportes) ...[
                        ChipDeporte(
                          texto: d,
                          emoji: emojiDeporte(d),
                          seleccionado: d == _deporte,
                          alPresionar: () => _elegirDeporte(d),
                        ),
                        const SizedBox(width: 7),
                      ],
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Row(
                    children: [
                      ChipTipo(
                        texto: 'Todos',
                        seleccionado: _tipo == null,
                        alPresionar: () => _elegirTipo(null),
                      ),
                      for (final t in _tipos) ...[
                        const SizedBox(width: 6),
                        ChipTipo(
                          texto: etiquetaTipo(t),
                          seleccionado: _tipo == t,
                          alPresionar: () => _elegirTipo(t),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_deporte == null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Esta sede todavía no tiene canchas cargadas.',
                style: Tipografia.texto(size: 13, color: context.colorTextoSuave),
              ),
            )
          else
            // La clave obliga a volver a pedir las canchas cuando cambia un filtro.
            CargaAsync<List<Espacio>>(
              key: ValueKey('$_deporte|$_tipo'),
              cargar: () => CatalogoApi(context.read<ApiClient>()).espacios(
                sedeId: sede.id,
                deporte: _deporte,
                tipo: _tipo,
              ),
              construir: (context, espacios) => _ListaCanchas(
                espacios: espacios,
                deporte: _deporte!,
                tipo: _tipo,
              ),
            ),
        ],
      ),
    );
  }
}

class _ListaCanchas extends StatelessWidget {
  const _ListaCanchas({required this.espacios, required this.deporte, required this.tipo});

  final List<Espacio> espacios;
  final String deporte;
  final String? tipo;

  @override
  Widget build(BuildContext context) {
    final n = espacios.length;
    // "Fútbol 5" ya dice el deporte; "Polvo de Ladrillo" no.
    final etiqueta = tipo == null ? null : etiquetaTipo(tipo!);
    final filtro = etiqueta == null
        ? deporte
        : (etiqueta.startsWith(deporte) ? etiqueta : '$deporte · $etiqueta');
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$n ${n == 1 ? 'cancha' : 'canchas'} · $filtro',
            style: Tipografia.texto(size: 11, color: context.colorTextoSuave),
          ),
          const SizedBox(height: 12),
          if (espacios.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No hay canchas con esos filtros.',
                  style: Tipografia.texto(size: 13, color: context.colorTextoSuave),
                ),
              ),
            ),
          for (final e in espacios) ...[
            TarjetaCancha(
              espacio: e,
              alVerHorarios: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => PantallaHorarios(espacio: e)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

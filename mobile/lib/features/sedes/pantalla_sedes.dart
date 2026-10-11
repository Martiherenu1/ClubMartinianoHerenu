/// "Todas las sedes" (CU-16): las cuatro sedes con su dirección, cantidad de
/// canchas y deportes.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/tema.dart';
import '../../core/api_client.dart';
import '../../data/catalogo_api.dart';
import '../../widgets/carga_async.dart';
import '../../widgets/etiquetas.dart';
import '../../widgets/imagen_catalogo.dart';
import 'pantalla_sede.dart';

class PantallaSedes extends StatelessWidget {
  const PantallaSedes({super.key});

  @override
  Widget build(BuildContext context) {
    return CargaAsync<List<Sede>>(
      cargar: () => CatalogoApi(context.read<ApiClient>()).sedes(),
      construir: (context, sedes) => _ListaSedes(sedes: sedes),
    );
  }
}

class _ListaSedes extends StatelessWidget {
  const _ListaSedes({required this.sedes});

  final List<Sede> sedes;

  @override
  Widget build(BuildContext context) {
    final fondo = Theme.of(context).scaffoldBackgroundColor;
    final arriba = MediaQuery.paddingOf(context).top;
    final totalCanchas = sedes.fold<int>(0, (suma, s) => suma + s.cantidadCanchas);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SizedBox(
          height: 150 + arriba,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const FotoSede(nombre: 'Ramos Mejía'),
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
                left: 18,
                right: 18,
                bottom: 10,
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
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'TODAS LAS '),
                          TextSpan(
                            text: 'SEDES',
                            style: TextStyle(color: context.colorAcento),
                          ),
                        ],
                      ),
                      style: Tipografia.titulo(
                        size: 34,
                        color: context.esModoOscuro ? Colors.white : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${sedes.length} sedes · $totalCanchas canchas disponibles',
                      style: Tipografia.texto(
                        size: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: Column(
            children: [
              for (final sede in sedes) ...[
                _TarjetaSede(
                  sede: sede,
                  alPresionar: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => PantallaSede(sede: sede)),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TarjetaSede extends StatelessWidget {
  const _TarjetaSede({required this.sede, required this.alPresionar});

  final Sede sede;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: sede.titulo,
      child: GestureDetector(
        onTap: alPresionar,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.colorTarjeta,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colorBordeTarjeta),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 162,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FotoSede(nombre: sede.nombre, imagenUrl: sede.imagenUrl, alto: 162),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.9),
                            Colors.black.withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                          stops: const [0, 0.45, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 10,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sede.titulo,
                                  style: Tipografia.titulo(size: 22, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.place_outlined,
                                      size: 10,
                                      color: Colors.white.withValues(alpha: 0.42),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        sede.direccion,
                                        overflow: TextOverflow.ellipsis,
                                        style: Tipografia.texto(
                                          size: 11,
                                          color: Colors.white.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.58),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${sede.cantidadCanchas}',
                                  style: Tipografia.titulo(size: 18, color: Colores.lima),
                                ),
                                Text(
                                  'canchas',
                                  style: Tipografia.texto(
                                    size: 9,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [for (final d in sede.nombresDeportes) EtiquetaDeporte(d)],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ver canchas →',
                      style: Tipografia.texto(
                        size: 12,
                        peso: FontWeight.w700,
                        color: context.colorAcento,
                      ),
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

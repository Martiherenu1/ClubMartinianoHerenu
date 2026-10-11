/// Tarjeta de una cancha en el detalle de la sede (CU-13, CU-16).
library;

import 'package:flutter/material.dart';

import '../../app/tema.dart';
import '../../core/formato.dart';
import '../../data/catalogo_api.dart';
import '../../widgets/etiquetas.dart';
import '../../widgets/imagen_catalogo.dart';

class TarjetaCancha extends StatelessWidget {
  const TarjetaCancha({super.key, required this.espacio, required this.alVerHorarios});

  final Espacio espacio;
  final VoidCallback alVerHorarios;

  @override
  Widget build(BuildContext context) {
    final e = espacio;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colorTarjeta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorBordeTarjeta),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 168,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FotoCancha(deporte: e.deporte, tipo: e.tipo, alto: 168),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.88),
                        Colors.black.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.45, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      etiquetaTipo(e.tipo),
                      style: Tipografia.texto(
                        size: 10,
                        peso: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Text(emojiDeporte(e.deporte), style: const TextStyle(fontSize: 16)),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Text(
                    e.nombreCompuesto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tipografia.codigo(size: 9, color: Colores.lima),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          if (e.cubierto)
                            EtiquetaCondicion.indoor(context)
                          else
                            EtiquetaCondicion.outdoor(context),
                          if (e.iluminacion) EtiquetaCondicion.iluminada(context),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatearPrecio(e.precioHora),
                          style: Tipografia.titulo(size: 20, color: context.colorTexto),
                        ),
                        Text(
                          '/ hora',
                          style: Tipografia.texto(size: 10, color: context.colorTextoTenue),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 11, color: context.colorTextoSuave),
                    const SizedBox(width: 4),
                    Text(
                      '${e.horaApertura} – ${e.horaCierre}',
                      style: Tipografia.texto(size: 11, color: context.colorTextoSuave),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                FilledButton.icon(
                  onPressed: alVerHorarios,
                  icon: const Icon(Icons.bolt, size: 16),
                  label: const Text('VER HORARIOS / RESERVAR'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    textStyle: Tipografia.titulo(size: 13).copyWith(letterSpacing: 0.9),
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

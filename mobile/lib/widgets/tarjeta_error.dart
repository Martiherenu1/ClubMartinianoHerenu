/// Tarjetas de error del Figma ("Error de conectividad" y "Error del servidor").
library;

import 'package:flutter/material.dart';

import '../app/tema.dart';
import '../core/errores.dart';

/// Muestra la tarjeta que corresponde al error. Solo para los errores que el
/// usuario no puede corregir editando un campo: sin conexión y servidor.
Future<void> mostrarTarjetaError(BuildContext context, ErrorApp error) {
  final esConexion = error is SinConexion;
  return showDialog<void>(
    context: context,
    builder: (_) => TarjetaError(
      titulo: esConexion ? 'ERROR DE CONECTIVIDAD' : 'ERROR DEL SERVIDOR',
      mensaje: esConexion
          ? 'Parece que no está conectado a ninguna red Wi-Fi. '
              'Reestablezca su conexión e intente otra vez.'
          : 'Ocurrió un error en el servidor. Intente nuevamente más tarde.',
    ),
  );
}

/// Tarjeta oscura con título rojo y mensaje.
///
/// Con [comoDialogo] (por defecto) se usa dentro de `showDialog` y trae el botón
/// "Aceptar". Con `comoDialogo: false` es una tarjeta común para poner en la
/// pantalla (por ejemplo cuando no cargó una lista).
class TarjetaError extends StatelessWidget {
  const TarjetaError({
    super.key,
    required this.titulo,
    required this.mensaje,
    this.comoDialogo = true,
  });

  final String titulo;
  final String mensaje;
  final bool comoDialogo;

  @override
  Widget build(BuildContext context) {
    final cuerpo = Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: Color(0xFFD9575C),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            mensaje,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.45),
          ),
          if (comoDialogo) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.7),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );

    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
    );

    if (comoDialogo) {
      return Dialog(
        backgroundColor: Colores.fondoOscuro,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        shape: forma,
        child: cuerpo,
      );
    }
    return Material(color: Colores.fondoOscuro, shape: forma, child: cuerpo);
  }
}

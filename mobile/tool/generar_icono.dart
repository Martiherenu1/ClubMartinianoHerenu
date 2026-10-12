/// Genera las imágenes del ícono de la app (monograma "CH" en lima sobre el
/// fondo oscuro del club) en `assets/icon/`.
///
/// Se dibuja con formas (sin tipografías) para que salga igual en cualquier
/// máquina. Para regenerarlo, desde `mobile/`:
///
///     flutter test tool/generar_icono.dart
///
/// y después aplicarlo a Android con `dart run flutter_launcher_icons`.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _lado = 1024.0;
const _lima = ui.Color(0xFFD4FF00);
const _fondo = ui.Color(0xFF050508);

/// Monograma "CH": dos letras de bloque de 330 de alto, centradas en el lienzo.
/// Entra holgado en la zona segura de un ícono adaptativo (círculo de ~626 px).
ui.Path _monograma() {
  const alto = 330.0;
  const ancho = 200.0;
  const trazo = 66.0;
  const separacion = 40.0;
  const total = ancho * 2 + separacion;
  const x0 = (_lado - total) / 2;
  const y0 = (_lado - alto) / 2;

  // C: rectángulo redondeado con el centro hueco y abierto a la derecha.
  final exterior = ui.Path()
    ..addRRect(ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTWH(x0, y0, ancho, alto),
      const ui.Radius.circular(54),
    ));
  final hueco = ui.Path()
    ..addRRect(ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTWH(x0 + trazo, y0 + trazo, ancho, alto - trazo * 2),
      const ui.Radius.circular(10),
    ));
  final c = ui.Path.combine(ui.PathOperation.difference, exterior, hueco);

  // H: dos barras y el travesaño.
  const xh = x0 + ancho + separacion;
  final h = ui.Path()
    ..addRRect(ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTWH(xh, y0, trazo, alto),
      const ui.Radius.circular(10),
    ))
    ..addRRect(ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTWH(xh + ancho - trazo, y0, trazo, alto),
      const ui.Radius.circular(10),
    ))
    ..addRect(const ui.Rect.fromLTWH(xh + trazo - 1, y0 + (alto - trazo) / 2, ancho - trazo * 2 + 2, trazo));

  return ui.Path.combine(ui.PathOperation.union, c, h);
}

Future<void> _guardar(String ruta, void Function(ui.Canvas) dibujar) async {
  final grabador = ui.PictureRecorder();
  dibujar(ui.Canvas(grabador, const ui.Rect.fromLTWH(0, 0, _lado, _lado)));
  final imagen = await grabador.endRecording().toImage(_lado.toInt(), _lado.toInt());
  final bytes = (await imagen.toByteData(format: ui.ImageByteFormat.png))!;
  File(ruta)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes.buffer.asUint8List());
}

void main() {
  test('genera el ícono de la app', () async {
    final pincel = ui.Paint()..color = _lima;
    final monograma = _monograma();

    // Ícono completo (Android antiguo): fondo oscuro con las esquinas redondeadas.
    await _guardar('assets/icon/icono.png', (c) {
      c.drawRRect(
        ui.RRect.fromRectAndRadius(
          const ui.Rect.fromLTWH(0, 0, _lado, _lado),
          const ui.Radius.circular(230),
        ),
        ui.Paint()..color = _fondo,
      );
      c.drawPath(monograma, pincel);
    });

    // Primer plano del ícono adaptativo: solo el monograma, sobre transparente
    // (el fondo oscuro lo pone el sistema).
    await _guardar('assets/icon/icono_primer_plano.png', (c) {
      c.drawPath(monograma, pincel);
    });
  });
}

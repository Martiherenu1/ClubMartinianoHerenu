/// Fotos de sedes y canchas.
///
/// Las fotos del Figma viajan dentro de la app (`assets/images`). La API tiene
/// el campo `imagen_url` de la sede por si más adelante se cargan fotos propias:
/// si viene, se usa; si no, se busca la foto incluida por nombre de sede.
library;

import 'package:flutter/material.dart';

const _fondoFoto = Color(0xFF1A1A22);

const _fotosSedes = {
  'morón': 'assets/images/sedes/moron.png',
  'ramos mejía': 'assets/images/sedes/ramos_mejia.png',
  'san justo': 'assets/images/sedes/san_justo.png',
  'castelar': 'assets/images/sedes/castelar.png',
};

/// Foto de una cancha según deporte y tipo; `null` si no hay (ej. Golf).
String? fotoDeCancha(String deporte, String tipo) {
  const base = 'assets/images/canchas/';
  switch (deporte) {
    case 'Fútbol':
      return switch (tipo) {
        'F11' => '${base}futbol_f11.png',
        'F7' || 'F8' => '${base}futbol_f7.png',
        _ => '${base}futbol_f5.png',
      };
    case 'Tenis':
      return tipo.toLowerCase().contains('polvo')
          ? '${base}tenis_polvo.png'
          : '${base}tenis_cemento.png';
    case 'Hockey':
      return '${base}hockey.png';
    case 'Vóley':
      return '${base}voley.png';
  }
  return null;
}

class FotoSede extends StatelessWidget {
  const FotoSede({super.key, required this.nombre, this.imagenUrl, this.alto});

  final String nombre;
  final String? imagenUrl;
  final double? alto;

  @override
  Widget build(BuildContext context) {
    final asset = _fotosSedes[nombre.toLowerCase()];
    return _Foto(url: imagenUrl, asset: asset, alto: alto);
  }
}

class FotoCancha extends StatelessWidget {
  const FotoCancha({super.key, required this.deporte, required this.tipo, this.alto});

  final String deporte;
  final String tipo;
  final double? alto;

  @override
  Widget build(BuildContext context) =>
      _Foto(asset: fotoDeCancha(deporte, tipo), alto: alto);
}

class _Foto extends StatelessWidget {
  const _Foto({this.url, this.asset, this.alto});

  final String? url;
  final String? asset;
  final double? alto;

  @override
  Widget build(BuildContext context) {
    const vacia = ColoredBox(color: _fondoFoto);
    Widget imagen = vacia;
    if (url != null) {
      imagen = Image.network(
        url!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: alto,
        errorBuilder: (_, _, _) => vacia,
      );
    } else if (asset != null) {
      imagen = Image.asset(
        asset!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: alto,
        errorBuilder: (_, _, _) => vacia,
      );
    }
    return SizedBox(height: alto, width: double.infinity, child: imagen);
  }
}

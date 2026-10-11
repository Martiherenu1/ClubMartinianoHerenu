/// API falsa con el catálogo del club para los tests de pantallas.
///
/// Responde como lo hace el backend: `GET /usuarios/me`, `/sedes`, `/espacios` y
/// `/reservas`, con los mismos filtros por query. Guarda cada pedido en
/// [pedidos] para poder comprobar qué parámetros mandó la app.
library;

import 'package:http/http.dart' as http;

import 'ayudas.dart';

Map<String, dynamic> _sede(
  int id,
  String nombre,
  String direccion,
  int canchas,
  Map<String, List<String>> deportes,
) =>
    {
      'id': id,
      'nombre': nombre,
      'direccion': direccion,
      'hora_apertura': '08:00:00',
      'hora_cierre': '23:00:00',
      'imagen_url': null,
      'cantidad_canchas': canchas,
      'deportes': [
        for (final e in deportes.entries) {'deporte': e.key, 'tipos': e.value},
      ],
    };

/// Las cuatro sedes del Figma: 7 + 4 + 6 + 5 = 22 canchas.
final sedesJson = [
  _sede(1, 'Morón', 'Av. Rivadavia 17500', 7, {
    'Fútbol': ['F11', 'F5', 'F7'],
    'Tenis': ['Cemento', 'Polvo de ladrillo'],
  }),
  _sede(2, 'Ramos Mejía', 'Calle Belgrano 1240', 4, {
    'Fútbol': ['F11', 'F5'],
    'Hockey': ['H7'],
    'Vóley': ['Indoor parquet'],
  }),
  _sede(3, 'San Justo', 'Av. Casanova 320', 6, {
    'Fútbol': ['F5', 'F8'],
    'Tenis': ['Sintético'],
    'Golf': ['9 hoyos', 'Driving range'],
  }),
  _sede(4, 'Castelar', 'Av. Rivadavia 22500', 5, {
    'Tenis': ['Cemento', 'Polvo de ladrillo'],
    'Vóley': ['Indoor parquet', 'Playa'],
    'Hockey': ['H11'],
  }),
];

Map<String, dynamic> espacioJson({
  required int id,
  int sedeId = 1,
  String sede = 'Morón',
  String direccion = 'Av. Rivadavia 17500',
  required String deporte,
  required String tipo,
  int numero = 1,
  required String nombre,
  bool cubierto = false,
  bool iluminacion = true,
  num precio = 3800,
}) =>
    {
      'id': id,
      'sede': {'id': sedeId, 'nombre': sede, 'direccion': direccion},
      'deporte': deporte,
      'tipo': tipo,
      'numero': numero,
      'nombre_compuesto': nombre,
      'cubierto': cubierto,
      'iluminacion': iluminacion,
      'precio_hora': precio,
      'hora_apertura': '08:00:00',
      'hora_cierre': '23:00:00',
    };

/// Canchas de Morón (las que muestra la pantalla "Sede Morón" del Figma).
final espaciosMoronJson = [
  espacioJson(
    id: 1,
    deporte: 'Fútbol',
    tipo: 'F5',
    nombre: 'Moron_Rivadavia_Futbol_F5_Cancha_1',
  ),
  espacioJson(
    id: 2,
    deporte: 'Fútbol',
    tipo: 'F5',
    numero: 2,
    nombre: 'Moron_Rivadavia_Futbol_F5_Cancha_2',
    cubierto: true,
    precio: 4200,
  ),
  espacioJson(
    id: 3,
    deporte: 'Fútbol',
    tipo: 'F7',
    nombre: 'Moron_Rivadavia_Futbol_F7_Cancha_1',
    precio: 5500,
  ),
  espacioJson(
    id: 4,
    deporte: 'Fútbol',
    tipo: 'F11',
    nombre: 'Moron_Rivadavia_Futbol_F11_Cancha_1',
    precio: 9000,
  ),
  espacioJson(
    id: 5,
    deporte: 'Tenis',
    tipo: 'Polvo de ladrillo',
    nombre: 'Moron_Rivadavia_Tenis_Polvo_Cancha_1',
    precio: 2500,
  ),
];

/// Una reserva confirmada para dentro de [dias] días, 19:00 a 20:00 en Morón.
Map<String, dynamic> reservaJson({int dias = 3}) {
  final f = DateTime.now().add(Duration(days: dias));
  String dos(int n) => n.toString().padLeft(2, '0');
  return {
    'id': 10,
    'espacio': espaciosMoronJson.last,
    'fecha': '${f.year}-${dos(f.month)}-${dos(f.day)}',
    'hora_inicio': '19:00:00',
    'hora_fin': '20:00:00',
    'duracion': 1,
    'precio_total': 2500,
    'estado': 'confirmada',
    'cancelable': true,
    'creada_en': '2026-10-11T12:00:00Z',
    'cancelada_en': null,
  };
}

class ServidorFalso {
  ServidorFalso({this.reservas = const []});

  /// Lo que devuelve `GET /reservas`.
  final List<Map<String, dynamic>> reservas;

  /// Si se asigna, el servidor lanza este error en cada pedido.
  Object? fallo;

  final pedidos = <Uri>[];

  /// Pedidos a [ruta] (sin el prefijo `/api/v1`).
  List<Uri> pedidosA(String ruta) =>
      pedidos.where((u) => u.path.endsWith(ruta)).toList();

  Future<http.Response> responder(http.Request r) async {
    pedidos.add(r.url);
    if (fallo != null) throw fallo!;

    final ruta = r.url.path.replaceFirst('/api/v1', '');
    final q = r.url.queryParameters;

    if (ruta == '/usuarios/me') return jsonResp(perfilJson, 200);

    if (ruta == '/sedes') {
      final deporte = q['deporte'];
      return jsonResp([
        for (final s in sedesJson)
          if (deporte == null ||
              (s['deportes'] as List).any((d) => d['deporte'] == deporte))
            s,
      ], 200);
    }

    if (ruta == '/espacios') {
      return jsonResp([
        for (final e in espaciosMoronJson)
          if ((q['sede_id'] == null || q['sede_id'] == '${e['sede']['id']}') &&
              (q['deporte'] == null || q['deporte'] == e['deporte']) &&
              (q['tipo'] == null || q['tipo'] == e['tipo']))
            e,
      ], 200);
    }

    if (ruta == '/reservas') return jsonResp(reservas, 200);

    return jsonResp({
      'error': {'codigo': 'NO_ENCONTRADO', 'mensaje': 'No existe.'},
    }, 404);
  }
}

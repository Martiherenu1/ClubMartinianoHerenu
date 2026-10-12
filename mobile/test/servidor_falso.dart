/// API falsa con el catálogo del club para los tests de pantallas.
///
/// Responde como lo hace el backend: `GET /usuarios/me`, `/sedes`, `/espacios` y
/// `/reservas`, con los mismos filtros por query. Guarda cada pedido en
/// [pedidos] para poder comprobar qué parámetros mandó la app.
library;

import 'dart:convert';

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

/// Una reserva de Morón de 19:00 a 20:00, para dentro de [dias] días.
///
/// Por defecto es confirmada y cancelable; `estado: 'completada'` o `'cancelada'`
/// arma una del historial (con `dias` negativo si ya pasó).
Map<String, dynamic> reservaJson({
  int id = 10,
  int dias = 3,
  String estado = 'confirmada',
  int espacio = 5,
  num precio = 2500,
}) {
  final f = DateTime.now().add(Duration(days: dias));
  String dos(int n) => n.toString().padLeft(2, '0');
  return {
    'id': id,
    'espacio': espaciosMoronJson.firstWhere((e) => e['id'] == espacio),
    'fecha': '${f.year}-${dos(f.month)}-${dos(f.day)}',
    'hora_inicio': '19:00:00',
    'hora_fin': '20:00:00',
    'duracion': 1,
    'precio_total': precio,
    'estado': estado,
    'cancelable': estado == 'confirmada',
    'creada_en': '2026-10-11T12:00:00Z',
    'cancelada_en': estado == 'cancelada' ? '2026-10-12T12:00:00Z' : null,
  };
}

class ServidorFalso {
  ServidorFalso({
    List<Map<String, dynamic>> reservas = const [],
    List<Map<String, dynamic>> historial = const [],
    this.horasOcupadas = const {9, 11, 14, 17, 20},
    this.diasLlenos = const {},
  })  : reservasIniciales = reservas,
        historialInicial = historial;

  /// Reservas próximas (`GET /reservas?vista=proximas`).
  late final List<Map<String, dynamic>> reservas = [...reservasIniciales];

  /// Historial (`GET /reservas?vista=historial`).
  late final List<Map<String, dynamic>> historial = [...historialInicial];

  final List<Map<String, dynamic>> reservasIniciales;
  final List<Map<String, dynamic>> historialInicial;

  /// Si es `true`, `DELETE /reservas/{id}` responde 409 `RESERVA_NO_CANCELABLE`.
  bool noCancelable = false;

  /// Horas (de inicio) ya reservadas en cualquier cancha; define la grilla de
  /// `GET /espacios/{id}/disponibilidad`.
  final Set<int> horasOcupadas;

  /// Fechas (`AAAA-MM-DD`) en las que no queda ningún turno.
  final Set<String> diasLlenos;

  /// Si es `true`, `POST /reservas` responde 409 `HORARIO_OCUPADO`.
  bool conflicto = false;

  /// Cuerpos recibidos en `POST /reservas`.
  final reservasCreadas = <Map<String, dynamic>>[];

  /// Si se asigna, el servidor lanza este error en cada pedido.
  Object? fallo;

  final pedidos = <Uri>[];

  Map<String, dynamic> _disponibilidad(Map<String, dynamic> espacio, String fecha, int d) {
    final lleno = diasLlenos.contains(fecha);
    final franjas = <Map<String, dynamic>>[];
    for (var h = 8; h + d <= 23; h++) {
      final ocupada = lleno || [for (var i = h; i < h + d; i++) i].any(horasOcupadas.contains);
      String hora(int n) => '${n.toString().padLeft(2, '0')}:00:00';
      franjas.add({
        'hora_inicio': hora(h),
        'hora_fin': hora(h + d),
        'disponible': !ocupada,
        'motivo': ocupada ? 'ocupado' : null,
      });
    }
    final libres = franjas.where((f) => f['disponible'] == true).length;
    final precio = espacio['precio_hora'] as num;
    return {
      'espacio': espacio,
      'fecha': fecha,
      'duracion': d,
      'precio_hora': precio,
      'precio_total': precio * d,
      'cantidad_disponibles': libres,
      'cantidad_no_disponibles': franjas.length - libres,
      'franjas': franjas,
    };
  }

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

    final disp = RegExp(r'^/espacios/(\d+)/disponibilidad$').firstMatch(ruta);
    if (disp != null) {
      final id = int.parse(disp.group(1)!);
      final espacio = espaciosMoronJson.firstWhere((e) => e['id'] == id);
      return jsonResp(
        _disponibilidad(espacio, q['fecha']!, int.parse(q['duracion'] ?? '1')),
        200,
      );
    }

    if (ruta == '/reservas' && r.method == 'POST') {
      final cuerpo = jsonDecode(r.body) as Map<String, dynamic>;
      reservasCreadas.add(cuerpo);
      if (conflicto) {
        return jsonResp({
          'error': {
            'codigo': 'HORARIO_OCUPADO',
            'mensaje': 'El horario seleccionado ya no está disponible.',
          },
        }, 409);
      }
      return jsonResp(reservaJson(), 201);
    }

    if (ruta == '/reservas') {
      final historial = q['vista'] == 'historial';
      return jsonResp(historial ? this.historial : reservas, 200);
    }

    final una = RegExp(r'^/reservas/(\d+)$').firstMatch(ruta);
    if (una != null) {
      final id = int.parse(una.group(1)!);
      final todas = [...reservas, ...historial];
      final encontrada = todas.where((x) => x['id'] == id).firstOrNull;
      if (encontrada == null) {
        return jsonResp({
          'error': {'codigo': 'RESERVA_NO_ENCONTRADA', 'mensaje': 'No encontramos esa reserva.'},
        }, 404);
      }
      if (r.method == 'DELETE') {
        if (noCancelable) {
          return jsonResp({
            'error': {
              'codigo': 'RESERVA_NO_CANCELABLE',
              'mensaje': 'No se puede cancelar una reserva que ya empezó.',
            },
          }, 409);
        }
        reservas.removeWhere((x) => x['id'] == id);
        final cancelada = {
          ...encontrada,
          'estado': 'cancelada',
          'cancelable': false,
          'cancelada_en': '2026-10-12T12:00:00Z',
        };
        historial.insert(0, cancelada);
        return jsonResp(cancelada, 200);
      }
      return jsonResp(encontrada, 200);
    }

    return jsonResp({
      'error': {'codigo': 'NO_ENCONTRADO', 'mensaje': 'No existe.'},
    }, 404);
  }
}

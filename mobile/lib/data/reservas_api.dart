/// Llamadas a la API de reservas del usuario (CU-08, CU-09, CU-10).
library;

import '../core/api_client.dart';
import '../core/formato.dart';
import 'catalogo_api.dart';

class Reserva {
  const Reserva({
    required this.id,
    required this.espacio,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.duracion,
    required this.precioTotal,
    required this.estado,
    required this.cancelable,
  });

  factory Reserva.fromJson(Map<String, dynamic> json) => Reserva(
        id: json['id'] as int,
        espacio: Espacio.fromJson(json['espacio'] as Map<String, dynamic>),
        fecha: DateTime.parse(json['fecha'] as String),
        horaInicio: recortarHora(json['hora_inicio'] as String),
        horaFin: recortarHora(json['hora_fin'] as String),
        duracion: json['duracion'] as int,
        precioTotal: (json['precio_total'] as num).toDouble(),
        estado: json['estado'] as String,
        cancelable: json['cancelable'] as bool,
      );

  final int id;
  final Espacio espacio;
  final DateTime fecha;
  final String horaInicio;
  final String horaFin;
  final int duracion;
  final double precioTotal;

  /// `confirmada`, `en_curso`, `completada` o `cancelada`.
  final String estado;
  final bool cancelable;
}

enum VistaReservas { proximas, historial }

class ReservasApi {
  const ReservasApi(this._api);

  final ApiClient _api;

  /// `POST /reservas` (CU-09). Si alguien tomó la franja antes responde 409
  /// `HORARIO_OCUPADO`, que llega como [ErrorNegocio].
  Future<Reserva> crear({
    required int espacioId,
    required DateTime fecha,
    required String horaInicio,
    required int duracion,
  }) async {
    final json = await _api.post('/reservas', body: {
      'espacio_id': espacioId,
      'fecha': fechaIso(fecha),
      'hora_inicio': horaInicio,
      'duracion': duracion,
    });
    return Reserva.fromJson(json as Map<String, dynamic>);
  }

  /// `GET /reservas?vista=`. Las próximas vienen ordenadas de la más cercana a
  /// la más lejana.
  Future<List<Reserva>> listar({VistaReservas vista = VistaReservas.proximas}) async {
    final json = await _api.get('/reservas', query: {'vista': vista.name});
    return (json as List).map((r) => Reserva.fromJson(r as Map<String, dynamic>)).toList();
  }
}

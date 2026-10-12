/// Llamadas a la API de reservas del usuario (CU-08, CU-09, CU-10).
library;

import '../core/api_client.dart';
import '../core/formato.dart';
import 'catalogo_api.dart';

/// Un recordatorio de una reserva (24 h o 1 h antes) y si ya salió.
class Recordatorio {
  const Recordatorio({
    required this.tipo,
    required this.programadoPara,
    required this.estado,
  });

  factory Recordatorio.fromJson(Map<String, dynamic> json) => Recordatorio(
        tipo: json['tipo'] as String,
        programadoPara: horaDelClub(json['programado_para'] as String),
        estado: json['estado'] as String,
      );

  /// `24h` o `1h`.
  final String tipo;

  /// Cuándo corresponde enviarlo, en hora del club.
  final DateTime programadoPara;

  /// `pendiente`, `enviado` o `no_enviado`.
  final String estado;

  String get etiqueta => tipo == '24h' ? '24 horas antes' : '1 hora antes';
}

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
    this.recordatorios = const [],
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
        recordatorios: [
          for (final r in (json['recordatorios'] as List? ?? const []))
            Recordatorio.fromJson(r as Map<String, dynamic>),
        ],
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

  /// Recordatorios que corresponden a la reserva (vacío si está cancelada).
  final List<Recordatorio> recordatorios;
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

  /// `GET /reservas/{id}`: detalle de una reserva propia.
  Future<Reserva> obtener(int id) async {
    final json = await _api.get('/reservas/$id');
    return Reserva.fromJson(json as Map<String, dynamic>);
  }

  /// `DELETE /reservas/{id}` (CU-10): la reserva pasa a `cancelada` y el horario
  /// queda libre. Si ya empezó o terminó responde 409 `RESERVA_NO_CANCELABLE`.
  Future<Reserva> cancelar(int id) async {
    final json = await _api.delete('/reservas/$id');
    return Reserva.fromJson(json as Map<String, dynamic>);
  }

  /// `GET /reservas?vista=`. Las próximas vienen ordenadas de la más cercana a
  /// la más lejana.
  Future<List<Reserva>> listar({VistaReservas vista = VistaReservas.proximas}) async {
    final json = await _api.get('/reservas', query: {'vista': vista.name});
    return (json as List).map((r) => Reserva.fromJson(r as Map<String, dynamic>)).toList();
  }
}

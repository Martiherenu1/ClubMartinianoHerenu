/// Llamada a la API de horarios disponibles (CU-12).
library;

import '../core/api_client.dart';
import '../core/formato.dart';
import 'catalogo_api.dart';

/// Un botón de la grilla de horarios.
class Franja {
  const Franja({
    required this.horaInicio,
    required this.horaFin,
    required this.disponible,
    required this.motivo,
  });

  factory Franja.fromJson(Map<String, dynamic> json) => Franja(
        horaInicio: recortarHora(json['hora_inicio'] as String),
        horaFin: recortarHora(json['hora_fin'] as String),
        disponible: json['disponible'] as bool,
        motivo: json['motivo'] as String?,
      );

  final String horaInicio;
  final String horaFin;
  final bool disponible;

  /// `ocupado` o `pasado` cuando no está disponible; `null` si se puede reservar.
  final String? motivo;

  /// `19:00 – 20:00`, como se lee en el botón.
  String get rotulo => '$horaInicio – $horaFin';
}

class Disponibilidad {
  const Disponibilidad({
    required this.espacio,
    required this.fecha,
    required this.duracion,
    required this.precioHora,
    required this.precioTotal,
    required this.cantidadDisponibles,
    required this.cantidadNoDisponibles,
    required this.franjas,
  });

  factory Disponibilidad.fromJson(Map<String, dynamic> json) => Disponibilidad(
        espacio: Espacio.fromJson(json['espacio'] as Map<String, dynamic>),
        fecha: DateTime.parse(json['fecha'] as String),
        duracion: json['duracion'] as int,
        precioHora: (json['precio_hora'] as num).toDouble(),
        precioTotal: (json['precio_total'] as num).toDouble(),
        cantidadDisponibles: json['cantidad_disponibles'] as int,
        cantidadNoDisponibles: json['cantidad_no_disponibles'] as int,
        franjas: (json['franjas'] as List)
            .map((f) => Franja.fromJson(f as Map<String, dynamic>))
            .toList(),
      );

  final Espacio espacio;
  final DateTime fecha;
  final int duracion;
  final double precioHora;

  /// Precio de la reserva: `precioHora × duracion`.
  final double precioTotal;
  final int cantidadDisponibles;
  final int cantidadNoDisponibles;
  final List<Franja> franjas;
}

class DisponibilidadApi {
  const DisponibilidadApi(this._api);

  final ApiClient _api;

  /// `GET /espacios/{id}/disponibilidad?fecha=&duracion=`. Solo lectura.
  Future<Disponibilidad> consultar({
    required int espacioId,
    required DateTime fecha,
    required int duracion,
  }) async {
    final json = await _api.get(
      '/espacios/$espacioId/disponibilidad',
      query: {'fecha': fechaIso(fecha), 'duracion': '$duracion'},
    );
    return Disponibilidad.fromJson(json as Map<String, dynamic>);
  }
}

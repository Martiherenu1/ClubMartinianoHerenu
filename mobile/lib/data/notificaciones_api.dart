/// Llamadas a la API de notificaciones (CU-24): registro del celular y panel.
library;

import '../core/api_client.dart';
import '../core/formato.dart';

/// Un aviso que ya recibió el usuario (panel de la campana).
class AvisoRecibido {
  const AvisoRecibido({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.cuerpo,
    required this.reservaId,
    required this.enviadaEn,
    required this.instante,
  });

  factory AvisoRecibido.fromJson(Map<String, dynamic> json) {
    final enviada = json['enviada_en'] as String;
    return AvisoRecibido(
      id: json['id'] as int,
      tipo: json['tipo'] as String,
      titulo: json['titulo'] as String,
      cuerpo: json['cuerpo'] as String,
      reservaId: json['reserva_id'] as int,
      enviadaEn: horaDelClub(enviada),
      instante: DateTime.parse(enviada),
    );
  }

  final int id;
  final String tipo;
  final String titulo;
  final String cuerpo;
  final int reservaId;

  /// Fecha y hora del club tal como vienen de la API (para mostrar).
  final DateTime enviadaEn;

  /// El mismo momento como instante absoluto (para comparar con "visto hasta").
  final DateTime instante;
}

class NotificacionesApi {
  const NotificacionesApi(this._api);

  final ApiClient _api;

  /// `POST /usuarios/me/dispositivos`: guarda el token de este celular.
  Future<void> registrarDispositivo(String token) =>
      _api.post('/usuarios/me/dispositivos', body: {
        'fcm_token': token,
        'plataforma': 'android',
      });

  /// `DELETE /usuarios/me/dispositivos/{token}`: lo quita al cerrar sesión.
  Future<void> quitarDispositivo(String token) =>
      _api.delete('/usuarios/me/dispositivos/${Uri.encodeComponent(token)}');

  /// `GET /notificaciones`: los avisos recibidos, del más nuevo al más viejo.
  Future<List<AvisoRecibido>> listar({int limite = 20}) async {
    final json = await _api.get('/notificaciones', query: {'limite': '$limite'});
    return (json as List)
        .map((e) => AvisoRecibido.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

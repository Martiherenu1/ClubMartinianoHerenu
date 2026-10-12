/// Notificaciones push con Firebase Cloud Messaging (CU-24).
///
/// `ServicioNotificaciones` es una interfaz para poder reemplazar Firebase en los
/// tests, igual que `ServicioAuth`.
///
/// Los avisos que llegan con la app cerrada o en segundo plano los muestra el
/// sistema; la app solo se entera cuando el usuario los toca (`abiertos` y
/// `avisoInicial`). Con la app abierta, FCM no muestra nada: avisa por
/// `enPrimerPlano` y la app lo muestra por su cuenta.
library;

import 'package:firebase_messaging/firebase_messaging.dart';

/// Estado del permiso de notificaciones del sistema.
enum PermisoNotificaciones {
  /// Todavía no se le pidió al usuario (Android 13+).
  sinPedir,
  concedido,
  denegado,
}

/// Un aviso push que le llegó (o tocó) al usuario.
class AvisoPush {
  const AvisoPush({required this.tipo, this.reservaId, this.titulo, this.cuerpo});

  /// `recordatorio_24h`, `recordatorio_1h` o `cancelacion`.
  final String tipo;

  /// La reserva a la que se refiere: es lo que se abre al tocar el aviso.
  final int? reservaId;
  final String? titulo;
  final String? cuerpo;
}

abstract interface class ServicioNotificaciones {
  Future<PermisoNotificaciones> permiso();

  /// Muestra el pedido de permiso del sistema y devuelve cómo quedó.
  Future<PermisoNotificaciones> pedirPermiso();

  /// Token de FCM de este celular, o `null` si no se pudo obtener (sin Google
  /// Play Services, sin conexión).
  Future<String?> token();

  /// FCM renueva el token de vez en cuando: hay que volver a registrarlo.
  Stream<String> get tokenRenovado;

  /// Llegó un aviso con la app abierta.
  Stream<AvisoPush> get enPrimerPlano;

  /// El usuario tocó un aviso con la app en segundo plano.
  Stream<AvisoPush> get abiertos;

  /// El aviso con el que se abrió la app si estaba cerrada, o `null`.
  Future<AvisoPush?> avisoInicial();

  /// Borra el token de este celular (al cerrar sesión), para que el próximo
  /// usuario que inicie sesión obtenga uno nuevo.
  Future<void> olvidarToken();
}

class NotificacionesFirebase implements ServicioNotificaciones {
  NotificacionesFirebase({FirebaseMessaging? mensajeria})
      : _fm = mensajeria ?? FirebaseMessaging.instance;

  final FirebaseMessaging _fm;

  static AvisoPush _aviso(RemoteMessage m) => AvisoPush(
        tipo: m.data['tipo'] as String? ?? '',
        reservaId: int.tryParse(m.data['reserva_id'] as String? ?? ''),
        titulo: m.notification?.title,
        cuerpo: m.notification?.body,
      );

  static PermisoNotificaciones _convertir(AuthorizationStatus estado) => switch (estado) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional =>
          PermisoNotificaciones.concedido,
        AuthorizationStatus.denied ||
        AuthorizationStatus.deniedPermanently =>
          PermisoNotificaciones.denegado,
        AuthorizationStatus.notDetermined => PermisoNotificaciones.sinPedir,
      };

  @override
  Future<PermisoNotificaciones> permiso() async =>
      _convertir((await _fm.getNotificationSettings()).authorizationStatus);

  @override
  Future<PermisoNotificaciones> pedirPermiso() async =>
      _convertir((await _fm.requestPermission()).authorizationStatus);

  @override
  Future<String?> token() async {
    try {
      return await _fm.getToken();
    } catch (_) {
      // Sin Google Play Services o sin red: la app sigue funcionando sin push.
      return null;
    }
  }

  @override
  Stream<String> get tokenRenovado => _fm.onTokenRefresh;

  @override
  Stream<AvisoPush> get enPrimerPlano => FirebaseMessaging.onMessage.map(_aviso);

  @override
  Stream<AvisoPush> get abiertos => FirebaseMessaging.onMessageOpenedApp.map(_aviso);

  @override
  Future<AvisoPush?> avisoInicial() async {
    final mensaje = await _fm.getInitialMessage();
    return mensaje == null ? null : _aviso(mensaje);
  }

  @override
  Future<void> olvidarToken() async {
    try {
      await _fm.deleteToken();
    } catch (_) {
      // Si no se puede borrar, queda el token; el backend lo descarta solo cuando
      // FCM informa que ya no existe.
    }
  }
}

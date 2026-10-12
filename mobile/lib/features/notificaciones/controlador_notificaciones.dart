/// Estado de las notificaciones push de la sesión (CU-24): permiso, registro del
/// celular en la API y qué avisos ya vio el usuario.
///
/// Vive mientras haya sesión (lo crea `PantallaPrincipal`). Todo lo que falla acá
/// es secundario: sin push la app funciona igual, así que los errores de red al
/// registrar el celular no se le muestran al usuario.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/servicio_notificaciones.dart';
import '../../data/notificaciones_api.dart';

class ControladorNotificaciones extends ChangeNotifier {
  ControladorNotificaciones({required this.servicio, required this.api});

  static const _clavePospuesto = 'recordatorios_pospuestos';
  static const _claveVistoHasta = 'notificaciones_vistas_hasta';

  final ServicioNotificaciones servicio;
  final NotificacionesApi api;

  PermisoNotificaciones _permiso = PermisoNotificaciones.sinPedir;
  bool _listo = false;
  bool _pospuesto = false;
  bool _cerrada = false;
  String? _tokenRegistrado;
  StreamSubscription<String>? _suscripcionToken;

  /// Sube cada vez que llega un aviso: el panel de la campana se vuelve a pedir.
  int _version = 0;

  PermisoNotificaciones get permiso => _permiso;
  int get version => _version;

  /// Hay que mostrar el modal "Activá los recordatorios": falta el permiso y el
  /// usuario todavía no dijo "Ahora no".
  bool get ofrecerPermiso =>
      _listo && _permiso == PermisoNotificaciones.sinPedir && !_pospuesto;

  /// Lee el permiso y, si ya está concedido, registra el celular en la API.
  Future<void> iniciar() async {
    try {
      _permiso = await servicio.permiso();
      final prefs = await SharedPreferences.getInstance();
      _pospuesto = prefs.getBool(_clavePospuesto) ?? false;
    } catch (_) {
      // Sin preferencias guardadas se ofrece el permiso como la primera vez.
    }
    _listo = true;
    if (_cerrada) return;
    notifyListeners();
    if (_permiso == PermisoNotificaciones.concedido) await _registrar();
  }

  /// El usuario aceptó el modal (o tocó "Activar"): pide el permiso al sistema.
  Future<PermisoNotificaciones> habilitar() async {
    _permiso = await servicio.pedirPermiso();
    if (_cerrada) return _permiso;
    notifyListeners();
    if (_permiso == PermisoNotificaciones.concedido) await _registrar();
    return _permiso;
  }

  /// "Ahora no": no se vuelve a ofrecer el modal (queda la tarjeta de la Home).
  Future<void> posponer() async {
    _pospuesto = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_clavePospuesto, true);
    } catch (_) {}
  }

  /// Llegó un aviso con la app abierta: refresca el panel.
  void avisoRecibido() {
    _version++;
    notifyListeners();
  }

  Future<void> _registrar() async {
    final token = await servicio.token();
    if (token == null || _cerrada) return;
    await _enviarToken(token);
    // FCM puede renovar el token: se vuelve a registrar el nuevo.
    _suscripcionToken ??= servicio.tokenRenovado.listen(_enviarToken);
  }

  Future<void> _enviarToken(String token) async {
    try {
      await api.registrarDispositivo(token);
      _tokenRegistrado = token;
    } catch (_) {
      // Se reintenta la próxima vez que se abra la app.
    }
  }

  /// Antes de cerrar sesión: saca este celular de la cuenta (CU-02) para que no
  /// siga recibiendo avisos de reservas ajenas. Nunca frena el cierre de sesión.
  Future<void> alCerrarSesion() async {
    _cerrada = true;
    // No se espera: cancelar la suscripción no necesita esperar a nadie.
    unawaited(_suscripcionToken?.cancel());
    _suscripcionToken = null;
    try {
      final token = _tokenRegistrado ?? await servicio.token();
      if (token != null) {
        await api.quitarDispositivo(token).timeout(const Duration(seconds: 4));
      }
    } catch (_) {
      // Sin red: el backend lo descarta solo cuando FCM diga que no existe más.
    }
    await servicio.olvidarToken();
  }

  // --- Panel de la campana: qué avisos ya se vieron ---

  Future<DateTime?> vistoHasta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final texto = prefs.getString(_claveVistoHasta);
      return texto == null ? null : DateTime.tryParse(texto);
    } catch (_) {
      return null;
    }
  }

  Future<void> marcarVistoHasta(DateTime instante) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_claveVistoHasta, instante.toIso8601String());
    } catch (_) {}
  }

  @override
  void dispose() {
    _cerrada = true;
    _suscripcionToken?.cancel();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo claro / oscuro elegido por el usuario (selector de la pantalla de perfil).
///
/// La preferencia se guarda en el celular para que se mantenga al reabrir la app.
class ControladorTema extends ChangeNotifier {
  static const _clave = 'modo_oscuro';

  ThemeMode _modo = ThemeMode.dark;
  ThemeMode get modo => _modo;
  bool get esOscuro => _modo == ThemeMode.dark;

  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _modo = (prefs.getBool(_clave) ?? true) ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    } catch (_) {
      // Sin preferencias guardadas se usa el modo por defecto.
    }
  }

  Future<void> alternar() async {
    _modo = esOscuro ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_clave, esOscuro);
    } catch (_) {
      // Si no se puede guardar, igual queda aplicado en esta sesión.
    }
  }
}

/// Acciones de navegación que las pestañas se piden entre sí (por ejemplo, la
/// Home abre una sede en la pestaña "Sedes").
library;

import 'package:flutter/foundation.dart';

import '../../data/catalogo_api.dart';

/// Posición de cada pestaña de la barra inferior.
abstract final class Pestana {
  static const inicio = 0;
  static const sedes = 1;
  static const reservas = 2;
  static const perfil = 3;
}

class NavegacionPrincipal {
  const NavegacionPrincipal({required this.irA, required this.abrirSede});

  /// Cambia de pestaña (ver [Pestana]).
  final void Function(int pestana) irA;

  /// Va a la pestaña Sedes y abre el detalle de la sede.
  final void Function(Sede sede) abrirSede;
}

/// Avisa que los datos del usuario cambiaron: se creó o canceló una reserva, o
/// se editó el perfil (la Home saluda por el nombre).
///
/// Las pestañas viven en un `IndexedStack`, así que no se reconstruyen solas:
/// Home y Reservas escuchan este aviso y vuelven a pedir sus datos.
class ReservasCambiadas extends ChangeNotifier {
  int _version = 0;

  /// Cambia cada vez que hay que recargar.
  int get version => _version;

  void avisar() {
    _version++;
    notifyListeners();
  }
}

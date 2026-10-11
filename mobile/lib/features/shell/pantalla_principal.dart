/// Estructura de la app con sesión: barra inferior con cuatro pestañas.
///
/// Cada pestaña tiene su propio `Navigator`, así la barra se mantiene visible
/// cuando se entra al detalle de una sede o de una reserva (como en el Figma) y
/// cada pestaña conserva su pila al cambiar de una a otra.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/catalogo_api.dart';
import '../../widgets/barra_inferior.dart';
import '../inicio/pantalla_inicio.dart';
import '../perfil/pantalla_perfil.dart';
import '../reservas/pantalla_reservas.dart';
import '../sedes/pantalla_sede.dart';
import '../sedes/pantalla_sedes.dart';
import 'navegacion_principal.dart';

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  final _navegadores = List.generate(4, (_) => GlobalKey<NavigatorState>());

  /// Las pestañas se arman la primera vez que se visitan: así no se piden al
  /// servidor datos de pantallas que el usuario todavía no abrió.
  final _visitadas = <int>{Pestana.inicio};
  int _indice = Pestana.inicio;

  late final _navegacion = NavegacionPrincipal(
    irA: _irA,
    abrirSede: _abrirSede,
  );

  void _irA(int pestana) {
    setState(() {
      _visitadas.add(pestana);
      _indice = pestana;
    });
  }

  void _elegirPestana(int pestana) {
    if (pestana == _indice) {
      // Tocar la pestaña activa vuelve a su pantalla principal.
      _navegadores[pestana].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    _irA(pestana);
  }

  void _abrirSede(Sede sede) {
    _irA(Pestana.sedes);
    // El navegador de la pestaña puede no existir todavía: se espera al frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = _navegadores[Pestana.sedes].currentState;
      if (nav == null) return;
      nav.popUntil((r) => r.isFirst);
      nav.push(MaterialPageRoute<void>(builder: (_) => PantallaSede(sede: sede)));
    });
  }

  Future<void> _alVolver(bool yaSalio, Object? _) async {
    if (yaSalio) return;
    // Primero se cierra lo que haya apilado en la pestaña actual…
    if (await _navegadores[_indice].currentState!.maybePop()) return;
    // …después se vuelve a Inicio, y recién ahí se sale de la app.
    if (_indice != Pestana.inicio) {
      _irA(Pestana.inicio);
    } else {
      await SystemNavigator.pop();
    }
  }

  Widget _pestana(int i, WidgetBuilder raiz) {
    if (!_visitadas.contains(i)) return const SizedBox.shrink();
    return Navigator(
      key: _navegadores[i],
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: raiz),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Provider<NavegacionPrincipal>.value(
      value: _navegacion,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: _alVolver,
        child: Scaffold(
          body: IndexedStack(
            index: _indice,
            children: [
              _pestana(Pestana.inicio, (_) => const PantallaInicio()),
              _pestana(Pestana.sedes, (_) => const PantallaSedes()),
              _pestana(Pestana.reservas, (_) => const PantallaReservas()),
              _pestana(Pestana.perfil, (_) => const PantallaPerfil()),
            ],
          ),
          bottomNavigationBar: BarraInferior(indice: _indice, alElegir: _elegirPestana),
        ),
      ),
    );
  }
}

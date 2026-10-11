/// AuthGate (módulo 9): "¿hay un usuario autenticado? Entonces muestro la
/// aplicación. Si no, muestro Login."
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/servicio_auth.dart';
import '../inicio/pantalla_inicio.dart';
import 'pantalla_login.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<ServicioAuth>();
    return StreamBuilder<UsuarioSesion?>(
      stream: auth.cambios,
      initialData: auth.actual,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        // Al cambiar de pantalla se descartan las rutas apiladas (registro, etc.).
        return snap.data == null ? const PantallaLogin() : const PantallaInicio();
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/servicio_auth.dart';
import '../features/auth/auth_gate.dart';
import 'controlador_tema.dart';
import 'tema.dart';

/// Raíz de la app: provee la autenticación, el cliente de la API y el tema.
class AppClub extends StatelessWidget {
  const AppClub({super.key, required this.auth, this.api, this.tema});

  final ServicioAuth auth;

  /// Se pueden inyectar en los tests.
  final ApiClient? api;
  final ControladorTema? tema;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ServicioAuth>.value(value: auth),
        // El cliente de la API pide el ID token vigente a Firebase en cada request.
        Provider<ApiClient>(
          create: (_) => api ?? ApiClient(proveedorToken: auth.idToken),
        ),
        ChangeNotifierProvider<ControladorTema>(
          create: (_) => tema ?? (ControladorTema()..cargar()),
        ),
      ],
      child: Consumer<ControladorTema>(
        builder: (context, controlador, _) => MaterialApp(
          title: 'ClubMartinianoHerenu',
          debugShowCheckedModeBanner: false,
          theme: temaClaro,
          darkTheme: temaOscuro,
          themeMode: controlador.modo,
          locale: const Locale('es', 'AR'),
          supportedLocales: const [Locale('es', 'AR'), Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const AuthGate(),
        ),
      ),
    );
  }
}

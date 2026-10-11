import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../features/prueba/pantalla_conexion.dart';
import 'controlador_tema.dart';
import 'tema.dart';

/// Raíz de la app: provee el cliente de la API y el tema, y define el modo
/// claro / oscuro.
class AppClub extends StatelessWidget {
  const AppClub({super.key, this.api, this.tema});

  /// Se pueden inyectar en los tests.
  final ApiClient? api;
  final ControladorTema? tema;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>(create: (_) => api ?? ApiClient()),
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
          home: const PantallaConexion(),
        ),
      ),
    );
  }
}

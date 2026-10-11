import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/controlador_tema.dart';
import '../../app/tema.dart';
import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/errores.dart';

/// Pantalla provisoria de la base de la app: verifica que el celular llegue a la
/// API. Se reemplaza por el login en el próximo PR.
class PantallaConexion extends StatefulWidget {
  const PantallaConexion({super.key});

  @override
  State<PantallaConexion> createState() => _PantallaConexionState();
}

class _PantallaConexionState extends State<PantallaConexion> {
  late Future<void> _verificacion;

  @override
  void initState() {
    super.initState();
    _verificacion = _verificar();
  }

  Future<void> _verificar() async {
    final api = context.read<ApiClient>();
    // /health vive fuera de /api/v1; se pide con un cliente de URL base propia.
    final salud = ApiClient(urlBase: Config.apiUrl);
    try {
      await salud.get('/health');
    } finally {
      salud.cerrar();
    }
    // Referencia usada para que el cliente principal quede instanciado.
    assert(api.proveedorToken == null);
  }

  void _reintentar() => setState(() => _verificacion = _verificar());

  @override
  Widget build(BuildContext context) {
    final tema = context.watch<ControladorTema>();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Cambiar modo claro / oscuro',
                    onPressed: tema.alternar,
                    icon: Icon(tema.esOscuro ? Icons.light_mode : Icons.dark_mode),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Text(
                'BIENVENIDO A',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colores.lima,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'CLUB '),
                    TextSpan(
                      text: 'MARTINIANO HEREÑU',
                      style: TextStyle(
                        color: tema.esOscuro ? Colores.lima : Colores.limaOscuro,
                      ),
                    ),
                  ],
                ),
                style: Tipografia.titulo(size: 38),
              ),
              const SizedBox(height: 8),
              const Text('Gestión de espacios deportivos'),
              const Spacer(),
              FutureBuilder<void>(
                future: _verificacion,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final error = snap.error;
                  final ok = error == null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            ok ? Icons.check_circle : Icons.error,
                            color: ok ? Colores.lima : Colores.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ok
                                  ? 'Conectado a la API (${Config.apiUrl})'
                                  : switch (error) {
                                      ErrorApp e => e.mensaje,
                                      _ => 'Error inesperado',
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _reintentar,
                        child: const Text('VERIFICAR DE NUEVO'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pantalla de inicio PROVISORIA: confirma que la sesión funciona de punta a
/// punta (token de Firebase → API → perfil en PostgreSQL). Se reemplaza por la
/// Home del Figma en el próximo PR.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/controlador_tema.dart';
import '../../app/tema.dart';
import '../../core/api_client.dart';
import '../../core/errores.dart';
import '../../core/servicio_auth.dart';
import '../../data/usuarios_api.dart';
import '../../widgets/tarjeta_error.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  late Future<Usuario> _perfil;

  @override
  void initState() {
    super.initState();
    _perfil = _cargar();
  }

  Future<Usuario> _cargar() async {
    try {
      return await UsuariosApi(context.read<ApiClient>()).miPerfil();
    } on NoAutenticado {
      // Token inválido o cuenta dada de baja: vuelve al login.
      await context.read<ServicioAuth>().cerrarSesion();
      rethrow;
    }
  }

  void _reintentar() => setState(() => _perfil = _cargar());

  @override
  Widget build(BuildContext context) {
    final tema = context.watch<ControladorTema>();
    return Scaffold(
      appBar: AppBar(
        title: Text('INICIO', style: Tipografia.titulo(size: 22)),
        actions: [
          IconButton(
            tooltip: 'Cambiar modo claro / oscuro',
            onPressed: tema.alternar,
            icon: Icon(tema.esOscuro ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: FutureBuilder<Usuario>(
          future: _perfil,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final error = snap.error;
            if (error != null) {
              return _Fallo(
                error: error,
                alReintentar: _reintentar,
              );
            }
            final u = snap.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('BUENOS DÍAS', style: TextStyle(letterSpacing: 3, fontSize: 12)),
                const SizedBox(height: 4),
                Text(u.nombreCompleto, style: Tipografia.titulo(size: 36)),
                const SizedBox(height: 16),
                Text(u.email),
                Text('DNI ${u.dni}'),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => context.read<ServicioAuth>().cerrarSesion(),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                  child: const Text('Cerrar sesión'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Fallo extends StatelessWidget {
  const _Fallo({required this.error, required this.alReintentar});

  final Object error;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    final e = error is ErrorApp ? error as ErrorApp : const ErrorServidor();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TarjetaError(
          titulo: e is SinConexion ? 'ERROR DE CONECTIVIDAD' : 'ERROR',
          mensaje: e.mensaje,
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: alReintentar, child: const Text('REINTENTAR')),
      ],
    );
  }
}

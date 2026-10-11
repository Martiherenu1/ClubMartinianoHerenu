/// Perfil. PROVISORIO: muestra los datos y permite cerrar sesión y cambiar el
/// modo claro / oscuro. La edición, el cambio de contraseña y la baja de la
/// cuenta llegan en el PR `feat/perfil`.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/controlador_tema.dart';
import '../../app/tema.dart';
import '../../core/api_client.dart';
import '../../core/servicio_auth.dart';
import '../../data/usuarios_api.dart';
import '../../widgets/carga_async.dart';

class PantallaPerfil extends StatelessWidget {
  const PantallaPerfil({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = context.watch<ControladorTema>();
    return Scaffold(
      appBar: AppBar(
        title: Text('MI PERFIL', style: Tipografia.titulo(size: 22)),
        actions: [
          IconButton(
            tooltip: 'Cambiar modo claro / oscuro',
            onPressed: tema.alternar,
            icon: Icon(tema.esOscuro ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: CargaAsync<Usuario>(
        cargar: () => UsuariosApi(context.read<ApiClient>()).miPerfil(),
        construir: (context, u) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(u.nombreCompleto, style: Tipografia.titulo(size: 32)),
              const SizedBox(height: 12),
              Text(u.email),
              Text('DNI ${u.dni}'),
              const Spacer(),
              OutlinedButton(
                onPressed: () => context.read<ServicioAuth>().cerrarSesion(),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

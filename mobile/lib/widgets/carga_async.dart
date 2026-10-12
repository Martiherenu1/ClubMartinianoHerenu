/// Carga de datos de una pantalla con sus tres estados: cargando, error (con
/// "Reintentar") y datos.
///
/// Si la API responde 401 (token inválido o cuenta dada de baja) cierra la
/// sesión y la app vuelve al login.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errores.dart';
import '../core/servicio_auth.dart';
import 'tarjeta_error.dart';

class CargaAsync<T> extends StatefulWidget {
  const CargaAsync({super.key, required this.cargar, required this.construir});

  final Future<T> Function() cargar;
  final Widget Function(BuildContext context, T datos) construir;

  @override
  State<CargaAsync<T>> createState() => _CargaAsyncState<T>();
}

class _CargaAsyncState<T> extends State<CargaAsync<T>> {
  late Future<T> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _ejecutar();
  }

  Future<T> _ejecutar() async {
    try {
      return await widget.cargar();
    } on ErrorApp catch (e) {
      if (_sesionInutilizable(e) && mounted) {
        await context.read<ServicioAuth>().cerrarSesion();
      }
      rethrow;
    }
  }

  void _reintentar() {
    setState(() {
      _futuro = _ejecutar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snap.hasError) {
          return VistaFallo(error: snap.error!, alReintentar: _reintentar);
        }
        return widget.construir(context, snap.requireData);
      },
    );
  }
}

/// La sesión no sirve para usar la app: el token venció o la cuenta fue dada de
/// baja (401), o la cuenta existe en Firebase pero no tiene perfil en la API
/// (registro incompleto o perfil borrado). En ambos casos se vuelve al login.
bool _sesionInutilizable(ErrorApp e) =>
    e is NoAutenticado || (e is ErrorNegocio && e.codigo == 'PERFIL_NO_ENCONTRADO');

/// Pantalla (o sección) que no pudo cargar: tarjeta de error + "Reintentar".
class VistaFallo extends StatelessWidget {
  const VistaFallo({super.key, required this.error, required this.alReintentar});

  final Object error;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    final e = error is ErrorApp ? error as ErrorApp : const ErrorServidor();
    // Sin conexión y error del servidor tienen su tarjeta del Figma; un error de
    // negocio (ej. 404) muestra el mensaje que mandó la API.
    final (titulo, mensaje) = switch (e) {
      SinConexion() => (
          'ERROR DE CONECTIVIDAD',
          'Parece que no está conectado a ninguna red Wi-Fi. '
              'Reestablezca su conexión e intente otra vez.',
        ),
      ErrorNegocio() => ('ERROR', e.mensaje),
      _ => (
          'ERROR DEL SERVIDOR',
          'Ocurrió un error en el servidor. Intente nuevamente más tarde.',
        ),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TarjetaError(titulo: titulo, mensaje: mensaje, comoDialogo: false),
            const SizedBox(height: 16),
            FilledButton(onPressed: alReintentar, child: const Text('REINTENTAR')),
          ],
        ),
      ),
    );
  }
}

/// Qué hacer cuando falla una acción del usuario (no la carga de una pantalla):
/// 401 → vuelve al login; sin conexión o servidor → tarjeta; error de negocio →
/// aviso con el mensaje de la API.
Future<void> mostrarFallo(BuildContext context, Object error) async {
  if (error is ErrorApp && _sesionInutilizable(error)) {
    await context.read<ServicioAuth>().cerrarSesion();
    return;
  }
  if (error is SinConexion || error is ErrorServidor) {
    await mostrarTarjetaError(context, error as ErrorApp);
    return;
  }
  final mensaje = error is ErrorApp ? error.mensaje : const ErrorServidor().mensaje;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
}

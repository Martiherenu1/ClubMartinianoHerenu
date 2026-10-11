/// Login (CU-01). Estados del Figma: formulario, "Completá todos los campos",
/// credenciales inválidas, error de conectividad y error del servidor.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/tema.dart';
import '../../core/errores.dart';
import '../../core/servicio_auth.dart';
import '../../widgets/tarjeta_error.dart';
import 'componentes_auth.dart';
import 'pantalla_recuperar.dart';
import 'pantalla_registro.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _cargando = false;
  bool _camposVacios = false;
  String? _mensajeError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    final auth = context.read<ServicioAuth>();
    final emailVacio = _email.text.trim().isEmpty;
    final passwordVacia = _password.text.isEmpty;

    // CU-01 FA1: campos incompletos → no se llama al servidor.
    if (emailVacio || passwordVacia) {
      setState(() {
        _camposVacios = true;
        _mensajeError = 'Completá todos los campos';
      });
      return;
    }

    setState(() {
      _cargando = true;
      _camposVacios = false;
      _mensajeError = null;
    });
    try {
      await auth.iniciarSesion(_email.text, _password.text);
      // Si salió bien, el AuthGate detecta la sesión y cambia de pantalla.
    } on ErrorApp catch (e) {
      if (!mounted) return;
      // Se deja de mostrar la carga ANTES de la tarjeta de error.
      setState(() => _cargando = false);
      if (e is SinConexion || e is ErrorServidor) {
        await mostrarTarjetaError(context, e); // CU-01 FA4 y FA5
      } else {
        setState(() => _mensajeError = e.mensaje); // CU-01 FA2
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _limpiarError() {
    if (_mensajeError != null || _camposVacios) {
      setState(() {
        _mensajeError = null;
        _camposVacios = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FondoAuth(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Sobretitulo('Bienvenido a'),
            const SizedBox(height: 6),
            const TituloClub(),
            const SizedBox(height: 8),
            Text(
              'Gestión de espacios deportivos',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                letterSpacing: 0.26,
              ),
            ),
            const SizedBox(height: 28),
            if (_mensajeError != null) ...[
              BannerError(_mensajeError!),
              const SizedBox(height: 16),
            ],
            CampoAuth(
              controlador: _email,
              hint: 'Email',
              teclado: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              conError: _camposVacios && _email.text.trim().isEmpty,
              alCambiar: _limpiarError,
            ),
            const SizedBox(height: 12),
            CampoAuth(
              controlador: _password,
              hint: 'Contraseña',
              esPassword: true,
              autofillHints: const [AutofillHints.password],
              accion: TextInputAction.done,
              conError: _camposVacios && _password.text.isEmpty,
              alCambiar: _limpiarError,
              alEnviar: _iniciarSesion,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PantallaRecuperar()),
                ),
                child: const Text(
                  '¿Olvidaste tu contraseña?',
                  style: TextStyle(
                    color: Colores.lima,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            BotonLima(
              texto: 'INICIAR SESIÓN',
              cargando: _cargando,
              alPresionar: _iniciarSesion,
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'o',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12),
                  ),
                ),
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '¿No tenés cuenta? ',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.34), fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const PantallaRegistro()),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'COMENZAR →',
                        style: Tipografia.titulo(size: 13, color: Colores.lima),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

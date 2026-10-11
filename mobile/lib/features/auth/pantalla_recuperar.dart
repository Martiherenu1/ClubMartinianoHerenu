/// Recuperar contraseña. Firebase manda el email con el enlace para elegir una
/// nueva; la app solo lo solicita (módulo 9 de la cursada).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/tema.dart';
import '../../core/errores.dart';
import '../../core/servicio_auth.dart';
import '../../widgets/tarjeta_error.dart';
import 'componentes_auth.dart';
import 'validaciones.dart';

class PantallaRecuperar extends StatefulWidget {
  const PantallaRecuperar({super.key});

  @override
  State<PantallaRecuperar> createState() => _PantallaRecuperarState();
}

class _PantallaRecuperarState extends State<PantallaRecuperar> {
  final _email = TextEditingController();
  bool _cargando = false;
  bool _enviado = false;
  String? _mensajeError;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final auth = context.read<ServicioAuth>();
    if (!emailValido(_email.text)) {
      setState(() => _mensajeError = 'Ingresá un email válido');
      return;
    }
    setState(() {
      _cargando = true;
      _mensajeError = null;
    });
    try {
      await auth.enviarEnlaceRecuperacion(_email.text);
      if (mounted) setState(() => _enviado = true);
    } on ErrorApp catch (e) {
      if (!mounted) return;
      // Se deja de mostrar la carga ANTES de la tarjeta de error.
      setState(() => _cargando = false);
      if (e is SinConexion || e is ErrorServidor) {
        await mostrarTarjetaError(context, e);
      } else {
        setState(() => _mensajeError = e.mensaje);
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FondoAuth(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BotonVolver(),
            const SizedBox(height: 8),
            const Sobretitulo('Recuperación'),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'OLVIDÉ MI '),
                  TextSpan(text: 'CONTRASEÑA', style: TextStyle(color: Colores.lima)),
                ],
              ),
              style: Tipografia.titulo(size: 36, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresá tu email y te enviaremos un enlace.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
            ),
            const SizedBox(height: 28),
            if (_enviado) _TarjetaEnviado(email: _email.text.trim()) else ..._formulario(),
          ],
        ),
      ),
    );
  }

  List<Widget> _formulario() => [
        if (_mensajeError != null) ...[
          BannerError(_mensajeError!),
          const SizedBox(height: 16),
        ],
        CampoAuth(
          controlador: _email,
          hint: 'Tu email registrado',
          teclado: TextInputType.emailAddress,
          accion: TextInputAction.done,
          conError: _mensajeError != null,
          alCambiar: () {
            if (_mensajeError != null) setState(() => _mensajeError = null);
          },
          alEnviar: _enviar,
        ),
        const SizedBox(height: 16),
        BotonLima(texto: 'ENVIAR ENLACE', cargando: _cargando, alPresionar: _enviar),
      ];
}

class _TarjetaEnviado extends StatelessWidget {
  const _TarjetaEnviado({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          const Icon(Icons.mark_email_read_outlined, color: Colors.white70, size: 40),
          const SizedBox(height: 14),
          const Text(
            '¡Enlace enviado!',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Revisá tu bandeja en '),
                TextSpan(
                  text: email,
                  style: const TextStyle(color: Colores.lima, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 28),
            ),
            child: const Text('VOLVER AL LOGIN'),
          ),
        ],
      ),
    );
  }
}

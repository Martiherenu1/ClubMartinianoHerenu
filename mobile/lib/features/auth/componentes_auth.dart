/// Piezas comunes de las pantallas de acceso (login, registro, recuperar
/// contraseña), con el estilo del Figma: fondo con foto y gradiente, campos
/// translúcidos y banner de error en rojo.
library;

import 'package:flutter/material.dart';

import '../../app/tema.dart';

const _rojo = Color(0xFFFF4D5A);

/// Las pantallas de acceso son siempre oscuras (así están en el Figma), sin
/// importar el modo claro/oscuro elegido en el perfil.
class FondoAuth extends StatelessWidget {
  const FondoAuth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: temaOscuro,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/fondo_login.png', fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xE6000000), // 90 %
                    Color(0xB8000000), // 72 %
                    Color(0xF7000000), // 97 %
                  ],
                  stops: [0, 0.5, 1],
                ),
              ),
            ),
            SafeArea(child: child),
          ],
        ),
      ),
    );
  }
}

/// "CLUB MARTINIANO HEREÑU" con el apellido en lima, siempre en una línea.
class TituloClub extends StatelessWidget {
  const TituloClub({super.key});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'CLUB '),
            TextSpan(
              text: 'MARTINIANO HEREÑU',
              style: TextStyle(color: Colores.lima),
            ),
          ],
        ),
        style: Tipografia.titulo(size: 40, color: Colors.white),
        maxLines: 1,
      ),
    );
  }
}

/// Texto chico, en mayúsculas y lima, que va arriba de los títulos.
class Sobretitulo extends StatelessWidget {
  const Sobretitulo(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto.toUpperCase(),
      style: const TextStyle(
        color: Colores.lima,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 4,
      ),
    );
  }
}

/// Campo de texto translúcido. Con `conError` se pinta el borde de rojo (el banner
/// de arriba explica el motivo).
class CampoAuth extends StatefulWidget {
  const CampoAuth({
    super.key,
    required this.controlador,
    required this.hint,
    this.etiqueta,
    this.esPassword = false,
    this.conError = false,
    this.teclado,
    this.alCambiar,
    this.autofillHints,
    this.accion = TextInputAction.next,
    this.alEnviar,
  });

  final TextEditingController controlador;
  final String hint;
  final String? etiqueta;
  final bool esPassword;
  final bool conError;
  final TextInputType? teclado;
  final VoidCallback? alCambiar;
  final Iterable<String>? autofillHints;
  final TextInputAction accion;
  final VoidCallback? alEnviar;

  @override
  State<CampoAuth> createState() => _CampoAuthState();
}

class _CampoAuthState extends State<CampoAuth> {
  bool _oculta = true;

  @override
  Widget build(BuildContext context) {
    final borde = widget.conError ? _rojo.withValues(alpha: 0.6) : null;
    final campo = TextField(
      controller: widget.controlador,
      obscureText: widget.esPassword && _oculta,
      keyboardType: widget.teclado,
      textInputAction: widget.accion,
      autofillHints: widget.autofillHints,
      autocorrect: false,
      enableSuggestions: !widget.esPassword,
      onChanged: (_) => widget.alCambiar?.call(),
      onSubmitted: (_) => widget.alEnviar?.call(),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: widget.hint,
        filled: true,
        fillColor: widget.conError
            ? _rojo.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.08),
        enabledBorder: borde == null
            ? null
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borde),
              ),
        suffixIcon: widget.esPassword
            ? IconButton(
                tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
                onPressed: () => setState(() => _oculta = !_oculta),
                icon: Icon(
                  _oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              )
            : null,
      ),
    );

    if (widget.etiqueta == null) return campo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            widget.etiqueta!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        campo,
      ],
    );
  }
}

/// Cartel rojo de error de los formularios ("Completá todos los campos").
class BannerError extends StatelessWidget {
  const BannerError(this.mensaje, {super.key});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _rojo.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _rojo.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: _rojo),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(color: _rojo, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón lima principal; muestra un indicador mientras `cargando`.
class BotonLima extends StatelessWidget {
  const BotonLima({
    super.key,
    required this.texto,
    required this.alPresionar,
    this.cargando = false,
  });

  final String texto;
  final VoidCallback? alPresionar;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: cargando ? null : alPresionar,
      child: cargando
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
            )
          : Text(texto),
    );
  }
}

/// "‹ Volver" de la parte de arriba.
class BotonVolver extends StatelessWidget {
  const BotonVolver({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.chevron_left, size: 18),
        label: const Text('Volver'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white.withValues(alpha: 0.6),
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}

/// Cambiar contraseña (CU-04): contraseña actual, nueva con requisitos en vivo y
/// repetición. Devuelve `true` al volver si la contraseña quedó cambiada.
///
/// Se hace directo contra Firebase (la app confirma la actual y después aplica
/// la nueva): la contraseña nunca pasa por nuestra API.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/tema.dart';
import '../../core/errores.dart';
import '../../core/servicio_auth.dart';
import '../../widgets/carga_async.dart';
import '../auth/validaciones.dart';

const _rojo = Color(0xFFDC2626);
const _ambar = Color(0xFFD97706);

/// Qué requisitos cumple una contraseña nueva (los tres del Figma).
({bool largo, bool mayuscula, bool numero}) evaluarPassword(String texto) => (
      largo: texto.length >= largoMinimoPassword,
      mayuscula: RegExp(r'[A-ZÁÉÍÓÚÑ]').hasMatch(texto),
      numero: RegExp(r'\d').hasMatch(texto),
    );

class PantallaCambiarPassword extends StatefulWidget {
  const PantallaCambiarPassword({super.key});

  @override
  State<PantallaCambiarPassword> createState() => _PantallaCambiarPasswordState();
}

class _PantallaCambiarPasswordState extends State<PantallaCambiarPassword> {
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _repetir = TextEditingController();

  bool _guardando = false;
  bool _intentoGuardar = false;

  /// La contraseña actual que Firebase rechazó (se limpia al volver a escribirla).
  String? _errorActualServidor;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _repetir.dispose();
    super.dispose();
  }

  bool get _nuevaCumple {
    final r = evaluarPassword(_nueva.text);
    return r.largo && r.mayuscula && r.numero;
  }

  String? get _errorActual {
    if (_errorActualServidor != null) return _errorActualServidor;
    if (_intentoGuardar && _actual.text.isEmpty) return 'Ingresá tu contraseña actual.';
    return null;
  }

  String? get _errorNueva {
    if (!_intentoGuardar) return null;
    if (!_nuevaCumple) return 'La contraseña nueva no cumple los requisitos.';
    if (_nueva.text == _actual.text) {
      return 'La nueva contraseña tiene que ser distinta de la actual.';
    }
    return null;
  }

  String? get _errorRepetir {
    if (!_intentoGuardar) return null;
    if (_repetir.text != _nueva.text) return 'Las contraseñas no coinciden.';
    return null;
  }

  void _alEscribir() => setState(() {});

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() {
      _intentoGuardar = true;
      _errorActualServidor = null;
    });
    if (_errorActual != null || _errorNueva != null || _errorRepetir != null) return;

    final auth = context.read<ServicioAuth>();
    final navegador = Navigator.of(context);
    setState(() => _guardando = true);
    try {
      await auth.cambiarPassword(actual: _actual.text, nueva: _nueva.text);
      if (mounted) navegador.pop(true);
    } on NoAutenticado {
      // La sesión ya no sirve: se vuelve al login.
      navegador.popUntil((r) => r.isFirst);
      await auth.cerrarSesion();
    } on ErrorApp catch (e) {
      if (!mounted) return;
      // Se deja de mostrar la carga ANTES de la tarjeta de error.
      setState(() => _guardando = false);
      if (e is ErrorNegocio && e.codigo == codigoPasswordActualIncorrecta) {
        setState(() => _errorActualServidor = e.mensaje);
      } else {
        await mostrarFallo(context, e);
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;
    final req = evaluarPassword(_nueva.text);
    final cumplidos = [req.largo, req.mayuscula, req.numero].where((c) => c).length;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(18, arriba + 26, 18, 32),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Semantics(
                button: true,
                label: 'Volver',
                child: Text(
                  '‹ Volver',
                  style: Tipografia.texto(size: 11, color: context.colorTextoSuave),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'SEGURIDAD',
            style: Tipografia.texto(
              size: 9,
              peso: FontWeight.w900,
              color: context.colorAcento,
              espaciado: 2.7,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'CAMBIAR\n'),
                TextSpan(
                  text: 'CONTRASEÑA',
                  style: TextStyle(color: context.colorAcento),
                ),
              ],
            ),
            style: Tipografia.titulo(size: 40, color: context.colorTexto)
                .copyWith(height: 1.05),
          ),
          const SizedBox(height: 4),
          Text(
            'Ingresá tu contraseña actual y elegí una nueva.',
            style: Tipografia.texto(size: 11, color: context.colorTextoSuave),
          ),
          const SizedBox(height: 24),
          _CampoPassword(
            etiqueta: 'Contraseña actual',
            controlador: _actual,
            error: _errorActual,
            alCambiar: () => setState(() {
              _errorActualServidor = null;
            }),
          ),
          const SizedBox(height: 16),
          _CampoPassword(
            etiqueta: 'Nueva contraseña',
            controlador: _nueva,
            error: _errorNueva,
            alCambiar: _alEscribir,
          ),
          const SizedBox(height: 9),
          _Fortaleza(cumplidos: cumplidos, hayTexto: _nueva.text.isNotEmpty),
          const SizedBox(height: 9),
          _Requisito('Al menos $largoMinimoPassword caracteres', req.largo),
          const SizedBox(height: 4),
          _Requisito('Una letra mayúscula', req.mayuscula),
          const SizedBox(height: 4),
          _Requisito('Un número', req.numero),
          const SizedBox(height: 16),
          _CampoPassword(
            etiqueta: 'Repetir nueva contraseña',
            controlador: _repetir,
            error: _errorRepetir,
            alCambiar: _alEscribir,
            accion: TextInputAction.done,
            alEnviar: _guardar,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                  )
                : const Text('GUARDAR CAMBIOS'),
          ),
          const SizedBox(height: 14),
          Center(
            child: GestureDetector(
              onTap: _guardando ? null : () => Navigator.of(context).maybePop(),
              child: Semantics(
                button: true,
                label: 'Cancelar',
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    'Cancelar',
                    style: Tipografia.texto(
                      size: 11,
                      peso: FontWeight.w700,
                      color: context.colorTextoSuave,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampoPassword extends StatefulWidget {
  const _CampoPassword({
    required this.etiqueta,
    required this.controlador,
    required this.alCambiar,
    this.error,
    this.accion = TextInputAction.next,
    this.alEnviar,
  });

  final String etiqueta;
  final TextEditingController controlador;
  final VoidCallback alCambiar;
  final String? error;
  final TextInputAction accion;
  final VoidCallback? alEnviar;

  @override
  State<_CampoPassword> createState() => _CampoPasswordState();
}

class _CampoPasswordState extends State<_CampoPassword> {
  bool _oculta = true;

  @override
  Widget build(BuildContext context) {
    final conError = widget.error != null;
    final ojo = IconButton(
      tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
      onPressed: () => setState(() => _oculta = !_oculta),
      icon: Icon(
        _oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 18,
        color: context.colorTextoSuave,
      ),
    );
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: conError ? _rojo : context.colorBordeTarjeta),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.etiqueta,
          style: Tipografia.texto(
            size: 10,
            peso: FontWeight.w500,
            color: context.colorTextoSuave,
            espaciado: 2.2,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: widget.controlador,
          obscureText: _oculta,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: widget.accion,
          onChanged: (_) => widget.alCambiar(),
          onSubmitted: (_) => widget.alEnviar?.call(),
          style: Tipografia.texto(size: 13, color: context.colorTexto),
          decoration: InputDecoration(
            filled: true,
            fillColor: conError
                ? _rojo.withValues(alpha: 0.08)
                : (context.esModoOscuro
                    ? Colors.white.withValues(alpha: 0.07)
                    : const Color(0xFFE9ECEF)),
            contentPadding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
            enabledBorder: borde,
            focusedBorder: borde.copyWith(
              borderSide: BorderSide(color: conError ? _rojo : Colores.lima, width: 1.5),
            ),
            suffixIcon: ojo,
          ),
        ),
        if (conError)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              widget.error!,
              style: Tipografia.texto(size: 10, peso: FontWeight.w500, color: _rojo),
            ),
          ),
      ],
    );
  }
}

/// Tres barras y una leyenda según cuántos requisitos se cumplen.
class _Fortaleza extends StatelessWidget {
  const _Fortaleza({required this.cumplidos, required this.hayTexto});

  final int cumplidos;
  final bool hayTexto;

  @override
  Widget build(BuildContext context) {
    final color = switch (cumplidos) {
      3 => context.colorAcento,
      2 => _ambar,
      _ => _rojo,
    };
    final leyenda = switch (cumplidos) {
      3 => 'CONTRASEÑA FUERTE',
      2 => 'CONTRASEÑA MEDIA',
      _ => 'CONTRASEÑA DÉBIL',
    };
    final vacia = context.esModoOscuro
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: hayTexto && i < cumplidos ? color : vacia,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (hayTexto) ...[
          const SizedBox(height: 9),
          Text(
            leyenda,
            style: Tipografia.texto(
              size: 9,
              peso: FontWeight.w900,
              color: color,
              espaciado: 1.6,
            ),
          ),
        ],
      ],
    );
  }
}

class _Requisito extends StatelessWidget {
  const _Requisito(this.texto, this.cumplido);

  final String texto;
  final bool cumplido;

  @override
  Widget build(BuildContext context) {
    final color = cumplido ? context.colorAcento : context.colorTextoSuave;
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cumplido ? color : Colors.transparent,
            border: Border.all(color: color),
          ),
        ),
        const SizedBox(width: 7),
        Text(texto, style: Tipografia.texto(size: 10, color: color)),
      ],
    );
  }
}

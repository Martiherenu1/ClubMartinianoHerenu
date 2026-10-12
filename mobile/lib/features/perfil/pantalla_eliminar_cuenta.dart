/// Baja de la cuenta (CU-07): encuesta de salida, "Procesando…" y "Gracias".
///
/// Son tres pasos de una misma pantalla (siempre oscura, como en el Figma). Si
/// la baja falla, la pantalla se cierra devolviendo el error para que el perfil
/// lo muestre; si sale bien, cierra la sesión y la app vuelve al login.
///
/// La encuesta es opcional ("Omitir"). Por ahora las respuestas no se guardan:
/// el backend no tiene dónde recibirlas.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/tema.dart';
import '../../core/api_client.dart';
import '../../core/errores.dart';
import '../../core/servicio_auth.dart';
import '../../core/servicio_notificaciones.dart';
import '../../data/usuarios_api.dart';

const _rojo = Color(0xFFDC2626);
const _rojoClaro = Color(0xFFF87171);
const _verde = Color(0xFF4ADE80);

enum _Fase { encuesta, procesando, gracias }

class FlujoEliminarCuenta extends StatefulWidget {
  const FlujoEliminarCuenta({
    super.key,
    this.esperaMinima = const Duration(milliseconds: 1200),
    this.esperaGracias = const Duration(seconds: 3),
  });

  /// Tiempo mínimo que se ve "Procesando…" (si la API contesta antes, igual se
  /// espera, para que el usuario alcance a leerlo).
  final Duration esperaMinima;

  /// Cuánto se ve "Gracias" antes de volver al login.
  final Duration esperaGracias;

  @override
  State<FlujoEliminarCuenta> createState() => _FlujoEliminarCuentaState();
}

class _FlujoEliminarCuentaState extends State<FlujoEliminarCuenta> {
  _Fase _fase = _Fase.encuesta;
  Timer? _timer;
  bool _terminando = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _eliminar() async {
    setState(() => _fase = _Fase.procesando);
    final api = UsuariosApi(context.read<ApiClient>());
    try {
      await Future.wait<void>([
        api.eliminarCuenta(),
        Future<void>.delayed(widget.esperaMinima),
      ]);
      if (!mounted) return;
      setState(() => _fase = _Fase.gracias);
      _timer = Timer(widget.esperaGracias, _terminar);
    } on ErrorApp catch (e) {
      if (mounted) Navigator.of(context).pop(e);
    }
  }

  /// La cuenta ya no existe: se cierra la sesión y se sale de esta pantalla (que
  /// está apilada sobre la app, así que no la descarta sola el cambio de sesión).
  Future<void> _terminar() async {
    if (_terminando || !mounted) return;
    _terminando = true;
    final auth = context.read<ServicioAuth>();
    final notificaciones = context.read<ServicioNotificaciones>();
    Navigator.of(context).popUntil((r) => r.isFirst);
    // El backend ya borró los celulares de la cuenta; acá se descarta el token local.
    await notificaciones.olvidarToken();
    await auth.cerrarSesion();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: temaOscuro,
      child: PopScope(
        // Una vez que empezó la baja no hay vuelta atrás.
        canPop: _fase == _Fase.encuesta,
        child: Scaffold(
          backgroundColor: Colores.fondoOscuro,
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: switch (_fase) {
                _Fase.encuesta => _Encuesta(
                    key: const ValueKey('encuesta'),
                    alContinuar: _eliminar,
                  ),
                _Fase.procesando => const _Procesando(key: ValueKey('procesando')),
                _Fase.gracias => GestureDetector(
                    key: const ValueKey('gracias'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _terminar,
                    child: const _Gracias(),
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Encuesta extends StatefulWidget {
  const _Encuesta({super.key, required this.alContinuar});

  final VoidCallback alContinuar;

  @override
  State<_Encuesta> createState() => _EncuestaState();
}

class _EncuestaState extends State<_Encuesta> {
  static const _humores = [
    (Icons.sentiment_satisfied_alt_outlined, 'Satisfecho'),
    (Icons.sentiment_neutral_outlined, 'Regular'),
    (Icons.sentiment_dissatisfied_outlined, 'Insatisfecho'),
  ];

  static const _motivos = [
    'Precio muy alto',
    'No encontré lo que buscaba',
    'Prefiero otra app',
    'Problemas técnicos',
    'La usé poco',
    'Otro',
  ];

  int? _humor;
  final _motivosElegidos = <String>{};
  final _comentario = TextEditingController();

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suave = Colors.white.withValues(alpha: 0.42);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      children: [
        const Center(child: Text('👋', style: TextStyle(fontSize: 44))),
        const SizedBox(height: 16),
        Text(
          'ANTES DE IRTE,',
          textAlign: TextAlign.center,
          style: Tipografia.titulo(size: 30, color: Colors.white),
        ),
        Text(
          '¿CÓMO FUE TU\nEXPERIENCIA?',
          textAlign: TextAlign.center,
          style: Tipografia.titulo(size: 30, color: Colores.lima),
        ),
        const SizedBox(height: 12),
        Text(
          'Tu opinión nos ayuda a mejorar el Club Martiniano Hereñu para todos.',
          textAlign: TextAlign.center,
          style: Tipografia.texto(size: 12, color: suave),
        ),
        const SizedBox(height: 28),
        _Subtitulo('¿Cómo te sentiste?', suave),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < _humores.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _TarjetaHumor(
                  icono: _humores[i].$1,
                  texto: _humores[i].$2,
                  elegida: _humor == i,
                  alPresionar: () => setState(() => _humor = i),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        _Subtitulo('¿Por qué eliminás tu cuenta?', suave),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final motivo in _motivos)
              _ChipMotivo(
                texto: motivo,
                elegido: _motivosElegidos.contains(motivo),
                alPresionar: () => setState(() {
                  if (!_motivosElegidos.remove(motivo)) _motivosElegidos.add(motivo);
                }),
              ),
          ],
        ),
        const SizedBox(height: 24),
        _Subtitulo('Comentario adicional (opcional)', suave),
        const SizedBox(height: 12),
        TextField(
          controller: _comentario,
          minLines: 4,
          maxLines: 4,
          maxLength: 300,
          style: Tipografia.texto(size: 13, color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Contanos qué podríamos mejorar...',
            counterText: '',
            contentPadding: EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              flex: 4,
              child: _BotonEncuesta(
                texto: 'Omitir',
                color: Colors.white.withValues(alpha: 0.55),
                fondo: Colors.white.withValues(alpha: 0.07),
                alPresionar: widget.alContinuar,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 7,
              child: _BotonEncuesta(
                texto: 'ENVIAR Y ELIMINAR',
                icono: Icons.send_outlined,
                color: Colors.white,
                fondo: _rojo,
                alPresionar: widget.alContinuar,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Subtitulo extends StatelessWidget {
  const _Subtitulo(this.texto, this.color);

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto.toUpperCase(),
      style: Tipografia.texto(size: 10, color: color, espaciado: 2),
    );
  }
}

class _TarjetaHumor extends StatelessWidget {
  const _TarjetaHumor({
    required this.icono,
    required this.texto,
    required this.elegida,
    required this.alPresionar,
  });

  final IconData icono;
  final String texto;
  final bool elegida;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final color = elegida ? _rojoClaro : Colors.white.withValues(alpha: 0.45);
    return Semantics(
      button: true,
      selected: elegida,
      label: texto,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: alPresionar,
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: elegida ? _rojo.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: elegida ? _rojoClaro : Colors.white.withValues(alpha: 0.1),
              width: elegida ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 26, color: color),
              const SizedBox(height: 6),
              Text(
                texto,
                style: Tipografia.texto(size: 10, peso: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipMotivo extends StatelessWidget {
  const _ChipMotivo({
    required this.texto,
    required this.elegido,
    required this.alPresionar,
  });

  final String texto;
  final bool elegido;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: elegido,
      label: texto,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: alPresionar,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: elegido ? _rojoClaro : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: elegido ? _rojoClaro : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            texto,
            style: Tipografia.texto(
              size: 12,
              peso: FontWeight.w700,
              color: elegido ? Colors.black : Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonEncuesta extends StatelessWidget {
  const _BotonEncuesta({
    required this.texto,
    required this.color,
    required this.fondo,
    required this.alPresionar,
    this.icono,
  });

  final String texto;
  final Color color;
  final Color fondo;
  final VoidCallback alPresionar;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: texto,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: alPresionar,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(12),
            boxShadow: fondo == _rojo
                ? [
                    BoxShadow(
                      color: _rojo.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icono != null) ...[
                Icon(icono, size: 15, color: color),
                const SizedBox(width: 8),
              ],
              Text(
                texto,
                style: icono == null
                    ? Tipografia.texto(size: 14, peso: FontWeight.w700, color: color)
                    : Tipografia.texto(
                        size: 11.5,
                        peso: FontWeight.w900,
                        color: color,
                        espaciado: 0.5,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Procesando extends StatelessWidget {
  const _Procesando({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 220,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEF4444).withValues(alpha: 0.13),
              ),
              child: const Icon(Icons.delete_outline, size: 30, color: _rojoClaro),
            ),
            const SizedBox(height: 28),
            Text(
              'PROCESANDO…',
              style: Tipografia.titulo(size: 26, color: const Color(0xFFF0F1F8)),
            ),
            const SizedBox(height: 6),
            Text(
              'Eliminando tu cuenta',
              style: Tipografia.texto(
                size: 12,
                color: Colors.white.withValues(alpha: 0.42),
              ),
            ),
            const SizedBox(height: 22),
            // Avanza hasta casi el final y espera a que termine la baja.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 0.88),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeOut,
              builder: (_, valor, _) => ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: valor,
                  minHeight: 3,
                  color: _rojoClaro,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Gracias extends StatelessWidget {
  const _Gracias();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: _verde.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(27),
                border: Border.all(color: _verde.withValues(alpha: 0.27)),
              ),
              child: const Icon(Icons.check, size: 46, color: _verde),
            ),
            const SizedBox(height: 20),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '¡GRACIAS POR TU OPINIÓN!',
                style: Tipografia.titulo(size: 34, color: const Color(0xFFF0F1F8)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 280,
              child: Text(
                'Tu cuenta fue eliminada. Esperamos verte de nuevo en el '
                'Club Martiniano Hereñu pronto.',
                textAlign: TextAlign.center,
                style: Tipografia.texto(
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.42),
                ).copyWith(height: 1.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

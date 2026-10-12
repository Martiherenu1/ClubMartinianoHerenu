/// Perfil (CU-05, CU-06): datos personales con edición en el lugar, modo
/// oscuro, cambio de contraseña (CU-04), cerrar sesión (CU-02) y baja de la
/// cuenta (CU-07), como en el Figma.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/controlador_tema.dart';
import '../../app/tema.dart';
import '../../core/api_client.dart';
import '../../core/errores.dart';
import '../../core/formato.dart';
import '../../core/servicio_auth.dart';
import '../../data/usuarios_api.dart';
import '../../widgets/carga_async.dart';
import '../auth/validaciones.dart';
import '../shell/navegacion_principal.dart';
import 'pantalla_cambiar_password.dart';
import 'pantalla_eliminar_cuenta.dart';

const _rojo = Color(0xFFDC2626);

class PantallaPerfil extends StatelessWidget {
  const PantallaPerfil({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CargaAsync<Usuario>(
        cargar: () => UsuariosApi(context.read<ApiClient>()).miPerfil(),
        construir: (context, usuario) => _ContenidoPerfil(usuario: usuario),
      ),
    );
  }
}

class _ContenidoPerfil extends StatefulWidget {
  const _ContenidoPerfil({required this.usuario});

  final Usuario usuario;

  @override
  State<_ContenidoPerfil> createState() => _ContenidoPerfilState();
}

class _ContenidoPerfilState extends State<_ContenidoPerfil> {
  late Usuario _usuario = widget.usuario;
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _dni = TextEditingController();
  late DateTime _fecha = _usuario.fechaNacimiento;

  bool _editando = false;
  bool _guardando = false;
  bool _intentoGuardar = false;
  bool _confirmandoBaja = false;

  /// Zona de peligro: al pedir la confirmación se desplaza hasta mostrarla
  /// completa (queda debajo de la barra inferior).
  final _claveZonaPeligro = GlobalKey();

  @override
  void initState() {
    super.initState();
    _mostrarDatos();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _apellido.dispose();
    _dni.dispose();
    super.dispose();
  }

  /// Vuelve a poner en los campos los datos guardados del usuario.
  void _mostrarDatos() {
    _nombre.text = _usuario.nombre;
    _apellido.text = _usuario.apellido;
    _dni.text = formatearDni(_usuario.dni);
    _fecha = _usuario.fechaNacimiento;
  }

  void _empezarEdicion() {
    setState(() {
      _editando = true;
      _intentoGuardar = false;
      _dni.text = _usuario.dni; // sin puntos para poder editarlo
    });
  }

  void _cancelarEdicion() {
    setState(() {
      _editando = false;
      _mostrarDatos();
    });
  }

  String? get _errorNombre =>
      _intentoGuardar && _nombre.text.trim().isEmpty ? 'Ingresá tu nombre.' : null;

  String? get _errorApellido =>
      _intentoGuardar && _apellido.text.trim().isEmpty ? 'Ingresá tu apellido.' : null;

  String? get _errorDni =>
      _intentoGuardar && !dniValido(_dni.text) ? 'El DNI debe tener 7 u 8 números.' : null;

  Future<void> _elegirFecha() async {
    final ayer = DateTime.now().subtract(const Duration(days: 1));
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha.isAfter(ayer) ? ayer : _fecha,
      firstDate: DateTime(1900),
      lastDate: ayer,
      helpText: 'FECHA DE NACIMIENTO',
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() => _intentoGuardar = true);
    if (_nombre.text.trim().isEmpty ||
        _apellido.text.trim().isEmpty ||
        !dniValido(_dni.text)) {
      return;
    }

    final nombre = _nombre.text.trim();
    final apellido = _apellido.text.trim();
    final dni = normalizarDni(_dni.text);
    final u = _usuario;
    final sinCambios = nombre == u.nombre &&
        apellido == u.apellido &&
        dni == u.dni &&
        _fecha == u.fechaNacimiento;
    if (sinCambios) {
      _cancelarEdicion();
      return;
    }

    setState(() => _guardando = true);
    try {
      final actualizado = await UsuariosApi(context.read<ApiClient>()).editarPerfil(
        nombre: nombre,
        apellido: apellido,
        dni: dni,
        fechaNacimiento: _fecha,
      );
      if (!mounted) return;
      // La Home saluda por el nombre: que lo vuelva a pedir.
      context.read<ReservasCambiadas>().avisar();
      setState(() {
        _usuario = actualizado;
        _editando = false;
        _mostrarDatos();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Datos actualizados')));
    } on ErrorApp catch (e) {
      if (!mounted) return;
      // Sigue en edición para poder corregir (ej.: DNI ya registrado, 409).
      setState(() => _guardando = false);
      await mostrarFallo(context, e);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cambiarPassword() async {
    final cambiada = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => const PantallaCambiarPassword()),
    );
    if (cambiada == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0B0C16),
          content: Row(
            children: [
              const Icon(Icons.check, size: 16, color: Colores.lima),
              const SizedBox(width: 10),
              Text(
                'Contraseña actualizada',
                style: Tipografia.texto(size: 13, color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _pedirConfirmacionDeBaja() {
    setState(() => _confirmandoBaja = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contexto = _claveZonaPeligro.currentContext;
      if (contexto == null) return;
      Scrollable.ensureVisible(
        contexto,
        duration: const Duration(milliseconds: 250),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  Future<void> _eliminarCuenta() async {
    final error = await Navigator.of(context, rootNavigator: true).push<Object?>(
      MaterialPageRoute(builder: (_) => const FlujoEliminarCuenta()),
    );
    if (!mounted) return;
    setState(() => _confirmandoBaja = false);
    // Si salió bien, el flujo ya cerró la sesión y esta pantalla no existe más.
    if (error != null) await mostrarFallo(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;
    final u = _usuario;
    return ListView(
      padding: EdgeInsets.fromLTRB(18, arriba + 20, 18, 24),
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'MI '),
              TextSpan(text: 'PERFIL', style: TextStyle(color: context.colorAcento)),
            ],
          ),
          style: Tipografia.titulo(size: 40, color: context.colorTexto),
        ),
        const SizedBox(height: 18),
        _Cabecera(usuario: u),
        const SizedBox(height: 22),
        const _TarjetaModoOscuro(),
        const SizedBox(height: 14),
        _tarjetaDatos(context),
        const SizedBox(height: 12),
        _tarjetaSeguridad(context),
        const SizedBox(height: 12),
        _botonCerrarSesion(context),
        const SizedBox(height: 12),
        _zonaDePeligro(context),
      ],
    );
  }

  // --- Datos personales ---

  Widget _tarjetaDatos(BuildContext context) {
    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'DATOS PERSONALES',
                  style: Tipografia.texto(
                    size: 10,
                    peso: FontWeight.w700,
                    color: context.colorTextoSuave,
                    espaciado: 2.2,
                  ),
                ),
              ),
              if (_editando) ...[
                _BotonPequeno(
                  texto: 'Cancelar',
                  color: context.colorTextoSuave,
                  alPresionar: _guardando ? null : _cancelarEdicion,
                ),
                const SizedBox(width: 8),
                _BotonPequeno(
                  texto: 'Guardar',
                  icono: Icons.check,
                  color: Colors.black,
                  fondo: Colores.lima,
                  cargando: _guardando,
                  alPresionar: _guardar,
                ),
              ] else
                _BotonPequeno(
                  texto: 'Editar',
                  icono: Icons.edit_outlined,
                  color: context.colorAcento,
                  conBorde: true,
                  alPresionar: _empezarEdicion,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CampoDato(
                  etiqueta: 'Nombre',
                  controlador: _nombre,
                  editando: _editando,
                  error: _errorNombre,
                  alCambiar: () => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CampoDato(
                  etiqueta: 'Apellido',
                  controlador: _apellido,
                  editando: _editando,
                  error: _errorApellido,
                  alCambiar: () => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CampoDato(
            etiqueta: 'DNI',
            controlador: _dni,
            editando: _editando,
            error: _errorDni,
            teclado: TextInputType.number,
            formateadores: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            alCambiar: () => setState(() {}),
          ),
          const SizedBox(height: 12),
          const _Etiqueta('Fecha de nacimiento'),
          const SizedBox(height: 6),
          _CajaDato(
            editando: _editando,
            alPresionar: _editando ? _elegirFecha : null,
            hijo: Row(
              children: [
                Expanded(
                  child: Text(
                    formatearFechaNumerica(_fecha),
                    style: Tipografia.texto(
                      size: 13,
                      color: _editando ? context.colorTexto : context.colorTextoSuave,
                    ),
                  ),
                ),
                if (_editando)
                  Icon(Icons.calendar_today_outlined,
                      size: 16, color: context.colorTextoSuave),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'EMAIL '),
                TextSpan(
                  text: '(solo lectura)',
                  style: TextStyle(
                    fontSize: 9,
                    color: context.colorTextoTenue,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            style: Tipografia.texto(
              size: 10,
              peso: FontWeight.w500,
              color: context.colorTextoSuave,
              espaciado: 2.2,
            ),
          ),
          const SizedBox(height: 6),
          Opacity(
            opacity: 0.6,
            child: _CajaDato(
              editando: false,
              hijo: Row(
                children: [
                  Expanded(
                    child: Text(
                      _usuario.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tipografia.texto(size: 13, color: context.colorTextoSuave),
                    ),
                  ),
                  Icon(Icons.lock_outline, size: 15, color: context.colorTextoSuave),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Seguridad, sesión y baja ---

  Widget _tarjetaSeguridad(BuildContext context) {
    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seguridad',
            style: Tipografia.texto(
              size: 10,
              peso: FontWeight.w700,
              color: context.colorTextoSuave,
              espaciado: 2.2,
            ),
          ),
          const SizedBox(height: 6),
          Semantics(
            button: true,
            label: 'Cambiar contraseña',
            child: InkWell(
              onTap: _cambiarPassword,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cambiar contraseña',
                        style: Tipografia.texto(
                          size: 13,
                          peso: FontWeight.w600,
                          color: context.colorTexto,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: context.colorTextoSuave),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonCerrarSesion(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cerrar sesión',
      child: InkWell(
        onTap: () => context.read<ServicioAuth>().cerrarSesion(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: context.colorTarjeta,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colorBordeTarjeta),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, size: 15, color: context.colorAcento),
              const SizedBox(width: 8),
              Text(
                'Cerrar sesión',
                style: Tipografia.texto(
                  size: 13,
                  peso: FontWeight.w700,
                  color: context.colorAcento,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _zonaDePeligro(BuildContext context) {
    return Container(
      key: _claveZonaPeligro,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _rojo.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _rojo.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 13, color: _rojo.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text(
                'ZONA DE PELIGRO',
                style: Tipografia.texto(
                  size: 10,
                  peso: FontWeight.w900,
                  color: _rojo.withValues(alpha: 0.7),
                  espaciado: 2.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_confirmandoBaja)
            Semantics(
              button: true,
              label: 'Eliminar cuenta',
              child: InkWell(
                onTap: _pedirConfirmacionDeBaja,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: _rojo,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _rojo.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.delete_outline, size: 15, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Eliminar cuenta',
                        style: Tipografia.texto(
                          size: 13,
                          peso: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            _confirmarBaja(context),
        ],
      ),
    );
  }

  /// "Info eliminar cuenta" del Figma: confirmación en el lugar del botón.
  Widget _confirmarBaja(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿Estás seguro? Esta acción elimina todos tus datos permanentemente. '
          'Tus reservas próximas se cancelan.',
          style: Tipografia.texto(size: 13, color: _rojo.withValues(alpha: 0.9))
              .copyWith(height: 1.5),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _BotonConfirmacion(
                texto: 'Cancelar',
                color: context.colorTextoSuave,
                fondo: context.colorTarjeta,
                borde: context.colorBordeTarjeta,
                alPresionar: () => setState(() => _confirmandoBaja = false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BotonConfirmacion(
                texto: 'Eliminar',
                color: Colors.white,
                fondo: _rojo,
                alPresionar: _eliminarCuenta,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Avatar con iniciales, nombre, email y "Miembro activo".
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colores.lima,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            iniciales(usuario.nombre, usuario.apellido),
            style: Tipografia.titulo(size: 24, color: Colors.black),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                usuario.nombreCompleto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tipografia.titulo(size: 22, color: context.colorTexto),
              ),
              const SizedBox(height: 2),
              Text(
                usuario.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tipografia.texto(size: 11, color: context.colorTextoSuave),
              ),
              const SizedBox(height: 3),
              Text(
                'MIEMBRO ACTIVO',
                style: Tipografia.texto(
                  size: 9,
                  peso: FontWeight.w900,
                  color: context.colorAcento,
                  espaciado: 2.7,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TarjetaModoOscuro extends StatelessWidget {
  const _TarjetaModoOscuro();

  @override
  Widget build(BuildContext context) {
    final tema = context.watch<ControladorTema>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: context.colorTarjeta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorBordeTarjeta),
      ),
      child: Row(
        children: [
          Icon(
            tema.esOscuro ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            size: 16,
            color: context.colorTextoSuave,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tema.esOscuro ? 'Modo oscuro' : 'Modo nocturno',
              style: Tipografia.texto(
                size: 13,
                peso: FontWeight.w600,
                color: context.colorTexto,
              ),
            ),
          ),
          Switch(
            value: tema.esOscuro,
            onChanged: (_) => tema.alternar(),
            thumbColor: const WidgetStatePropertyAll(Colors.white),
            activeTrackColor: Colores.lima,
            inactiveTrackColor: Colors.black.withValues(alpha: 0.16),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorTarjeta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorBordeTarjeta),
      ),
      child: child,
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto.toUpperCase(),
      style: Tipografia.texto(
        size: 10,
        peso: FontWeight.w500,
        color: context.colorTextoSuave,
        espaciado: 2.2,
      ),
    );
  }
}

/// Caja de un dato: gris cuando solo se mira, con borde cuando se edita.
class _CajaDato extends StatelessWidget {
  const _CajaDato({
    required this.hijo,
    required this.editando,
    this.alPresionar,
    this.error = false,
  });

  final Widget hijo;
  final bool editando;
  final VoidCallback? alPresionar;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final oscuro = context.esModoOscuro;
    final base = oscuro ? Colors.white : Colors.black;
    return InkWell(
      onTap: alPresionar,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: error
              ? _rojo.withValues(alpha: 0.08)
              : base.withValues(alpha: editando ? 0.05 : 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: error ? _rojo : base.withValues(alpha: editando ? 0.13 : 0.08),
          ),
        ),
        child: hijo,
      ),
    );
  }
}

/// Campo de texto que solo se puede tocar al editar.
class _CampoDato extends StatelessWidget {
  const _CampoDato({
    required this.etiqueta,
    required this.controlador,
    required this.editando,
    required this.alCambiar,
    this.error,
    this.teclado,
    this.formateadores,
  });

  final String etiqueta;
  final TextEditingController controlador;
  final bool editando;
  final VoidCallback alCambiar;
  final String? error;
  final TextInputType? teclado;
  final List<TextInputFormatter>? formateadores;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Etiqueta(etiqueta),
        const SizedBox(height: 6),
        _CajaDato(
          editando: editando,
          error: error != null,
          hijo: IgnorePointer(
            ignoring: !editando,
            child: TextField(
              controller: controlador,
              readOnly: !editando,
              showCursor: editando,
              keyboardType: teclado,
              inputFormatters: formateadores,
              onChanged: (_) => alCambiar(),
              style: Tipografia.texto(
                size: 13,
                color: editando ? context.colorTexto : context.colorTextoSuave,
              ),
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(error!, style: Tipografia.texto(size: 10, color: _rojo)),
          ),
      ],
    );
  }
}

class _BotonPequeno extends StatelessWidget {
  const _BotonPequeno({
    required this.texto,
    required this.color,
    required this.alPresionar,
    this.icono,
    this.fondo,
    this.conBorde = false,
    this.cargando = false,
  });

  final String texto;
  final Color color;
  final VoidCallback? alPresionar;
  final IconData? icono;
  final Color? fondo;
  final bool conBorde;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: texto,
      child: InkWell(
        onTap: cargando ? null : alPresionar,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 31,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(8),
            border: conBorde ? Border.all(color: context.colorBordeTarjeta) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cargando)
                SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              else if (icono != null)
                Icon(icono, size: 12, color: color),
              if (cargando || icono != null) const SizedBox(width: 5),
              Text(
                texto,
                style: Tipografia.texto(size: 11, peso: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonConfirmacion extends StatelessWidget {
  const _BotonConfirmacion({
    required this.texto,
    required this.color,
    required this.fondo,
    required this.alPresionar,
    this.borde,
  });

  final String texto;
  final Color color;
  final Color fondo;
  final Color? borde;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: texto,
      child: InkWell(
        onTap: alPresionar,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(10),
            border: borde == null ? null : Border.all(color: borde!),
          ),
          child: Text(
            texto,
            style: Tipografia.texto(size: 12, peso: FontWeight.w700, color: color),
          ),
        ),
      ),
    );
  }
}

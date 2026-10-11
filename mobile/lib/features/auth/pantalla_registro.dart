/// Registro (CU-03). Estados del Figma: formulario, campos vacíos, usuario ya
/// registrado y registro exitoso ("¡Usuario Registrado!").
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/tema.dart';
import '../../core/api_client.dart';
import '../../core/errores.dart';
import '../../data/usuarios_api.dart';
import '../../widgets/tarjeta_error.dart';
import 'componentes_auth.dart';
import 'validaciones.dart';

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _dni = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  DateTime? _fechaNacimiento;

  bool _cargando = false;
  bool _intentoEnviar = false;
  bool _registrado = false;
  String? _mensajeError;

  static final _formatoFecha = DateFormat('dd/MM/yyyy');

  @override
  void dispose() {
    for (final c in [_nombre, _apellido, _dni, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hayCamposVacios =>
      _nombre.text.trim().isEmpty ||
      _apellido.text.trim().isEmpty ||
      _dni.text.trim().isEmpty ||
      _fechaNacimiento == null ||
      _email.text.trim().isEmpty ||
      _password.text.isEmpty;

  /// Primer problema de formato, en el orden en que aparecen los campos.
  String? get _errorDeFormato {
    if (!dniValido(_dni.text)) return 'El DNI debe tener 7 u 8 números.';
    if (!emailValido(_email.text)) return 'Ingresá un email válido.';
    if (!passwordValida(_password.text)) {
      return 'La contraseña debe tener al menos $largoMinimoPassword caracteres.';
    }
    return null;
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(hoy.year - 25, 1, 1),
      firstDate: DateTime(1900),
      lastDate: hoy,
      helpText: 'FECHA DE NACIMIENTO',
    );
    if (elegida != null) {
      setState(() {
        _fechaNacimiento = elegida;
        _mensajeError = null;
      });
    }
  }

  Future<void> _registrar() async {
    // CU-03 FA1: datos incompletos → no se llama al servidor.
    setState(() => _intentoEnviar = true);
    if (_hayCamposVacios) {
      setState(() => _mensajeError = 'Completá todos los campos');
      return;
    }
    final formato = _errorDeFormato;
    if (formato != null) {
      setState(() => _mensajeError = formato);
      return;
    }

    final usuarios = UsuariosApi(context.read<ApiClient>());
    setState(() {
      _cargando = true;
      _mensajeError = null;
    });
    try {
      await usuarios.registrar(
        nombre: _nombre.text.trim(),
        apellido: _apellido.text.trim(),
        dni: normalizarDni(_dni.text),
        fechaNacimiento: _fechaNacimiento!,
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) setState(() => _registrado = true);
    } on ErrorApp catch (e) {
      if (!mounted) return;
      // Se deja de mostrar la carga ANTES de la tarjeta de error.
      setState(() => _cargando = false);
      if (e is SinConexion || e is ErrorServidor) {
        await mostrarTarjetaError(context, e);
      } else if (e is ErrorNegocio &&
          (e.codigo == 'DNI_YA_REGISTRADO' || e.codigo == 'EMAIL_YA_REGISTRADO')) {
        // CU-03 FA2: se queda en el formulario para poder corregir los datos.
        setState(() => _mensajeError = 'Este usuario ya está registrado');
      } else {
        setState(() => _mensajeError = e.mensaje);
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _limpiarError() {
    if (_mensajeError != null) setState(() => _mensajeError = null);
  }

  bool _vacio(TextEditingController c) => _intentoEnviar && c.text.trim().isEmpty;

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
            const Sobretitulo('Nueva cuenta'),
            const SizedBox(height: 6),
            Text('CREAR CUENTA', style: Tipografia.titulo(size: 40, color: Colors.white)),
            const SizedBox(height: 20),
            if (_registrado) _TarjetaRegistrado() else ..._formulario(),
          ],
        ),
      ),
    );
  }

  List<Widget> _formulario() {
    return [
      if (_mensajeError != null) ...[
        BannerError(_mensajeError!),
        const SizedBox(height: 16),
      ],
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: CampoAuth(
              controlador: _nombre,
              etiqueta: 'Nombre *',
              hint: 'Juan',
              conError: _vacio(_nombre),
              alCambiar: _limpiarError,
              autofillHints: const [AutofillHints.givenName],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: CampoAuth(
              controlador: _apellido,
              etiqueta: 'Apellido *',
              hint: 'Pérez',
              conError: _vacio(_apellido),
              alCambiar: _limpiarError,
              autofillHints: const [AutofillHints.familyName],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      CampoAuth(
        controlador: _dni,
        etiqueta: 'DNI *',
        hint: '31.234.567',
        teclado: TextInputType.number,
        conError: _vacio(_dni),
        alCambiar: _limpiarError,
      ),
      const SizedBox(height: 12),
      _CampoFecha(
        fecha: _fechaNacimiento == null ? null : _formatoFecha.format(_fechaNacimiento!),
        conError: _intentoEnviar && _fechaNacimiento == null,
        alPresionar: _elegirFecha,
      ),
      const SizedBox(height: 12),
      CampoAuth(
        controlador: _email,
        etiqueta: 'Email *',
        hint: 'juan@email.com',
        teclado: TextInputType.emailAddress,
        conError: _vacio(_email),
        alCambiar: _limpiarError,
        autofillHints: const [AutofillHints.email],
      ),
      const SizedBox(height: 12),
      CampoAuth(
        controlador: _password,
        etiqueta: 'Contraseña *',
        hint: 'Mínimo $largoMinimoPassword caracteres',
        esPassword: true,
        accion: TextInputAction.done,
        conError: _intentoEnviar && _password.text.isEmpty,
        alCambiar: _limpiarError,
        alEnviar: _registrar,
      ),
      const SizedBox(height: 20),
      BotonLima(texto: 'CREAR CUENTA', cargando: _cargando, alPresionar: _registrar),
    ];
  }
}

class _CampoFecha extends StatelessWidget {
  const _CampoFecha({
    required this.fecha,
    required this.conError,
    required this.alPresionar,
  });

  final String? fecha;
  final bool conError;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    const rojo = Color(0xFFFF4D5A);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Fecha de nacimiento *',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        InkWell(
          onTap: alPresionar,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: conError
                  ? rojo.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: conError
                    ? rojo.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    fecha ?? 'dd/mm/aaaa',
                    style: TextStyle(
                      fontSize: 14,
                      color: fecha == null
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.white,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TarjetaRegistrado extends StatelessWidget {
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
          const Icon(Icons.check_circle_outline, color: Colores.lima, size: 40),
          const SizedBox(height: 12),
          const Text(
            '¡Usuario Registrado!',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Tu cuenta fue creada. Ya podés iniciar sesión.',
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

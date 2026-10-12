/// Llamadas a la API de usuarios (CU-03 registro, CU-05 perfil, CU-06 edición,
/// CU-07 baja de la cuenta).
library;

import '../core/api_client.dart';

class Usuario {
  const Usuario({
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.dni,
    required this.fechaNacimiento,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        nombre: json['nombre'] as String,
        apellido: json['apellido'] as String,
        email: json['email'] as String,
        dni: json['dni'] as String,
        fechaNacimiento: DateTime.parse(json['fecha_nacimiento'] as String),
      );

  final String nombre;
  final String apellido;
  final String email;
  final String dni;
  final DateTime fechaNacimiento;

  String get nombreCompleto => '$nombre $apellido';
}

String _fechaIso(DateTime f) =>
    '${f.year.toString().padLeft(4, '0')}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

class UsuariosApi {
  const UsuariosApi(this._api);

  final ApiClient _api;

  /// `POST /usuarios`: crea la cuenta en Firebase y el perfil. No requiere sesión.
  Future<Usuario> registrar({
    required String nombre,
    required String apellido,
    required String dni,
    required DateTime fechaNacimiento,
    required String email,
    required String password,
  }) async {
    final json = await _api.post('/usuarios', body: {
      'nombre': nombre,
      'apellido': apellido,
      'dni': dni,
      'fecha_nacimiento': _fechaIso(fechaNacimiento),
      'email': email,
      'password': password,
    });
    return Usuario.fromJson(json as Map<String, dynamic>);
  }

  /// `GET /usuarios/me`: perfil del usuario con sesión.
  Future<Usuario> miPerfil() async {
    final json = await _api.get('/usuarios/me');
    return Usuario.fromJson(json as Map<String, dynamic>);
  }

  /// `PUT /usuarios/me`: edita nombre, apellido, DNI y fecha de nacimiento (el
  /// email no se puede cambiar). Devuelve el perfil actualizado.
  Future<Usuario> editarPerfil({
    required String nombre,
    required String apellido,
    required String dni,
    required DateTime fechaNacimiento,
  }) async {
    final json = await _api.put('/usuarios/me', body: {
      'nombre': nombre,
      'apellido': apellido,
      'dni': dni,
      'fecha_nacimiento': _fechaIso(fechaNacimiento),
    });
    return Usuario.fromJson(json as Map<String, dynamic>);
  }

  /// `DELETE /usuarios/me`: da de baja la cuenta. El servidor cancela las
  /// reservas futuras y borra la cuenta de Firebase.
  Future<void> eliminarCuenta() => _api.delete('/usuarios/me');
}

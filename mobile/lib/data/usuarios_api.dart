/// Llamadas a la API de usuarios (CU-03 registro, CU-05 perfil).
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
    final f = fechaNacimiento;
    final json = await _api.post('/usuarios', body: {
      'nombre': nombre,
      'apellido': apellido,
      'dni': dni,
      'fecha_nacimiento':
          '${f.year.toString().padLeft(4, '0')}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}',
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
}

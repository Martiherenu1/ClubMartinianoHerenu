/// Errores de la app, ya traducidos de HTTP y de la red a casos que la
/// interfaz sabe mostrar (las tarjetas "Error de conexión" y "Error del
/// servidor" del Figma, la vuelta al login, y los mensajes inline).
library;

sealed class ErrorApp implements Exception {
  const ErrorApp(this.mensaje);

  /// Texto para mostrarle al usuario.
  final String mensaje;

  @override
  String toString() => '$runtimeType: $mensaje';
}

/// El celular no puede comunicarse con el servidor: sin internet, sin red o el
/// servidor no responde a tiempo. → tarjeta "Error de conexión a Internet".
class SinConexion extends ErrorApp {
  const SinConexion()
      : super('No hay conexión a Internet. Revisá tu red e intentá de nuevo.');
}

/// El servidor respondió con un error propio (5xx) o con algo inesperado.
/// → tarjeta "Error del servidor".
class ErrorServidor extends ErrorApp {
  const ErrorServidor()
      : super('Hubo un problema en el servidor. Intentá de nuevo más tarde.');
}

/// Email o contraseña incorrectos al iniciar sesión.
///
/// El mensaje es genérico a propósito (CU-01, FA2): no dice cuál de los dos datos
/// falló, para no revelar qué emails tienen cuenta.
class CredencialesInvalidas extends ErrorApp {
  const CredencialesInvalidas()
      : super('No se pudo iniciar sesión. Verificá tu email y contraseña.');
}

/// 401: el token falta, venció o la cuenta fue dada de baja. → vuelve al login.
class NoAutenticado extends ErrorApp {
  const NoAutenticado(super.mensaje);
}

/// Error de negocio con `{"error": {"codigo", "mensaje"}}` (400, 404, 409, 422).
/// El `mensaje` ya viene en español desde la API.
class ErrorNegocio extends ErrorApp {
  const ErrorNegocio({
    required this.codigo,
    required String mensaje,
    required this.status,
  }) : super(mensaje);

  /// Constante estable, ej. `HORARIO_OCUPADO`, `EMAIL_YA_REGISTRADO`.
  final String codigo;
  final int status;
}

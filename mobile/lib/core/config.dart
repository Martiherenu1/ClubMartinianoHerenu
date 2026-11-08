/// Configuración de la app.
library;

abstract final class Config {
  /// URL base de la API.
  ///
  /// Por defecto apunta a la API publicada en Render, así la app funciona apenas
  /// se instala. Para probar contra el backend local (`10.0.2.2` es la dirección
  /// con la que el emulador de Android ve el `localhost` de la PC):
  ///
  ///     flutter run --dart-define=API_URL=http://10.0.2.2:8000
  static const apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://clubmartinianoherenu-api.onrender.com',
  );

  /// Prefijo de la versión de la API.
  static const apiPrefijo = '/api/v1';

  /// La API gratuita de Render "se duerme" y la primera respuesta puede tardar
  /// ~50 s, por eso el timeout es generoso.
  static const timeoutApi = Duration(seconds: 60);
}

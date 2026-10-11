/// Validaciones de formato de los formularios de acceso.
///
/// Se hacen en la app para responder al instante sin llamar al servidor
/// (CU-01 FA1, CU-03 FA1); el backend las vuelve a verificar.
library;

final _regexEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _regexDni = RegExp(r'^\d{7,8}$');

/// Largo mínimo de la contraseña (lo dice el Figma: "Mínimo 8 caracteres").
const largoMinimoPassword = 8;

bool emailValido(String texto) => _regexEmail.hasMatch(texto.trim());

/// "31.234.567" → "31234567".
String normalizarDni(String texto) => texto.replaceAll(RegExp(r'[.\s]'), '');

bool dniValido(String texto) => _regexDni.hasMatch(normalizarDni(texto));

bool passwordValida(String texto) => texto.length >= largoMinimoPassword;

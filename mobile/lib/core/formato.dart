/// Formatos de texto que usan varias pantallas: precios, fechas, horas y las
/// etiquetas de deportes y tipos de cancha.
///
/// Se escriben a mano (sin `intl`) para que el resultado no dependa del idioma
/// del celular ni de inicializar datos de fecha.
library;

const _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// `3800` → `$ 3.800` (formato argentino: punto como separador de miles).
String formatearPrecio(num valor) {
  final entero = valor.round().toString();
  final conPuntos = entero.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '\$ $conPuntos';
}

/// `2026-08-15` → `sáb, 15 ago`.
String formatearFechaCorta(DateTime fecha) =>
    '${_dias[fecha.weekday - 1]}, ${fecha.day} ${_meses[fecha.month - 1]}';

const _diasLargos = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
];
const _mesesLargos = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto',
  'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// `2026-08-15` → `sábado 15 de agosto`.
String formatearFechaLarga(DateTime f) =>
    '${_diasLargos[f.weekday - 1]} ${f.day} de ${_mesesLargos[f.month - 1]}';

/// `2026-10-12` → `mié` (tres letras, en minúscula).
String diaSemanaCorto(DateTime fecha) => _dias[fecha.weekday - 1];

/// `2026-10-05` → `2026-10-05`: el formato de fecha que usa la API.
String fechaIso(DateTime f) =>
    '${f.year.toString().padLeft(4, '0')}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

/// `"08:00:00"` → `"08:00"`. Lo que manda la API trae segundos.
String recortarHora(String hora) => hora.length >= 5 ? hora.substring(0, 5) : hora;

/// `Buenos días` / `Buenas tardes` / `Buenas noches` según la hora.
String saludoSegunHora(DateTime ahora) {
  if (ahora.hour < 12) return 'Buenos días';
  if (ahora.hour < 20) return 'Buenas tardes';
  return 'Buenas noches';
}

/// Cuánto falta para una fecha: `hoy`, `mañana`, `en 3 días`.
String cuandoEs(DateTime fecha, DateTime hoy) {
  final dias = DateTime(fecha.year, fecha.month, fecha.day)
      .difference(DateTime(hoy.year, hoy.month, hoy.day))
      .inDays;
  if (dias <= 0) return 'hoy';
  if (dias == 1) return 'mañana';
  return 'en $dias días';
}

/// `Carlos`, `García` → `CG`.
String iniciales(String nombre, String apellido) {
  String primera(String s) => s.trim().isEmpty ? '' : s.trim()[0].toUpperCase();
  return '${primera(nombre)}${primera(apellido)}';
}

/// Mayúscula inicial en cada palabra, salvo "de": `polvo de ladrillo` →
/// `Polvo de Ladrillo`.
String _titulo(String texto) => texto
    .split(' ')
    .map((p) => p.isEmpty || p == 'de' ? p : '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');

const _tiposAbreviados = {
  'F5': 'Fútbol 5',
  'F7': 'Fútbol 7',
  'F8': 'Fútbol 8',
  'F11': 'Fútbol 11',
  'H7': 'Hockey 7',
  'H11': 'Hockey 11',
};

/// Texto del tipo de cancha tal como se ve en el Figma: `F5` → `Fútbol 5`,
/// `Polvo de ladrillo` → `Polvo de Ladrillo`.
String etiquetaTipo(String tipo) => _tiposAbreviados[tipo] ?? _titulo(tipo);

const _ordenDeportes = ['Fútbol', 'Tenis', 'Golf', 'Hockey', 'Vóley'];

/// Deportes en el orden de los filtros del Figma; los que no figuran van al
/// final, por orden alfabético.
List<String> ordenarDeportes(Iterable<String> deportes) {
  int peso(String d) {
    final i = _ordenDeportes.indexOf(d);
    return i == -1 ? _ordenDeportes.length : i;
  }

  return deportes.toList()
    ..sort((a, b) {
      final porPeso = peso(a).compareTo(peso(b));
      return porPeso != 0 ? porPeso : a.compareTo(b);
    });
}

/// Emoji que identifica al deporte en filtros y tarjetas.
String emojiDeporte(String deporte) => switch (deporte) {
      'Fútbol' => '⚽',
      'Tenis' => '🎾',
      'Golf' => '⛳',
      'Hockey' => '🏑',
      'Vóley' => '🏐',
      _ => '🏟️',
    };

/// `40123456` → `40.123.456` (como se ve el DNI en el perfil del Figma).
String formatearDni(String dni) {
  final digitos = dni.replaceAll(RegExp(r'\D'), '');
  if (digitos.length < 7) return dni;
  final conPuntos = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) conPuntos.write('.');
    conPuntos.write(digitos[i]);
  }
  return conPuntos.toString();
}

/// `15/03/2001`: la fecha de nacimiento con el mismo formato que el registro.
String formatearFechaNumerica(DateTime fecha) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year}';
}

/// La fecha y hora de un instante que la API manda con la zona del club
/// (`2026-10-15T19:00:00-03:00` → 15/10 a las 19:00), sin convertirla a la zona
/// del celular: así el aviso dice la hora del club aunque el celular esté en otra.
DateTime horaDelClub(String iso) => DateTime.parse(iso.substring(0, 19));

/// `2026-10-15 19:00` → `jue, 15 oct · 19:00`.
String formatearFechaYHora(DateTime f) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${formatearFechaCorta(f)} · ${dos(f.hour)}:${dos(f.minute)}';
}

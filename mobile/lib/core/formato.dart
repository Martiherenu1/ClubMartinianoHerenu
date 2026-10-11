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

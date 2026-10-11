/// Sistema de diseño de la app, tomado del Figma grupal.
///
/// - Acento lima `#D4FF00`, fondo oscuro `#050508`, superficie clara `#F2F2F2`.
/// - Tipografías: Barlow Condensed (títulos y botones), Inter (texto) y
///   DM Mono (códigos de cancha y precios).
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores del diseño.
abstract final class Colores {
  static const lima = Color(0xFFD4FF00);
  static const limaOscuro = Color(0xFF5E7000); // acento sobre fondo claro (texto)
  static const fondoOscuro = Color(0xFF050508);
  static const superficieOscura = Color(0xFF14141A);
  static const fondoClaro = Color(0xFFF8F9FA);
  static const superficieClara = Color(0xFFF2F2F2);
  static const textoClaro = Color(0xFF282832);
  static const error = Color(0xFFFF5A5F);
}

/// Estilos de texto que se usan fuera del `TextTheme` estándar.
abstract final class Tipografia {
  /// Títulos grandes y botones: "CLUB MARTINIANO HEREÑU", "INICIAR SESIÓN".
  static TextStyle titulo({double size = 28, Color? color}) =>
      GoogleFonts.barlowCondensed(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: color,
        height: 1.1,
      );

  /// Nombre compuesto de la cancha y precios.
  static TextStyle codigo({double size = 12, Color? color}) =>
      GoogleFonts.dmMono(fontSize: size, color: color);

  /// Texto corriente de las tarjetas (Inter).
  static TextStyle texto({
    double size = 12,
    FontWeight peso = FontWeight.w400,
    Color? color,
    double? espaciado,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: peso,
        color: color,
        letterSpacing: espaciado,
      );
}

/// Colores que cambian entre modo claro y oscuro en las pantallas del Figma
/// (Home, Sedes, Canchas): tarjetas, bordes y texto.
extension ColoresDeContexto on BuildContext {
  bool get esModoOscuro => Theme.of(this).brightness == Brightness.dark;

  /// Lima sobre fondo oscuro; verde oliva `#5E7000` sobre fondo claro.
  Color get colorAcento => esModoOscuro ? Colores.lima : Colores.limaOscuro;

  Color get colorTarjeta =>
      esModoOscuro ? Colors.white.withValues(alpha: 0.07) : Colors.white;

  Color get colorBordeTarjeta => esModoOscuro
      ? Colors.white.withValues(alpha: 0.11)
      : Colors.black.withValues(alpha: 0.09);

  Color get colorTexto => esModoOscuro ? Colors.white : const Color(0xFF0B0C16);

  Color get colorTextoSuave => esModoOscuro
      ? Colors.white.withValues(alpha: 0.55)
      : Colors.black.withValues(alpha: 0.5);

  Color get colorTextoTenue => esModoOscuro
      ? Colors.white.withValues(alpha: 0.38)
      : Colors.black.withValues(alpha: 0.28);
}

ThemeData _construir(Brightness brillo) {
  final oscuro = brillo == Brightness.dark;
  final fondo = oscuro ? Colores.fondoOscuro : Colores.fondoClaro;
  final superficie = oscuro ? Colores.superficieOscura : Colors.white;
  final texto = oscuro ? Colors.white : Colores.textoClaro;

  final esquema = ColorScheme.fromSeed(
    seedColor: Colores.lima,
    brightness: brillo,
  ).copyWith(
    primary: oscuro ? Colores.lima : Colores.textoClaro,
    onPrimary: oscuro ? Colors.black : Colores.lima,
    secondary: Colores.lima,
    onSecondary: Colors.black,
    surface: superficie,
    onSurface: texto,
    error: Colores.error,
  );

  final base = ThemeData(brightness: brillo, colorScheme: esquema, useMaterial3: true);
  final textos = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: texto,
    displayColor: texto,
  );

  final borde = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: texto.withValues(alpha: 0.14)),
  );

  return base.copyWith(
    scaffoldBackgroundColor: fondo,
    textTheme: textos,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: texto.withValues(alpha: 0.06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: borde,
      enabledBorder: borde,
      focusedBorder: borde.copyWith(
        borderSide: const BorderSide(color: Colores.lima, width: 1.5),
      ),
      errorBorder: borde.copyWith(
        borderSide: const BorderSide(color: Colores.error),
      ),
      hintStyle: TextStyle(color: texto.withValues(alpha: 0.3)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Colores.lima,
        foregroundColor: Colors.black,
        disabledBackgroundColor: texto.withValues(alpha: 0.1),
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.barlowCondensed(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: fondo,
      foregroundColor: texto,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
  );
}

final ThemeData temaClaro = _construir(Brightness.light);
final ThemeData temaOscuro = _construir(Brightness.dark);

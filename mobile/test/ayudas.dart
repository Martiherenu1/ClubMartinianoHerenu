import 'dart:async';
import 'dart:convert';

import 'package:club_martinianoherenu/app/app.dart';
import 'package:club_martinianoherenu/app/controlador_tema.dart';
import 'package:club_martinianoherenu/core/api_client.dart';
import 'package:club_martinianoherenu/core/errores.dart';
import 'package:club_martinianoherenu/core/servicio_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Reemplaza a Firebase en los tests.
class AuthFalso implements ServicioAuth {
  AuthFalso({UsuarioSesion? inicial}) : _actual = inicial;

  final _controlador = StreamController<UsuarioSesion?>.broadcast();
  UsuarioSesion? _actual;

  /// Si se asigna, la próxima operación lanza este error.
  Object? errorAlIniciar;
  Object? errorAlRecuperar;

  /// Contraseña vigente de la cuenta: `cambiarPassword` la confirma contra esta.
  String passwordActual = 'Clave1234';
  Object? errorAlCambiarPassword;

  final intentos = <(String, String)>[];
  final enlaces = <String>[];
  final cambiosDePassword = <(String, String)>[];

  /// Igual que `authStateChanges` de Firebase: apenas alguien escucha, emite el
  /// estado actual y después cada cambio.
  @override
  Stream<UsuarioSesion?> get cambios async* {
    yield _actual;
    yield* _controlador.stream;
  }

  @override
  UsuarioSesion? get actual => _actual;

  @override
  Future<String?> idToken() async => _actual == null ? null : 'token-de-prueba';

  @override
  Future<void> iniciarSesion(String email, String password) async {
    intentos.add((email, password));
    if (errorAlIniciar != null) throw errorAlIniciar!;
    _actual = UsuarioSesion(uid: 'uid-1', email: email);
    _controlador.add(_actual);
  }

  @override
  Future<void> cerrarSesion() async {
    _actual = null;
    _controlador.add(null);
  }

  @override
  Future<void> enviarEnlaceRecuperacion(String email) async {
    if (errorAlRecuperar != null) throw errorAlRecuperar!;
    enlaces.add(email);
  }

  @override
  Future<void> cambiarPassword({required String actual, required String nueva}) async {
    if (errorAlCambiarPassword != null) throw errorAlCambiarPassword!;
    if (actual != passwordActual) {
      throw const ErrorNegocio(
        codigo: codigoPasswordActualIncorrecta,
        mensaje: 'La contraseña actual no es correcta.',
        status: 400,
      );
    }
    cambiosDePassword.add((actual, nueva));
    passwordActual = nueva;
  }
}

http.Response jsonResp(Object cuerpo, int status) => http.Response(
      jsonEncode(cuerpo),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const perfilJson = {
  'id': 1,
  'email': 'martiniano@mail.com',
  'nombre': 'Martiniano',
  'apellido': 'Hereñu',
  'dni': '40123456',
  'fecha_nacimiento': '2001-03-15',
  'activo': true,
  'creado_en': '2026-10-11T12:00:00Z',
};

/// En los tests no hay internet para bajar las fuentes de Google: se ignoran
/// esos errores (no son un problema de la app).
void prepararEntornoDeTest(WidgetTester tester) {
  GoogleFonts.config.allowRuntimeFetching = false;
  final original = FlutterError.onError;
  FlutterError.onError = (detalles) {
    final texto = detalles.exceptionAsString();
    if (texto.contains('google_fonts') || texto.contains('GoogleFonts')) return;
    original?.call(detalles);
  };
  addTearDown(() => FlutterError.onError = original);

  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<void> abrirApp(
  WidgetTester tester, {
  required AuthFalso auth,
  required Future<http.Response> Function(http.Request) servidor,
}) async {
  prepararEntornoDeTest(tester);
  final api = ApiClient(
    cliente: MockClient(servidor),
    urlBase: 'http://api.test/api/v1',
    proveedorToken: auth.idToken,
    timeout: const Duration(seconds: 5),
  );
  await tester.pumpWidget(AppClub(auth: auth, api: api, tema: ControladorTema()));
  await tester.pump();
}

Future<void> escribir(WidgetTester tester, int indiceCampo, String texto) async {
  await tester.enterText(find.byType(TextField).at(indiceCampo), texto);
  await tester.pump();
}

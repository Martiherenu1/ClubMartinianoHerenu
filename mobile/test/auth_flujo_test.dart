import 'dart:convert';

import 'package:club_martinianoherenu/core/errores.dart';
import 'package:club_martinianoherenu/core/servicio_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'ayudas.dart';
import 'servidor_falso.dart';

/// Servidor falso con el catálogo; para estos tests solo importa que responda el
/// perfil y la Home pueda cargar después del login.
Future<http.Response> soloPerfil(http.Request r) => ServidorFalso().responder(r);

void main() {
  group('Login (CU-01)', () {
    testWidgets('sin sesión muestra el login con el nombre del club', (tester) async {
      await abrirApp(tester, auth: AuthFalso(), servidor: soloPerfil);

      expect(find.textContaining('MARTINIANO HEREÑU', findRichText: true), findsOneWidget);
      expect(find.text('Gestión de espacios deportivos'), findsOneWidget);
      expect(find.text('INICIAR SESIÓN'), findsOneWidget);
      expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
      expect(find.text('Administrador'), findsNothing); // el panel de admin no se hace
    });

    testWidgets('FA1: campos vacíos → "Completá todos los campos" sin llamar a Firebase',
        (tester) async {
      final auth = AuthFalso();
      await abrirApp(tester, auth: auth, servidor: soloPerfil);

      await tester.tap(find.text('INICIAR SESIÓN'));
      await tester.pump();

      expect(find.text('Completá todos los campos'), findsOneWidget);
      expect(auth.intentos, isEmpty);
    });

    testWidgets('FA2: credenciales inválidas → mensaje genérico', (tester) async {
      final auth = AuthFalso()..errorAlIniciar = const CredencialesInvalidas();
      await abrirApp(tester, auth: auth, servidor: soloPerfil);

      await escribir(tester, 0, 'martiniano@mail.com');
      await escribir(tester, 1, 'mala-clave');
      await tester.tap(find.text('INICIAR SESIÓN'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudo iniciar sesión'), findsOneWidget);
      expect(auth.intentos, [('martiniano@mail.com', 'mala-clave')]);
    });

    testWidgets('FA5: sin conexión → tarjeta "Error de conectividad"', (tester) async {
      final auth = AuthFalso()..errorAlIniciar = const SinConexion();
      await abrirApp(tester, auth: auth, servidor: soloPerfil);

      await escribir(tester, 0, 'martiniano@mail.com');
      await escribir(tester, 1, 'clave1234');
      await tester.tap(find.text('INICIAR SESIÓN'));
      await tester.pumpAndSettle();

      expect(find.text('ERROR DE CONECTIVIDAD'), findsOneWidget);
      expect(find.textContaining('ninguna red Wi-Fi'), findsOneWidget);

      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      expect(find.text('ERROR DE CONECTIVIDAD'), findsNothing);
    });

    testWidgets('FA4: error del servidor → tarjeta "Error del servidor"', (tester) async {
      final auth = AuthFalso()..errorAlIniciar = const ErrorServidor();
      await abrirApp(tester, auth: auth, servidor: soloPerfil);

      await escribir(tester, 0, 'martiniano@mail.com');
      await escribir(tester, 1, 'clave1234');
      await tester.tap(find.text('INICIAR SESIÓN'));
      await tester.pumpAndSettle();

      expect(find.text('ERROR DEL SERVIDOR'), findsOneWidget);
    });

    testWidgets('login correcto → entra a la app y muestra el perfil del backend',
        (tester) async {
      final auth = AuthFalso();
      await abrirApp(tester, auth: auth, servidor: soloPerfil);

      await escribir(tester, 0, 'martiniano@mail.com');
      await escribir(tester, 1, 'clave1234');
      await tester.tap(find.text('INICIAR SESIÓN'));
      await tester.pumpAndSettle();

      expect(find.text('Martiniano Hereñu'), findsOneWidget);
      expect(find.text('INICIAR SESIÓN'), findsNothing);
    });

    testWidgets('con sesión previa abre directo la app y cerrar sesión vuelve al login',
        (tester) async {
      final auth = AuthFalso(inicial: const UsuarioSesion(uid: 'uid-1', email: 'a@a.com'));
      await abrirApp(tester, auth: auth, servidor: soloPerfil);
      await tester.pumpAndSettle();

      expect(find.text('Martiniano Hereñu'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('PERFIL'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    });

    testWidgets('un 401 del backend cierra la sesión y vuelve al login', (tester) async {
      final auth = AuthFalso(inicial: const UsuarioSesion(uid: 'uid-1'));
      await abrirApp(
        tester,
        auth: auth,
        servidor: (r) async => jsonResp(
          {'error': {'codigo': 'NO_AUTENTICADO', 'mensaje': 'Esta cuenta fue dada de baja.'}},
          401,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('INICIAR SESIÓN'), findsOneWidget);
      expect(auth.actual, isNull);
    });
  });

  group('Registro (CU-03)', () {
    Future<void> irARegistro(WidgetTester tester, AuthFalso auth,
        Future<http.Response> Function(http.Request) servidor) async {
      await abrirApp(tester, auth: auth, servidor: servidor);
      await tester.tap(find.text('COMENZAR →'));
      await tester.pumpAndSettle();
    }

    Future<void> completar(WidgetTester tester, {String dni = '38.196.142'}) async {
      await escribir(tester, 0, 'Rodrigo');
      await escribir(tester, 1, 'Gil');
      await escribir(tester, 2, dni);
      await tester.tap(find.text('dd/mm/aaaa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ACEPTAR'));
      await tester.pumpAndSettle();
      await escribir(tester, 3, 'rodrigo@mail.com');
      await escribir(tester, 4, 'clave1234');
    }

    testWidgets('muestra los campos del Figma', (tester) async {
      await irARegistro(tester, AuthFalso(), soloPerfil);

      for (final etiqueta in [
        'Nombre *',
        'Apellido *',
        'DNI *',
        'Fecha de nacimiento *',
        'Email *',
        'Contraseña *',
      ]) {
        expect(find.text(etiqueta), findsOneWidget, reason: etiqueta);
      }
      expect(find.text('CREAR CUENTA'), findsNWidgets(2)); // título y botón
    });

    testWidgets('FA1: campos vacíos → "Completá todos los campos"', (tester) async {
      var llamadas = 0;
      await irARegistro(tester, AuthFalso(), (r) async {
        llamadas++;
        return jsonResp({}, 201);
      });

      await tester.tap(find.widgetWithText(FilledButton, 'CREAR CUENTA'));
      await tester.pump();

      expect(find.text('Completá todos los campos'), findsOneWidget);
      expect(llamadas, 0);
    });

    testWidgets('DNI con formato inválido se avisa sin llamar al servidor', (tester) async {
      var llamadas = 0;
      await irARegistro(tester, AuthFalso(), (r) async {
        llamadas++;
        return jsonResp({}, 201);
      });
      await completar(tester, dni: '123');

      await tester.tap(find.widgetWithText(FilledButton, 'CREAR CUENTA'));
      await tester.pump();

      expect(find.textContaining('DNI debe tener 7 u 8'), findsOneWidget);
      expect(llamadas, 0);
    });

    testWidgets('FA2: usuario ya registrado → se queda en el formulario', (tester) async {
      await irARegistro(tester, AuthFalso(), (r) async => jsonResp({
            'error': {'codigo': 'DNI_YA_REGISTRADO', 'mensaje': 'Ya existe una cuenta con ese DNI.'}
          }, 409));
      await completar(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'CREAR CUENTA'));
      await tester.pumpAndSettle();

      expect(find.text('Este usuario ya está registrado'), findsOneWidget);
      expect(find.text('¡Usuario Registrado!'), findsNothing);
      // Los datos quedan cargados para poder corregirlos.
      expect(find.text('Rodrigo'), findsOneWidget);
    });

    testWidgets('registro exitoso: manda los datos normalizados y muestra la confirmación',
        (tester) async {
      http.Request? recibido;
      await irARegistro(tester, AuthFalso(), (r) async {
        recibido = r;
        return jsonResp(perfilJson, 201);
      });
      await completar(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'CREAR CUENTA'));
      await tester.pumpAndSettle();

      expect(find.text('¡Usuario Registrado!'), findsOneWidget);
      final body = jsonDecode(recibido!.body) as Map<String, dynamic>;
      expect(body['dni'], '38196142'); // sin puntos
      expect(body['email'], 'rodrigo@mail.com');
      expect(body['nombre'], 'Rodrigo');
      expect(body['fecha_nacimiento'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));

      await tester.tap(find.text('VOLVER AL LOGIN'));
      await tester.pumpAndSettle();
      expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    });

    testWidgets('sin conexión al registrarse → tarjeta de conectividad', (tester) async {
      await irARegistro(tester, AuthFalso(), (r) async => throw const SinConexion());
      await completar(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'CREAR CUENTA'));
      await tester.pumpAndSettle();

      expect(find.text('ERROR DE CONECTIVIDAD'), findsOneWidget);
    });
  });

  group('Recuperar contraseña', () {
    Future<void> irARecuperar(WidgetTester tester, AuthFalso auth) async {
      await abrirApp(tester, auth: auth, servidor: soloPerfil);
      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();
    }

    testWidgets('email inválido se avisa y no se envía nada', (tester) async {
      final auth = AuthFalso();
      await irARecuperar(tester, auth);

      await escribir(tester, 0, 'no-es-un-email');
      await tester.tap(find.text('ENVIAR ENLACE'));
      await tester.pump();

      expect(find.text('Ingresá un email válido'), findsOneWidget);
      expect(auth.enlaces, isEmpty);
    });

    testWidgets('envía el enlace y muestra "¡Enlace enviado!"', (tester) async {
      final auth = AuthFalso();
      await irARecuperar(tester, auth);

      await escribir(tester, 0, 'martiniano@mail.com');
      await tester.tap(find.text('ENVIAR ENLACE'));
      await tester.pumpAndSettle();

      expect(find.text('¡Enlace enviado!'), findsOneWidget);
      expect(find.textContaining('martiniano@mail.com', findRichText: true), findsOneWidget);
      expect(auth.enlaces, ['martiniano@mail.com']);

      await tester.tap(find.text('VOLVER AL LOGIN'));
      await tester.pumpAndSettle();
      expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    });
  });
}

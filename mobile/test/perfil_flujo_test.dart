import 'package:club_martinianoherenu/core/errores.dart';
import 'package:club_martinianoherenu/core/servicio_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayudas.dart';
import 'servidor_falso.dart';

const _sesion = UsuarioSesion(uid: 'uid-1', email: 'martiniano@mail.com');

Future<void> abrirPerfil(
  WidgetTester tester,
  ServidorFalso servidor, {
  AuthFalso? auth,
}) async {
  await abrirApp(
    tester,
    auth: auth ?? AuthFalso(inicial: _sesion),
    servidor: servidor.responder,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel('PERFIL').last);
  await tester.pumpAndSettle();
}

Future<void> tocar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Los campos de la pantalla de perfil en orden: nombre, apellido y DNI.
Future<void> escribirDato(WidgetTester tester, int campo, String texto) async {
  await tester.enterText(find.byType(TextField).at(campo), texto);
  await tester.pump();
}

void main() {
  group('Perfil (CU-05)', () {
    testWidgets('muestra los datos del usuario', (tester) async {
      await abrirPerfil(tester, ServidorFalso());

      expect(find.textContaining('PERFIL', findRichText: true), findsWidgets);
      expect(find.text('MH'), findsOneWidget);
      expect(find.text('Martiniano Hereñu'), findsWidgets);
      expect(find.text('MIEMBRO ACTIVO'), findsOneWidget);
      // Sin editar, el DNI se ve con puntos y la fecha como dd/mm/aaaa.
      expect(find.text('40.123.456'), findsOneWidget);
      expect(find.text('15/03/2001'), findsOneWidget);
      // El email aparece en la cabecera y en el campo de solo lectura.
      expect(find.text('martiniano@mail.com'), findsNWidgets(2));
      expect(find.text('Cambiar contraseña'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(find.text('Eliminar cuenta'), findsOneWidget);
    });

    testWidgets('el interruptor cambia entre modo oscuro y claro', (tester) async {
      await abrirPerfil(tester, ServidorFalso());
      expect(find.text('Modo oscuro'), findsOneWidget);

      await tocar(tester, find.byType(Switch));

      expect(find.text('Modo nocturno'), findsOneWidget);
      expect(find.text('Modo oscuro'), findsNothing);
    });

    testWidgets('cerrar sesión vuelve al login', (tester) async {
      final auth = AuthFalso(inicial: _sesion);
      await abrirPerfil(tester, ServidorFalso(), auth: auth);

      await tocar(tester, find.text('Cerrar sesión'));

      expect(find.text('INICIAR SESIÓN'), findsOneWidget);
      expect(auth.actual, isNull);
    });
  });

  group('Editar perfil (CU-06)', () {
    testWidgets('edita los datos, guarda y la Home los refleja', (tester) async {
      final servidor = ServidorFalso();
      await abrirPerfil(tester, servidor);

      await tocar(tester, find.text('Editar'));
      // Al editar el DNI se muestra sin puntos.
      expect(find.text('40123456'), findsOneWidget);
      await escribirDato(tester, 0, 'Juan');
      await escribirDato(tester, 2, '40.999.888');
      await tocar(tester, find.text('Guardar'));

      expect(servidor.perfilesEditados.single, {
        'nombre': 'Juan',
        'apellido': 'Hereñu',
        'dni': '40999888',
        'fecha_nacimiento': '2001-03-15',
      });
      expect(find.text('Datos actualizados'), findsOneWidget);
      expect(find.text('Juan Hereñu'), findsWidgets);
      expect(find.text('40.999.888'), findsOneWidget);
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Guardar'), findsNothing);

      await tester.tap(find.bySemanticsLabel('INICIO').last);
      await tester.pumpAndSettle();
      expect(find.text('Juan Hereñu'), findsOneWidget);
    });

    testWidgets('datos inválidos: avisa y no llama al servidor', (tester) async {
      final servidor = ServidorFalso();
      await abrirPerfil(tester, servidor);
      await tocar(tester, find.text('Editar'));

      await escribirDato(tester, 0, '   ');
      await escribirDato(tester, 2, '123');
      await tocar(tester, find.text('Guardar'));

      expect(find.text('Ingresá tu nombre.'), findsOneWidget);
      expect(find.text('El DNI debe tener 7 u 8 números.'), findsOneWidget);
      expect(servidor.perfilesEditados, isEmpty);
    });

    testWidgets('DNI ya registrado (409): muestra el mensaje y sigue editando', (tester) async {
      final servidor = ServidorFalso()..dniDuplicado = true;
      await abrirPerfil(tester, servidor);
      await tocar(tester, find.text('Editar'));
      await escribirDato(tester, 2, '30111222');

      await tocar(tester, find.text('Guardar'));

      expect(find.text('Ese DNI ya está registrado en otra cuenta.'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
      expect(find.text('Datos actualizados'), findsNothing);
    });

    testWidgets('cancelar descarta lo escrito', (tester) async {
      final servidor = ServidorFalso();
      await abrirPerfil(tester, servidor);
      await tocar(tester, find.text('Editar'));
      await escribirDato(tester, 0, 'Otro nombre');

      await tocar(tester, find.text('Cancelar'));

      expect(find.text('Otro nombre'), findsNothing);
      expect(find.text('Martiniano'), findsOneWidget);
      expect(find.text('40.123.456'), findsOneWidget);
      expect(servidor.perfilesEditados, isEmpty);
    });

    testWidgets('guardar sin cambios no llama al servidor', (tester) async {
      final servidor = ServidorFalso();
      await abrirPerfil(tester, servidor);
      await tocar(tester, find.text('Editar'));

      await tocar(tester, find.text('Guardar'));

      expect(servidor.perfilesEditados, isEmpty);
      expect(find.text('Editar'), findsOneWidget);
    });
  });

  group('Cambiar contraseña (CU-04)', () {
    Future<AuthFalso> abrirCambio(WidgetTester tester) async {
      final auth = AuthFalso(inicial: _sesion);
      await abrirPerfil(tester, ServidorFalso(), auth: auth);
      await tocar(tester, find.text('Cambiar contraseña'));
      expect(find.textContaining('CAMBIAR', findRichText: true), findsWidgets);
      return auth;
    }

    // Campos: contraseña actual, nueva y repetir.
    Future<void> completar(
      WidgetTester tester, {
      String actual = 'Clave1234',
      String nueva = 'NuevaClave9',
      String? repetir,
    }) async {
      await escribir(tester, 0, actual);
      await escribir(tester, 1, nueva);
      await escribir(tester, 2, repetir ?? nueva);
    }

    testWidgets('la lista de requisitos y la fortaleza se actualizan en vivo', (tester) async {
      await abrirCambio(tester);
      expect(find.text('CONTRASEÑA FUERTE'), findsNothing);

      await escribir(tester, 1, 'abc');
      expect(find.text('CONTRASEÑA DÉBIL'), findsOneWidget);

      await escribir(tester, 1, 'abcdefgh1');
      expect(find.text('CONTRASEÑA MEDIA'), findsOneWidget);

      await escribir(tester, 1, 'Abcdefgh1');
      expect(find.text('CONTRASEÑA FUERTE'), findsOneWidget);
      expect(find.text('Al menos 8 caracteres'), findsOneWidget);
      expect(find.text('Una letra mayúscula'), findsOneWidget);
      expect(find.text('Un número'), findsOneWidget);
    });

    testWidgets('cambia la contraseña y vuelve al perfil con aviso', (tester) async {
      final auth = await abrirCambio(tester);
      await completar(tester);

      await tocar(tester, find.text('GUARDAR CAMBIOS'));

      expect(auth.cambiosDePassword, [('Clave1234', 'NuevaClave9')]);
      expect(find.text('Contraseña actualizada'), findsOneWidget);
      expect(find.text('Cambiar contraseña'), findsOneWidget);
      expect(find.text('GUARDAR CAMBIOS'), findsNothing);
    });

    testWidgets('contraseña actual incorrecta: error en el campo, sin cambiar nada',
        (tester) async {
      final auth = await abrirCambio(tester);
      await completar(tester, actual: 'equivocada');

      await tocar(tester, find.text('GUARDAR CAMBIOS'));

      expect(find.text('La contraseña actual no es correcta.'), findsOneWidget);
      expect(auth.cambiosDePassword, isEmpty);
      expect(find.text('GUARDAR CAMBIOS'), findsOneWidget);
    });

    testWidgets('la nueva no cumple los requisitos o no coincide: no se envía',
        (tester) async {
      final auth = await abrirCambio(tester);

      await completar(tester, nueva: 'corta');
      await tocar(tester, find.text('GUARDAR CAMBIOS'));
      expect(find.text('La contraseña nueva no cumple los requisitos.'), findsOneWidget);

      await completar(tester, nueva: 'NuevaClave9', repetir: 'OtraClave9');
      await tocar(tester, find.text('GUARDAR CAMBIOS'));
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);

      expect(auth.cambiosDePassword, isEmpty);
    });

    testWidgets('la nueva tiene que ser distinta de la actual', (tester) async {
      final auth = await abrirCambio(tester);
      await completar(tester, actual: 'Clave1234', nueva: 'Clave1234');

      await tocar(tester, find.text('GUARDAR CAMBIOS'));

      expect(
        find.text('La nueva contraseña tiene que ser distinta de la actual.'),
        findsOneWidget,
      );
      expect(auth.cambiosDePassword, isEmpty);
    });

    testWidgets('sin conexión: tarjeta de error y queda en el formulario', (tester) async {
      final auth = await abrirCambio(tester);
      auth.errorAlCambiarPassword = const SinConexion();
      await completar(tester);

      await tocar(tester, find.text('GUARDAR CAMBIOS'));

      expect(find.text('ERROR DE CONECTIVIDAD'), findsOneWidget);
    });

    testWidgets('sesión vencida: vuelve al login', (tester) async {
      final auth = await abrirCambio(tester);
      auth.errorAlCambiarPassword = const NoAutenticado('Tu sesión expiró.');
      await completar(tester);

      await tocar(tester, find.text('GUARDAR CAMBIOS'));

      expect(find.text('INICIAR SESIÓN'), findsOneWidget);
      expect(find.text('GUARDAR CAMBIOS'), findsNothing);
    });

    testWidgets('"Cancelar" vuelve al perfil sin cambios', (tester) async {
      final auth = await abrirCambio(tester);

      await tocar(tester, find.text('Cancelar'));

      expect(find.text('GUARDAR CAMBIOS'), findsNothing);
      expect(find.text('Cambiar contraseña'), findsOneWidget);
      expect(auth.cambiosDePassword, isEmpty);
    });
  });

  group('Eliminar cuenta (CU-07)', () {
    Future<void> pedirBaja(WidgetTester tester) async {
      await tocar(tester, find.text('Eliminar cuenta'));
    }

    testWidgets('pide confirmación y "Cancelar" deja todo como estaba', (tester) async {
      final servidor = ServidorFalso();
      await abrirPerfil(tester, servidor);

      await pedirBaja(tester);
      expect(find.textContaining('¿Estás seguro?'), findsOneWidget);
      expect(find.text('Eliminar cuenta'), findsNothing);

      // Hay dos "Cancelar" posibles; en pantalla solo está el de la confirmación.
      await tocar(tester, find.text('Cancelar'));

      expect(find.text('Eliminar cuenta'), findsOneWidget);
      expect(servidor.cuentaEliminada, isFalse);
    });

    testWidgets('encuesta → procesando → gracias → login', (tester) async {
      final servidor = ServidorFalso();
      final auth = AuthFalso(inicial: _sesion);
      await abrirPerfil(tester, servidor, auth: auth);
      await pedirBaja(tester);

      await tocar(tester, find.text('Eliminar'));

      // Encuesta de salida (Figma "Experiencia usuario").
      expect(find.textContaining('ANTES DE IRTE'), findsOneWidget);
      expect(find.text('Satisfecho'), findsOneWidget);
      expect(find.text('Precio muy alto'), findsOneWidget);
      expect(find.text('ENVIAR Y ELIMINAR'), findsOneWidget);
      expect(servidor.cuentaEliminada, isFalse);

      await tester.tap(find.text('Insatisfecho'));
      await tester.tap(find.text('Problemas técnicos'));
      await tester.pump();
      await tester.tap(find.text('ENVIAR Y ELIMINAR'));
      await tester.pump();
      expect(find.text('PROCESANDO…'), findsOneWidget);
      expect(find.text('Eliminando tu cuenta'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 400));
      expect(servidor.cuentaEliminada, isTrue);
      expect(find.text('¡GRACIAS POR TU OPINIÓN!'), findsOneWidget);
      expect(auth.actual, isNotNull);

      // Pasados unos segundos se cierra la sesión y vuelve al login.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(auth.actual, isNull);
      expect(find.text('INICIAR SESIÓN'), findsOneWidget);
      expect(find.text('¡GRACIAS POR TU OPINIÓN!'), findsNothing);
    });

    testWidgets('"Omitir" también da de baja la cuenta', (tester) async {
      final servidor = ServidorFalso();
      final auth = AuthFalso(inicial: _sesion);
      await abrirPerfil(tester, servidor, auth: auth);
      await pedirBaja(tester);
      await tocar(tester, find.text('Eliminar'));

      await tester.tap(find.text('Omitir'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 400));
      // Tocar "Gracias" no espera los 3 segundos.
      await tester.tap(find.text('¡GRACIAS POR TU OPINIÓN!'));
      await tester.pumpAndSettle();

      expect(servidor.cuentaEliminada, isTrue);
      expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    });

    testWidgets('si la baja falla vuelve al perfil con el error y la cuenta sigue',
        (tester) async {
      final servidor = ServidorFalso()..bajaFalla = true;
      final auth = AuthFalso(inicial: _sesion);
      await abrirPerfil(tester, servidor, auth: auth);
      await pedirBaja(tester);
      await tocar(tester, find.text('Eliminar'));

      await tester.tap(find.text('Omitir'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('ERROR DEL SERVIDOR'), findsOneWidget);
      expect(auth.actual, isNotNull);
      expect(servidor.cuentaEliminada, isFalse);

      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      // Vuelve a estar el botón (la confirmación se cerró).
      expect(find.text('Eliminar cuenta'), findsOneWidget);
    });

    testWidgets('desde la encuesta se puede volver sin eliminar nada', (tester) async {
      final servidor = ServidorFalso();
      await abrirPerfil(tester, servidor);
      await pedirBaja(tester);
      await tocar(tester, find.text('Eliminar'));
      expect(find.textContaining('ANTES DE IRTE'), findsOneWidget);

      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.pop();
      await tester.pumpAndSettle();

      expect(find.textContaining('ANTES DE IRTE'), findsNothing);
      expect(find.text('Eliminar cuenta'), findsOneWidget);
      expect(servidor.cuentaEliminada, isFalse);
    });
  });
}

import 'package:club_martinianoherenu/core/servicio_auth.dart';
import 'package:club_martinianoherenu/core/servicio_notificaciones.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ayudas.dart';
import 'servidor_falso.dart';

const _sesion = UsuarioSesion(uid: 'uid-1', email: 'martiniano@mail.com');

ServidorFalso _servidor() => ServidorFalso(
      reservas: [
        reservaJson(
          id: 10,
          dias: 3,
          recordatorios: [
            recordatorioJson('24h', 'enviado', '2026-10-14T19:00:00'),
            recordatorioJson('1h', 'pendiente', '2026-10-15T18:00:00'),
          ],
        ),
      ],
    );

Future<void> abrirHome(
  WidgetTester tester,
  ServidorFalso servidor,
  NotificacionesFalso notificaciones, {
  AuthFalso? auth,
}) async {
  SharedPreferences.setMockInitialValues({});
  await abrirApp(
    tester,
    auth: auth ?? AuthFalso(inicial: _sesion),
    servidor: servidor.responder,
    notificaciones: notificaciones,
  );
  await tester.pumpAndSettle();
}

Future<void> tocar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('Registro del celular (CU-24)', () {
    testWidgets('con el permiso concedido registra el token sin preguntar', (tester) async {
      final servidor = _servidor();
      await abrirHome(tester, servidor, NotificacionesFalso());

      expect(servidor.dispositivos, ['token-fcm-1']);
      expect(find.text('ACTIVÁ LOS'), findsNothing);
      expect(find.text('Recordatorios activos'), findsOneWidget);
    });

    testWidgets('sin permiso explica los recordatorios y, al aceptar, los activa',
        (tester) async {
      final servidor = _servidor();
      final notif = NotificacionesFalso(estado: PermisoNotificaciones.sinPedir);
      await abrirHome(tester, servidor, notif);

      expect(find.text('ACTIVÁ LOS'), findsOneWidget);
      expect(find.textContaining('24 horas y 1 hora antes'), findsOneWidget);
      expect(servidor.dispositivos, isEmpty);

      await tocar(tester, find.text('HABILITAR NOTIFICACIONES'));

      expect(notif.pedidosDePermiso, 1);
      expect(servidor.dispositivos, ['token-fcm-1']);
      expect(find.text('ACTIVÁ LOS'), findsNothing);
      expect(find.text('Recordatorios activos'), findsOneWidget);
    });

    testWidgets('"Ahora no" no pide el permiso y deja activarlo desde la Home',
        (tester) async {
      final servidor = _servidor();
      final notif = NotificacionesFalso(estado: PermisoNotificaciones.sinPedir);
      await abrirHome(tester, servidor, notif);

      await tocar(tester, find.text('Ahora no'));

      expect(notif.pedidosDePermiso, 0);
      expect(servidor.dispositivos, isEmpty);
      expect(find.text('Recordatorios desactivados'), findsOneWidget);

      await tocar(tester, find.text('Activar'));

      expect(notif.pedidosDePermiso, 1);
      expect(servidor.dispositivos, ['token-fcm-1']);
      expect(find.text('Recordatorios activos'), findsOneWidget);
    });

    testWidgets('si el sistema rechaza el permiso avisa cómo habilitarlo', (tester) async {
      final servidor = _servidor();
      final notif = NotificacionesFalso(
        estado: PermisoNotificaciones.denegado,
        alPedir: PermisoNotificaciones.denegado,
      );
      await abrirHome(tester, servidor, notif);
      // Ya lo rechazó antes: no se vuelve a mostrar el modal.
      expect(find.text('ACTIVÁ LOS'), findsNothing);

      await tocar(tester, find.text('Activar'));

      expect(find.textContaining('ajustes del celular'), findsOneWidget);
      expect(servidor.dispositivos, isEmpty);
    });

    testWidgets('si FCM renueva el token, lo vuelve a registrar', (tester) async {
      final servidor = _servidor();
      final notif = NotificacionesFalso();
      await abrirHome(tester, servidor, notif);

      notif.renovarToken('token-fcm-2');
      await tester.pumpAndSettle();

      expect(servidor.dispositivos, ['token-fcm-1', 'token-fcm-2']);
    });

    testWidgets('si la API no deja registrar el celular, la app sigue funcionando',
        (tester) async {
      final servidor = _servidor()..registroFalla = true;
      await abrirHome(tester, servidor, NotificacionesFalso());

      expect(find.text('Martiniano Hereñu'), findsOneWidget);
      expect(find.text('ERROR DEL SERVIDOR'), findsNothing);
    });

    testWidgets('sin token (sin Google Play Services) no registra nada', (tester) async {
      final servidor = _servidor();
      await abrirHome(tester, servidor, NotificacionesFalso(tokenActual: null));

      expect(servidor.dispositivos, isEmpty);
      expect(find.text('Martiniano Hereñu'), findsOneWidget);
    });

    testWidgets('cerrar sesión saca el celular de la cuenta', (tester) async {
      final servidor = _servidor();
      final notif = NotificacionesFalso();
      final auth = AuthFalso(inicial: _sesion);
      await abrirHome(tester, servidor, notif, auth: auth);

      await tester.tap(find.bySemanticsLabel('PERFIL').last);
      await tester.pumpAndSettle();
      await tocar(tester, find.text('Cerrar sesión'));

      expect(servidor.dispositivosQuitados, ['token-fcm-1']);
      expect(notif.tokenOlvidado, isTrue);
      expect(auth.actual, isNull);
      expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    });
  });

  group('Tocar un aviso abre la reserva', () {
    const aviso = AvisoPush(
      tipo: 'recordatorio_1h',
      reservaId: 10,
      titulo: 'Tu reserva comienza en 1 hora',
      cuerpo: 'Sede Morón · Tenis Polvo de ladrillo\njue 15 oct, 19:00 a 20:00',
    );

    testWidgets('con la app en segundo plano', (tester) async {
      final servidor = _servidor();
      final notif = NotificacionesFalso();
      await abrirHome(tester, servidor, notif);

      notif.tocarAviso(aviso);
      await tester.pumpAndSettle();

      expect(find.textContaining('DETALLE DE', findRichText: true), findsOneWidget);
      expect(servidor.pedidosA('/reservas/10'), isNotEmpty);
    });

    testWidgets('con la app cerrada (aviso inicial)', (tester) async {
      final servidor = _servidor();
      await abrirHome(tester, servidor, NotificacionesFalso(inicial: aviso));

      expect(find.textContaining('DETALLE DE', findRichText: true), findsOneWidget);
      expect(servidor.pedidosA('/reservas/10'), isNotEmpty);
    });

    testWidgets('con la app abierta muestra el aviso y "Ver" abre la reserva',
        (tester) async {
      final servidor = _servidor();
      final notif = NotificacionesFalso();
      await abrirHome(tester, servidor, notif);

      notif.llegarAviso(aviso);
      await tester.pumpAndSettle();

      expect(find.text('Tu reserva comienza en 1 hora\nSede Morón · Tenis Polvo de ladrillo'),
          findsOneWidget);
      expect(find.textContaining('DETALLE DE', findRichText: true), findsNothing);

      await tester.tap(find.text('VER'));
      await tester.pumpAndSettle();

      expect(find.textContaining('DETALLE DE', findRichText: true), findsOneWidget);
    });

    testWidgets('un aviso sin reserva no hace nada', (tester) async {
      final servidor = _servidor();
      final notif = NotificacionesFalso();
      await abrirHome(tester, servidor, notif);

      notif.tocarAviso(const AvisoPush(tipo: 'otro'));
      await tester.pumpAndSettle();

      expect(find.textContaining('DETALLE DE', findRichText: true), findsNothing);
    });
  });

  group('Campana y panel de notificaciones', () {
    testWidgets('sin avisos: panel vacío y sin punto', (tester) async {
      await abrirHome(tester, _servidor(), NotificacionesFalso());

      expect(find.bySemanticsLabel('Notificaciones'), findsOneWidget);
      await tocar(tester, find.bySemanticsLabel('Notificaciones'));

      expect(find.text('Notificaciones'), findsOneWidget);
      expect(find.text('Todavía no tenés notificaciones.'), findsOneWidget);
    });

    testWidgets('con avisos nuevos marca la campana, los lista y los da por vistos',
        (tester) async {
      final servidor = _servidor()
        ..avisos = [
          avisoJson(id: 2),
          avisoJson(
            id: 1,
            tipo: 'recordatorio_24h',
            titulo: 'Tenés una reserva mañana',
            cuerpo: 'Sede Morón · Tenis Polvo de ladrillo — jue 15 oct, 19:00',
            enviadaEn: '2026-10-14T19:00:00-03:00',
          ),
        ];
      await abrirHome(tester, servidor, NotificacionesFalso());

      expect(find.bySemanticsLabel('Notificaciones, hay avisos nuevos'), findsOneWidget);

      await tocar(tester, find.bySemanticsLabel('Notificaciones, hay avisos nuevos'));

      expect(find.text('Tu reserva comienza en 1 hora'), findsOneWidget);
      expect(find.text('Tenés una reserva mañana'), findsOneWidget);
      expect(find.textContaining('jue, 15 oct · 18:00'), findsOneWidget);

      // Cerrar el panel los da por vistos: la campana pierde el punto.
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Notificaciones'), findsOneWidget);
      expect(find.bySemanticsLabel('Notificaciones, hay avisos nuevos'), findsNothing);
    });

    testWidgets('tocar un aviso del panel abre esa reserva', (tester) async {
      final servidor = _servidor()..avisos = [avisoJson()];
      await abrirHome(tester, servidor, NotificacionesFalso());

      await tocar(tester, find.bySemanticsLabel('Notificaciones, hay avisos nuevos'));
      await tocar(tester, find.text('Tu reserva comienza en 1 hora'));

      expect(find.textContaining('DETALLE DE', findRichText: true), findsOneWidget);
      expect(servidor.pedidosA('/reservas/10'), isNotEmpty);
    });

    testWidgets('al llegar un aviso con la app abierta se vuelve a pedir la lista',
        (tester) async {
      final servidor = _servidor();
      final notif = NotificacionesFalso();
      await abrirHome(tester, servidor, notif);
      final antes = servidor.pedidosA('/notificaciones').length;

      servidor.avisos = [avisoJson()];
      notif.llegarAviso(const AvisoPush(tipo: 'recordatorio_1h', reservaId: 10, titulo: 'Hola'));
      await tester.pumpAndSettle();

      expect(servidor.pedidosA('/notificaciones').length, greaterThan(antes));
      expect(find.bySemanticsLabel('Notificaciones, hay avisos nuevos'), findsOneWidget);
    });
  });

  group('Recordatorios en el detalle de la reserva', () {
    testWidgets('muestra cuándo sale cada recordatorio y si ya salió', (tester) async {
      final servidor = _servidor();
      await abrirHome(tester, servidor, NotificacionesFalso());
      await tester.tap(find.bySemanticsLabel('RESERVAS').last);
      await tester.pumpAndSettle();
      await tocar(tester, find.text('Sede Morón').first);

      expect(find.text('RECORDATORIOS'), findsOneWidget);
      expect(find.text('24 horas antes'), findsOneWidget);
      expect(find.text('1 hora antes'), findsOneWidget);
      expect(find.text('Enviado'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('mié, 14 oct · 19:00'), findsOneWidget);
      expect(find.text('jue, 15 oct · 18:00'), findsOneWidget);
    });

    testWidgets('una reserva sin recordatorios no muestra el bloque', (tester) async {
      final servidor = ServidorFalso(
        historial: [reservaJson(id: 12, dias: -20, estado: 'cancelada')],
      );
      await abrirHome(tester, servidor, NotificacionesFalso());
      await tester.tap(find.bySemanticsLabel('RESERVAS').last);
      await tester.pumpAndSettle();
      await tocar(tester, find.text('Historial'));
      await tocar(tester, find.text('Sede Morón').first);

      expect(find.textContaining('DETALLE DE', findRichText: true), findsOneWidget);
      expect(find.text('RECORDATORIOS'), findsNothing);
    });
  });
}

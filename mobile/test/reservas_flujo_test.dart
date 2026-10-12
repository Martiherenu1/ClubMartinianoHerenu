import 'package:club_martinianoherenu/core/errores.dart';
import 'package:club_martinianoherenu/core/formato.dart';
import 'package:club_martinianoherenu/core/servicio_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayudas.dart';
import 'servidor_falso.dart';

const _sesion = UsuarioSesion(uid: 'uid-1', email: 'martiniano@mail.com');

/// Dos próximas (Morón tenis y Morón fútbol 11) y una completada.
ServidorFalso _servidor({bool conProximas = true}) => ServidorFalso(
      reservas: conProximas
          ? [
              reservaJson(id: 10, dias: 3),
              reservaJson(id: 11, dias: 9, espacio: 4, precio: 9000),
            ]
          : const [],
      historial: [reservaJson(id: 12, dias: -20, estado: 'completada', precio: 4200)],
    );

Future<void> abrirReservas(WidgetTester tester, ServidorFalso servidor) async {
  await abrirApp(tester, auth: AuthFalso(inicial: _sesion), servidor: servidor.responder);
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel('RESERVAS').last);
  await tester.pumpAndSettle();
}

Future<void> tocar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

List<Uri> _pedidosA(ServidorFalso s, String metodoRuta) =>
    s.pedidos.where((u) => u.path.endsWith(metodoRuta)).toList();

void main() {
  group('Mis reservas (CU-08)', () {
    testWidgets('lista las próximas con estado, fecha, horario, precio y "Cancelar"',
        (tester) async {
      final servidor = _servidor();
      await abrirReservas(tester, servidor);

      expect(find.textContaining('RESERVAS', findRichText: true), findsWidgets);
      expect(find.text('2 activas · 1 historial'), findsOneWidget);
      expect(find.text('Próximas (2)'), findsOneWidget);

      expect(find.text('Sede Morón'), findsNWidgets(2));
      expect(find.text('Activa'), findsNWidgets(2));
      expect(find.text('19:00 – 20:00'), findsNWidgets(2));
      expect(find.text(r'$ 2.500'), findsOneWidget);
      expect(find.text(r'$ 9.000'), findsOneWidget);
      expect(find.text('Cancelar'), findsNWidgets(2));
      expect(
        find.text(formatearFechaCorta(DateTime.now().add(const Duration(days: 3)))),
        findsOneWidget,
      );

      // Se piden las dos vistas.
      final vistas = _pedidosA(servidor, '/reservas').map((u) => u.queryParameters['vista']);
      expect(vistas, containsAll(['proximas', 'historial']));
    });

    testWidgets('Historial muestra las terminadas, sin botón de cancelar', (tester) async {
      await abrirReservas(tester, _servidor());

      await tocar(tester, find.text('Historial'));

      expect(find.text('Completada'), findsOneWidget);
      expect(find.text(r'$ 4.200'), findsOneWidget);
      expect(find.text('Cancelar'), findsNothing);
    });

    testWidgets('sin próximas muestra el estado vacío y lleva a Sedes', (tester) async {
      await abrirReservas(tester, _servidor(conProximas: false));

      expect(find.text('0 activas · 1 historial'), findsOneWidget);
      expect(find.text('No tenés reservas próximas'), findsOneWidget);

      await tocar(tester, find.text('VER SEDES'));
      expect(find.text('4 sedes · 22 canchas disponibles'), findsOneWidget);
    });

    testWidgets('sin conexión: error con "Reintentar"', (tester) async {
      final servidor = _servidor()..fallo = const SinConexion();
      await abrirReservas(tester, servidor);
      expect(find.text('ERROR DE CONECTIVIDAD'), findsOneWidget);

      servidor.fallo = null;
      await tocar(tester, find.text('REINTENTAR'));

      expect(find.text('ERROR DE CONECTIVIDAD'), findsNothing);
      expect(find.text('Próximas (2)'), findsOneWidget);
    });
  });

  group('Detalle', () {
    testWidgets('muestra los datos completos de la reserva', (tester) async {
      final servidor = _servidor();
      await abrirReservas(tester, servidor);

      await tocar(tester, find.text('Sede Morón').first);

      expect(_pedidosA(servidor, '/reservas/10'), isNotEmpty);
      expect(find.textContaining('DETALLE DE', findRichText: true), findsOneWidget);
      expect(find.text('CONFIRMADA'), findsOneWidget);
      final fecha = DateTime.now().add(const Duration(days: 3));
      expect(find.text(formatearFechaLarga(fecha)), findsOneWidget);
      expect(find.text('19:00 a 20:00'), findsOneWidget);
      expect(find.text('Tenis · Polvo de Ladrillo · Exterior'), findsOneWidget);
      expect(find.text('Av. Rivadavia 17500, Morón'), findsOneWidget);
      expect(find.text(r'$ 2.500'), findsOneWidget);
      expect(find.text('Cancelar reserva'), findsOneWidget);
    });

    testWidgets('una reserva del historial no ofrece cancelar', (tester) async {
      await abrirReservas(tester, _servidor());
      await tocar(tester, find.text('Historial'));

      await tocar(tester, find.text('Sede Morón'));

      expect(find.text('COMPLETADA'), findsOneWidget);
      expect(find.text('Cancelar reserva'), findsNothing);
    });
  });

  group('Cancelar (CU-10)', () {
    testWidgets('desde la lista: confirma, cancela y pasa al historial', (tester) async {
      final servidor = _servidor();
      await abrirReservas(tester, servidor);

      await tocar(tester, find.text('Cancelar').first);

      // Pantalla de confirmación del Figma.
      expect(find.text('¿Querés cancelar la reserva?'), findsOneWidget);
      expect(find.textContaining('liberado inmediatamente'), findsOneWidget);
      expect(find.text('Volver'), findsOneWidget);
      expect(servidor.pedidos.where((u) => u.path.endsWith('/reservas/10')), isEmpty);

      await tocar(tester, find.text('Cancelar reserva'));

      // DELETE /reservas/10 y vuelve a la lista actualizada.
      expect(_pedidosA(servidor, '/reservas/10'), isNotEmpty);
      expect(find.text('Reserva cancelada'), findsOneWidget);
      expect(find.text('1 activa · 2 historial'), findsOneWidget);
      expect(find.text('Próximas (1)'), findsOneWidget);
    });

    testWidgets('"Volver" no cancela nada', (tester) async {
      final servidor = _servidor();
      await abrirReservas(tester, servidor);
      await tocar(tester, find.text('Cancelar').first);

      await tocar(tester, find.text('Volver'));

      expect(find.text('Próximas (2)'), findsOneWidget);
      expect(servidor.reservas, hasLength(2));
    });

    testWidgets('desde el detalle: también cancela y vuelve a la lista', (tester) async {
      final servidor = _servidor();
      await abrirReservas(tester, servidor);
      await tocar(tester, find.text('Sede Morón').first);

      await tocar(tester, find.text('Cancelar reserva'));
      await tocar(tester, find.text('Cancelar reserva'));

      expect(servidor.reservas.map((r) => r['id']), [11]);
      expect(find.text('Próximas (1)'), findsOneWidget);
      expect(find.text('Reserva cancelada'), findsOneWidget);
    });

    testWidgets('si ya empezó (409): avisa y actualiza la lista', (tester) async {
      final servidor = _servidor()..noCancelable = true;
      await abrirReservas(tester, servidor);
      await tocar(tester, find.text('Cancelar').first);

      await tocar(tester, find.text('Cancelar reserva'));

      expect(find.text('No se puede cancelar una reserva que ya empezó.'), findsOneWidget);
      expect(find.text('¿Querés cancelar la reserva?'), findsNothing);
      expect(find.text('Próximas (2)'), findsOneWidget);
    });

    testWidgets('al cancelar, la Home deja de mostrar esa reserva como próxima',
        (tester) async {
      final servidor = _servidor();
      await abrirApp(
        tester,
        auth: AuthFalso(inicial: _sesion),
        servidor: servidor.responder,
      );
      await tester.pumpAndSettle();
      expect(find.text('en 3 días →'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('RESERVAS').last);
      await tester.pumpAndSettle();
      await tocar(tester, find.text('Cancelar').first);
      await tocar(tester, find.text('Cancelar reserva'));

      await tester.tap(find.bySemanticsLabel('INICIO').last);
      await tester.pumpAndSettle();
      // La próxima ahora es la otra reserva (en 9 días).
      expect(find.text('en 3 días →'), findsNothing);
      expect(find.text('en 9 días →'), findsOneWidget);
    });
  });
}

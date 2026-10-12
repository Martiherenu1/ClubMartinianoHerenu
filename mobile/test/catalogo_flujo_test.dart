import 'package:club_martinianoherenu/core/errores.dart';
import 'package:club_martinianoherenu/core/servicio_auth.dart';
import 'package:club_martinianoherenu/widgets/etiquetas.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayudas.dart';
import 'servidor_falso.dart';

const _sesion = UsuarioSesion(uid: 'uid-1', email: 'martiniano@mail.com');

Future<ServidorFalso> abrirConSesion(
  WidgetTester tester, {
  List<Map<String, dynamic>> reservas = const [],
}) async {
  final servidor = ServidorFalso(reservas: reservas);
  await abrirApp(tester, auth: AuthFalso(inicial: _sesion), servidor: servidor.responder);
  await tester.pumpAndSettle();
  return servidor;
}

/// La barra inferior tiene el nombre de la pestaña; en pantalla también puede
/// aparecer el mismo texto como título, por eso se busca dentro de la barra.
Future<void> irAPestana(WidgetTester tester, String nombre) async {
  await tester.tap(find.bySemanticsLabel(nombre).last);
  await tester.pumpAndSettle();
}

void main() {
  group('Home', () {
    testWidgets('muestra saludo, próxima reserva, filtros y sedes', (tester) async {
      await abrirConSesion(tester, reservas: [reservaJson(dias: 3)]);

      expect(find.text('Martiniano Hereñu'), findsOneWidget);
      expect(find.text('MH'), findsOneWidget); // iniciales en el avatar
      expect(find.text('ZONA DEPORTIVA'), findsOneWidget);

      // Próxima reserva
      expect(find.text('PRÓXIMA RESERVA'), findsOneWidget);
      expect(find.text('en 3 días →'), findsOneWidget);
      expect(find.text('Sede Morón'), findsOneWidget);
      expect(find.text('Moron_Rivadavia_Tenis_Polvo_Cancha_1'), findsOneWidget);
      expect(find.text('19:00'), findsOneWidget);
      expect(find.text(r'$ 2.500'), findsOneWidget);

      // Filtros por deporte: salen de las sedes
      for (final d in ['Todos', 'Fútbol', 'Tenis', 'Golf', 'Hockey', 'Vóley']) {
        expect(find.text(d), findsOneWidget, reason: d);
      }

      expect(find.text('SEDES DISPONIBLES'), findsOneWidget);
      expect(find.text('Ver todas →'), findsOneWidget);
      expect(find.text('MORÓN'), findsOneWidget);
      expect(find.text('Av. Rivadavia 17500'), findsOneWidget);
    });

    testWidgets('sin reservas próximas lo avisa', (tester) async {
      await abrirConSesion(tester);

      expect(find.text('Todavía no tenés reservas próximas.'), findsOneWidget);
    });

    testWidgets('filtrar por deporte pide /sedes?deporte= y deja solo esas sedes',
        (tester) async {
      final servidor = await abrirConSesion(tester);
      expect(find.text('MORÓN'), findsOneWidget);

      final golf = find.widgetWithText(ChipDeporte, 'Golf');
      await tester.ensureVisible(golf);
      await tester.tap(golf);
      await tester.pumpAndSettle();

      expect(servidor.pedidosA('/sedes').last.queryParameters['deporte'], 'Golf');
      expect(find.text('SAN JUSTO'), findsOneWidget);
      expect(find.text('MORÓN'), findsNothing);

      // Volver a "Todos" trae todas otra vez.
      final todos = find.widgetWithText(ChipDeporte, 'Todos');
      await tester.ensureVisible(todos);
      await tester.tap(todos);
      await tester.pumpAndSettle();
      expect(find.text('MORÓN'), findsOneWidget);
    });

    testWidgets('sin conexión muestra el error y "Reintentar" vuelve a cargar',
        (tester) async {
      final servidor = ServidorFalso()..fallo = const SinConexion();
      await abrirApp(
        tester,
        auth: AuthFalso(inicial: _sesion),
        servidor: servidor.responder,
      );
      await tester.pumpAndSettle();

      expect(find.text('ERROR DE CONECTIVIDAD'), findsOneWidget);
      expect(find.text('Martiniano Hereñu'), findsNothing);

      servidor.fallo = null;
      await tester.tap(find.text('REINTENTAR'));
      await tester.pumpAndSettle();

      expect(find.text('ERROR DE CONECTIVIDAD'), findsNothing);
      expect(find.text('Martiniano Hereñu'), findsOneWidget);
    });

    testWidgets('"Ver todas" lleva a la pestaña Sedes', (tester) async {
      await abrirConSesion(tester);

      await tester.tap(find.text('Ver todas →'));
      await tester.pumpAndSettle();

      expect(find.text('4 sedes · 22 canchas disponibles'), findsOneWidget);
    });
  });

  group('Todas las sedes', () {
    testWidgets('lista las cuatro sedes con canchas y deportes', (tester) async {
      await abrirConSesion(tester);
      await irAPestana(tester, 'SEDES');

      expect(find.text('4 sedes · 22 canchas disponibles'), findsOneWidget);
      for (final s in ['SEDE MORÓN', 'SEDE RAMOS MEJÍA', 'SEDE SAN JUSTO', 'SEDE CASTELAR']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      expect(find.text('7'), findsOneWidget); // canchas de Morón
      expect(find.text('⚽ Fútbol'), findsNWidgets(3));
      expect(find.text('Ver canchas →'), findsNWidgets(4));
    });

    testWidgets('abrir una sede muestra sus canchas y "Todas las sedes" vuelve',
        (tester) async {
      final servidor = await abrirConSesion(tester);
      await irAPestana(tester, 'SEDES');

      await tester.tap(find.text('SEDE MORÓN'));
      await tester.pumpAndSettle();

      // Se piden las canchas de esa sede, del primer deporte.
      final pedido = servidor.pedidosA('/espacios').last.queryParameters;
      expect(pedido['sede_id'], '1');
      expect(pedido['deporte'], 'Fútbol');
      expect(pedido.containsKey('tipo'), isFalse);

      expect(find.text('SEDE MORÓN'), findsOneWidget);
      expect(find.text('4 canchas · Fútbol'), findsOneWidget);
      expect(find.text('Moron_Rivadavia_Futbol_F5_Cancha_1'), findsOneWidget);
      expect(find.text(r'$ 3.800'), findsOneWidget);
      expect(find.text('08:00 – 23:00'), findsNWidgets(4));
      expect(find.text('Outdoor'), findsNWidgets(3));
      expect(find.text('Indoor'), findsOneWidget); // F5 cancha 2 es cubierta

      await tester.tap(find.text('Todas las sedes'));
      await tester.pumpAndSettle();
      expect(find.text('4 sedes · 22 canchas disponibles'), findsOneWidget);
    });

    testWidgets('desde la Home, tocar una sede la abre en la pestaña Sedes',
        (tester) async {
      await abrirConSesion(tester);

      await tester.tap(find.text('MORÓN'));
      await tester.pumpAndSettle();

      expect(find.text('SEDE MORÓN'), findsOneWidget);
      expect(find.text('Todas las sedes'), findsOneWidget);
    });
  });

  group('Sede: filtros de canchas (CU-20)', () {
    Future<ServidorFalso> abrirMoron(WidgetTester tester) async {
      final servidor = await abrirConSesion(tester);
      await irAPestana(tester, 'SEDES');
      await tester.tap(find.text('SEDE MORÓN'));
      await tester.pumpAndSettle();
      return servidor;
    }

    testWidgets('filtrar por tipo manda el parámetro y acota la lista', (tester) async {
      final servidor = await abrirMoron(tester);

      await tester.tap(find.widgetWithText(ChipTipo, 'Fútbol 5'));
      await tester.pumpAndSettle();

      expect(servidor.pedidosA('/espacios').last.queryParameters['tipo'], 'F5');
      expect(find.text('2 canchas · Fútbol 5'), findsOneWidget);
      expect(find.text('Moron_Rivadavia_Futbol_F7_Cancha_1'), findsNothing);
    });

    testWidgets('cambiar de deporte reinicia el tipo y muestra sus tipos', (tester) async {
      final servidor = await abrirMoron(tester);
      await tester.tap(find.widgetWithText(ChipTipo, 'Fútbol 5'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChipDeporte, 'Tenis'));
      await tester.pumpAndSettle();

      final pedido = servidor.pedidosA('/espacios').last.queryParameters;
      expect(pedido['deporte'], 'Tenis');
      expect(pedido.containsKey('tipo'), isFalse);
      expect(find.text('Polvo de Ladrillo'), findsWidgets); // chip + etiqueta de la cancha
      expect(find.text('Cemento'), findsOneWidget);
      expect(find.text('1 cancha · Tenis'), findsOneWidget);
    });

    testWidgets('"Ver horarios / reservar" abre la pantalla de horarios de esa cancha',
        (tester) async {
      await abrirMoron(tester);

      await tester.tap(find.text('VER HORARIOS / RESERVAR').first);
      await tester.pumpAndSettle();

      // Pantalla de horarios de la primera cancha (el detalle de cada flujo
      // está en horarios_flujo_test.dart).
      expect(find.text('HORARIO DISPONIBLE'), findsOneWidget);
      expect(find.text('Moron_Rivadavia_Futbol_F5_Cancha_1'), findsOneWidget);
    });
  });

  group('Pestañas', () {
    testWidgets('cuenta sin perfil en la API (404): vuelve al login', (tester) async {
      final servidor = ServidorFalso()
        ..fallo = const ErrorNegocio(
          codigo: 'PERFIL_NO_ENCONTRADO',
          mensaje: 'Tu perfil no existe.',
          status: 404,
        );
      await abrirApp(
        tester,
        auth: AuthFalso(inicial: _sesion),
        servidor: servidor.responder,
      );
      await tester.pumpAndSettle();

      expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    });

    testWidgets('un 401 del backend en la Home cierra la sesión', (tester) async {
      final servidor = ServidorFalso()
        ..fallo = const NoAutenticado('Esta cuenta fue dada de baja.');
      await abrirApp(
        tester,
        auth: AuthFalso(inicial: _sesion),
        servidor: servidor.responder,
      );
      await tester.pumpAndSettle();

      expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    });
  });
}

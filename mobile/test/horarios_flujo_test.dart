import 'dart:convert';

import 'package:club_martinianoherenu/core/errores.dart';
import 'package:club_martinianoherenu/core/formato.dart';
import 'package:club_martinianoherenu/core/servicio_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayudas.dart';
import 'servidor_falso.dart';

const _sesion = UsuarioSesion(uid: 'uid-1', email: 'martiniano@mail.com');

DateTime get _hoy {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime _enDias(int d) => DateTime(_hoy.year, _hoy.month, _hoy.day + d);

/// Sede Morón → "VER HORARIOS / RESERVAR" de la primera cancha (Fútbol 5, cancha 1).
Future<void> abrirHorarios(WidgetTester tester, ServidorFalso servidor) async {
  await abrirApp(tester, auth: AuthFalso(inicial: _sesion), servidor: servidor.responder);
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel('SEDES').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('SEDE MORÓN'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('VER HORARIOS / RESERVAR').first);
  await tester.pumpAndSettle();
}

Future<void> tocar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Map<String, String> ultimaConsulta(ServidorFalso s) =>
    s.pedidos.lastWhere((u) => u.path.endsWith('/disponibilidad')).queryParameters;

void main() {
  group('Horarios (CU-12)', () {
    testWidgets('muestra cancha, fechas, duración y la grilla del día', (tester) async {
      final servidor = ServidorFalso();
      await abrirHorarios(tester, servidor);

      expect(find.text('SEDE MORÓN'), findsOneWidget);
      expect(find.text('FÚTBOL · FÚTBOL 5'), findsOneWidget);
      expect(find.text('Moron_Rivadavia_Futbol_F5_Cancha_1'), findsOneWidget);

      // Las dos canchas de Fútbol 5, con su condición.
      expect(find.text('Cancha 1'), findsOneWidget);
      expect(find.text('Cancha 2'), findsOneWidget);

      // Hoy y los días siguientes.
      expect(find.bySemanticsLabel(formatearFechaCorta(_hoy)), findsOneWidget);
      expect(find.text('1 hora'), findsOneWidget);
      expect(find.text('2 horas'), findsOneWidget);

      // Primera consulta: hoy, 1 hora, cancha 1.
      final pedido = servidor.pedidos.lastWhere((u) => u.path.endsWith('/disponibilidad'));
      expect(pedido.path, endsWith('/espacios/1/disponibilidad'));
      expect(pedido.queryParameters['fecha'], fechaIso(_hoy));
      expect(pedido.queryParameters['duracion'], '1');

      // 15 franjas (08–09 … 22–23), 5 ocupadas.
      expect(find.text('08:00 – 09:00'), findsOneWidget);
      expect(find.text('22:00 – 23:00'), findsOneWidget);
      expect(find.text('Algunos horarios están ocupados · 5 no disponibles'), findsOneWidget);
      expect(find.text(r'$ 3.800'), findsOneWidget); // total de 1 hora
      expect(find.text('SELECCIONÁ UN HORARIO'), findsOneWidget);
    });

    testWidgets('elegir una franja habilita "Confirmar reserva" y la resume', (tester) async {
      await abrirHorarios(tester, ServidorFalso());

      await tocar(tester, find.text('19:00 – 20:00'));

      expect(find.text('CONFIRMAR RESERVA'), findsOneWidget);
      expect(find.text('SELECCIONÁ UN HORARIO'), findsNothing);
      // Una vez en la grilla y otra en el resumen.
      expect(find.text('19:00 – 20:00'), findsNWidgets(2));
      expect(find.text(formatearFechaCorta(_hoy)), findsOneWidget);
    });

    testWidgets('una franja ocupada no se puede elegir', (tester) async {
      await abrirHorarios(tester, ServidorFalso());

      await tocar(tester, find.text('09:00 – 10:00')); // ocupada

      expect(find.text('SELECCIONÁ UN HORARIO'), findsOneWidget);
      expect(find.text('CONFIRMAR RESERVA'), findsNothing);
    });

    testWidgets('2 horas vuelve a consultar y cambia grilla y total', (tester) async {
      final servidor = ServidorFalso();
      await abrirHorarios(tester, servidor);

      await tocar(tester, find.text('2 horas'));

      expect(ultimaConsulta(servidor)['duracion'], '2');
      expect(find.text('08:00 – 10:00'), findsOneWidget);
      expect(find.text(r'$ 3.800 × 2'), findsOneWidget);
      expect(find.text(r'$ 7.600'), findsOneWidget);
    });

    testWidgets('cambiar de fecha consulta ese día y limpia la elección', (tester) async {
      final servidor = ServidorFalso();
      await abrirHorarios(tester, servidor);
      await tocar(tester, find.text('19:00 – 20:00'));
      expect(find.text('CONFIRMAR RESERVA'), findsOneWidget);

      await tocar(tester, find.bySemanticsLabel(formatearFechaCorta(_enDias(2))));

      expect(ultimaConsulta(servidor)['fecha'], fechaIso(_enDias(2)));
      expect(find.text('SELECCIONÁ UN HORARIO'), findsOneWidget);
    });

    testWidgets('cambiar de cancha consulta la otra cancha', (tester) async {
      final servidor = ServidorFalso();
      await abrirHorarios(tester, servidor);

      await tocar(tester, find.text('Cancha 2'));

      final pedido = servidor.pedidos.lastWhere((u) => u.path.endsWith('/disponibilidad'));
      expect(pedido.path, endsWith('/espacios/2/disponibilidad'));
      expect(find.text('Moron_Rivadavia_Futbol_F5_Cancha_2'), findsOneWidget);
    });

    testWidgets('FA4: día sin turnos → estado vacío y botón deshabilitado', (tester) async {
      final lleno = fechaIso(_enDias(1));
      await abrirHorarios(tester, ServidorFalso(diasLlenos: {lleno}));

      await tocar(tester, find.bySemanticsLabel(formatearFechaCorta(_enDias(1))));

      expect(find.text('NO HAY HORARIOS DISPONIBLES'), findsOneWidget);
      expect(find.text('Probá seleccionando otra fecha arriba.'), findsOneWidget);
      expect(find.text('SELECCIONÁ UN HORARIO'), findsOneWidget);
    });

    testWidgets('FA5: sin conexión → error con "Reintentar" que vuelve a cargar',
        (tester) async {
      final servidor = ServidorFalso();
      await abrirHorarios(tester, servidor);

      servidor.fallo = const SinConexion();
      await tocar(tester, find.text('2 horas'));
      expect(find.text('ERROR DE CONECTIVIDAD'), findsOneWidget);

      servidor.fallo = null;
      await tocar(tester, find.text('REINTENTAR'));
      expect(find.text('ERROR DE CONECTIVIDAD'), findsNothing);
      expect(find.text('08:00 – 10:00'), findsOneWidget);
    });
  });

  group('Reservar (CU-09)', () {
    testWidgets('confirma, muestra "Reserva confirmada" y lleva a Reservas',
        (tester) async {
      final servidor = ServidorFalso();
      await abrirHorarios(tester, servidor);
      await tocar(tester, find.text('19:00 – 20:00'));
      final consultasAntes =
          servidor.pedidos.where((u) => u.path.endsWith('/usuarios/me')).length;

      await tocar(tester, find.text('CONFIRMAR RESERVA'));

      // Lo que mandó la app.
      expect(servidor.reservasCreadas, hasLength(1));
      expect(servidor.reservasCreadas.single, {
        'espacio_id': 1,
        'fecha': fechaIso(_hoy),
        'hora_inicio': '19:00',
        'duracion': 1,
      });

      // Pantalla de confirmación.
      expect(find.textContaining('CONFIRMADA!', findRichText: true), findsOneWidget);
      expect(find.text('Redirigiendo a tus reservas…'), findsOneWidget);

      // Después de un momento va a la pestaña Reservas.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('MIS RESERVAS'), findsOneWidget);
      expect(find.textContaining('CONFIRMADA!', findRichText: true), findsNothing);

      // La Home vuelve a pedir sus datos: la próxima reserva puede haber cambiado.
      final despues = servidor.pedidos.where((u) => u.path.endsWith('/usuarios/me')).length;
      expect(despues, greaterThan(consultasAntes));
    });

    testWidgets('si alguien tomó el horario: avisa y actualiza la grilla', (tester) async {
      final servidor = ServidorFalso()..conflicto = true;
      await abrirHorarios(tester, servidor);
      await tocar(tester, find.text('19:00 – 20:00'));
      final consultasAntes =
          servidor.pedidos.where((u) => u.path.endsWith('/disponibilidad')).length;

      await tocar(tester, find.text('CONFIRMAR RESERVA'));

      expect(find.text('El horario seleccionado ya no está disponible.'), findsOneWidget);
      // Sigue en la pantalla de horarios, sin elección, con la grilla refrescada.
      expect(find.text('SELECCIONÁ UN HORARIO'), findsOneWidget);
      final consultasDespues =
          servidor.pedidos.where((u) => u.path.endsWith('/disponibilidad')).length;
      expect(consultasDespues, consultasAntes + 1);
    });

    testWidgets('sin conexión al confirmar: tarjeta de error y conserva la elección',
        (tester) async {
      final servidor = ServidorFalso();
      await abrirHorarios(tester, servidor);
      await tocar(tester, find.text('19:00 – 20:00'));

      servidor.fallo = const SinConexion();
      await tocar(tester, find.text('CONFIRMAR RESERVA'));

      expect(find.text('ERROR DE CONECTIVIDAD'), findsOneWidget);
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      expect(find.text('CONFIRMAR RESERVA'), findsOneWidget);
    });

    test('el cuerpo de la reserva es JSON válido', () {
      // Guarda contra cambios de formato en la fecha ("AAAA-MM-DD").
      expect(jsonEncode({'fecha': fechaIso(DateTime(2026, 10, 5))}), '{"fecha":"2026-10-05"}');
    });
  });
}

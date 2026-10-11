import 'dart:convert';

import 'package:club_martinianoherenu/app/app.dart';
import 'package:club_martinianoherenu/app/controlador_tema.dart';
import 'package:club_martinianoherenu/core/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  // En los tests no hay internet para bajar las fuentes de Google.
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('la pantalla inicial muestra el nombre del club', (tester) async {
    final api = ApiClient(
      cliente: MockClient(
        (_) async => http.Response(jsonEncode({'status': 'ok'}), 200),
      ),
    );

    await tester.pumpWidget(AppClub(api: api, tema: ControladorTema()));
    await tester.pump();

    expect(find.textContaining('MARTINIANO HEREÑU', findRichText: true), findsOneWidget);
    expect(find.text('Gestión de espacios deportivos'), findsOneWidget);
    tester.takeException(); // fuentes no disponibles en el entorno de test
  });
}

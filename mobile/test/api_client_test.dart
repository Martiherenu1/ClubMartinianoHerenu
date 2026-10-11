import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:club_martinianoherenu/core/api_client.dart';
import 'package:club_martinianoherenu/core/errores.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ApiClient clienteCon(
  Future<http.Response> Function(http.Request) respuesta, {
  Future<String?> Function()? token,
}) {
  return ApiClient(
    cliente: MockClient(respuesta),
    urlBase: 'http://api.test/api/v1',
    proveedorToken: token,
    timeout: const Duration(seconds: 2),
  );
}

http.Response json(Object cuerpo, int status) => http.Response(
      jsonEncode(cuerpo),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  group('respuestas correctas', () {
    test('GET devuelve el JSON y manda el token en el header', () async {
      late http.Request recibido;
      final api = clienteCon(
        (r) async {
          recibido = r;
          return json({'ok': true}, 200);
        },
        token: () async => 'mi-token',
      );

      final resultado = await api.get('/sedes', query: {'deporte': 'Fútbol', 'x': null});

      expect(resultado, {'ok': true});
      expect(recibido.headers['Authorization'], 'Bearer mi-token');
      expect(recibido.url.path, '/api/v1/sedes');
      expect(recibido.url.queryParameters, {'deporte': 'Fútbol'}); // null se omite
    });

    test('sin sesión no manda Authorization', () async {
      late http.Request recibido;
      final api = clienteCon((r) async {
        recibido = r;
        return json([], 200);
      });
      await api.get('/sedes');
      expect(recibido.headers.containsKey('Authorization'), isFalse);
    });

    test('POST manda el body como JSON', () async {
      late http.Request recibido;
      final api = clienteCon((r) async {
        recibido = r;
        return json({'id': 1}, 201);
      });
      await api.post('/reservas', body: {'duracion': 2});
      expect(jsonDecode(recibido.body), {'duracion': 2});
      expect(recibido.headers['Content-Type'], contains('application/json'));
    });

    test('204 sin cuerpo devuelve null', () async {
      final api = clienteCon((r) async => http.Response('', 204));
      expect(await api.delete('/usuarios/me'), isNull);
    });
  });

  group('errores', () {
    test('409 con formato de la API → ErrorNegocio con código y mensaje', () async {
      final api = clienteCon((r) async => json({
            'error': {
              'codigo': 'HORARIO_OCUPADO',
              'mensaje': 'El horario seleccionado ya no está disponible.',
            }
          }, 409));

      await expectLater(
        api.post('/reservas', body: {}),
        throwsA(isA<ErrorNegocio>()
            .having((e) => e.codigo, 'codigo', 'HORARIO_OCUPADO')
            .having((e) => e.status, 'status', 409)
            .having((e) => e.mensaje, 'mensaje', contains('ya no está'))),
      );
    });

    test('401 → NoAutenticado con el mensaje de la API', () async {
      final api = clienteCon((r) async => json({
            'error': {'codigo': 'NO_AUTENTICADO', 'mensaje': 'Tu sesión expiró.'}
          }, 401));
      await expectLater(
        api.get('/usuarios/me'),
        throwsA(isA<NoAutenticado>().having((e) => e.mensaje, 'mensaje', 'Tu sesión expiró.')),
      );
    });

    test('500 → ErrorServidor', () async {
      final api = clienteCon((r) async => json({
            'error': {'codigo': 'ERROR_INTERNO', 'mensaje': 'interno'}
          }, 500));
      await expectLater(api.get('/sedes'), throwsA(isA<ErrorServidor>()));
    });

    test('502 de un proxy, sin formato de la API → ErrorServidor', () async {
      final api = clienteCon((r) async => http.Response('<html>Bad Gateway</html>', 502));
      await expectLater(api.get('/sedes'), throwsA(isA<ErrorServidor>()));
    });

    test('respuesta que no es JSON → ErrorServidor', () async {
      final api = clienteCon((r) async => http.Response('no soy json', 200));
      await expectLater(api.get('/sedes'), throwsA(isA<ErrorServidor>()));
    });

    test('sin red (SocketException) → SinConexion', () async {
      final api = clienteCon((r) async => throw const SocketException('sin red'));
      await expectLater(api.get('/sedes'), throwsA(isA<SinConexion>()));
    });

    test('servidor que no responde a tiempo → SinConexion', () async {
      final api = ApiClient(
        cliente: MockClient((r) => Completer<http.Response>().future),
        urlBase: 'http://api.test/api/v1',
        timeout: const Duration(milliseconds: 100),
      );
      await expectLater(api.get('/sedes'), throwsA(isA<SinConexion>()));
    });
  });
}

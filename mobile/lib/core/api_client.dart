/// Cliente HTTP de la API del club.
///
/// Se encarga de: armar la URL, mandar el ID token de Firebase en
/// `Authorization: Bearer`, aplicar timeout y traducir todo error a un
/// [ErrorApp] (ver `errores.dart`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'errores.dart';

/// Devuelve el ID token vigente de Firebase, o `null` si no hay sesión.
typedef ProveedorToken = Future<String?> Function();

class ApiClient {
  ApiClient({
    http.Client? cliente,
    this.proveedorToken,
    String? urlBase,
    Duration? timeout,
  })  : _cliente = cliente ?? http.Client(),
        _urlBase = urlBase ?? '${Config.apiUrl}${Config.apiPrefijo}',
        _timeout = timeout ?? Config.timeoutApi;

  final http.Client _cliente;
  final String _urlBase;
  final Duration _timeout;

  /// Se asigna cuando hay sesión iniciada.
  ProveedorToken? proveedorToken;

  Future<dynamic> get(String ruta, {Map<String, String?>? query}) =>
      _enviar('GET', ruta, query: query);

  Future<dynamic> post(String ruta, {Object? body}) =>
      _enviar('POST', ruta, body: body);

  Future<dynamic> put(String ruta, {Object? body}) =>
      _enviar('PUT', ruta, body: body);

  Future<dynamic> delete(String ruta) => _enviar('DELETE', ruta);

  Future<dynamic> _enviar(
    String metodo,
    String ruta, {
    Map<String, String?>? query,
    Object? body,
  }) async {
    final parametros = <String, String>{
      for (final e in (query ?? const {}).entries)
        if (e.value != null) e.key: e.value!,
    };
    final uri = Uri.parse('$_urlBase$ruta')
        .replace(queryParameters: parametros.isEmpty ? null : parametros);

    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };
    final token = await proveedorToken?.call();
    if (token != null) headers['Authorization'] = 'Bearer $token';

    try {
      final request = http.Request(metodo, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final stream = await _cliente.send(request).timeout(_timeout);
      final respuesta = await http.Response.fromStream(stream).timeout(_timeout);
      return _procesar(respuesta);
    } on ErrorApp {
      rethrow;
    } on TimeoutException {
      throw const SinConexion();
    } on SocketException {
      throw const SinConexion();
    } on http.ClientException {
      throw const SinConexion();
    } on FormatException {
      throw const ErrorServidor();
    }
  }

  dynamic _procesar(http.Response r) {
    final cuerpo = utf8.decode(r.bodyBytes);
    final json = cuerpo.isEmpty ? null : jsonDecode(cuerpo);

    if (r.statusCode >= 200 && r.statusCode < 300) return json;

    final error = (json is Map ? json['error'] : null) as Map?;
    final mensaje = error?['mensaje'] as String?;
    final codigo = error?['codigo'] as String?;

    if (r.statusCode == 401) {
      throw NoAutenticado(mensaje ?? 'Tu sesión expiró. Volvé a iniciar sesión.');
    }
    if (r.statusCode >= 500 || error == null) {
      throw const ErrorServidor();
    }
    throw ErrorNegocio(
      codigo: codigo ?? 'ERROR',
      mensaje: mensaje ?? 'No se pudo completar la operación.',
      status: r.statusCode,
    );
  }

  void cerrar() => _cliente.close();
}

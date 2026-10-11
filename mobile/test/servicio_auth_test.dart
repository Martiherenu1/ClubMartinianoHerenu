import 'package:club_martinianoherenu/core/errores.dart';
import 'package:club_martinianoherenu/core/servicio_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

ErrorApp traducir(String codigo) =>
    traducirErrorFirebase(FirebaseAuthException(code: codigo));

void main() {
  group('traducirErrorFirebase', () {
    test('sin red → SinConexion', () {
      expect(traducir('network-request-failed'), isA<SinConexion>());
    });

    test('credenciales incorrectas → mensaje genérico (no revela qué falló)', () {
      for (final codigo in [
        'invalid-credential',
        'wrong-password',
        'user-not-found',
        'invalid-email',
        'user-disabled',
      ]) {
        final e = traducir(codigo);
        expect(e, isA<CredencialesInvalidas>(), reason: codigo);
        expect(e.mensaje, contains('No se pudo iniciar sesión'));
      }
      // El mensaje de "usuario inexistente" y "contraseña mala" es el mismo.
      expect(traducir('user-not-found').mensaje, traducir('wrong-password').mensaje);
    });

    test('demasiados intentos → error de negocio con código', () {
      final e = traducir('too-many-requests');
      expect(e, isA<ErrorNegocio>().having((x) => x.codigo, 'codigo', 'DEMASIADOS_INTENTOS'));
    });

    test('cualquier otro código → ErrorServidor', () {
      expect(traducir('internal-error'), isA<ErrorServidor>());
    });
  });
}

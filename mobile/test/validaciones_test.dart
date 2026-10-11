import 'package:club_martinianoherenu/features/auth/validaciones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('emailValido', () {
    test('acepta emails comunes', () {
      expect(emailValido('juan@email.com'), isTrue);
      expect(emailValido('  juan.perez+club@mail.com.ar '), isTrue);
    });

    test('rechaza lo que no es un email', () {
      for (final malo in ['', 'juan', 'juan@', '@email.com', 'juan@email', 'a b@c.com']) {
        expect(emailValido(malo), isFalse, reason: '"$malo"');
      }
    });
  });

  group('DNI', () {
    test('normaliza puntos y espacios', () {
      expect(normalizarDni('31.234.567'), '31234567');
      expect(normalizarDni(' 31 234 567 '), '31234567');
    });

    test('acepta 7 u 8 dígitos', () {
      expect(dniValido('31.234.567'), isTrue);
      expect(dniValido('9.123.456'), isTrue);
    });

    test('rechaza largos y caracteres inválidos', () {
      for (final malo in ['', '123456', '123456789', '12ab5678', '1.2.3']) {
        expect(dniValido(malo), isFalse, reason: '"$malo"');
      }
    });
  });

  group('contraseña', () {
    test('mínimo de 8 caracteres, como dice el Figma', () {
      expect(passwordValida('1234567'), isFalse);
      expect(passwordValida('12345678'), isTrue);
      expect(largoMinimoPassword, 8);
    });
  });
}

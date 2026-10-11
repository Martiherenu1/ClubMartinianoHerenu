import 'package:club_martinianoherenu/core/formato.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatearPrecio', () {
    test('usa punto como separador de miles', () {
      expect(formatearPrecio(3800), r'$ 3.800');
      expect(formatearPrecio(9000), r'$ 9.000');
      expect(formatearPrecio(2500.0), r'$ 2.500');
    });

    test('sin separador por debajo de mil y con millones', () {
      expect(formatearPrecio(950), r'$ 950');
      expect(formatearPrecio(1250000), r'$ 1.250.000');
    });
  });

  group('fechas y horas', () {
    test('fecha corta como en el Figma', () {
      expect(formatearFechaCorta(DateTime(2026, 8, 15)), 'sáb, 15 ago');
      expect(formatearFechaCorta(DateTime(2026, 10, 12)), 'lun, 12 oct');
    });

    test('recortarHora saca los segundos', () {
      expect(recortarHora('08:00:00'), '08:00');
      expect(recortarHora('19:30'), '19:30');
    });

    test('cuandoEs', () {
      final hoy = DateTime(2026, 10, 14, 15, 30);
      expect(cuandoEs(DateTime(2026, 10, 14), hoy), 'hoy');
      expect(cuandoEs(DateTime(2026, 10, 15), hoy), 'mañana');
      expect(cuandoEs(DateTime(2026, 10, 17), hoy), 'en 3 días');
    });

    test('saludo según la hora', () {
      expect(saludoSegunHora(DateTime(2026, 1, 1, 9)), 'Buenos días');
      expect(saludoSegunHora(DateTime(2026, 1, 1, 15)), 'Buenas tardes');
      expect(saludoSegunHora(DateTime(2026, 1, 1, 22)), 'Buenas noches');
    });
  });

  group('etiquetas', () {
    test('tipos abreviados', () {
      expect(etiquetaTipo('F5'), 'Fútbol 5');
      expect(etiquetaTipo('F11'), 'Fútbol 11');
      expect(etiquetaTipo('H7'), 'Hockey 7');
    });

    test('tipos de texto libre quedan con mayúsculas del Figma', () {
      expect(etiquetaTipo('Polvo de ladrillo'), 'Polvo de Ladrillo');
      expect(etiquetaTipo('Indoor parquet'), 'Indoor Parquet');
      expect(etiquetaTipo('Cemento'), 'Cemento');
    });

    test('iniciales', () {
      expect(iniciales('Carlos', 'García'), 'CG');
      expect(iniciales('martiniano', ''), 'M');
    });
  });
}

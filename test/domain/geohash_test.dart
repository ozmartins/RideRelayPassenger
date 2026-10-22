import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/geohash.dart';

void main() {
  test('kPrecisoesDaTag é 5, 4 e 3, nessa ordem', () {
    expect(kPrecisoesDaTag, [5, 4, 3]);
  });

  group('Geohash.encode', () {
    test('reproduz as âncoras públicas independentes', () {
      expect(Geohash.encode(42.605, -5.603, 5), 'ezs42');
      expect(Geohash.encode(57.64911, 10.40744, 11), 'u4pruydqqvj');
    });

    test('as precisões menores são prefixos da maior', () {
      final g5 = Geohash.encode(-28.9298, -49.4753, 5);
      expect(Geohash.encode(-28.9298, -49.4753, 4), g5.substring(0, 4));
      expect(Geohash.encode(-28.9298, -49.4753, 3), g5.substring(0, 3));
    });

    test('aceita os limites de coordenada', () {
      for (final p in [(-90.0, -180.0), (90.0, 180.0), (0.0, 0.0)]) {
        final g = Geohash.encode(p.$1, p.$2, 5);
        expect(g, matches(RegExp(r'^[0-9b-hjkmnp-z]{5}$')));
      }
    });

    test('rejeita latitude, longitude e precisão inválidas', () {
      expect(() => Geohash.encode(90.1, 0, 5), throwsArgumentError);
      expect(() => Geohash.encode(-90.1, 0, 5), throwsArgumentError);
      expect(() => Geohash.encode(0, 180.1, 5), throwsArgumentError);
      expect(() => Geohash.encode(0, -180.1, 5), throwsArgumentError);
      expect(() => Geohash.encode(double.nan, 0, 5), throwsArgumentError);
      expect(() => Geohash.encode(0, 0, 0), throwsArgumentError);
      expect(() => Geohash.encode(0, 0, 13), throwsArgumentError);
    });
  });
}

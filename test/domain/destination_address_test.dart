import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/destination_address.dart';

void main() {
  group('DestinationAddress — texto livre (FR-007 da feature 004)', () {
    test('aceita texto vazio', () {
      const destino = DestinationAddress(
        '',
        latitude: -28.9298,
        longitude: -49.4753,
      );
      expect(destino.text, '');
    });

    test('aceita texto qualquer sem validação de formato', () {
      const destino = DestinationAddress(
        'quintal do vizinho, sem número',
        latitude: -28.9298,
        longitude: -49.4753,
      );
      expect(destino.text, 'quintal do vizinho, sem número');
    });

    test('expõe latitude e longitude (feature 006)', () {
      const destino = DestinationAddress(
        'Praça Central',
        latitude: -28.6721,
        longitude: -49.3671,
      );
      expect(destino.latitude, -28.6721);
      expect(destino.longitude, -49.3671);
    });
  });

  group('DestinationAddress — igualdade (feature 006)', () {
    test('duas instâncias com mesmo texto e coordenadas são iguais', () {
      expect(
        const DestinationAddress(
          'Praça Central',
          latitude: -28.6721,
          longitude: -49.3671,
        ),
        const DestinationAddress(
          'Praça Central',
          latitude: -28.6721,
          longitude: -49.3671,
        ),
      );
    });

    test('mesmo texto com coordenadas diferentes não são iguais (endereços '
        'homônimos — Edge Case da feature 005, agora também por '
        'coordenada)', () {
      expect(
        const DestinationAddress(
          'Rua das Flores',
          latitude: -28.6721,
          longitude: -49.3671,
        ),
        isNot(
          const DestinationAddress(
            'Rua das Flores',
            latitude: -27.5954,
            longitude: -48.5480,
          ),
        ),
      );
    });
  });
}

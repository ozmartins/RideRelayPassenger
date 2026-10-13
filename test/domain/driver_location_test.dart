import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/driver_location.dart';
import 'package:passenger/domain/nostr_event.dart';

NostrEvent evento(String content, {DateTime? createdAt}) => NostrEvent(
  id: 'id',
  authorPublicKey: 'motorista',
  createdAt: createdAt ?? DateTime.utc(2026, 9, 30, 12),
  kind: 20005,
  content: content,
  isSignatureValid: true,
);

void main() {
  group('DriverLocation.fromNostrEvent', () {
    test('aceita lat/lon e guarda o instante declarado', () {
      final instante = DateTime.utc(2026, 9, 30, 12, 0, 5);

      final posicao = DriverLocation.fromNostrEvent(
        evento('{"lat":-28.9312,"lon":-49.4889}', createdAt: instante),
      );

      expect(posicao.latitude, -28.9312);
      expect(posicao.longitude, -49.4889);
      expect(posicao.reportedAt, instante);
    });

    test('aceita inteiros e os limites da faixa', () {
      final posicao = DriverLocation.fromNostrEvent(
        evento('{"lat":-90,"lon":180}'),
      );

      expect(posicao.latitude, -90);
      expect(posicao.longitude, 180);
    });

    for (final content in <String>[
      'isto não é json',
      '[1, 2]',
      '"texto"',
      '{}',
      '{"lat":-28.9}',
      '{"lon":-49.4}',
      '{"lat":"-28.9","lon":"-49.4"}',
      '{"lat":null,"lon":-49.4}',
      '{"lat":-28.9,"lon":null}',
      '{"lat":90.0001,"lon":-49.4}',
      '{"lat":-90.0001,"lon":-49.4}',
      '{"lat":-28.9,"lon":180.5}',
      '{"lat":-28.9,"lon":-181}',
      '{"lat":1e999,"lon":-49.4}',
    ]) {
      test('recusa content malformado ou fora de faixa: $content', () {
        expect(
          () => DriverLocation.fromNostrEvent(evento(content)),
          throwsFormatException,
        );
      });
    }
  });

  group('DriverLocation.isNewerThan', () {
    DriverLocation em(int segundos) => DriverLocation(
      latitude: 0,
      longitude: 0,
      reportedAt: DateTime.utc(
        2026,
        9,
        30,
        12,
      ).add(Duration(seconds: segundos)),
    );

    test('sem posição anterior, vale', () {
      expect(em(0).isNewerThan(null), isTrue);
    });

    test('instante estritamente posterior vale', () {
      expect(em(5).isNewerThan(em(0)), isTrue);
    });

    test('instante igual ou anterior não vale', () {
      expect(em(0).isNewerThan(em(0)), isFalse);
      expect(em(0).isNewerThan(em(5)), isFalse);
    });
  });
}

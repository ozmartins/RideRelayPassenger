import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:passenger/domain/nostr_event.dart';
import 'package:passenger/domain/ride_route.dart';

NostrEvent evento(String content, {DateTime? createdAt}) => NostrEvent(
  id: 'id',
  authorPublicKey: 'motorista',
  createdAt: createdAt ?? DateTime.utc(2026, 10, 3, 12),
  kind: 20011,
  content: content,
  isSignatureValid: true,
);

String conteudo(List<List<Object?>> pontos) => jsonEncode({'points': pontos});

List<List<Object?>> pontos(int n) => [
  for (var i = 0; i < n; i++) [-28.9 + i * 0.00001, -49.4 + i * 0.00001],
];

void main() {
  group('RideRoute.fromNostrEvent', () {
    test('aceita 2 pontos e guarda o instante declarado', () {
      final instante = DateTime.utc(2026, 10, 3, 12, 0, 5);

      final rota = RideRoute.fromNostrEvent(
        evento('{"points":[[-28.9,-49.4],[-28.8,-49.3]]}', createdAt: instante),
      );

      expect(rota.points, const [LatLng(-28.9, -49.4), LatLng(-28.8, -49.3)]);
      expect(rota.reportedAt, instante);
    });

    test('aceita 1000 pontos e os limites da faixa', () {
      expect(
        RideRoute.fromNostrEvent(evento(conteudo(pontos(1000)))).points,
        hasLength(1000),
      );
      final limites = RideRoute.fromNostrEvent(
        evento(
          conteudo([
            [-90, -180],
            [90, 180],
          ]),
        ),
      );
      expect(limites.points.first, const LatLng(-90, -180));
      expect(limites.points.last, const LatLng(90, 180));
    });

    test('descarta com menos de 2 ou mais de 1000 pontos', () {
      for (final n in [0, 1, 1001]) {
        expect(
          () => RideRoute.fromNostrEvent(evento(conteudo(pontos(n)))),
          throwsFormatException,
          reason: '$n pontos',
        );
      }
    });

    test('descarta conteúdo malformado', () {
      const invalidos = [
        'não é json',
        '[]',
        '{}',
        '{"points":"x"}',
        '{"points":null}',
        '{"points":[1,2]}',
        '{"points":[[1],[2]]}',
        '{"points":[[1,2,3],[4,5,6]]}',
        '{"points":[["a","b"],["c","d"]]}',
        '{"points":[[-28.9,null],[-28.8,-49.3]]}',
      ];
      for (final texto in invalidos) {
        expect(
          () => RideRoute.fromNostrEvent(evento(texto)),
          throwsFormatException,
          reason: texto,
        );
      }
    });

    test('descarta coordenadas fora de faixa', () {
      const foraDeFaixa = [
        [90.1, 0],
        [-90.1, 0],
        [0, 180.1],
        [0, -180.1],
      ];
      for (final ponto in foraDeFaixa) {
        expect(
          () => RideRoute.fromNostrEvent(
            evento(
              conteudo([
                [-28.9, -49.4],
                ponto,
              ]),
            ),
          ),
          throwsFormatException,
          reason: '$ponto',
        );
      }
    });

    test('descarta coordenada não finita', () {
      expect(
        () => RideRoute.fromNostrEvent(
          evento('{"points":[[-28.9,-49.4],[1e999,0]]}'),
        ),
        throwsFormatException,
      );
    });

    test('a lista de pontos não é modificável', () {
      final rota = RideRoute.fromNostrEvent(evento(conteudo(pontos(2))));

      expect(() => rota.points.add(const LatLng(0, 0)), throwsUnsupportedError);
    });
  });

  group('RideRoute.isNewerThan', () {
    RideRoute em(int segundos) => RideRoute.fromNostrEvent(
      evento(
        conteudo(pontos(2)),
        createdAt: DateTime.utc(
          2026,
          10,
          3,
          12,
        ).add(Duration(seconds: segundos)),
      ),
    );

    test('é mais nova quando não há rota anterior', () {
      expect(em(0).isNewerThan(null), isTrue);
    });

    test('é mais nova só com created_at estritamente posterior', () {
      expect(em(5).isNewerThan(em(0)), isTrue);
      expect(em(5).isNewerThan(em(5)), isFalse);
      expect(em(1).isNewerThan(em(5)), isFalse);
    });
  });
}

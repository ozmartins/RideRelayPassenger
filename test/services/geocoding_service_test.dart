import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:passenger/domain/address_suggestion.dart';
import 'package:passenger/services/geocoding_service.dart';

/// Dublê de `http.Client`: nenhum teste toca rede real (Princípio II).
class _ClienteHttpDeTeste extends http.BaseClient {
  _ClienteHttpDeTeste(this._respostas);

  /// Resposta programada por chamada, na ordem em que `send` é chamado. Uma
  /// função em vez de um valor fixo permite simular timeout com um atraso.
  final Future<http.StreamedResponse> Function(http.BaseRequest) _respostas;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _respostas(request);
}

http.StreamedResponse _respostaTexto(String corpo, {int status = 200}) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(corpo)),
    status,
  );
}

const _corpoComResultados = '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "geometry": {"type": "Point", "coordinates": [-9.13, 38.70]},
      "properties": {
        "osm_type": "R",
        "osm_id": 123456,
        "name": "Lisboa",
        "street": null,
        "housenumber": null,
        "city": null,
        "county": "Lisboa",
        "state": "Lisboa",
        "country": "Portugal",
        "countrycode": "PT"
      }
    },
    {
      "geometry": {"type": "Point", "coordinates": [-49.49, -28.93]},
      "properties": {
        "osm_type": "W",
        "osm_id": 789,
        "name": "Praça Central",
        "street": "Rua das Flores",
        "housenumber": "123",
        "city": "Araranguá",
        "county": null,
        "state": "Santa Catarina",
        "country": "Brasil",
        "countrycode": "BR"
      }
    }
  ]
}
''';

const _corpoVazio = '{"type": "FeatureCollection", "features": []}';

void main() {
  group('PhotonGeocodingService.search', () {
    test('sucesso com resultados monta AddressSuggestion a partir das '
        'propriedades', () async {
      final service = PhotonGeocodingService(
        client: _ClienteHttpDeTeste(
          (req) async => _respostaTexto(_corpoComResultados),
        ),
      );

      final sugestoes = await service.search('Lisboa');

      expect(sugestoes, [
        const AddressSuggestion(
          id: 'R123456',
          displayText: 'Lisboa, Lisboa, Lisboa, Portugal',
          latitude: 38.70,
          longitude: -9.13,
        ),
        const AddressSuggestion(
          id: 'W789',
          displayText:
              'Praça Central, Rua das Flores, 123, Araranguá, '
              'Santa Catarina, Brasil',
          latitude: -28.93,
          longitude: -49.49,
        ),
      ]);
    });

    test('lê a latitude/longitude na ordem GeoJSON [lon, lat] — não '
        'trocada (D4 de specs/006-solicitar-corrida/research.md)', () async {
      // coordinates[0] é longitude, coordinates[1] é latitude. Um valor
      // grande e distinto em cada posição torna uma inversão de ordem
      // detectável por este teste (nenhum dos dois poderia ser confundido
      // com o outro se a leitura estivesse correta).
      const corpo = '''
      {"type": "FeatureCollection", "features": [
        {
          "geometry": {"type": "Point", "coordinates": [-49.4753, -28.9298]},
          "properties": {"osm_type": "N", "osm_id": 1, "name": "Teste"}
        }
      ]}
      ''';
      final service = PhotonGeocodingService(
        client: _ClienteHttpDeTeste((req) async => _respostaTexto(corpo)),
      );

      final sugestoes = await service.search('Araranguá');

      expect(sugestoes.single.longitude, -49.4753);
      expect(sugestoes.single.latitude, -28.9298);
    });

    test('sucesso com lista vazia retorna lista vazia (sem lançar)', () async {
      final service = PhotonGeocodingService(
        client: _ClienteHttpDeTeste((req) async => _respostaTexto(_corpoVazio)),
      );

      final sugestoes = await service.search('texto sem correspondência');

      expect(sugestoes, isEmpty);
    });

    test('envia q, lang=default e limit=5, sem nenhum outro parâmetro de '
        'geolocalização, e um User-Agent próprio', () async {
      http.BaseRequest? capturada;
      final service = PhotonGeocodingService(
        client: _ClienteHttpDeTeste((req) async {
          capturada = req;
          return _respostaTexto(_corpoVazio);
        }),
      );

      await service.search('Araranguá');

      final uri = capturada!.url;
      expect(uri.host, 'photon.komoot.io');
      expect(uri.scheme, 'https');
      expect(
        uri.queryParameters,
        {'q': 'Araranguá', 'lang': 'default', 'limit': '5'},
      );
      // A Photon pública bloqueia o User-Agent padrão do package:http com
      // HTTP 403 (D4 de research.md) — verificado contra a rede real.
      expect(
        capturada!.headers['User-Agent'],
        contains('CorridasPassageiro'),
      );
    });

    test('erro HTTP lança GeocodingFailure', () async {
      final service = PhotonGeocodingService(
        client: _ClienteHttpDeTeste(
          (req) async => _respostaTexto('erro', status: 500),
        ),
      );

      expect(
        () => service.search('Araranguá'),
        throwsA(isA<GeocodingFailure>()),
      );
    });

    test('corpo malformado lança GeocodingFailure', () async {
      final service = PhotonGeocodingService(
        client: _ClienteHttpDeTeste(
          (req) async => _respostaTexto('isso não é JSON'),
        ),
      );

      expect(
        () => service.search('Araranguá'),
        throwsA(isA<GeocodingFailure>()),
      );
    });

    test('item sem properties.name lança GeocodingFailure', () async {
      const corpo = '''
      {"type": "FeatureCollection", "features": [
        {"geometry": {}, "properties": {"osm_type": "R", "osm_id": 1}}
      ]}
      ''';
      final service = PhotonGeocodingService(
        client: _ClienteHttpDeTeste((req) async => _respostaTexto(corpo)),
      );

      expect(
        () => service.search('Araranguá'),
        throwsA(isA<GeocodingFailure>()),
      );
    });

    test('timeout de 5 s lança GeocodingFailure', () async {
      final service = PhotonGeocodingService(
        client: _ClienteHttpDeTeste((req) async {
          await Future<void>.delayed(const Duration(seconds: 6));
          return _respostaTexto(_corpoVazio);
        }),
      );

      expect(
        () => service.search('Araranguá'),
        throwsA(isA<GeocodingFailure>()),
      );
    }, timeout: const Timeout(Duration(seconds: 8)));
  });
}

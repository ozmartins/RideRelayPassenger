import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:open_route_service/open_route_service.dart';
import 'package:passenger/services/route_service.dart';

/// Dublê de `http.Client`: nenhum teste toca rede real (Princípio II
/// aplicado por analogia — mesmo padrão de
/// `test/services/geocoding_service_test.dart`).
class _ClienteHttpDeTeste extends http.BaseClient {
  _ClienteHttpDeTeste(this._respostas);

  final Future<http.StreamedResponse> Function(http.BaseRequest) _respostas;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _respostas(request);
}

http.StreamedResponse _respostaJson(String corpo, {int status = 200}) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(corpo)),
    status,
    headers: {'content-type': 'application/json'},
  );
}

const _origem = LatLng(-28.9298, -49.4753);
const _destino = LatLng(-28.9350, -49.4800);

/// Resposta mínima do endpoint de directions geojson: dois pontos e uma
/// distância de 812,5 m — formato `[longitude, latitude]` (GeoJSON), D1 de
/// `specs/007-rota-ate-destino/research.md`.
const _corpoComRota = '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {"summary": {"distance": 812.5, "duration": 120.0}},
      "geometry": {
        "type": "LineString",
        "coordinates": [[-49.4753, -28.9298], [-49.4800, -28.9350]]
      }
    }
  ]
}
''';

void main() {
  test('devolve RouteResult com pontos, distância, origem e destino', () async {
    final servico = OrsRouteService(
      client: OpenRouteService(
        apiKey: 'chave-de-teste',
        client: _ClienteHttpDeTeste((_) async => _respostaJson(_corpoComRota)),
      ),
    );

    final rota = await servico.route(origin: _origem, destination: _destino);

    expect(rota.distanceMeters, 812.5);
    expect(rota.originUsed, _origem);
    expect(rota.destination, _destino);
    expect(rota.points, [
      const LatLng(-28.9298, -49.4753),
      const LatLng(-28.9350, -49.4800),
    ]);
  });

  test(
    'consulta sempre o perfil driving-car, mesmo sem defaultProfile',
    () async {
      Uri? url;
      final servico = OrsRouteService(
        client: OpenRouteService(
          apiKey: 'chave-de-teste',
          client: _ClienteHttpDeTeste((requisicao) async {
            url = requisicao.url;
            return _respostaJson(_corpoComRota);
          }),
        ),
      );

      await servico.route(origin: _origem, destination: _destino);

      expect(url!.scheme, 'https');
      expect(url!.path, endsWith('/driving-car'));
    },
  );

  test('lança RouteFailure em resposta de erro HTTP', () async {
    final servico = OrsRouteService(
      client: OpenRouteService(
        apiKey: 'chave-de-teste',
        client: _ClienteHttpDeTeste(
          (_) async =>
              _respostaJson('{"error": "limite excedido"}', status: 429),
        ),
      ),
    );

    expect(
      () => servico.route(origin: _origem, destination: _destino),
      throwsA(isA<RouteFailure>()),
    );
  });

  test('lança RouteFailure em resposta malformada', () async {
    final servico = OrsRouteService(
      client: OpenRouteService(
        apiKey: 'chave-de-teste',
        client: _ClienteHttpDeTeste(
          (_) async => _respostaJson('{"features": []}'),
        ),
      ),
    );

    expect(
      () => servico.route(origin: _origem, destination: _destino),
      throwsA(isA<RouteFailure>()),
    );
  });
}

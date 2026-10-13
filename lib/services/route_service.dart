import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:open_route_service/open_route_service.dart';

import '../domain/route_result.dart';
import 'ors_api_key.dart';

/// Cálculo de rota real (rodoviária, não linha reta) entre dois pontos.
///
/// Abstração do projeto (Princípio III): a implementação real consulta a API
/// openrouteservice via o pacote `open_route_service` (decisão D1 de
/// `specs/007-rota-ate-destino/research.md`); os testes usam um dublê,
/// seguindo o mesmo padrão de `GeocodingService`/`LocationService` — nenhum
/// teste automatizado toca rede real.
abstract class RouteService {
  /// Calcula o trajeto rodoviário entre [origin] e [destination].
  ///
  /// Lança em qualquer falha — rede, timeout, chave de API ausente/inválida,
  /// limite de requisições excedido, resposta malformada. Quem chama trata
  /// qualquer exceção como "rota indisponível" (FR-007), sem distinguir
  /// motivos.
  Future<RouteResult> route({
    required LatLng origin,
    required LatLng destination,
  });
}

/// Implementação real: consulta a API openrouteservice
/// (`https://api.openrouteservice.org`) pelo perfil `driving-car`.
///
/// Único tipo do aplicativo, além do teste deste arquivo, que conhece
/// `package:open_route_service` (Princípio III). A chave de API vem do arquivo de
/// configuração `assets/ors_api_key.txt` (`OrsApiKey`).
class OrsRouteService implements RouteService {
  OrsRouteService({String? apiKey, OpenRouteService? client})
    : _client = client ?? _buildClient(apiKey ?? OrsApiKey.value);

  final OpenRouteService _client;

  // O pacote `open_route_service` 1.2.9 envia a chave só como query param
  // `api_key=`, formato que a API atual do openrouteservice.org rejeita com
  // 401 "Authorization field missing" — exige o header `Authorization` (D4
  // de `specs/007-rota-ate-destino/research.md`).
  static OpenRouteService _buildClient(String apiKey) => OpenRouteService(
    apiKey: apiKey,
    defaultProfile: ORSProfile.drivingCar,
    client: _AuthorizingHttpClient(apiKey),
  );

  @override
  Future<RouteResult> route({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final GeoJsonFeatureCollection resposta;
    try {
      // Sempre `driving-car`, mesmo com um `OpenRouteService` injetado sem
      // `defaultProfile` (o pacote assume `foot-walking` nesse caso).
      resposta = await _client.directionsRouteGeoJsonGet(
        profileOverride: ORSProfile.drivingCar,
        startCoordinate: ORSCoordinate(
          latitude: origin.latitude,
          longitude: origin.longitude,
        ),
        endCoordinate: ORSCoordinate(
          latitude: destination.latitude,
          longitude: destination.longitude,
        ),
      );
    } on Object catch (erro) {
      throw RouteFailure(erro);
    }

    try {
      final feature = resposta.features.first;
      final coordenadas = feature.geometry.coordinates.first;
      final resumo = feature.properties['summary'] as Map<String, dynamic>;
      final distancia = (resumo['distance'] as num).toDouble();

      return RouteResult(
        points: [
          for (final coordenada in coordenadas)
            LatLng(coordenada.latitude, coordenada.longitude),
        ],
        distanceMeters: distancia,
        originUsed: origin,
        destination: destination,
      );
    } on Object catch (erro) {
      throw RouteFailure(erro);
    }
  }
}

/// O cálculo de rota falhou — rede indisponível, timeout, chave de API
/// ausente/inválida, limite de requisições excedido ou resposta malformada
/// do serviço (FR-007, User Story 3 de `specs/007-rota-ate-destino/spec.md`).
class RouteFailure implements Exception {
  const RouteFailure(this.cause);
  final Object? cause;

  @override
  String toString() => 'Falha no cálculo de rota: $cause';
}

/// Acrescenta o header `Authorization` a toda requisição — workaround do bug
/// de D4 de `specs/007-rota-ate-destino/research.md`.
class _AuthorizingHttpClient extends http.BaseClient {
  _AuthorizingHttpClient(this._apiKey) : _inner = http.Client();

  final String _apiKey;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = _apiKey;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

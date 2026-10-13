import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/address_suggestion.dart';

/// Busca de endereços a partir de texto livre (Key Entities do `spec.md`).
///
/// Abstração do projeto (Princípio III): a implementação real consulta a
/// instância pública da Photon (decisão D2 de
/// `specs/005-busca-endereco-photon/research.md`); os testes usam um dublê,
/// seguindo o mesmo padrão de `LocationService` — nenhum teste automatizado
/// toca rede real (Princípio II).
abstract class GeocodingService {
  /// Busca endereços correspondentes a [text].
  ///
  /// [text] nunca é vazio quando chamado — a tela só chama depois do mínimo
  /// de caracteres de D3 de `research.md`.
  ///
  /// Retorna a lista de sugestões em caso de sucesso (pode ser vazia — "sem
  /// resultado" não é erro). Lança uma exceção em qualquer falha de rede,
  /// timeout ou resposta malformada, para que quem chama distinga "sem
  /// resultado" (FR-008) de "falha de busca" (FR-009).
  Future<List<AddressSuggestion>> search(String text);
}

/// Implementação real: consulta a instância pública da Photon
/// (`https://photon.komoot.io/api/`).
///
/// Único tipo do aplicativo, além do teste deste arquivo, que conhece
/// `package:http` e o formato de resposta da Photon (Princípio III). Nenhum
/// parâmetro de geolocalização é enviado — a exceção da constituição 2.2.0
/// exige ausência de identificador do usuário na chamada (D2 de
/// `research.md`). Envia um `User-Agent` próprio e usa `lang=default` — a
/// Photon pública não suporta português nem aceita o `User-Agent` padrão do
/// `package:http` (D4 de `research.md`).
class PhotonGeocodingService implements GeocodingService {
  PhotonGeocodingService({http.Client? client})
    : _client = client ?? http.Client();

  static final _baseUri = Uri.parse('https://photon.komoot.io/api/');
  static const _timeout = Duration(seconds: 5);

  /// A Photon bloqueia com HTTP 403 o `User-Agent` padrão do `package:http`
  /// (`"Dart/<versão> (dart:io)"`), independentemente dos parâmetros —
  /// verificado em 2026-09-18 (D4 de `research.md`). Um `User-Agent` que
  /// identifique o aplicativo evita o bloqueio.
  static const _userAgent =
      'CaronasPassageiro/1.0 (br.ufsc.tcc.caronas.passenger; academic '
      'prototype, UFSC)';

  final http.Client _client;

  @override
  Future<List<AddressSuggestion>> search(String text) async {
    // 'pt' não é suportado pela Photon pública — só default/de/en/fr
    // (verificado em 2026-09-18, D4 de `research.md`); 'default' devolve o
    // nome local do lugar tal como está no OpenStreetMap.
    final uri = _baseUri.replace(
      queryParameters: {'q': text, 'lang': 'default', 'limit': '5'},
    );

    final http.Response resposta;
    try {
      resposta = await _client
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(_timeout);
    } on Object catch (erro) {
      throw GeocodingFailure(erro);
    }

    if (resposta.statusCode != 200) {
      throw GeocodingFailure(
        'A Photon respondeu com status ${resposta.statusCode}',
      );
    }

    try {
      final corpo = jsonDecode(resposta.body) as Map<String, dynamic>;
      final features = corpo['features'] as List<dynamic>;
      return features
          .map((f) => _paraSugestao(f as Map<String, dynamic>))
          .toList();
    } on Object catch (erro) {
      throw GeocodingFailure(erro);
    }
  }

  static AddressSuggestion _paraSugestao(Map<String, dynamic> feature) {
    final propriedades = feature['properties'] as Map<String, dynamic>;

    final osmType = propriedades['osm_type'] as String;
    final osmId = propriedades['osm_id'];
    final id = '$osmType$osmId';

    // GeoJSON usa a ordem [longitude, latitude] — invertida em relação ao
    // par usual "lat, lon" (D4 de `specs/006-solicitar-corrida/research.md`).
    final geometria = feature['geometry'] as Map<String, dynamic>;
    final coordenadas = geometria['coordinates'] as List<dynamic>;
    final longitude = (coordenadas[0] as num).toDouble();
    final latitude = (coordenadas[1] as num).toDouble();

    final nome = propriedades['name'] as String;

    final partes = <String>[nome];

    final rua = propriedades['street'] as String?;
    final numero = propriedades['housenumber'] as String?;
    if (rua != null) {
      partes.add(numero != null ? '$rua, $numero' : rua);
    }

    final cidade = (propriedades['city'] ?? propriedades['county']) as String?;
    if (cidade != null) partes.add(cidade);

    final estado = propriedades['state'] as String?;
    if (estado != null) partes.add(estado);

    final pais = propriedades['country'] as String?;
    if (pais != null) partes.add(pais);

    return AddressSuggestion(
      id: id,
      displayText: partes.join(', '),
      latitude: latitude,
      longitude: longitude,
    );
  }
}

/// A busca de endereço falhou — rede indisponível, timeout ou resposta
/// malformada da Photon (FR-009).
class GeocodingFailure implements Exception {
  const GeocodingFailure(this.cause);
  final Object? cause;

  @override
  String toString() => 'Falha na busca de endereço: $cause';
}

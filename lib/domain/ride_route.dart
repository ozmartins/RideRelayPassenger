import 'dart:convert';

import 'package:latlong2/latlong.dart';

import 'nostr_event.dart';

/// Trajeto da corrida enviado pelo motorista, lido do `content` de um
/// `kind: 20011` (emenda 13 do contrato) já verificado e deduplicado pelo
/// `EventFeed` (feature 018, `data-model.md`).
///
/// Existe só em memória, durante a corrida — nunca persistida (FR-007).
class RideRoute {
  RideRoute._({required List<LatLng> points, required this.reportedAt})
    : points = List.unmodifiable(points);

  /// Menor e maior número de pontos aceitos (contrato, emenda 13).
  static const int minPoints = 2;
  static const int maxPoints = 1000;

  /// Pontos do trajeto, na ordem de percurso, da posição do motorista ao
  /// destino. Lista não modificável.
  final List<LatLng> points;

  /// Instante **declarado pelo autor** (`created_at`). Serve só para uma rota
  /// antiga não sobrescrever uma mais nova (D8 de `research.md` da feature 017
  /// do motorista); não é decisão de segurança.
  final DateTime reportedAt;

  /// Decodifica um [NostrEvent] de `kind: 20011`.
  ///
  /// Lança [FormatException] se `content` não for um objeto JSON com `points`
  /// — lista de 2 a 1000 pares `[lat, lon]` numéricos, finitos e dentro de
  /// faixa. Quem chama descarta a rota sem alterar o traçado (regra 3 de
  /// recepção: `content` é dado, nunca instrução).
  factory RideRoute.fromNostrEvent(NostrEvent event) {
    try {
      final content = jsonDecode(event.content) as Map<String, dynamic>;
      final bruto = content['points'] as List<dynamic>;
      if (bruto.length < minPoints || bruto.length > maxPoints) {
        throw FormatException(
          'quantidade de pontos fora de faixa: '
          '${bruto.length}',
        );
      }
      final pontos = <LatLng>[];
      for (final item in bruto) {
        final par = item as List<dynamic>;
        if (par.length != 2) {
          throw FormatException('ponto não é um par [lat, lon]: $par');
        }
        final lat = (par[0] as num).toDouble();
        final lon = (par[1] as num).toDouble();
        if (!lat.isFinite || lat < -90 || lat > 90) {
          throw FormatException('lat fora de faixa: $lat');
        }
        if (!lon.isFinite || lon < -180 || lon > 180) {
          throw FormatException('lon fora de faixa: $lon');
        }
        pontos.add(LatLng(lat, lon));
      }
      return RideRoute._(points: pontos, reportedAt: event.createdAt);
    } on Object catch (erro) {
      throw FormatException('Rota da corrida malformada: $erro');
    }
  }

  /// Verdadeiro se esta rota deve substituir [other]: não há outra ou o
  /// instante declarado é estritamente posterior.
  bool isNewerThan(RideRoute? other) =>
      other == null || reportedAt.isAfter(other.reportedAt);

  @override
  String toString() => 'RideRoute(${points.length} pontos, $reportedAt)';
}

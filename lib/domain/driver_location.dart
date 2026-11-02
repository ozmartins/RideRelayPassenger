import 'dart:convert';

import 'nostr_event.dart';

/// Posição do motorista da corrida aceita, lida do `content` de um
/// `kind: 20005` (emenda 08 do contrato) já verificado e deduplicado pelo
/// `EventFeed` (feature 016, `data-model.md`).
///
/// Existe só em memória, durante a corrida — nunca persistida nem reenviada
/// (FR-009).
class DriverLocation {
  const DriverLocation({
    required this.latitude,
    required this.longitude,
    required this.reportedAt,
  });

  /// Latitude em graus decimais, finita, de −90 a 90.
  final double latitude;

  /// Longitude em graus decimais, finita, de −180 a 180.
  final double longitude;

  /// Instante **declarado pelo autor** (`created_at`). Serve só para um
  /// ponto antigo não sobrescrever um mais novo (D4 de `research.md`); não
  /// é decisão de segurança.
  final DateTime reportedAt;

  /// Decodifica um [NostrEvent] de `kind: 20005`.
  ///
  /// Lança [FormatException] se `content` não for um objeto JSON com `lat` e
  /// `lon` numéricos, finitos e dentro de faixa — quem chama descarta o
  /// ponto sem alterar o marcador (regra 3 de recepção: `content` é dado,
  /// nunca instrução).
  factory DriverLocation.fromNostrEvent(NostrEvent event) {
    try {
      final content = jsonDecode(event.content) as Map<String, dynamic>;
      final lat = (content['lat'] as num).toDouble();
      final lon = (content['lon'] as num).toDouble();
      if (!lat.isFinite || lat < -90 || lat > 90) {
        throw FormatException('lat fora de faixa: $lat');
      }
      if (!lon.isFinite || lon < -180 || lon > 180) {
        throw FormatException('lon fora de faixa: $lon');
      }
      return DriverLocation(
        latitude: lat,
        longitude: lon,
        reportedAt: event.createdAt,
      );
    } on Object catch (erro) {
      throw FormatException('Localização do motorista malformada: $erro');
    }
  }

  /// Verdadeiro se esta posição deve substituir [other]: não há outra ou o
  /// instante declarado é estritamente posterior (FR-008).
  bool isNewerThan(DriverLocation? other) =>
      other == null || reportedAt.isAfter(other.reportedAt);

  @override
  String toString() => 'DriverLocation($latitude, $longitude, $reportedAt)';
}

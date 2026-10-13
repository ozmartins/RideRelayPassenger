import 'dart:convert';

import 'nostr_event.dart';

/// Orçamento de carona recebido de um motorista, já verificado e
/// deduplicado pelo `EventFeed` (regras de recepção do contrato) antes de
/// chegar aqui.
///
/// Formato de `content` definido nas emendas 05/06 do contrato
/// (`specs/002-nostr-relay-connection/contracts/nostr-events.md`) —
/// `pricePerKm`, `total`, `driverName`, `carBrand`, `carModel`, `carYear` e
/// `etaMinutes` (opcional). `data-model.md` da feature 008.
class ReceivedQuote {
  const ReceivedQuote({
    required this.quoteId,
    required this.requestId,
    required this.driverPubkey,
    required this.driverName,
    required this.carBrand,
    required this.carModel,
    required this.carYear,
    required this.pricePerKm,
    required this.total,
    this.etaMinutes,
  });

  /// O `id` do evento `kind: 20002` — chave de persistência (FR-002).
  final String quoteId;

  /// Extraído da tag `["e", ...]` do evento — a solicitação respondida.
  final String requestId;

  /// Chave pública de quem publicou o orçamento — destinatário da
  /// aceitação/recusa (FR-008, FR-009).
  final String driverPubkey;

  final String driverName;
  final String carBrand;
  final String carModel;
  final int carYear;
  final double pricePerKm;
  final double total;

  /// Tempo estimado até o ponto de partida, em minutos — `null` quando o
  /// motorista não conseguiu calculá-lo (emenda 06 do contrato; FR-006).
  final int? etaMinutes;

  /// Decodifica um [NostrEvent] de `kind: 20002` para esta entidade.
  ///
  /// Lança [FormatException] se `content` não seguir o formato das emendas
  /// 05/06, ou se a tag `["e", ...]` estiver ausente — quem chama descarta
  /// o evento sem persistir nem exibir (regra 3 de recepção: `content` é
  /// dado, nunca instrução).
  factory ReceivedQuote.fromNostrEvent(NostrEvent event) {
    final requestId = event.referencedEventId;
    if (requestId == null) {
      throw const FormatException(
        'Orçamento sem tag de referência à solicitação',
      );
    }
    try {
      final content = jsonDecode(event.content) as Map<String, dynamic>;
      return ReceivedQuote(
        quoteId: event.id,
        requestId: requestId,
        driverPubkey: event.authorPublicKey,
        driverName: content['driverName'] as String,
        carBrand: content['carBrand'] as String,
        carModel: content['carModel'] as String,
        carYear: (content['carYear'] as num).toInt(),
        pricePerKm: (content['pricePerKm'] as num).toDouble(),
        total: (content['total'] as num).toDouble(),
        etaMinutes: (content['etaMinutes'] as num?)?.toInt(),
      );
    } on Object catch (erro) {
      throw FormatException('Orçamento malformado: $erro');
    }
  }

  @override
  String toString() =>
      'ReceivedQuote($quoteId, $driverName, $carBrand $carModel $carYear, '
      'R\$$total)';
}

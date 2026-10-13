/// Corrida aceita pelo passageiro — existe a partir do toque em "Aceitar"
/// (feature 008); antes disso não há nenhuma instância.
///
/// `data-model.md` da feature 009. As flags `movementNotified`/
/// `meetingConfirmed`/`destinationConfirmed` (acrescentadas nas features 009
/// e 010) foram removidas pela feature 014 — a fase da corrida passou a ser
/// responsabilidade exclusiva de `PassengerRideStatus`, derivável a partir
/// dele (ver `data-model.md` da feature 014).
class AcceptedRide {
  const AcceptedRide({required this.quoteId, required this.driverPubkey});

  /// `id` do evento `kind: 20002` (orçamento) aceito — mesma referência
  /// usada na tag `["e", ...]` dos eventos do motorista relativos a esta
  /// corrida (`kind: 20005`/`20006`/`20007`/`20009`).
  final String quoteId;

  /// Chave pública do motorista escolhido (`ReceivedQuote.driverPubkey` no
  /// momento da aceitação).
  final String driverPubkey;

  @override
  bool operator ==(Object other) =>
      other is AcceptedRide &&
      other.quoteId == quoteId &&
      other.driverPubkey == driverPubkey;

  @override
  int get hashCode => Object.hash(quoteId, driverPubkey);

  @override
  String toString() => 'AcceptedRide($quoteId, driver: $driverPubkey)';
}

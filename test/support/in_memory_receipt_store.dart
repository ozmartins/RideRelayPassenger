import 'package:passenger/domain/receipt.dart';
import 'package:passenger/domain/reputation.dart';
import 'package:passenger/services/receipt_store.dart';

/// Dublê em memória de `ReceiptStore`: reproduz a lógica de decisão da
/// implementação real (`SqfliteReceiptStore`) com as mesmas funções puras
/// (`isIntactReceipt`, `reputationFromReceipts`), sem tocar SQLite.
class InMemoryReceiptStore implements ReceiptStore {
  final Map<String, Receipt> recebidos = {};
  final Map<String, Receipt> emitidos = {};
  final Set<String> pendentes = {}; // guid_corrida dos emitidos sem ack
  final Map<String, Reputation> declaradas = {};
  final List<String> ordemEmitidos = [];

  @override
  Future<bool> saveReceived(Receipt receipt) async {
    if (recebidos.containsKey(receipt.guidCorrida)) return false;
    recebidos[receipt.guidCorrida] = receipt;
    return true;
  }

  @override
  Future<Receipt?> receivedFor(String guidCorrida) async {
    final r = recebidos[guidCorrida];
    return r != null && isIntactReceipt(r) ? r : null;
  }

  @override
  Future<Reputation> myReputation() async =>
      reputationFromReceipts(recebidos.values.where(isIntactReceipt));

  @override
  Future<void> saveIssued(Receipt receipt) async {
    if (emitidos.containsKey(receipt.guidCorrida)) return;
    emitidos[receipt.guidCorrida] = receipt;
    ordemEmitidos.add(receipt.guidCorrida);
    pendentes.add(receipt.guidCorrida);
  }

  @override
  Future<Receipt?> issuedFor(String guidCorrida) async => emitidos[guidCorrida];

  @override
  Future<List<Receipt>> pendingIssued() async => [
    for (final guid in ordemEmitidos)
      if (pendentes.contains(guid)) emitidos[guid]!,
  ];

  @override
  Future<void> markAcked(String idRecibo) async {
    pendentes.removeWhere((guid) => emitidos[guid]!.idRecibo == idRecibo);
  }

  @override
  Future<void> saveDeclared(
    String quoteId,
    String avaliado,
    Reputation reputation,
  ) async => declaradas[quoteId] = reputation;

  @override
  Future<Reputation?> declaredFor(String quoteId) async => declaradas[quoteId];
}

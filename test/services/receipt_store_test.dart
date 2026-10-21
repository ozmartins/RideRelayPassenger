import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/identity.dart';
import 'package:passenger/domain/receipt.dart';
import 'package:passenger/domain/reputation.dart';
import 'package:passenger/services/receipt_signature.dart';
import 'package:passenger/services/receipt_store.dart';

import '../support/event_fixtures.dart';
import '../support/in_memory_receipt_store.dart';

Identity _nova() {
  final par = novoPar();
  return Identity(publicKey: par.public, privateKey: par.private);
}

/// Os testes exercitam o contrato de `ReceiptStore` no dublê em memória e as
/// funções puras que `SqfliteReceiptStore` também usa — nenhum teste toca
/// SQLite real (Princípio III).
void main() {
  final avaliador = _nova();
  final eu = _nova();

  Receipt recibo(int seq, {int? nota = 4, String? guid, Identity? de}) =>
      ReceiptSignature.issue(
        identity: de ?? avaliador,
        guidCorrida: guid ?? seq.toRadixString(16).padLeft(64, 'e'),
        pubkeyAvaliado: eu.publicKey,
        nota: nota,
        criadoEm: 1790000000 + seq,
        seq: seq,
      );

  group('reputationFromReceipts', () {
    test('sem recibos: vazia', () {
      expect(reputationFromReceipts(const []).isEmpty, isTrue);
    });

    test('conta corridas e avaliações, calcula média, seq_proximo e head', () {
      final r0 = recibo(0, nota: 5);
      final r1 = recibo(1, nota: null);
      final r2 = recibo(2, nota: 3);
      final rep = reputationFromReceipts([r1, r0, r2]);
      expect(rep.corridas, 3);
      expect(rep.avaliacoes, 2);
      expect(rep.media, 4.0);
      expect(rep.seqProximo, 3);
      expect(rep.head, r2.idRecibo);
      expect(rep.recibos.map((r) => r.seq), [2, 1, 0]);
    });

    test('apresenta só os $kReputacaoJanela mais recentes por seq', () {
      final todos = [for (var s = 0; s < 8; s++) recibo(s)];
      final rep = reputationFromReceipts(todos.reversed);
      expect(rep.corridas, 8);
      expect(rep.recibos.map((r) => r.seq), [7, 6, 5, 4, 3]);
    });

    test('media é omitida sem avaliações', () {
      final rep = reputationFromReceipts([recibo(0, nota: null)]);
      expect(rep.avaliacoes, 0);
      expect(rep.media, isNull);
    });

    test('ramo (mesmo seq) desempata pelo id_recibo, não por criado_em', () {
      final a = recibo(0, guid: 'a' * 64);
      final b = recibo(0, guid: 'b' * 64);
      final esperado = [a, b]..sort((x, y) => x.idRecibo.compareTo(y.idRecibo));
      final rep = reputationFromReceipts([b, a]);
      expect(rep.head, esperado.first.idRecibo);
      expect(rep.seqProximo, 1);
    });
  });

  group('recibos recebidos', () {
    test('são imutáveis: o segundo da mesma corrida não substitui', () async {
      final loja = InMemoryReceiptStore();
      final primeiro = recibo(0, nota: 5, guid: 'c' * 64);
      final outro = recibo(1, nota: 1, guid: 'c' * 64);
      expect(await loja.saveReceived(primeiro), isTrue);
      expect(await loja.saveReceived(outro), isFalse);
      expect((await loja.receivedFor('c' * 64))!.idRecibo, primeiro.idRecibo);
    });

    test('myReputation recalcula sobre o que foi recebido', () async {
      final loja = InMemoryReceiptStore();
      expect((await loja.myReputation()).isEmpty, isTrue);
      await loja.saveReceived(recibo(0, nota: 5));
      await loja.saveReceived(recibo(1, nota: 3));
      final rep = await loja.myReputation();
      expect(rep.corridas, 2);
      expect(rep.seqProximo, 2);
    });

    test(
      'recibo adulterado no armazenamento some da leitura e da conta',
      () async {
        final loja = InMemoryReceiptStore();
        final bom = recibo(0, nota: 5);
        final ruim = recibo(1, nota: 5);
        await loja.saveReceived(bom);
        await loja.saveReceived(ruim);
        // Altera a nota por fora do app, sem refazer id nem assinatura.
        loja.recebidos[ruim.guidCorrida] = Receipt(
          guidCorrida: ruim.guidCorrida,
          pubkeyAvaliador: ruim.pubkeyAvaliador,
          pubkeyAvaliado: ruim.pubkeyAvaliado,
          nota: 1,
          criadoEm: ruim.criadoEm,
          seq: ruim.seq,
          idRecibo: ruim.idRecibo,
          assinatura: ruim.assinatura,
        );
        expect(await loja.receivedFor(ruim.guidCorrida), isNull);
        final rep = await loja.myReputation();
        expect(rep.corridas, 1);
        expect(rep.head, bom.idRecibo);
      },
    );
  });

  group('recibos emitidos', () {
    test('ficam pendentes até a confirmação e sobrevivem na ordem', () async {
      final loja = InMemoryReceiptStore();
      final a = recibo(0, guid: 'a' * 64);
      final b = recibo(0, guid: 'b' * 64);
      await loja.saveIssued(a);
      await loja.saveIssued(b);
      expect((await loja.pendingIssued()).map((r) => r.idRecibo), [
        a.idRecibo,
        b.idRecibo,
      ]);
      await loja.markAcked(a.idRecibo);
      expect((await loja.pendingIssued()).map((r) => r.idRecibo), [b.idRecibo]);
      expect((await loja.issuedFor('a' * 64))!.idRecibo, a.idRecibo);
    });

    test('gravar de novo a mesma corrida mantém o primeiro', () async {
      final loja = InMemoryReceiptStore();
      final a = recibo(0, guid: 'a' * 64, nota: 5);
      await loja.saveIssued(a);
      await loja.saveIssued(recibo(1, guid: 'a' * 64, nota: 1));
      expect((await loja.issuedFor('a' * 64))!.idRecibo, a.idRecibo);
    });
  });

  group('reputação declarada', () {
    test('guarda e devolve por orçamento; ausente é null', () async {
      final loja = InMemoryReceiptStore();
      expect(await loja.declaredFor('q' * 64), isNull);
      final rep = reputationFromReceipts([recibo(0)]);
      await loja.saveDeclared('q' * 64, avaliador.publicKey, rep);
      expect((await loja.declaredFor('q' * 64))!.corridas, 1);
    });
  });

  test('isIntactReceipt: recibo íntegro passa, id trocado falha', () {
    final r = recibo(0);
    expect(isIntactReceipt(r), isTrue);
    final ruim = Receipt(
      guidCorrida: r.guidCorrida,
      pubkeyAvaliador: r.pubkeyAvaliador,
      pubkeyAvaliado: r.pubkeyAvaliado,
      nota: r.nota,
      criadoEm: r.criadoEm,
      seq: r.seq,
      idRecibo: 'f' * 64,
      assinatura: r.assinatura,
    );
    expect(isIntactReceipt(ruim), isFalse);
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/receipt.dart';

import '../support/receipt_builders.dart';
import '../support/receipt_harness.dart';

void main() {
  late RecibosCenario c;

  setUp(() => c = RecibosCenario());
  tearDown(() => c.fechar());

  /// Recibo do motorista (avaliador) para mim (avaliado).
  Receipt reciboParaMim({
    int seq = 0,
    int? nota = 5,
    int guid = 1,
    String? anterior,
  }) => emitirRecibo(
    de: c.motorista,
    para: c.eu.publicKey,
    seq: seq,
    guid: guidDe(guid),
    nota: nota,
    hashAnterior: anterior,
  );

  Future<void> receber(Map<String, dynamic> evento) async {
    c.entregar(evento);
    await c.assentar();
    await c.service.settled();
  }

  group('recibo válido (1.8)', () {
    test(
      'é gravado, a confirmação 20015 sai cifrada e a reputação é recalculada',
      () async {
        await c.iniciar();
        final recibo = reciboParaMim(nota: 4);

        await receber(c.eventoDeRecibo(recibo));

        expect((await c.store.receivedFor(recibo.guidCorrida))!, recibo);
        final acks = c.publicadosDe(20015);
        expect(acks, hasLength(1));
        final claro = c.decifradoPeloMotorista(acks.single)!;
        expect(jsonDecode(claro), {'id_recibo': recibo.idRecibo});
        expect(acks.single['content'], isNot(contains('id_recibo')));
        final tags = acks.single['tags'] as List;
        expect(tags, anyElement(equals(['e', recibo.guidCorrida])));
        expect(tags, anyElement(equals(['p', c.motorista.publicKey])));

        final rep = await c.store.myReputation();
        expect(rep.corridas, 1);
        expect(rep.avaliacoes, 1);
        expect(rep.media, 4.0);
        expect(rep.seqProximo, 1);
        expect(rep.head, recibo.idRecibo);
      },
    );

    test('recibo sem nota conta como corrida, não como avaliação', () async {
      await c.iniciar();

      await receber(c.eventoDeRecibo(reciboParaMim(nota: null)));

      final rep = await c.store.myReputation();
      expect(rep.corridas, 1);
      expect(rep.avaliacoes, 0);
      expect(rep.media, isNull);
    });

    test(
      'vários recibos: seq_proximo = max(seq)+1 e head do maior seq',
      () async {
        await c.iniciar();
        final r0 = reciboParaMim(seq: 0, guid: 1);
        final r1 = reciboParaMim(seq: 1, guid: 2, anterior: r0.idRecibo);

        // Fora de ordem de chegada: a ordem é por seq.
        await receber(c.eventoDeRecibo(r1));
        await receber(c.eventoDeRecibo(r0));

        final rep = await c.store.myReputation();
        expect(rep.corridas, 2);
        expect(rep.seqProximo, 2);
        expect(rep.head, r1.idRecibo);
        expect(rep.recibos.map((r) => r.seq), [1, 0]);
      },
    );

    test('repetido idêntico: não grava de novo e reenvia o 20015', () async {
      await c.iniciar();
      final recibo = reciboParaMim();

      await receber(c.eventoDeRecibo(recibo));
      await receber(c.eventoDeRecibo(recibo)); // outro evento, mesmo recibo

      expect((await c.store.myReputation()).corridas, 1);
      expect(c.publicadosDe(20015), hasLength(2));
    });

    test(
      'mesma corrida com recibo diferente: ignorado, o primeiro permanece',
      () async {
        await c.iniciar();
        final primeiro = reciboParaMim(nota: 5);
        final outro = reciboParaMim(nota: 1);

        await receber(c.eventoDeRecibo(primeiro));
        await receber(c.eventoDeRecibo(outro));

        expect((await c.store.receivedFor(primeiro.guidCorrida))!.nota, 5);
        expect(c.publicadosDe(20015), hasLength(1));
      },
    );
  });

  group('recibo inválido: ignorado sem efeito e sem 20015', () {
    Future<void> deveIgnorar(Map<String, dynamic> evento) async {
      await c.iniciar();
      await receber(evento);
      expect(await c.store.myReputation().then((r) => r.isEmpty), isTrue);
      expect(c.publicadosDe(20015), isEmpty);
    }

    test('assinatura que não confere', () async {
      await deveIgnorar(
        c.eventoDeRecibo(comAssinaturaTrocada(reciboParaMim())),
      );
    });

    test('id_recibo que não confere com os campos', () async {
      await deveIgnorar(c.eventoDeRecibo(comNotaTrocada(reciboParaMim())));
    });

    test('avaliado que não sou eu', () async {
      final outro = identidadeNova();
      final recibo = emitirRecibo(
        de: c.motorista,
        para: outro.publicKey,
        seq: 0,
        guid: guidDe(1),
      );
      await deveIgnorar(c.eventoDeRecibo(recibo));
    });

    test('avaliador diferente do autor do evento', () async {
      // O recibo é de um terceiro, mas quem publica o evento é o motorista.
      final terceiro = identidadeNova();
      final recibo = emitirRecibo(
        de: terceiro,
        para: c.eu.publicKey,
        seq: 0,
        guid: guidDe(1),
      );
      await deveIgnorar(c.eventoDeRecibo(recibo));
    });

    test('guid_corrida diferente da tag e', () async {
      await deveIgnorar(
        c.eventoDeRecibo(reciboParaMim(), guidNaTag: guidDe(99)),
      );
    });

    test('avaliador igual ao avaliado (autoavaliação)', () async {
      final auto = emitirRecibo(
        de: c.eu,
        para: c.eu.publicKey,
        seq: 0,
        guid: guidDe(1),
      );
      await deveIgnorar(c.eventoDeRecibo(auto, de: c.eu));
    });

    test('nota fora de 1..5 e versão diferente de 1', () async {
      Receipt com({int v = 1, int? nota = 4}) {
        final id = Receipt.computeId(
          guidCorrida: guidDe(1),
          pubkeyAvaliador: c.motorista.publicKey,
          pubkeyAvaliado: c.eu.publicKey,
          nota: nota,
          criadoEm: 1,
          seq: 0,
        );
        return Receipt(
          v: v,
          guidCorrida: guidDe(1),
          pubkeyAvaliador: c.motorista.publicKey,
          pubkeyAvaliado: c.eu.publicKey,
          nota: nota,
          criadoEm: 1,
          seq: 0,
          idRecibo: id,
          assinatura: 'f' * 128,
        );
      }

      await c.iniciar();
      await receber(c.eventoDeRecibo(com(nota: 6)));
      await receber(c.eventoDeRecibo(com(v: 2)));
      expect((await c.store.myReputation()).isEmpty, isTrue);
      expect(c.publicadosDe(20015), isEmpty);
    });

    test('content em claro (sem cifra): descartado', () async {
      await deveIgnorar(c.eventoDeRecibo(reciboParaMim(), emClaro: true));
    });

    test('cifrado a outra chave (tag p alheia): descartado', () async {
      await deveIgnorar(
        c.eventoDeRecibo(
          reciboParaMim(),
          paraNaTag: identidadeNova().publicKey,
        ),
      );
    });
  });
}

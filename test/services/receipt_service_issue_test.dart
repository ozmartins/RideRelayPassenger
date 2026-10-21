import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/accepted_ride.dart';
import 'package:passenger/domain/receipt.dart';
import 'package:passenger/domain/relay.dart';
import 'package:passenger/services/receipt_service.dart';
import 'package:passenger/services/receipt_signature.dart';

import '../support/receipt_builders.dart';
import '../support/receipt_harness.dart';

void main() {
  late RecibosCenario c;
  late AcceptedRide corrida;

  setUp(() {
    c = RecibosCenario(clock: () => DateTime.utc(2026, 10, 20, 12));
    corrida = AcceptedRide(
      quoteId: guidDe(1),
      driverPubkey: c.motorista.publicKey,
    );
  });
  tearDown(() => c.fechar());

  /// Declara a reputação do motorista nesta corrida: [n] recibos encadeados.
  Future<List<Receipt>> motoristaComHistorico(int n) async {
    final cadeia = cadeiaDeRecibos(
      avaliador: identidadeNova(),
      dono: c.motorista,
      tamanho: n,
    );
    await c.store.saveDeclared(
      corrida.quoteId,
      c.motorista.publicKey,
      reputacaoDe(cadeia.reversed.take(5).toList(), seqProximo: n),
    );
    return cadeia;
  }

  group('issueFor: emissão do recibo (1.7)', () {
    test(
      'com nota: assina, encadeia ao head declarado e publica cifrado',
      () async {
        await c.iniciar();
        final cadeia = await motoristaComHistorico(3);

        final r = await c.service.issueFor(corrida, 5);
        await c.assentar();

        expect(r, ReceiptIssueOutcome.issued);
        final emitido = (await c.store.issuedFor(corrida.quoteId))!;
        expect(emitido.nota, 5);
        expect(emitido.seq, 3);
        expect(emitido.hashAnterior, cadeia[2].idRecibo);
        expect(emitido.pubkeyAvaliador, c.eu.publicKey);
        expect(emitido.pubkeyAvaliado, c.motorista.publicKey);
        expect(
          emitido.criadoEm,
          DateTime.utc(2026, 10, 20, 12).millisecondsSinceEpoch ~/ 1000,
        );
        expect(emitido.hasValidId, isTrue);
        expect(ReceiptSignature.verify(emitido), isTrue);

        final publicados = c.publicadosDe(20014);
        expect(publicados, hasLength(1));
        final claro = c.decifradoPeloMotorista(publicados.single)!;
        expect(Receipt.fromJson(jsonDecode(claro)), emitido);
        // Content em claro seria erro: nem o guid nem a assinatura aparecem.
        expect(publicados.single['content'], isNot(contains(emitido.idRecibo)));
        expect(publicados.single['content'], isNot(contains('guid_corrida')));
      },
    );

    test('"pular": o recibo sai sem nota (conta como corrida)', () async {
      await c.iniciar();

      await c.service.issueFor(corrida, null);

      final emitido = (await c.store.issuedFor(corrida.quoteId))!;
      expect(emitido.nota, isNull);
      expect(emitido.toJson().containsKey('nota'), isFalse);
      expect(emitido.hasValidFields, isTrue);
    });

    test('motorista sem histórico (sem reputacao no orçamento): seq 0, sem hash_anterior', () async {
      await c.iniciar();

      final r = await c.service.issueFor(corrida, 4);

      expect(r, ReceiptIssueOutcome.issued);
      final emitido = (await c.store.issuedFor(corrida.quoteId))!;
      expect(emitido.seq, 0);
      expect(emitido.hashAnterior, isNull);
    });

    test(
      'reputação declarada inconsistente: nenhum recibo, nada publicado',
      () async {
        await c.iniciar();
        final cadeia = await motoristaComHistorico(3);
        // head falso: não bate com o recibo seq 2.
        await c.store.saveDeclared(
          corrida.quoteId,
          c.motorista.publicKey,
          reputacaoDe(
            [cadeia[2], cadeia[1], cadeia[0]],
            seqProximo: 3,
            head: cadeia[0].idRecibo,
          ),
        );

        final r = await c.service.issueFor(corrida, 5);
        await c.assentar();

        expect(r, ReceiptIssueOutcome.skippedInconsistent);
        expect(await c.store.issuedFor(corrida.quoteId), isNull);
        expect(c.publicadosDe(20014), isEmpty);
      },
    );

    test(
      'idempotente por corrida: a segunda chamada não emite outro',
      () async {
        await c.iniciar();

        await c.service.issueFor(corrida, 5);
        final r = await c.service.issueFor(corrida, 1);

        expect(r, ReceiptIssueOutcome.alreadyIssued);
        expect((await c.store.issuedFor(corrida.quoteId))!.nota, 5);
      },
    );
  });

  group('pendente e reenvio (1.7, passos 4 e 5)', () {
    test(
      'é gravado como pendente ANTES de publicar (sem relay conectado)',
      () async {
        // Sem iniciar os relays: não há para onde publicar.
        final r = await c.service.issueFor(corrida, 5);

        expect(r, ReceiptIssueOutcome.issued);
        expect(await c.store.pendingIssued(), hasLength(1));
      },
    );

    test('falha ao publicar não lança e o recibo segue pendente', () async {
      await c.iniciar();
      c.transport.conexoes['wss://a.test']!.aceitaPublicacao = false;

      final r = await c.service.issueFor(corrida, 5);
      await c.assentar();

      expect(r, ReceiptIssueOutcome.issued);
      expect(await c.store.pendingIssued(), hasLength(1));
    });

    test(
      'retryPending reenvia enquanto pendente e para após o 20015',
      () async {
        await c.iniciar();
        await c.service.issueFor(corrida, 5);
        await c.assentar();
        expect(c.publicadosDe(20014), hasLength(1));

        await c.service.retryPending();
        await c.assentar();
        expect(c.publicadosDe(20014), hasLength(2));

        final emitido = (await c.store.issuedFor(corrida.quoteId))!;
        c.entregar(
          c.eventoDeConfirmacao(
            guid: corrida.quoteId,
            idRecibo: emitido.idRecibo,
          ),
        );
        await c.assentar();
        await c.service.settled();

        expect(await c.store.pendingIssued(), isEmpty);
        await c.service.retryPending();
        await c.assentar();
        expect(c.publicadosDe(20014), hasLength(2));
      },
    );

    test(
      'sobrevive a reinício: novo serviço sobre a mesma store reenvia',
      () async {
        await c.service.issueFor(corrida, 5); // sem relays: só gravado
        expect(await c.store.pendingIssued(), hasLength(1));

        final c2 = RecibosCenario();
        addTearDown(c2.fechar);
        for (final r in await c.store.pendingIssued()) {
          await c2.store.saveIssued(r);
        }
        await c2.iniciar(); // abrir o app dispara retryPending

        expect(c2.publicadosDe(20014), hasLength(1));
      },
    );

    test('reconexão de relay dispara o reenvio', () async {
      await c.iniciar(['wss://a.test']);
      await c.service.issueFor(corrida, 5);
      await c.assentar();
      expect(c.publicadosDe(20014), hasLength(1));

      await c.relayService.add(const Relay(url: 'wss://b.test'));
      await c.assentar();

      expect(
        c.publicados(url: 'wss://b.test').where((p) => p['kind'] == 20014),
        isNotEmpty,
      );
    });

    test('o relógio de 60 s reenvia com o app aberto', () async {
      final rapido = RecibosCenario(
        retryInterval: const Duration(milliseconds: 40),
      );
      addTearDown(rapido.fechar);
      await rapido.iniciar();
      final ride = AcceptedRide(
        quoteId: guidDe(2),
        driverPubkey: rapido.motorista.publicKey,
      );
      await rapido.service.issueFor(ride, 3);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(rapido.publicadosDe(20014).length, greaterThan(1));
    });
  });

  group('confirmação 20015 (onAckEvent)', () {
    test('de quem não é o avaliado do recibo: ignorada', () async {
      await c.iniciar();
      await c.service.issueFor(corrida, 5);
      final emitido = (await c.store.issuedFor(corrida.quoteId))!;

      c.entregar(
        c.eventoDeConfirmacao(
          guid: corrida.quoteId,
          idRecibo: emitido.idRecibo,
          de: identidadeNova(), // terceiro
        ),
      );
      await c.assentar();
      await c.service.settled();

      expect(await c.store.pendingIssued(), hasLength(1));
    });

    test('com id_recibo diferente: ignorada', () async {
      await c.iniciar();
      await c.service.issueFor(corrida, 5);

      c.entregar(
        c.eventoDeConfirmacao(guid: corrida.quoteId, idRecibo: 'f' * 64),
      );
      await c.assentar();
      await c.service.settled();

      expect(await c.store.pendingIssued(), hasLength(1));
    });

    test('de corrida sem recibo emitido: ignorada sem erro', () async {
      await c.iniciar();

      c.entregar(c.eventoDeConfirmacao(guid: guidDe(77), idRecibo: 'f' * 64));
      await c.assentar();
      await c.service.settled();

      expect(await c.store.pendingIssued(), isEmpty);
    });
  });
}

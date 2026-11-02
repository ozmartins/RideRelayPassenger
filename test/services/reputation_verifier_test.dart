import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/receipt.dart';
import 'package:passenger/domain/reputation.dart';
import 'package:passenger/domain/reputation_view.dart';
import 'package:passenger/services/receipt_signature.dart';
import 'package:passenger/services/reputation_verifier.dart';

import '../support/receipt_builders.dart';
import '../support/receipt_vectors.dart';

void main() {
  group('vetor de contrato compartilhado (um recibo por vez)', () {
    for (final v in vetoresDeRecibo()) {
      test('${v['nome']}', () {
        final recibo = Receipt.fromJson(v['recibo']);
        final reputacao = Reputation(
          corridas: 1,
          avaliacoes: recibo.nota == null ? 0 : 1,
          media: recibo.nota?.toDouble(),
          seqProximo: recibo.seq + 1,
          head: recibo.idRecibo,
          recibos: [recibo],
        );

        final view = ReputationVerifier.verify(
          reputacao,
          v['autor_do_evento'] as String,
        );

        final valido = v['valido'] as bool;
        expect(view.verifiedCount, valido ? 1 : 0, reason: '${v['motivo']}');
        expect(view.invalidDiscarded, valido ? 0 : 1);
      });
    }

    test('as assinaturas dos vetores válidos conferem (verificadas)', () {
      for (final v in vetoresDeRecibo().where((v) => v['valido'] as bool)) {
        expect(
          ReceiptSignature.verify(Receipt.fromJson(v['recibo'])),
          isTrue,
          reason: '${v['nome']}',
        );
      }
    });
  });

  group('reputação com cadeia (regra 1.6)', () {
    final dono = identidadeNova();
    final avaliador = identidadeNova();
    final outro = identidadeNova();
    final c = cadeiaDeRecibos(avaliador: avaliador, dono: dono);
    final tres = [c[2], c[1], c[0]];

    ReputationView verificar(Reputation r, {String? owner}) =>
        ReputationVerifier.verify(r, owner ?? dono.publicKey);

    test('sem histórico: nada a verificar', () {
      final v = verificar(const Reputation.empty());
      expect(v.verifiedCount, 0);
      expect(v.invalidDiscarded, 0);
      expect(v.inconsistent, isFalse);
      expect(v.verifiedAverage, isNull);
      expect(v.hasHistory, isFalse);
    });

    test('válida: três recibos encadeados, head correto', () {
      final v = verificar(reputacaoDe(tres, seqProximo: 3));
      expect(v.verifiedCount, 3);
      expect(v.invalidDiscarded, 0);
      expect(v.gaps, 0);
      expect(v.inconsistent, isFalse);
      expect(v.verifiedRatings, 3);
      expect(v.verifiedAverage, closeTo((3 + 2 + 1) / 3, 1e-9));
    });

    test('recibo sem nota conta como corrida, não como avaliação', () {
      final v = verificar(reputacaoDe([c[4], c[3]], seqProximo: 5));
      expect(v.verifiedCount, 2);
      expect(v.verifiedRatings, 1);
      expect(v.verifiedAverage, c[3].nota!.toDouble());
    });

    test('lacuna de seq: "N recibos não apresentados"', () {
      final v = verificar(reputacaoDe([c[6], c[5], c[3]], seqProximo: 7));
      expect(v.verifiedCount, 3);
      expect(v.gaps, 1);
      expect(v.inconsistent, isFalse);
    });

    test('(a) id adulterado: descartado e contado; vira lacuna', () {
      final v = verificar(
        reputacaoDe([c[2], comNotaTrocada(c[1]), c[0]], seqProximo: 3),
      );
      expect(v.verifiedCount, 2);
      expect(v.invalidDiscarded, 1);
      expect(v.gaps, 1);
      expect(v.inconsistent, isFalse);
    });

    test('(b) assinatura adulterada no head: descartado, head sem recibo', () {
      final v = verificar(
        reputacaoDe(
          [comAssinaturaTrocada(c[2]), c[1], c[0]],
          seqProximo: 3,
          head: c[2].idRecibo,
        ),
      );
      expect(v.verifiedCount, 2);
      expect(v.invalidDiscarded, 1);
      expect(v.inconsistent, isTrue);
    });

    test('(c) recibos de outro avaliado: todos descartados', () {
      final v = verificar(
        reputacaoDe(tres, seqProximo: 3),
        owner: outro.publicKey,
      );
      expect(v.verifiedCount, 0);
      expect(v.invalidDiscarded, 3);
      expect(v.inconsistent, isTrue);
    });

    test('(d) v ≠ 1 e nota fora de 1..5: descartados', () {
      Receipt com({int v = 1, int? nota = 4}) {
        final id = Receipt.computeId(
          guidCorrida: guidDe(50),
          pubkeyAvaliador: avaliador.publicKey,
          pubkeyAvaliado: dono.publicKey,
          nota: nota,
          criadoEm: 1,
          seq: 0,
        );
        return Receipt(
          v: v,
          guidCorrida: guidDe(50),
          pubkeyAvaliador: avaliador.publicKey,
          pubkeyAvaliado: dono.publicKey,
          nota: nota,
          criadoEm: 1,
          seq: 0,
          idRecibo: id,
          assinatura: 'f' * 128,
        );
      }

      for (final r in [com(v: 2), com(nota: 0), com(nota: 6)]) {
        final v = verificar(reputacaoDe([r], seqProximo: 1));
        expect(v.verifiedCount, 0);
        expect(v.invalidDiscarded, 1);
      }
    });

    test('(e) seq não decrescente: o fora de ordem é descartado', () {
      final v = verificar(
        reputacaoDe([c[1], c[2], c[0]], seqProximo: 3, head: c[2].idRecibo),
      );
      expect(v.verifiedCount, 2);
      expect(v.invalidDiscarded, 1);
      expect(v.inconsistent, isTrue);
    });

    test('(f) guid_corrida repetido: o mais antigo é descartado', () {
      final r3 = emitirRecibo(
        de: avaliador,
        para: dono.publicKey,
        seq: 3,
        guid: c[1].guidCorrida,
        hashAnterior: c[2].idRecibo,
      );
      final v = verificar(reputacaoDe([r3, c[2], c[1], c[0]], seqProximo: 4));
      expect(v.verifiedCount, 3);
      expect(v.invalidDiscarded, 1);
      expect(v.gaps, 1);
      expect(v.inconsistent, isFalse);
    });

    test('(g) autoavaliação: descartada', () {
      final auto = emitirRecibo(de: dono, para: dono.publicKey, seq: 0);
      final v = verificar(reputacaoDe([auto], seqProximo: 1));
      expect(v.verifiedCount, 0);
      expect(v.invalidDiscarded, 1);
    });

    test('(h) head divergente: inconsistente', () {
      final v = verificar(
        reputacaoDe(tres, seqProximo: 3, head: c[1].idRecibo),
      );
      expect(v.verifiedCount, 3);
      expect(v.inconsistent, isTrue);
    });

    test(
      '(h) seq_proximo > 0 sem nenhum recibo apresentado: inconsistente',
      () {
        final v = verificar(
          const Reputation(
            corridas: 12,
            avaliacoes: 9,
            media: 4.8,
            seqProximo: 12,
            head: null,
            recibos: [],
          ),
        );
        expect(v.inconsistent, isTrue);
        expect(v.declared.corridas, 12);
      },
    );

    test('(h) head presente com seq_proximo 0: inconsistente', () {
      final v = verificar(
        Reputation(
          corridas: 0,
          avaliacoes: 0,
          seqProximo: 0,
          head: 'c' * 64,
          recibos: const [],
        ),
      );
      expect(v.inconsistent, isTrue);
    });

    test('(i) hash_anterior que não aponta para o seq-1: inconsistente', () {
      final quebrado = emitirRecibo(
        de: avaliador,
        para: dono.publicKey,
        seq: 2,
        hashAnterior: c[0].idRecibo, // devia ser c[1].idRecibo
      );
      final v = verificar(reputacaoDe([quebrado, c[1], c[0]], seqProximo: 3));
      expect(v.verifiedCount, 3);
      expect(v.inconsistent, isTrue);
    });

    test('recibo ilegível (estrutura) entra na contagem de descartados', () {
      final base = reputacaoDe(tres, seqProximo: 3);
      final comIlegivel = Reputation(
        corridas: base.corridas,
        avaliacoes: base.avaliacoes,
        media: base.media,
        seqProximo: base.seqProximo,
        head: base.head,
        recibos: base.recibos,
        ilegiveis: 2,
      );
      final v = verificar(comIlegivel);
      expect(v.verifiedCount, 3);
      expect(v.invalidDiscarded, 2);
    });
  });

  group('verificado separado do declarado', () {
    test('o declarado nunca entra nas contas do verificado', () {
      final dono = identidadeNova();
      final c = cadeiaDeRecibos(avaliador: identidadeNova(), dono: dono);
      final base = reputacaoDe([c[2], c[1], c[0]], seqProximo: 3);
      final mentirosa = Reputation(
        corridas: 999,
        avaliacoes: 999,
        media: 5.0,
        seqProximo: base.seqProximo,
        head: base.head,
        recibos: base.recibos,
      );

      final view = ReputationVerifier.verify(mentirosa, dono.publicKey);

      expect(view.declared.corridas, 999);
      expect(view.declared.media, 5.0);
      expect(view.verifiedCount, 3);
      expect(view.verifiedAverage, isNot(5.0));
    });
  });
}

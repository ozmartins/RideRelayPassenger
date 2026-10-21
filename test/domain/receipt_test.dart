import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/receipt.dart';

import '../support/receipt_builders.dart';
import '../support/receipt_vectors.dart';

void main() {
  final avaliador = identidadeNova();
  final avaliado = identidadeNova();

  Receipt recibo({int seq = 1, int? nota = 5, String? anterior}) =>
      emitirRecibo(
        de: avaliador,
        para: avaliado.publicKey,
        seq: seq,
        nota: nota,
        hashAnterior: anterior,
      );

  Map<String, dynamic> base() => recibo(anterior: 'd' * 64).toJson();

  group('vetor de contrato compartilhado', () {
    for (final v in vetoresDeRecibo()) {
      test('${v['nome']}: forma canônica e id', () {
        final recibo = Receipt.fromJson(v['recibo']);
        if (v['valido'] as bool) {
          expect(recibo.canonical, v['canonico']);
          expect(recibo.hasValidId, isTrue);
        } else {
          // Inválido: ou o id não confere com os campos, ou o motivo é outro
          // (versão, nota, autoavaliação…) e o id é só o do que foi assinado.
          expect(recibo.canonical, isNotEmpty);
        }
        expect(recibo.canonical, startsWith('tcc-recibo-v1|'));
      });
    }

    test('o id_recibo adulterado não confere com os campos', () {
      final v = vetoresDeRecibo().firstWhere(
        (v) => v['nome'] == 'id_recibo_adulterado',
      );
      expect(Receipt.fromJson(v['recibo']).hasValidId, isFalse);
    });
  });

  group('forma canônica e id', () {
    test('usa "-" para nota e hash_anterior ausentes', () {
      final r = recibo(seq: 0, nota: null);
      final partes = r.canonical.split('|');
      expect(partes, hasLength(8));
      expect(partes.first, 'tcc-recibo-v1');
      expect(partes[4], '-');
      expect(partes[7], '-');
    });

    test('escreve nota e hash_anterior quando presentes', () {
      final r = recibo(anterior: 'd' * 64);
      final partes = r.canonical.split('|');
      expect(partes[4], '5');
      expect(partes[7], 'd' * 64);
    });

    test('o id é o SHA-256 em hex minúsculo da forma canônica', () {
      final r = recibo();
      expect(r.idRecibo, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(r.hasValidId, isTrue);
    });

    test('o id muda ao alterar qualquer campo', () {
      final r = recibo(anterior: 'd' * 64);
      String id({
        String? guid,
        String? de,
        String? para,
        int? nota,
        int? criadoEm,
        int? seq,
        String? anterior,
      }) => Receipt.computeId(
        guidCorrida: guid ?? r.guidCorrida,
        pubkeyAvaliador: de ?? r.pubkeyAvaliador,
        pubkeyAvaliado: para ?? r.pubkeyAvaliado,
        nota: nota ?? r.nota,
        criadoEm: criadoEm ?? r.criadoEm,
        seq: seq ?? r.seq,
        hashAnterior: anterior ?? r.hashAnterior,
      );
      final outro = 'f' * 64;
      final ids = <String>{
        r.idRecibo,
        id(guid: outro),
        id(de: outro),
        id(para: outro),
        id(nota: r.nota == 5 ? 1 : 5),
        id(criadoEm: r.criadoEm + 1),
        id(seq: r.seq + 1),
        id(anterior: outro),
      };
      expect(ids, hasLength(8));
    });

    test('hasValidId é falso quando um campo muda sem recalcular o id', () {
      expect(comNotaTrocada(recibo()).hasValidId, isFalse);
    });
  });

  group('hasValidFields (regra d do contrato)', () {
    test('recibo normal é válido', () {
      expect(recibo().hasValidFields, isTrue);
      expect(recibo(nota: null).hasValidFields, isTrue);
    });

    test('v ≠ 1, nota fora de 1..5 e seq negativo não são válidos', () {
      Receipt com({int v = 1, int? nota = 4, int seq = 0}) => Receipt(
        v: v,
        guidCorrida: 'a' * 64,
        pubkeyAvaliador: 'b' * 64,
        pubkeyAvaliado: 'c' * 64,
        nota: nota,
        criadoEm: 1,
        seq: seq,
        idRecibo: 'd' * 64,
        assinatura: 'e' * 128,
      );
      expect(com(v: 2).hasValidFields, isFalse);
      expect(com(nota: 0).hasValidFields, isFalse);
      expect(com(nota: 6).hasValidFields, isFalse);
      expect(com(seq: -1).hasValidFields, isFalse);
      expect(com(nota: 1).hasValidFields, isTrue);
      expect(com(nota: 5).hasValidFields, isTrue);
    });
  });

  group('toJson', () {
    test('ida e volta preserva o recibo', () {
      final r = Receipt.fromJson(base());
      expect(Receipt.fromJson(r.toJson()), r);
    });

    test('omite nota e hash_anterior nulos, nunca os escreve como null', () {
      final json = recibo(seq: 0, nota: null).toJson();
      expect(json.containsKey('nota'), isFalse);
      expect(json.containsKey('hash_anterior'), isFalse);
    });

    test('usa as chaves do contrato', () {
      expect(
        recibo(anterior: 'd' * 64).toJson().keys,
        containsAll([
          'v',
          'guid_corrida',
          'pubkey_avaliador',
          'pubkey_avaliado',
          'nota',
          'criado_em',
          'seq',
          'hash_anterior',
          'id_recibo',
          'assinatura',
        ]),
      );
    });
  });

  group('fromJson: estrutura estrita', () {
    void rejeita(String nome, void Function(Map<String, dynamic>) altera) {
      test(nome, () {
        final json = base();
        altera(json);
        expect(() => Receipt.fromJson(json), throwsFormatException);
      });
    }

    test('não é um objeto', () {
      expect(() => Receipt.fromJson('texto'), throwsFormatException);
      expect(() => Receipt.fromJson(null), throwsFormatException);
    });

    for (final chave in [
      'v',
      'guid_corrida',
      'pubkey_avaliador',
      'pubkey_avaliado',
      'criado_em',
      'seq',
      'id_recibo',
      'assinatura',
    ]) {
      rejeita('campo ausente: $chave', (j) => j.remove(chave));
    }
    rejeita('seq como texto', (j) => j['seq'] = '1');
    rejeita('nota como texto', (j) => j['nota'] = '5');
    rejeita('nota nula', (j) => j['nota'] = null);
    rejeita('hash_anterior nulo', (j) => j['hash_anterior'] = null);
    rejeita('hex curto', (j) => j['guid_corrida'] = 'abc');
    rejeita('hex em maiúsculas', (j) {
      j['pubkey_avaliador'] = (j['pubkey_avaliador'] as String).toUpperCase();
    });
    rejeita('assinatura curta', (j) => j['assinatura'] = 'ab' * 10);

    test('valor fora da regra é lido (quem verifica descarta e conta)', () {
      expect(Receipt.fromJson(base()..['v'] = 2).hasValidFields, isFalse);
      expect(Receipt.fromJson(base()..['nota'] = 6).hasValidFields, isFalse);
    });
  });
}

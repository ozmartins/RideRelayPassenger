import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/reputation.dart';

import '../support/receipt_builders.dart';

void main() {
  final avaliador = identidadeNova();
  final dono = identidadeNova();
  final cadeia = cadeiaDeRecibos(avaliador: avaliador, dono: dono);

  // JSON novo a cada chamada: os testes de rejeição alteram a lista.
  Map<String, dynamic> valida() => jsonDecode(
    jsonEncode(
      reputacaoDe([cadeia[2], cadeia[1], cadeia[0]], seqProximo: 3).toJson(),
    ),
  ) as Map<String, dynamic>;

  test('a janela de apresentação é 5', () {
    expect(kReputacaoJanela, 5);
  });

  test('vazia: sem recibos, sem media e sem head', () {
    const r = Reputation.empty();
    expect(r.isEmpty, isTrue);
    final json = r.toJson();
    expect(json.containsKey('media'), isFalse);
    expect(json.containsKey('head'), isFalse);
    expect(json['seq_proximo'], 0);
    expect(json['recibos'], isEmpty);
  });

  test('ida e volta de uma reputação com recibos', () {
    final r = Reputation.fromJson(valida());
    expect(r.recibos, hasLength(3));
    expect(r.isEmpty, isFalse);
    expect(r.ilegiveis, 0);
    final json = r.toJson();
    expect(json['seq_proximo'], 3);
    expect(Reputation.fromJson(json).recibos.first, r.recibos.first);
  });

  test('media é escrita quando há avaliações', () {
    expect(Reputation.fromJson(valida()).media, isNotNull);
    expect(Reputation.fromJson(valida()).toJson().containsKey('media'), isTrue);
  });

  test('ilegiveis não é serializado', () {
    final json = valida();
    (json['recibos'] as List).add({'v': 1});
    final r = Reputation.fromJson(json);
    expect(r.ilegiveis, 1);
    expect(r.toJson().containsKey('ilegiveis'), isFalse);
  });

  group('resumo: leitura estrita', () {
    void rejeita(String nome, void Function(Map<String, dynamic>) altera) {
      test(nome, () {
        final json = valida();
        altera(json);
        expect(() => Reputation.fromJson(json), throwsFormatException);
      });
    }

    for (final chave in ['corridas', 'avaliacoes', 'seq_proximo', 'recibos']) {
      rejeita('campo ausente: $chave', (j) => j.remove(chave));
    }
    rejeita('corridas negativa', (j) => j['corridas'] = -1);
    rejeita('media como texto', (j) => j['media'] = 'alta');
    rejeita('head inválido', (j) => j['head'] = 'xyz');
    rejeita('recibos não é lista', (j) => j['recibos'] = {});
    test('não é um objeto', () {
      expect(() => Reputation.fromJson(7), throwsFormatException);
    });
  });

  group('recibos da lista: o ruim é descartado e contado, o resto fica', () {
    test('recibo malformado não invalida a reputação', () {
      final json = valida();
      (json['recibos'] as List)[1] = {'v': 1};
      final r = Reputation.fromJson(json);
      expect(r.recibos, hasLength(2));
      expect(r.ilegiveis, 1);
    });

    test('passando da janela, o excedente é descartado e contado', () {
      final json = valida();
      final um = (json['recibos'] as List).first;
      json['recibos'] = List.filled(kReputacaoJanela + 3, um);
      final r = Reputation.fromJson(json);
      expect(r.recibos, hasLength(kReputacaoJanela));
      expect(r.ilegiveis, 3);
    });
  });
}

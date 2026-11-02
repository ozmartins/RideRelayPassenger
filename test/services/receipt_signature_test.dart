import 'package:dart_nostr/dart_nostr.dart' as nostr;
import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/identity.dart';
import 'package:passenger/domain/receipt.dart';
import 'package:passenger/services/receipt_signature.dart';

Identity _nova() {
  final par = nostr.Nostr.instance.services.keys.generateKeyPair();
  return Identity(publicKey: par.public, privateKey: par.private);
}

void main() {
  final avaliador = _nova();
  final avaliado = _nova();
  final guid = 'a' * 64;

  Receipt emitir({int? nota = 4, int seq = 0, String? anterior}) =>
      ReceiptSignature.issue(
        identity: avaliador,
        guidCorrida: guid,
        pubkeyAvaliado: avaliado.publicKey,
        nota: nota,
        criadoEm: 1790000000,
        seq: seq,
        hashAnterior: anterior,
      );

  test('emite um recibo cujo id e assinatura conferem', () {
    final r = emitir();
    expect(r.pubkeyAvaliador, avaliador.publicKey);
    expect(r.pubkeyAvaliado, avaliado.publicKey);
    expect(r.hasValidId, isTrue);
    expect(ReceiptSignature.verify(r), isTrue);
  });

  test('emite sem nota quando o avaliador não avaliou', () {
    final r = emitir(nota: null);
    expect(r.nota, isNull);
    expect(r.toJson().containsKey('nota'), isFalse);
    expect(ReceiptSignature.verify(r), isTrue);
  });

  test('o recibo emitido contém só chaves públicas', () {
    final texto = emitir().toJson().toString();
    expect(texto, isNot(contains(avaliador.privateKey)));
    expect(texto, isNot(contains(avaliado.privateKey)));
  });

  test('assinatura de outro autor não confere', () {
    final r = emitir();
    final falso = Receipt(
      guidCorrida: r.guidCorrida,
      pubkeyAvaliador: avaliado.publicKey, // alega outro autor
      pubkeyAvaliado: r.pubkeyAvaliado,
      nota: r.nota,
      criadoEm: r.criadoEm,
      seq: r.seq,
      idRecibo: r.idRecibo,
      assinatura: r.assinatura,
    );
    expect(ReceiptSignature.verify(falso), isFalse);
  });

  test('id adulterado invalida a assinatura', () {
    final r = emitir();
    final adulterado = Receipt(
      guidCorrida: r.guidCorrida,
      pubkeyAvaliador: r.pubkeyAvaliador,
      pubkeyAvaliado: r.pubkeyAvaliado,
      nota: r.nota,
      criadoEm: r.criadoEm,
      seq: r.seq,
      idRecibo: 'b' * 64,
      assinatura: r.assinatura,
    );
    expect(ReceiptSignature.verify(adulterado), isFalse);
  });

  test('assinatura malformada devolve falso sem lançar', () {
    final r = emitir();
    final ruim = Receipt(
      guidCorrida: r.guidCorrida,
      pubkeyAvaliador: r.pubkeyAvaliador,
      pubkeyAvaliado: r.pubkeyAvaliado,
      nota: r.nota,
      criadoEm: r.criadoEm,
      seq: r.seq,
      idRecibo: r.idRecibo,
      assinatura: 'zz',
    );
    expect(ReceiptSignature.verify(ruim), isFalse);
  });

  test('encadeia: hash_anterior entra no id', () {
    final r0 = emitir();
    final r1 = emitir(seq: 1, anterior: r0.idRecibo);
    expect(r1.hashAnterior, r0.idRecibo);
    expect(r1.idRecibo, isNot(r0.idRecibo));
    expect(ReceiptSignature.verify(r1), isTrue);
  });
}

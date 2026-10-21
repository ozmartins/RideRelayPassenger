import 'package:passenger/domain/identity.dart';
import 'package:passenger/domain/receipt.dart';
import 'package:passenger/domain/reputation.dart';
import 'package:passenger/services/receipt_signature.dart';

import 'event_fixtures.dart';

/// Identidade descartável para os testes.
Identity identidadeNova() {
  final par = novoPar();
  return Identity(publicKey: par.public, privateKey: par.private);
}

/// Identificador de corrida de teste (hex de 64 posições).
String guidDe(int n) => (0xa000 + n).toRadixString(16).padLeft(64, '0');

/// Recibo assinado por [de] para [para].
Receipt emitirRecibo({
  required Identity de,
  required String para,
  required int seq,
  String? guid,
  int? nota = 4,
  String? hashAnterior,
}) => ReceiptSignature.issue(
  identity: de,
  guidCorrida: guid ?? guidDe(seq),
  pubkeyAvaliado: para,
  nota: nota,
  criadoEm: 1790000000 + seq,
  seq: seq,
  hashAnterior: hashAnterior,
);

/// Cadeia encadeada de [tamanho] recibos de [avaliador] para [dono] (seq 0..).
/// A nota do seq 4 é omitida (conta como corrida, não como avaliação).
List<Receipt> cadeiaDeRecibos({
  required Identity avaliador,
  required Identity dono,
  int tamanho = 7,
}) {
  final cadeia = <Receipt>[];
  for (var s = 0; s < tamanho; s++) {
    cadeia.add(
      emitirRecibo(
        de: avaliador,
        para: dono.publicKey,
        seq: s,
        nota: s == 4 ? null : 1 + (s % 5),
        hashAnterior: s == 0 ? null : cadeia[s - 1].idRecibo,
      ),
    );
  }
  return cadeia;
}

/// Reputação declarada com [recibos] (do mais novo ao mais antigo).
Reputation reputacaoDe(
  List<Receipt> recibos, {
  required int seqProximo,
  String? head,
}) {
  final notas = [
    for (final r in recibos)
      if (r.nota != null) r.nota!,
  ];
  return Reputation(
    corridas: seqProximo,
    avaliacoes: notas.length,
    media: notas.isEmpty ? null : notas.reduce((a, b) => a + b) / notas.length,
    seqProximo: seqProximo,
    head: seqProximo == 0
        ? null
        : (head ?? (recibos.isEmpty ? null : recibos.first.idRecibo)),
    recibos: recibos,
  );
}

/// Cópia de [r] com a nota trocada, mantendo id e assinatura (id não confere).
Receipt comNotaTrocada(Receipt r) => Receipt(
  guidCorrida: r.guidCorrida,
  pubkeyAvaliador: r.pubkeyAvaliador,
  pubkeyAvaliado: r.pubkeyAvaliado,
  nota: r.nota == 5 ? 1 : 5,
  criadoEm: r.criadoEm,
  seq: r.seq,
  hashAnterior: r.hashAnterior,
  idRecibo: r.idRecibo,
  assinatura: r.assinatura,
);

/// Cópia de [r] com o último caractere da assinatura trocado.
Receipt comAssinaturaTrocada(Receipt r) {
  final s = r.assinatura;
  final ultimo = s.endsWith('0') ? '1' : '0';
  return Receipt(
    guidCorrida: r.guidCorrida,
    pubkeyAvaliador: r.pubkeyAvaliador,
    pubkeyAvaliado: r.pubkeyAvaliado,
    nota: r.nota,
    criadoEm: r.criadoEm,
    seq: r.seq,
    hashAnterior: r.hashAnterior,
    idRecibo: r.idRecibo,
    assinatura: s.substring(0, s.length - 1) + ultimo,
  );
}

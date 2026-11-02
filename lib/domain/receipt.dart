import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Recibo de avaliação de uma corrida concluída: prova assinada pelo
/// avaliador, entregue ao avaliado (feature 027, emenda 25 do contrato,
/// seção "Reputação por recibos").
///
/// Imutável. Este tipo só descreve e serializa o recibo; verificar `idRecibo`
/// e `assinatura` é papel de `ReputationVerifier` e `ReceiptSignature`. A
/// chave privada nunca entra aqui (Princípio I).
class Receipt {
  const Receipt({
    this.v = 1,
    required this.guidCorrida,
    required this.pubkeyAvaliador,
    required this.pubkeyAvaliado,
    this.nota,
    required this.criadoEm,
    required this.seq,
    this.hashAnterior,
    required this.idRecibo,
    required this.assinatura,
  });

  /// Versão do formato; só `1` existe.
  final int v;

  /// `id` do evento `kind: 20002` aceito (`quoteId`).
  final String guidCorrida;

  /// Autor do recibo.
  final String pubkeyAvaliador;

  /// Quem recebe o recibo.
  final String pubkeyAvaliado;

  /// Nota de 1 a 5; `null` quando o avaliador não avaliou (conta como corrida,
  /// não como avaliação).
  final int? nota;

  /// Epoch em segundos. Só informativo: nunca ordena nada com segurança.
  final int criadoEm;

  /// Posição na cadeia do avaliado.
  final int seq;

  /// `idRecibo` do recibo `seq − 1`; `null` quando `seq` é 0.
  final String? hashAnterior;

  /// SHA-256 em hexadecimal de [canonical].
  final String idRecibo;

  /// Assinatura Schnorr (BIP-340) do avaliador sobre [idRecibo].
  final String assinatura;

  static final _hex64 = RegExp(r'^[0-9a-f]{64}$');
  static final _hex128 = RegExp(r'^[0-9a-f]{128}$');

  /// Forma canônica do contrato (1.2): campos separados por `|`, ausente = `-`.
  static String canonicalOf({
    required String guidCorrida,
    required String pubkeyAvaliador,
    required String pubkeyAvaliado,
    int? nota,
    required int criadoEm,
    required int seq,
    String? hashAnterior,
  }) =>
      'tcc-recibo-v1|$guidCorrida|$pubkeyAvaliador|$pubkeyAvaliado|'
      '${nota ?? '-'}|$criadoEm|$seq|${hashAnterior ?? '-'}';

  /// `id_recibo` = SHA-256 (hex minúsculo) de [canonicalOf] em UTF-8.
  static String computeId({
    required String guidCorrida,
    required String pubkeyAvaliador,
    required String pubkeyAvaliado,
    int? nota,
    required int criadoEm,
    required int seq,
    String? hashAnterior,
  }) => sha256
      .convert(
        utf8.encode(
          canonicalOf(
            guidCorrida: guidCorrida,
            pubkeyAvaliador: pubkeyAvaliador,
            pubkeyAvaliado: pubkeyAvaliado,
            nota: nota,
            criadoEm: criadoEm,
            seq: seq,
            hashAnterior: hashAnterior,
          ),
        ),
      )
      .toString();

  /// Forma canônica deste recibo (sem `assinatura`).
  String get canonical => canonicalOf(
    guidCorrida: guidCorrida,
    pubkeyAvaliador: pubkeyAvaliador,
    pubkeyAvaliado: pubkeyAvaliado,
    nota: nota,
    criadoEm: criadoEm,
    seq: seq,
    hashAnterior: hashAnterior,
  );

  /// Regra (d) do contrato: `v == 1`, `seq ≥ 0` e, se houver, `nota` em 1..5.
  bool get hasValidFields =>
      v == 1 && seq >= 0 && (nota == null || (nota! >= 1 && nota! <= 5));

  /// Verdadeiro se [idRecibo] é o hash de [canonical].
  bool get hasValidId =>
      idRecibo ==
      computeId(
        guidCorrida: guidCorrida,
        pubkeyAvaliador: pubkeyAvaliador,
        pubkeyAvaliado: pubkeyAvaliado,
        nota: nota,
        criadoEm: criadoEm,
        seq: seq,
        hashAnterior: hashAnterior,
      );

  /// JSON do contrato (chaves em português); `nota` e `hash_anterior` são
  /// omitidos quando nulos — nunca `null`.
  Map<String, dynamic> toJson() => {
    'v': v,
    'guid_corrida': guidCorrida,
    'pubkey_avaliador': pubkeyAvaliador,
    'pubkey_avaliado': pubkeyAvaliado,
    if (nota != null) 'nota': nota,
    'criado_em': criadoEm,
    'seq': seq,
    if (hashAnterior != null) 'hash_anterior': hashAnterior,
    'id_recibo': idRecibo,
    'assinatura': assinatura,
  };

  /// Leitura estrita da **estrutura**: lança [FormatException] para campo
  /// ausente, de tipo errado ou hexadecimal de tamanho errado. Não julga o
  /// valor (`v` ≠ 1, `nota` fora de 1..5, `seq` negativo: ver
  /// [hasValidFields]) nem verifica `id_recibo` ou assinatura.
  factory Receipt.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Recibo não é um objeto');
    String hex64(String chave) {
      final valor = json[chave];
      if (valor is! String || !_hex64.hasMatch(valor)) {
        throw FormatException('Recibo com "$chave" inválido');
      }
      return valor;
    }

    int inteiro(String chave) {
      final valor = json[chave];
      if (valor is! int) throw FormatException('Recibo com "$chave" inválido');
      return valor;
    }

    // `v`, `seq` e `nota` fora do permitido NÃO são erro de leitura: o recibo
    // é lido e depois descartado e contado por quem verifica (contrato, 1.6
    // d), sem invalidar a reputação inteira.
    final v = inteiro('v');
    final seq = inteiro('seq');
    final int? nota = json.containsKey('nota') ? inteiro('nota') : null;
    String? hashAnterior;
    if (json.containsKey('hash_anterior')) {
      hashAnterior = hex64('hash_anterior');
    }
    final assinatura = json['assinatura'];
    if (assinatura is! String || !_hex128.hasMatch(assinatura)) {
      throw const FormatException('Recibo com "assinatura" inválida');
    }
    return Receipt(
      v: v,
      guidCorrida: hex64('guid_corrida'),
      pubkeyAvaliador: hex64('pubkey_avaliador'),
      pubkeyAvaliado: hex64('pubkey_avaliado'),
      nota: nota,
      criadoEm: inteiro('criado_em'),
      seq: seq,
      hashAnterior: hashAnterior,
      idRecibo: hex64('id_recibo'),
      assinatura: assinatura,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Receipt &&
      other.idRecibo == idRecibo &&
      other.assinatura == assinatura;

  @override
  int get hashCode => Object.hash(idRecibo, assinatura);

  @override
  String toString() => 'Receipt(${guidCorrida.substring(0, 8)}…, seq: $seq)';
}

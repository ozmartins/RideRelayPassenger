import 'package:dart_nostr/dart_nostr.dart' as nostr;

import '../domain/identity.dart';
import '../domain/receipt.dart';

/// Emissão, assinatura e verificação de assinatura dos recibos (feature 027,
/// seção "Reputação por recibos" do contrato).
///
/// Mesma API de `RideRatingSignature` (`keys.sign/verify`, que já aplica o
/// SHA-256 à mensagem), com a mensagem sendo o `id_recibo` em hexadecimal
/// (D2 de `specs/027-recibos-de-reputacao/research.md`). Funções puras, sem
/// `sqflite`: testáveis diretamente (Princípio II). A chave privada só entra
/// em `keys.sign` e nunca em hash, log ou evento (Princípio I).
class ReceiptSignature {
  const ReceiptSignature._();

  /// Monta, calcula o `id_recibo` e assina o recibo de [identity] (avaliador)
  /// para [pubkeyAvaliado] sobre a corrida [guidCorrida].
  static Receipt issue({
    required Identity identity,
    required String guidCorrida,
    required String pubkeyAvaliado,
    int? nota,
    required int criadoEm,
    required int seq,
    String? hashAnterior,
  }) {
    final id = Receipt.computeId(
      guidCorrida: guidCorrida,
      pubkeyAvaliador: identity.publicKey,
      pubkeyAvaliado: pubkeyAvaliado,
      nota: nota,
      criadoEm: criadoEm,
      seq: seq,
      hashAnterior: hashAnterior,
    );
    return Receipt(
      guidCorrida: guidCorrida,
      pubkeyAvaliador: identity.publicKey,
      pubkeyAvaliado: pubkeyAvaliado,
      nota: nota,
      criadoEm: criadoEm,
      seq: seq,
      hashAnterior: hashAnterior,
      idRecibo: id,
      assinatura: nostr.Nostr.instance.services.keys.sign(
        privateKey: identity.privateKey,
        message: id,
      ),
    );
  }

  /// Verdadeiro somente se a assinatura de [receipt] validar contra o seu
  /// `id_recibo` e a chave `pubkey_avaliador`. Assinatura malformada devolve
  /// falso, não lança. Não confere se o `id_recibo` corresponde aos campos
  /// (isso é [Receipt.hasValidId]).
  static bool verify(Receipt receipt) {
    try {
      return nostr.Nostr.instance.services.keys.verify(
        publicKey: receipt.pubkeyAvaliador,
        message: receipt.idRecibo,
        signature: receipt.assinatura,
      );
    } on Object {
      return false;
    }
  }
}

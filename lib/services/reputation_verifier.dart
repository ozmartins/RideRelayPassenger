import '../domain/receipt.dart';
import '../domain/reputation.dart';
import '../domain/reputation_view.dart';
import 'receipt_signature.dart';

/// Verifica uma [Reputation] recebida (contrato, seção 1.6). Função pura:
/// mesma entrada, mesma saída; sem rede, relógio nem armazenamento.
///
/// Cópia fiel do verificador do motorista; o vetor de contrato compartilhado
/// (`test/fixtures/receipt_vectors.json`) garante que os dois concordam.
class ReputationVerifier {
  const ReputationVerifier._();

  /// [owner] é a chave pública de quem apresenta a reputação (autor do
  /// `20001`/`20002`): todo recibo MUST ter `pubkey_avaliado == owner`.
  static ReputationView verify(Reputation reputation, String owner) {
    final validos = <Receipt>[];
    final guids = <String>{};
    var descartados = reputation.ilegiveis; // ilegíveis também são contados

    for (final r in reputation.recibos) {
      final ok =
          r.hasValidFields && // (d)
          r.pubkeyAvaliado == owner && // (c)
          r.pubkeyAvaliador != r.pubkeyAvaliado && // (g)
          (validos.isEmpty || r.seq < validos.last.seq) && // (e)
          !guids.contains(r.guidCorrida) && // (f)
          r.hasValidId && // (a)
          ReceiptSignature.verify(r); // (b)
      if (!ok) {
        descartados++;
        continue;
      }
      validos.add(r);
      guids.add(r.guidCorrida);
    }

    var inconsistente = false;

    // (h) o head é o id_recibo do recibo seq_proximo−1, presente na lista.
    if (reputation.seqProximo > 0) {
      final esperado = validos
          .where((r) => r.seq == reputation.seqProximo - 1)
          .firstOrNull;
      if (esperado == null || esperado.idRecibo != reputation.head) {
        inconsistente = true;
      }
    } else if (reputation.head != null) {
      inconsistente = true;
    }

    // (i) encadeamento entre recibos consecutivos presentes; lacunas contadas.
    var lacunas = 0;
    for (var i = 0; i + 1 < validos.length; i++) {
      final novo = validos[i];
      final antigo = validos[i + 1];
      final distancia = novo.seq - antigo.seq;
      if (distancia == 1) {
        if (novo.hashAnterior != antigo.idRecibo) inconsistente = true;
      } else {
        lacunas += distancia - 1;
      }
    }

    final notas = [
      for (final r in validos)
        if (r.nota != null) r.nota!,
    ];
    return ReputationView(
      declared: reputation,
      verifiedCount: validos.length,
      verifiedRatings: notas.length,
      verifiedAverage: notas.isEmpty
          ? null
          : notas.reduce((a, b) => a + b) / notas.length,
      invalidDiscarded: descartados,
      gaps: lacunas,
      inconsistent: inconsistente,
    );
  }
}

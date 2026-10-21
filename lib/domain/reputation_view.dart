import 'reputation.dart';

/// Resultado de verificar uma [Reputation] recebida (contrato, 1.6).
///
/// Mantém o **verificado** (calculado só sobre recibos válidos) separado do
/// **declarado** (o que o usuário afirma): nunca há uma nota única que os
/// misture.
class ReputationView {
  const ReputationView({
    required this.declared,
    required this.verifiedCount,
    required this.verifiedRatings,
    this.verifiedAverage,
    required this.invalidDiscarded,
    required this.gaps,
    required this.inconsistent,
  });

  /// Reputação como foi declarada.
  final Reputation declared;

  /// Recibos válidos (corridas verificadas).
  final int verifiedCount;

  /// Recibos válidos que têm nota.
  final int verifiedRatings;

  /// Média das notas dos recibos válidos; `null` sem notas válidas.
  final double? verifiedAverage;

  /// Recibos descartados por falhar a verificação individual.
  final int invalidDiscarded;

  /// Recibos não apresentados (lacunas de `seq` entre os válidos).
  final int gaps;

  /// `head` não confere com o recibo `seq_proximo − 1` presente na lista.
  final bool inconsistent;

  /// Há algo a mostrar: recibos válidos ou corridas declaradas.
  bool get hasHistory => verifiedCount > 0 || declared.corridas > 0;
}

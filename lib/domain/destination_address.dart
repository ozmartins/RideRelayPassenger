/// Endereço de destino efetivamente registrado para a corrida.
///
/// Local ao aparelho. Desde a constituição 2.16.0 é guardado por
/// `DestinationStore` (só texto e coordenadas, só no aparelho, apagado quando o
/// usuário limpa o campo) e restaurado ao reabrir o app; antes, existia apenas
/// em memória (Key Entities do `spec.md` da feature 004).
/// Não depende de [PassengerPosition] estar disponível (FR-010 da feature
/// 004). Desde a feature 006, `latitude`/`longitude` podem ser publicadas em
/// relay como parte de uma solicitação de corrida (FR-006/FR-011 da feature
/// 006) — o texto (`text`) continua só de exibição, nunca publicado.
///
/// Desde a feature 005, `MapScreen` só constrói esta classe a partir de uma
/// `AddressSuggestion` explicitamente selecionada pelo passageiro — nunca a
/// partir do texto bruto digitado no campo de destino (FR-004, FR-005;
/// `data-model.md` da feature 005). Desde a feature 006, `latitude`/
/// `longitude` são copiadas da mesma `AddressSuggestion` (`data-model.md` da
/// feature 006).
class DestinationAddress {
  const DestinationAddress(
    this.text, {
    required this.latitude,
    required this.longitude,
  });

  final String text;

  /// Latitude em graus decimais do destino (feature 006).
  final double latitude;

  /// Longitude em graus decimais do destino (feature 006).
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is DestinationAddress &&
      other.text == text &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(text, latitude, longitude);

  @override
  String toString() => 'DestinationAddress($text, $latitude, $longitude)';
}

/// Forma de pagamento escolhida pelo passageiro para a corrida (Key Entities
/// do `spec.md` da feature 006).
///
/// `cash` vem pré-selecionado por padrão ao abrir a tela do mapa (FR-005,
/// clarificação da sessão 2026-09-20).
enum PaymentMethod {
  cash('Dinheiro', 'dinheiro'),
  pix('PIX', 'pix'),
  card('Cartão', 'cartao');

  const PaymentMethod(this.label, this.contractValue);

  /// Texto exibido ao passageiro no seletor da tela do mapa.
  final String label;

  /// Valor enviado no campo `payment` do `content` do evento Nostr, conforme
  /// `contracts/ride-request-event.md` (D3 de `research.md`).
  final String contractValue;
}

/// Estado único de corrida do passageiro, introduzido pela feature 014.
///
/// Substitui a combinação antes implícita de `_solicitacaoAtivaId`/
/// `_corridaDecidida` (campos soltos de `_MapScreenState`) e das três flags
/// booleanas de `AcceptedRide` — por analogia direta a `DriverRideStatus` do
/// motorista. Persistido em disco (`PassengerRideStateStore`), sobrevive a
/// um reinício do app (FR-009).
enum PassengerRideStatus {
  /// Default. Nenhuma solicitação, orçamento ou corrida em andamento
  /// (FR-002).
  inicial,

  /// Solicitação de corrida enviada (`kind: 20001`); aguardando orçamentos
  /// (FR-003).
  aguardandoOrcamentos,

  /// Orçamento aceito (`kind: 20003` publicado); o motorista ainda não
  /// confirmou que começou a se deslocar (FR-004).
  orcamentoAceito,

  /// Primeira confirmação de que o motorista começou a se deslocar
  /// (`kind: 20005`) já recebida (FR-005).
  motoristaACaminho,

  /// Confirmação de encontro com o motorista (`kind: 20008`) já publicada
  /// (FR-006).
  emCorrida,

  /// Confirmação de destino (`kind: 20010`) já publicada; corrida
  /// aguardando avaliação (FR-007).
  destinoConfirmadoAguardandoAvaliacao,
}

/// Guardas de transição de [PassengerRideStatus] (FR-003 a FR-008, FR-010),
/// por analogia a `DriverRideRules` do motorista.
///
/// Funções puras, testáveis sem I/O. Uma transição chamada fora do estado
/// esperado é ignorada pelo chamador (não aplicada), não uma exceção — ver
/// FR-010 e os Edge Cases do `spec.md`.
abstract final class PassengerRideRules {
  /// A transição para [PassengerRideStatus.aguardandoOrcamentos] só é válida
  /// a partir de [PassengerRideStatus.inicial] (FR-003).
  static bool canRequestRide(PassengerRideStatus current) =>
      current == PassengerRideStatus.inicial;

  /// A transição para [PassengerRideStatus.orcamentoAceito] só é válida a
  /// partir de [PassengerRideStatus.aguardandoOrcamentos] (FR-004) — um
  /// orçamento tardio, chegando depois de a solicitação já ter sido
  /// decidida, é ignorado (FR-010).
  static bool canAcceptQuote(PassengerRideStatus current) =>
      current == PassengerRideStatus.aguardandoOrcamentos;

  /// A transição para [PassengerRideStatus.motoristaACaminho] só é válida a
  /// partir de [PassengerRideStatus.orcamentoAceito] (FR-005).
  static bool canNotifyMovement(PassengerRideStatus current) =>
      current == PassengerRideStatus.orcamentoAceito;

  /// A transição para [PassengerRideStatus.emCorrida] só é válida a
  /// partir de [PassengerRideStatus.motoristaACaminho] (FR-006) — uma
  /// confirmação de encontro fora de ordem é ignorada (FR-010).
  static bool canConfirmMeeting(PassengerRideStatus current) =>
      current == PassengerRideStatus.motoristaACaminho;

  /// A transição para
  /// [PassengerRideStatus.destinoConfirmadoAguardandoAvaliacao] só é válida
  /// a partir de [PassengerRideStatus.emCorrida] (FR-007) — uma
  /// confirmação de destino fora de ordem é ignorada (FR-010).
  static bool canConfirmDestinationArrival(PassengerRideStatus current) =>
      current == PassengerRideStatus.emCorrida;

  /// A rota enviada pelo motorista (`kind: 20011`, emenda 13) só vale — para
  /// ser guardada e traçada — com o passageiro em
  /// [PassengerRideStatus.emCorrida] (FR-002, FR-005 da feature 018). Pelo
  /// mesmo motivo, só nesse estado a rota local da feature 007 deixa de ser
  /// calculada e desenhada (FR-008).
  static bool canShowDriverRoute(PassengerRideStatus current) =>
      current == PassengerRideStatus.emCorrida;

  /// A transição de volta a [PassengerRideStatus.inicial] a partir da
  /// conclusão da avaliação (confirmada ou pulada) só é válida a partir de
  /// [PassengerRideStatus.destinoConfirmadoAguardandoAvaliacao] (FR-008).
  static bool canFinishRating(PassengerRideStatus current) =>
      current == PassengerRideStatus.destinoConfirmadoAguardandoAvaliacao;

  /// A transição de volta a [PassengerRideStatus.inicial] por cancelamento
  /// da solicitação (feature 015) só é válida a partir de
  /// [PassengerRideStatus.aguardandoOrcamentos] (FR-009, FR-011 da feature
  /// 015).
  static bool canCancelRequest(PassengerRideStatus current) =>
      current == PassengerRideStatus.aguardandoOrcamentos;

  /// O aviso de cancelamento do motorista (`kind: 20012`, emenda 14) só vale
  /// nas três fases de corrida aceita e ainda não concluída
  /// ([PassengerRideStatus.orcamentoAceito],
  /// [PassengerRideStatus.motoristaACaminho] e
  /// [PassengerRideStatus.emCorrida]) — resulta sempre em
  /// [PassengerRideStatus.inicial] (FR-002, FR-004 da feature 019). Em
  /// [PassengerRideStatus.destinoConfirmadoAguardandoAvaliacao] a corrida já
  /// foi concluída, e antes de aceitar um orçamento não há corrida a
  /// cancelar.
  static bool canBeCancelledByDriver(PassengerRideStatus current) =>
      current == PassengerRideStatus.orcamentoAceito ||
      current == PassengerRideStatus.motoristaACaminho ||
      current == PassengerRideStatus.emCorrida;

  /// O cancelamento da corrida aceita pelo próprio passageiro (`kind: 20013`,
  /// emenda 19) vale nas mesmas três fases do cancelamento pelo motorista —
  /// [PassengerRideStatus.orcamentoAceito], [PassengerRideStatus.motoristaACaminho]
  /// e [PassengerRideStatus.emCorrida] — e resulta em
  /// [PassengerRideStatus.inicial] (FR-001, FR-003 da feature 023). Antes de
  /// aceitar o cancelamento é o da solicitação ([canCancelRequest]), e em
  /// [PassengerRideStatus.destinoConfirmadoAguardandoAvaliacao] a corrida já
  /// foi concluída.
  static bool canCancelRide(PassengerRideStatus current) =>
      current == PassengerRideStatus.orcamentoAceito ||
      current == PassengerRideStatus.motoristaACaminho ||
      current == PassengerRideStatus.emCorrida;

  /// O aviso de que o motorista não pode atender a corrida (`kind: 20006`,
  /// emenda 16) só vale em [PassengerRideStatus.orcamentoAceito] — fase em
  /// que o motorista ainda não começou a se deslocar para este passageiro.
  /// Resulta em [PassengerRideStatus.inicial] (FR-002, FR-004 da feature
  /// 020). Depois da primeira localização ([PassengerRideStatus.
  /// motoristaACaminho]) o motorista já assumiu a corrida, e um aviso nessa
  /// fase seria incoerente.
  static bool canBeDeclinedByDriver(PassengerRideStatus current) =>
      current == PassengerRideStatus.orcamentoAceito;
}

# Phase 1 — Data Model: Estado único de corrida do passageiro

## `PassengerRideStatus` (enum, domínio puro)

Representa, em cada momento, a fase única e corrente da corrida do passageiro (FR-001) — por
analogia direta a `DriverRideStatus` do motorista (`driver/lib/domain/driver_ride_status.dart`).

| Valor | Significa | Persistido? |
|---|---|---|
| `inicial` | Default. Nenhuma solicitação, orçamento ou corrida em andamento (FR-002). | Sim — é o valor default quando nada foi salvo, mesma convenção de `DriverRideStatus.aguardandoSolicitacao`. |
| `aguardandoOrcamentos` | Solicitação de corrida enviada (`kind: 20001`); aguardando orçamentos (FR-003). | Sim, junto do id da solicitação ativa. |
| `orcamentoAceito` | Orçamento aceito (`kind: 20003` publicado); motorista ainda não confirmou que começou a se deslocar (FR-004). | Sim, junto de `quoteId`/`driverPubkey` (delegado a `AcceptedRide`). |
| `motoristaACaminho` | Primeira confirmação de que o motorista começou a se deslocar (`kind: 20005`) já recebida (FR-005). | Sim. |
| `encontroConfirmado` | Confirmação de encontro com o motorista (`kind: 20008`) já publicada (FR-006). | Sim. |
| `destinoConfirmadoAguardandoAvaliacao` | Confirmação de destino (`kind: 20010`) já publicada; corrida aguardando avaliação (FR-007). | Sim. |

**Identidade/exclusividade**: exatamente um valor corrente por vez (FR-001) — é um enum, a
exclusividade é uma propriedade da linguagem, não uma regra a validar.

**Ciclo de vida**: `inicial` → `aguardandoOrcamentos` → `orcamentoAceito` → `motoristaACaminho` →
`encontroConfirmado` → `destinoConfirmadoAguardandoAvaliacao` → `inicial` (FR-003 a FR-008,
unidirecional, sem atalhos nem retrocessos — ver `PassengerRideRules` abaixo e Edge Cases do
`spec.md` para eventos fora de ordem).

## `PassengerRideRules` (funções puras, domínio)

Guardas de transição — por analogia a `DriverRideRules` do motorista. Cada função recebe o status
corrente e diz se a transição correspondente é válida a partir dele (FR-010: uma transição chamada
fora do estado esperado é ignorada, não aplicada).

```dart
abstract final class PassengerRideRules {
  static bool canRequestRide(PassengerRideStatus current) =>
      current == PassengerRideStatus.inicial;

  static bool canAcceptQuote(PassengerRideStatus current) =>
      current == PassengerRideStatus.aguardandoOrcamentos;

  static bool canNotifyMovement(PassengerRideStatus current) =>
      current == PassengerRideStatus.orcamentoAceito;

  static bool canConfirmMeeting(PassengerRideStatus current) =>
      current == PassengerRideStatus.motoristaACaminho;

  static bool canConfirmDestinationArrival(PassengerRideStatus current) =>
      current == PassengerRideStatus.encontroConfirmado;

  static bool canFinishRating(PassengerRideStatus current) =>
      current == PassengerRideStatus.destinoConfirmadoAguardandoAvaliacao;
}
```

## `AcceptedRide` (alterada)

| Campo | Tipo | Regras |
|---|---|---|
| `quoteId` | `String` | Obrigatório. Sem alteração — mesma referência já usada desde a feature 008. |
| `driverPubkey` | `String` | Obrigatório. Sem alteração. |
| ~~`movementNotified`~~ | ~~`bool`~~ | **Removido** (FR-011) — equivalente a `status.index >= PassengerRideStatus.motoristaACaminho.index`. |
| ~~`meetingConfirmed`~~ | ~~`bool`~~ | **Removido** (FR-011) — equivalente a `status.index >= PassengerRideStatus.encontroConfirmado.index`. |
| ~~`destinationConfirmed`~~ | ~~`bool`~~ | **Removido** (FR-011) — equivalente a `status == PassengerRideStatus.destinoConfirmadoAguardandoAvaliacao`. |

`AcceptedRideStore`/`PreferencesAcceptedRideStore` acompanham a remoção (grava/lê só `quoteId` e
`driverPubkey`); passam a existir apenas a partir de `orcamentoAceito`, nunca antes.

## Persistência (`PassengerRideStateStore` / `PreferencesPassengerRideStateStore`)

Ver D1 de `research.md`. Interface mínima, mesmo padrão de `RideStateStore` do motorista:

```dart
abstract class PassengerRideStateStore {
  /// `(inicial, null)` se nenhum estado foi salvo ainda — mesmo default do
  /// enum quando não há nada persistido.
  Future<(PassengerRideStatus, String?)> load(); // (status, solicitacaoId)

  /// Grava o par status + id da solicitação ativa. `solicitacaoId` só é
  /// relevante (e não-nulo) quando `status == aguardandoOrcamentos` — nos
  /// demais estados além de `inicial`, a identificação da corrida já é
  /// responsabilidade de `AcceptedRide`/`AcceptedRideStore`.
  Future<void> save(PassengerRideStatus status, String? solicitacaoId);
}
```

Formato JSON persistido (chave `passenger_ride_state`):

```json
{ "status": "aguardandoOrcamentos", "solicitacaoId": "<id do kind:20001>" }
```

Quando `status` é `inicial`, `solicitacaoId` é omitido (mesma convenção de omissão condicional já
usada por `PreferencesRideStateStore` do motorista para os campos de `ActiveRide`).

## Fluxo de leitura no boot do app

Ao iniciar, `_MapScreenState` carrega, nesta ordem: `PassengerRideStateStore.load()` (status +
`solicitacaoId` se `aguardandoOrcamentos`) e, se o status for `orcamentoAceito` ou posterior,
`AcceptedRideStore.load()` (para `quoteId`/`driverPubkey`) — mesmo padrão de duas leituras
complementares já usado hoje por `_carregarCorridaAceita`, apenas acrescido da leitura do novo
status.

Se as duas leituras divergirem (status avançado sem `AcceptedRide` correspondente, ou o inverso),
trata-se como estado corrompido: volta a `(inicial, null)`, sem `AcceptedRide` (D5 de
`research.md`).

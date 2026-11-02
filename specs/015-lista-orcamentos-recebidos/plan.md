# Implementation Plan: Tela de orçamentos recebidos e cancelamento da solicitação

**Branch**: `master` (commits diretos, sem branch de feature — Padrão de Commits da constituição) | **Date**: 2026-09-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/015-lista-orcamentos-recebidos/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

O painel de solicitação de corrida (destino, forma de pagamento, "Solicitar corrida") passa a
aparecer só quando `_rideStatus == PassengerRideStatus.inicial`. A modal `RideQuotesModal` é
eliminada e substituída por uma tela dedicada, `ReceivedQuotesScreen` (novo), que `MapScreen` passa
a exibir por completo (sem dim nem overlay sobre o mapa — um retorno antecipado do `build()`,
diferente do padrão das demais modais) enquanto `_rideStatus ==
PassengerRideStatus.aguardandoOrcamentos`. A tela mostra cada `ReceivedQuote` já recebido num item
condensado (mesmos dados de hoje, aceitar incluso) e um botão "Cancelar" fixo embaixo, sempre
visível. Cancelar publica recusa (`kind: 20004`, já existente) para cada orçamento já na lista,
volta `_rideStatus` a `inicial` e persiste — nova guarda `PassengerRideRules.canCancelRequest`, por
analogia às demais guardas da feature 014. Ao entrar (ou restaurar, num reinício) a fase
`aguardandoOrcamentos`, a tela recarrega os orçamentos já persistidos para a solicitação ativa via
`ReceivedQuoteStore.byRequest` (Clarification da sessão 2026-09-28).

## Technical Context

**Language/Version**: Dart 3 / Flutter (mesma versão já fixada no `pubspec.yaml` do projeto)

**Primary Dependencies**: nenhuma dependência nova — reaproveita `ReceivedQuoteStore`, `EventFeed`
(`publishQuoteRejection`, já usado hoje), `PassengerRideStateStore` e `PassengerRideRules` (feature
014).

**Storage**: sem alteração de esquema — `received_quotes.db` (feature 008) já é suficiente para
`ReceivedQuoteStore.byRequest`, usado agora também para restaurar a lista ao entrar/restaurar
`aguardandoOrcamentos`.

**Testing**: `flutter_test`, widget tests em `test/screens/map_screen_test.dart` e um teste de
widget dedicado para `ReceivedQuotesScreen` isolado (`test/screens/received_quotes_screen_test.dart`,
substitui `ride_quotes_modal_test.dart`, removido). Nenhum teste toca rede real nem SQLite real além
do que já é feito hoje.

**Target Platform**: Android (sem mudança)

**Project Type**: mobile-app (Flutter, Android apenas) — mesma estrutura já usada pelo passageiro.

**Performance Goals**: cada orçamento aparece na lista em até 2 s de ser processado (SC-002) — mesma
ordem de grandeza já observada na modal que esta feature substitui.

**Constraints**: nenhum evento Nostr novo — a recusa ao cancelar reaproveita a mesma
`publishQuoteRejection`/`kind: 20004` já usada ao aceitar outro orçamento (FR-010, Assumptions).

**Scale/Scope**: protótipo de avaliação de viabilidade — uma solicitação ativa por vez (mesma
premissa de `PassengerRideStatus`); a lista de orçamentos de uma solicitação não tem limite
declarado (mesma ausência de limite já aceita pela feature 008).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio | Avaliação |
|---|---|
| I. Segredo criptográfico não vaza | PASS por vacuidade. Nenhum material de chave é tocado — a tela e o cancelamento só leem/publicam eventos já assinados pelo fluxo existente. |
| II. Assinatura e verificação nascem com teste | PASS por vacuidade — nenhuma assinatura/verificação nova nesta feature; reaproveita `publishQuoteRejection`, já coberto por teste desde a feature 008. |
| III. Dependência de terceiros exige decisão registrada | PASS. Nenhuma dependência nova ao `pubspec.yaml`. |
| IV. O contrato de evento vem antes do código | PASS por vacuidade. Nenhum evento Nostr novo ou alterado — a recusa ao cancelar reaproveita `kind: 20004`, já definido pela emenda 07 do contrato (feature 008). |
| V. Simplicidade proporcional e rastreabilidade acadêmica | PASS. Reaproveita `ReceivedQuoteStore.byRequest` (já existente, sem uso até agora) em vez de introduzir uma persistência nova para a lista; a guarda `canCancelRequest` segue o mesmo padrão já estabelecido de `PassengerRideRules` em vez de uma checagem ad hoc. |

**Resultado do gate inicial**: PASS — sem violação a justificar em Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/015-lista-orcamentos-recebidos/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

Sem diretório `contracts/`: nenhum evento Nostr novo ou alterado por esta feature.

### Source Code (repository root)

```text
passenger/lib/
├── domain/
│   └── passenger_ride_status.dart  # ALTERADO — PassengerRideRules ganha canCancelRequest
│                                     # (válida só a partir de aguardandoOrcamentos)
└── screens/
    ├── received_quotes_screen.dart  # NOVO — substitui ride_quotes_modal.dart; lista
    │                                  # condensada (ValueListenable<List<ReceivedQuote>>),
    │                                  # botão "Cancelar" fixo embaixo, onAccept/onCancel
    ├── ride_quotes_modal.dart       # REMOVIDO (FR-007)
    └── map_screen.dart              # ALTERADO — painel de solicitação só quando
                                       # _rideStatus == inicial; build() retorna
                                       # ReceivedQuotesScreen sem dim/overlay quando
                                       # _rideStatus == aguardandoOrcamentos (substitui o
                                       # bloco de _modalOrcamentosVisivel); nova
                                       # _cancelarSolicitacao (guarda + recusa a cada
                                       # orçamento listado + volta a inicial); carrega
                                       # ReceivedQuoteStore.byRequest ao entrar/restaurar
                                       # aguardandoOrcamentos

passenger/test/
└── screens/
    ├── received_quotes_screen_test.dart  # NOVO — substitui ride_quotes_modal_test.dart
    ├── ride_quotes_modal_test.dart        # REMOVIDO
    └── map_screen_test.dart               # ALTERADO — cenários de US1/US2/US3 do spec
```

**Structure Decision**: mesma estrutura de três camadas já usada desde a feature 002 do passageiro,
sem novo diretório de topo. Nenhum arquivo de contrato Nostr é tocado.

## Complexity Tracking

*Nenhuma violação de princípio a justificar — tabela omitida (Constitution Check: PASS).*

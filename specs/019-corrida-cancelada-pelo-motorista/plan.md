# Implementation Plan: Corrida cancelada pelo motorista (passageiro)

**Branch**: `master` (commits diretos, sem branch de feature — Padrão de Commits da constituição) | **Date**: 2026-10-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/019-corrida-cancelada-pelo-motorista/spec.md`

## Summary

O passageiro passa a se inscrever no `kind: 20012` ("Corrida cancelada", emenda 14, definida pela
feature `018-cancelar-corrida-motorista` do motorista). `MapScreen` ganha
`_processarCancelamentoDoMotorista`: com assinatura já verificada pelo `EventFeed`, aceita o aviso
só se o autor é o motorista da `AcceptedRide`, a tag `["e", ...]` é o `quoteId` dela, o `id` ainda
não foi tratado e o estado permite (`PassengerRideRules.canBeCancelledByDriver`: `orcamentoAceito`,
`motoristaACaminho`, `emCorrida`). Aceito, **no mesmo instante** persiste o estado `inicial`, zera a
corrida aceita, a posição e a rota do motorista, apaga as outras modais da corrida e abre
`RideCancelledModal` (mensagem + "OK"), renderizada em `Stack` como as demais. "OK" só fecha a
modal. Nenhuma avaliação, nenhum evento publicado, nenhum campo ou armazenamento novo. Sem mudança
no motorista; o contrato é consumido como a emenda 14 o define.

## Technical Context

**Language/Version**: Dart 3 / Flutter (versão já fixada no `pubspec.yaml`)

**Primary Dependencies**: nenhuma nova — `dart_nostr` (chaves/assinatura, só como já usado), `flutter_map`.

**Storage**: sem mudança — `PassengerRideStateStore.save(inicial, null)`; `AcceptedRideStore` não
tem `clear` e não precisa (D3: ao reabrir em `inicial`, a corrida aceita nem é lida; a próxima
aceitação a sobrescreve — mesma situação da conclusão normal).

**Testing**: `flutter_test` com os dublês de `test/support/` e os helpers de
`test/screens/map_screen_test.dart`; nenhum teste toca rede (Princípio II). Regra de estado é função
pura testada diretamente. Nenhum código de assinatura/verificação novo (a verificação é a do
`EventFeed`, já testada).

**Target Platform**: Android (sem mudança)

**Project Type**: mobile-app (Flutter, Android apenas)

**Performance Goals**: efeito local imediato ao receber o evento.

**Constraints**: nenhum evento novo publicado; aviso só vale de quem a corrida aceitou (autor +
`quoteId`); modal segue a Identidade Visual.

**Scale/Scope**: uma corrida aceita por vez.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio / restrição | Avaliação |
|---|---|
| I. Segredo criptográfico não vaza | PASS. Nenhum segredo tocado; nada novo em log nem persistência. |
| II. Assinatura/verificação nascem com teste | PASS. Não há código de assinatura/verificação novo: o evento chega por `EventFeed`, que já recalcula o `id` e verifica a assinatura antes de entregá-lo. A conferência de autor é lógica de estado, testada no mapa (US3). |
| III. Dependência exige decisão registrada | PASS por vacuidade. |
| IV. Contrato antes do código, replicado | **GATE ATIVO (precondição).** A emenda 14 MUST já constar idêntica nas duas cópias (feita pela T001/T002 da feature 018 do motorista). T001 desta feature verifica; se faltar, parar. Esta feature não altera formato algum. |
| V. Simplicidade e medição | PASS. Sem entidade, sem sinalizador, sem `clear` novo no store; reuso de `PassengerRideStateStore`, do padrão de modal em `Stack` e da verificação de autor das features 016/018 (D2, D3). |
| Restrições de Segurança e Privacidade | PASS sem emenda — nada é enviado; só recebe um evento sem conteúdo. |
| Identidade Visual e Design | **APLICA.** A modal nova usa `ModalTematizado` com ação primária `roxo` 48 px, como `DriverMovingModal`. |

Pós-design (Phase 1): inalterado.

## Project Structure

### Documentation (this feature)

```text
specs/019-corrida-cancelada-pelo-motorista/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/README.md   # sem formato novo; consumo da emenda 14 e pré-condição
├── checklists/requirements.md
└── tasks.md              # /speckit-tasks
```

### Source Code

```text
lib/
├── domain/passenger_ride_status.dart   # + PassengerRideRules.canBeCancelledByDriver
├── services/event_feed.dart            # + rideCancelledKind = 20012
├── screens/
│   ├── ride_cancelled_modal.dart       # NOVO: modal informativa (mensagem + "OK")
│   └── map_screen.dart                 # _processarCancelamentoDoMotorista, modal no build, despacho por kind
└── main.dart                           # + rideCancelledKind em acceptedKinds

test/
├── domain/passenger_ride_status_test.dart   # + canBeCancelledByDriver
├── screens/ride_cancelled_modal_test.dart   # NOVO
└── screens/map_screen_test.dart             # + cancelamento nas três fases, limpeza, reinício, inválidos
```

**Structure Decision**: mesma divisão `domain/` + `services/` + `screens/` do restante do app; sem
serviço nem armazenamento novo.

## Complexity Tracking

Sem violações a justificar.

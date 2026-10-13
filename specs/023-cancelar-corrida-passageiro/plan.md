# Implementation Plan: Cancelar corrida (passageiro)

**Branch**: `master` (commits diretos, sem branch de feature — Padrão de Commits da constituição) | **Date**: 2026-10-07 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/023-cancelar-corrida-passageiro/spec.md`

## Summary

Em "orçamento aceito", "motorista a caminho" e "em corrida", o mapa do passageiro passa a mostrar a ação
"Cancelar corrida". Ela abre uma modal de confirmação; confirmar volta o estado a `inicial` persistido, descarta
a corrida aceita, a posição e a rota do motorista e cancela o relógio de silêncio — tudo pelo
`_encerrarCorridaAceita` que as features 019/020/021 já usam — e publica ao motorista o `kind: 20013`
("Corrida cancelada pelo passageiro", emenda 19, já commitada nas duas cópias do contrato), cifrado ao motorista
com o texto `{}`. Não abre avaliação. Falha de publicação é absorvida, sem fila nem reenvio. Nenhuma
persistência nova, nenhuma inscrição nova, nenhuma dependência nova. A contrapartida do motorista é a feature
`020-corrida-cancelada-pelo-passageiro`, já implementada.

## Technical Context

**Language/Version**: Dart 3 / Flutter (versão já fixada no `pubspec.yaml`)

**Primary Dependencies**: nenhuma nova — reaproveita `EventFeed._publish` (cifra NIP-44 da feature 022),
`PassengerRideStateStore`, `ModalTematizado`.

**Storage**: sem mudança — `PassengerRideStateStore.save(inicial, null)` (já chamado por
`_encerrarCorridaAceita`); a `AcceptedRide` fica no `AcceptedRideStore`, ignorada no boot pelo estado `inicial`.

**Testing**: `flutter_test` com os dublês de `test/support/` (`FakeTransport`); nenhum teste toca rede
(Princípio II). A suíte `test/screens/map_screen_test.dart` é lenta (~13 min): rodar em segundo plano.

**Target Platform**: Android (sem mudança)

**Project Type**: mobile-app (Flutter, Android apenas)

**Performance Goals**: efeito local imediato (SC-001, ≤ 1 s); a publicação não bloqueia o efeito local.

**Constraints**: um aviso por corrida (FR-004); nunca em claro (emenda 17); botão e modal seguem a seção
Identidade Visual da constituição.

**Scale/Scope**: uma corrida aceita; um evento por cancelamento.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio / restrição | Avaliação |
|---|---|
| I. Segredo criptográfico não vaza | PASS. Mesma assinatura e cifra dos demais kinds do passageiro; sem log nem persistência de chave nova. |
| II. Assinatura/verificação nascem com teste | PASS (obrigação). O novo `EventFeed.publishRideCancellation` MUST ter teste de assinatura, tags e cifra, no padrão de `publishMeetingConfirmation`. |
| III. Dependência exige decisão registrada | PASS por vacuidade — nenhuma dependência nova. |
| IV. Contrato antes do código, replicado | PASS. A emenda 19 já está nas duas cópias (commit `747f944`), antes do código; conferir por `diff`. |
| V. Simplicidade e medição | PASS. Reaproveita `_encerrarCorridaAceita` e o padrão de modal em `Stack`; sem sinalizador persistido novo nem reenvio (D3). |
| Restrições de Segurança e Privacidade | PASS sem emenda — `20013` cifrado ao motorista (2.11.0), sem dado além dos identificadores de correlação. |
| Identidade Visual e Design | **APLICA.** Botão de ação destrutiva e modal novos MUST seguir a seção: `ModalTematizado`, ação primária `roxo` 48 px; botão no tratamento de alerta (`ColorScheme.error`), como o do motorista (018). |

Pós-design (Phase 1): inalterado.

## Project Structure

### Documentation (this feature)

```text
specs/023-cancelar-corrida-passageiro/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/README.md   # aponta a emenda 19 (já aplicada); nada a inserir
├── checklists/requirements.md
└── tasks.md
```

### Source Code

```text
lib/
├── domain/passenger_ride_status.dart   # + PassengerRideRules.canCancelRide
├── services/event_feed.dart            # + rideCancelledByPassengerKind, publishRideCancellation
└── screens/
    ├── cancel_ride_modal.dart          # NOVO: confirmação (apresentacional)
    └── map_screen.dart                 # + botão, _cancelarCorrida, _publicarCancelamento, Stack da confirmação

test/
├── domain/passenger_ride_status_test.dart    # + canCancelRide (arquivo conforme o existente)
├── event_feed_test.dart                      # + publishRideCancellation
├── screens/cancel_ride_modal_test.dart       # NOVO
└── screens/map_screen_test.dart              # + cancelar nas três fases, desistir, duplo toque, concorrência
```

**Structure Decision**: mesma divisão `domain/` + `services/` + `screens/`; sem serviço novo. `main.dart` não
muda: o passageiro só publica o `20013`, não o consome.

## Complexity Tracking

Sem violações a justificar.

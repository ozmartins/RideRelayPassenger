# Implementation Plan: Expirar a corrida por silêncio do motorista (passageiro)

**Branch**: `master` (commits diretos, sem branch de feature — Padrão de Commits da constituição) | **Date**: 2026-10-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/021-expirar-por-silencio/spec.md`

## Summary

`MapScreen` ganha um temporizador de silêncio (`Timer` de 3 minutos, configurável por construtor para os
testes). Ele é armado ao entrar em `orcamentoAceito` (aceitação) e ao restaurar `orcamentoAceito` ou
`motoristaACaminho` na abertura do app; é rearmado a cada `kind: 20005` novo que passa nas conferências
de autor e de `["e", quoteId]` já usadas pela feature 016 (a validade do `content` não é exigida); e é
cancelado ao sair dessas duas fases por qualquer motivo. Ao disparar, `_expirarPorSilencio` confere que
a corrida ainda está numa das duas fases (`PassengerRideRules.canExpireBySilence`) e chama o
`_encerrarCorridaAceita` da feature 020, abrindo `DriverSilentModal` ("Motorista sem sinal", "OK").
Nada é publicado, nada é persistido além do estado `inicial`, nenhum formato muda.

## Technical Context

**Language/Version**: Dart 3 / Flutter (versão já fixada no `pubspec.yaml`)

**Primary Dependencies**: nenhuma nova (`dart:async` `Timer`).

**Storage**: sem mudança — `PassengerRideStateStore.save(inicial, null)` (via `_encerrarCorridaAceita`);
o instante do último sinal só existe em memória (D3).

**Testing**: `flutter_test`; o tempo é avançado com `tester.pump(Duration)` sobre o relógio falso, com o
prazo reduzido por parâmetro de construtor (D1); nenhum teste toca rede (Princípio II). A regra de
estado é função pura testada diretamente.

**Target Platform**: Android (sem mudança)

**Project Type**: mobile-app (Flutter, Android apenas)

**Performance Goals**: um único `Timer` ativo; rearmar é barato (cancela e recria).

**Constraints**: 3 minutos (constante única); só `orcamentoAceito` e `motoristaACaminho`; nenhum
evento publicado; nenhum campo persistido novo.

**Scale/Scope**: uma corrida aceita por vez.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio / restrição | Avaliação |
|---|---|
| I. Segredo criptográfico não vaza | PASS. Nenhum segredo tocado. |
| II. Assinatura/verificação nascem com teste | PASS. Nenhum código de assinatura/verificação novo; o sinal chega por `EventFeed`, que já verifica. A conferência de autor é lógica de estado, testada no mapa (US3). |
| III. Dependência exige decisão registrada | PASS por vacuidade. |
| IV. Contrato antes do código, replicado | PASS por vacuidade — nenhum formato novo nem alterado; só consome o `kind: 20005` como a emenda 08/12 define. Nenhuma emenda. |
| V. Simplicidade e medição | PASS. Um `Timer` em memória em vez de relógio persistido (D3); reuso de `_encerrarCorridaAceita` e do padrão de modal em `Stack`. O prazo de 3 minutos vem do usuário, não de medição; o risco em "orçamento aceito" está registrado nas Assumptions. |
| Restrições de Segurança e Privacidade | PASS sem emenda — nada é enviado. |
| Identidade Visual e Design | **APLICA.** Modal nova usa `ModalTematizado`, ação primária `roxo` 48 px, como `DriverUnavailableModal`. |

Pós-design (Phase 1): inalterado.

## Project Structure

### Documentation (this feature)

```text
specs/021-expirar-por-silencio/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/README.md   # sem formato novo
├── checklists/requirements.md
└── tasks.md              # /speckit-tasks
```

### Source Code

```text
lib/
├── domain/passenger_ride_status.dart   # + PassengerRideRules.canExpireBySilence
└── screens/
    ├── driver_silent_modal.dart        # NOVO: modal informativa (mensagem + "OK")
    └── map_screen.dart                 # Timer de silêncio, _armarSilencio, _expirarPorSilencio, modal no build

test/
├── domain/passenger_ride_status_test.dart   # + canExpireBySilence
├── screens/driver_silent_modal_test.dart    # NOVO
└── screens/map_screen_test.dart             # + expiração nas duas fases, reinício, cancelamento da contagem, sinais inválidos
```

**Structure Decision**: mesma divisão `domain/` + `screens/` do restante do app; sem serviço novo.
`MapScreen` ganha um parâmetro opcional `driverSilenceTimeout` (padrão 3 minutos).

## Complexity Tracking

Sem violações a justificar.

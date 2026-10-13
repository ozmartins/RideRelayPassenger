# Implementation Plan: Estado único de corrida do passageiro

**Branch**: `master` (commits diretos, sem branch de feature — Padrão de Commits da constituição) | **Date**: 2026-09-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/014-estado-corrida-passageiro/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

O passageiro passa a ter um enum único `PassengerRideStatus`
(`Inicial`, `AguardandoOrcamentos`, `OrcamentoAceito`, `MotoristaACaminho`,
`EncontroConfirmado`, `DestinoConfirmadoAguardandoAvaliacao`), análogo ao
`DriverRideStatus` do motorista, substituindo a combinação hoje implícita de
`_solicitacaoAtivaId`/`_corridaDecidida` (campos soltos de `_MapScreenState`)
e as três flags booleanas de `AcceptedRide`
(`movementNotified`/`meetingConfirmed`/`destinationConfirmed`). O estado é
persistido em disco por um novo `PassengerRideStateStore`, sobre o mesmo
`KeyValueStore` já usado por `AcceptedRideStore` — por analogia direta ao par
`DriverRideStatus`/`RideStateStore` do motorista, adaptado à costura de
injeção do passageiro. `AcceptedRide` perde as três flags e passa a guardar
só `quoteId`/`driverPubkey`, já que a fase da corrida é lida do novo estado.
Nenhum evento Nostr novo, nenhuma alteração ao contrato — reorganização de
estado local (confirmado no spec, Assumptions).

## Technical Context

**Language/Version**: Dart 3 / Flutter (mesma versão já fixada no `pubspec.yaml` do projeto)

**Primary Dependencies**: nenhuma dependência nova — reaproveita `KeyValueStore`, já usado por
`AcceptedRideStore` e `RelayRepository`.

**Storage**: `shared_preferences` via `KeyValueStore`, um único valor JSON, chave
`passenger_ride_state` — mesmo padrão de `PreferencesAcceptedRideStore` e do `RideStateStore` do
motorista (que usa o mesmo mecanismo do lado dele).

**Testing**: `flutter_test`, com dublê de `PassengerRideStateStore` para os testes de
`map_screen_test.dart` e teste de contrato próprio para
`PreferencesPassengerRideStateStore` contra um `KeyValueStore` em memória — mesmo padrão de
`ride_state_store_test.dart` do motorista. Nenhum teste toca rede real nem `shared_preferences` real
(Princípio II).

**Target Platform**: Android (sem mudança)

**Project Type**: mobile-app (Flutter, Android apenas) — mesma estrutura já usada pelo passageiro.

**Performance Goals**: a transição de estado é observável imediatamente após o evento que a causa
(publicação local ou recepção de evento Nostr já decodificado) — sem latência perceptível adicional
além da já existente nos fluxos de aceitação/confirmação (SC-001).

**Constraints**: nenhum evento Nostr novo, nenhuma alteração ao contrato de eventos
(`specs/002-nostr-relay-connection/contracts/nostr-events.md`) — reorganização estritamente local
(FR do spec, Assumptions).

**Scale/Scope**: protótipo de avaliação de viabilidade — uma corrida ativa por vez (mesma premissa
já usada por `AcceptedRide`); o novo estado é mutuamente exclusivo por definição (FR-001).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio | Avaliação |
|---|---|
| I. Segredo criptográfico não vaza | PASS por vacuidade. Nenhum material de chave é tocado — o estado de corrida é um enum e alguns identificadores já públicos (`quoteId`, `driverPubkey`), sem qualquer segredo. |
| II. Assinatura e verificação nascem com teste | PASS por vacuidade — nenhuma assinatura/verificação nesta feature. A regra geral de teste automatizado (Fluxo de Desenvolvimento e Gates) cobre a máquina de estados e o novo store via testes unitários e de contrato, por analogia a `driver_ride_status_test.dart`/`ride_state_store_test.dart`. |
| III. Dependência de terceiros exige decisão registrada | PASS. Nenhuma dependência nova ao `pubspec.yaml` — `KeyValueStore`/`shared_preferences` já registrados (D2 de `specs/002-nostr-relay-connection/research.md`); reaproveitados sem nova decisão. |
| IV. O contrato de evento vem antes do código | PASS por vacuidade. Nenhum evento Nostr novo nem alterado — reorganização de estado estritamente local do passageiro (spec, Assumptions), então não há contrato a definir nem replicar no motorista. |
| V. Simplicidade proporcional e rastreabilidade acadêmica | PASS. Reaproveita diretamente o padrão já estabelecido pelo motorista (`DriverRideStatus`/`DriverRideRules`/`RideStateStore`) em vez de inventar um mecanismo novo; remove as três flags de `AcceptedRide` em vez de mantê-las paralelamente ao novo estado (decisão de clarificação), evitando duas fontes de verdade para a mesma informação. |

**Resultado do gate inicial**: PASS — sem violação a justificar em Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/014-estado-corrida-passageiro/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

Sem diretório `contracts/`: nenhum evento Nostr novo é definido ou alterado por esta feature (mesma
situação da feature irmã `011-avaliar-corrida`).

### Source Code (repository root)

```text
passenger/lib/
├── domain/
│   ├── passenger_ride_status.dart  # NOVO — enum PassengerRideStatus + PassengerRideRules
│   │                                # (guardas de transição puras, por analogia a
│   │                                # DriverRideStatus/DriverRideRules do motorista)
│   └── accepted_ride.dart          # ALTERADO — remove movementNotified/meetingConfirmed/
│                                    # destinationConfirmed; mantém só quoteId/driverPubkey
├── services/
│   ├── passenger_ride_state_store.dart  # NOVO — PassengerRideStateStore (abstrata) +
│   │                                      # PreferencesPassengerRideStateStore sobre
│   │                                      # KeyValueStore, por analogia a RideStateStore
│   │                                      # do motorista e a PreferencesAcceptedRideStore
│   └── accepted_ride_store.dart         # ALTERADO — acompanha a remoção das três flags
│                                          # de AcceptedRide (load/save simplificados)
└── screens/
    └── map_screen.dart   # ALTERADO — substitui _solicitacaoAtivaId/_corridaDecidida e as
                            # três flags de AcceptedRide pelo novo _rideStatus
                            # (PassengerRideStatus), carregado/persistido via
                            # PassengerRideStateStore; cada ponto de transição
                            # (_solicitarCorrida, _aceitarOrcamento,
                            # _processarLocalizacaoMotorista, _confirmarEncontro,
                            # _confirmarDestino, _avaliarCorrida/_pularAvaliacao) passa a
                            # validar com PassengerRideRules e persistir o novo estado

passenger/test/
├── domain/
│   ├── passenger_ride_status_test.dart  # NOVO — por analogia a driver_ride_status_test.dart
│   └── accepted_ride_test.dart           # ALTERADO — remove asserções sobre as flags removidas
├── services/
│   ├── passenger_ride_state_store_test.dart  # NOVO — por analogia a ride_state_store_test.dart
│   └── accepted_ride_store_test.dart          # ALTERADO — acompanha o novo formato persistido
└── screens/
    └── map_screen_test.dart  # ALTERADO — cenários de US1/US2/US3 do spec, verificando o
                                # estado corrente a cada transição em vez das flags antigas
```

**Structure Decision**: mesma estrutura de três camadas já usada desde a feature 002 do passageiro,
sem novo diretório de topo. Nenhum arquivo de contrato Nostr é tocado; a mudança é inteiramente
dentro de `domain/`, `services/` e `screens/` já existentes.

## Complexity Tracking

*Nenhuma violação de princípio a justificar — tabela omitida (Constitution Check: PASS).*

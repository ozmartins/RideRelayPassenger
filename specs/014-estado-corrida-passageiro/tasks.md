# Tasks: Estado único de corrida do passageiro

**Input**: Design documents from `/specs/014-estado-corrida-passageiro/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: incluídas para toda transição de estado, por decisão de projeto (mesmo padrão já seguido
pelas features 009-013) — não exigidas pelo Princípio II (nenhuma assinatura/verificação nesta
feature), mas obrigatórias pelo gate 2 do Fluxo de Desenvolvimento (`flutter test` completo, sem
teste ignorado).

**Organization**: três user stories (US1 P1, US2 P1, US3 P2 — spec.md); tarefas em
Foundational → US1 → US2 → US3 → Polish.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependência entre si)
- Caminhos de arquivo sempre relativos a `Prototipo/passenger/`

---

## Phase 1: Foundational (Blocking Prerequisites)

**Purpose**: enum, guardas de transição e stores que todas as user stories usam — nenhuma delas
pode começar antes desta fase.

- [X] T001 [P] Criar enum `PassengerRideStatus` (6 valores: `inicial`, `aguardandoOrcamentos`,
  `orcamentoAceito`, `motoristaACaminho`, `encontroConfirmado`,
  `destinoConfirmadoAguardandoAvaliacao`) e `PassengerRideRules` (guardas `canRequestRide`,
  `canAcceptQuote`, `canNotifyMovement`, `canConfirmMeeting`, `canConfirmDestinationArrival`,
  `canFinishRating`, por analogia a `DriverRideRules` do motorista) em
  `lib/domain/passenger_ride_status.dart`; testes unitários de cada guarda (permitida/negada) em
  `test/domain/passenger_ride_status_test.dart`
- [X] T002 [P] Remover `movementNotified`/`meetingConfirmed`/`destinationConfirmed` de `AcceptedRide`
  (mantém só `quoteId`/`driverPubkey`) em `lib/domain/accepted_ride.dart`; atualizar
  `test/domain/accepted_ride_test.dart` removendo as asserções sobre os campos removidos
- [X] T003 Criar `PassengerRideStateStore` (abstrata: `load` retorna
  `(PassengerRideStatus, String? solicitacaoId)`; `save`) e
  `PreferencesPassengerRideStateStore` sobre `KeyValueStore` (chave `passenger_ride_state`, default
  `(inicial, null)` quando nada foi salvo, D1 de `research.md`) em
  `lib/services/passenger_ride_state_store.dart`; testes de contrato (load/save, estado corrompido
  volta ao default) em `test/services/passenger_ride_state_store_test.dart` (depende de T001)
- [X] T004 Atualizar `AcceptedRideStore`/`PreferencesAcceptedRideStore` acompanhando a remoção dos
  três campos de `AcceptedRide` (grava/lê só `quoteId`/`driverPubkey`) em
  `lib/services/accepted_ride_store.dart`; atualizar `test/services/accepted_ride_store_test.dart`
  (depende de T002)

**Checkpoint**: fundação pronta — as user stories podem começar.

---

## Phase 2: User Story 1 - Estado inicial ao instalar o app (Priority: P1) 🎯 MVP

**Goal**: na primeira abertura do app, sem nada persistido, o estado é `inicial` e nenhuma
indicação de corrida aparece (FR-002); e uma divergência entre os dois stores de persistência
(estado corrompido) não deixa o app em um estado interno inconsistente (FR-009, D5 de
`research.md`).

**Independent Test**: instanciar `MapScreen` com um `PassengerRideStateStore` que retorna o default
(nada salvo) e verificar que `_rideStatus == PassengerRideStatus.inicial` e nenhuma modal de corrida
é exibida; separadamente, simular uma divergência entre os dois stores e verificar que o app volta
ao default em vez de ficar em um estado inconsistente.

### Tests for User Story 1

- [X] T005 [P] [US1] Widget test: `MapScreen` inicia, sem nada persistido em
  `PassengerRideStateStore`, com `_rideStatus == PassengerRideStatus.inicial` e nenhuma modal de
  solicitação/orçamento/corrida visível (FR-002, US1 cenário 1-2), em
  `test/screens/map_screen_test.dart`
- [X] T006 [P] [US1] Widget test: `PassengerRideStateStore` indica `orcamentoAceito` (ou
  posterior) mas `AcceptedRideStore` retorna `null` no boot (ou o inverso: `AcceptedRide` existe
  mas o status é `inicial`/`aguardandoOrcamentos`) → `MapScreen` trata como corrompido e volta a
  `_rideStatus = inicial`, sem `AcceptedRide` (D5 de `research.md`, FR-009), em
  `test/screens/map_screen_test.dart`

### Implementation for User Story 1

- [X] T007 [US1] `MapScreen` carrega `PassengerRideStateStore.load()` e, se o status carregado for
  `orcamentoAceito` ou posterior, também `AcceptedRideStore.load()`, em `initState` (mesmo ponto de
  `_carregarCorridaAceita`); atribui o resultado a um novo campo `_rideStatus`
  (`PassengerRideStatus`), restaura `_solicitacaoAtivaId` do `solicitacaoId` salvo quando
  `aguardandoOrcamentos`, e reconcilia divergência entre os dois stores voltando a
  `(inicial, null)` quando detectada (D5 de `research.md`) (depende de T003, T004)

**Checkpoint**: US1 completa e testável de forma independente.

---

## Phase 3: User Story 2 - Um único estado ativo por vez durante o ciclo da corrida (Priority: P1)

**Goal**: cada transição do ciclo (solicitar, aceitar orçamento, motorista a caminho, encontro
confirmado, destino confirmado) atualiza `_rideStatus` para exatamente um valor, validada por
`PassengerRideRules`; eventos fora de ordem ou tardios são ignorados sem alterar o estado (FR-003 a
FR-006, FR-010).

**Independent Test**: com duplês de teste para os eventos Nostr recebidos, percorrer o ciclo
solicitar → aceitar → motorista a caminho → encontro confirmado → destino confirmado e verificar,
a cada passo, que `_rideStatus` é exatamente o esperado; em seguida, injetar um evento fora de
ordem/tardio e verificar que `_rideStatus` não muda.

### Tests for User Story 2

- [X] T008 [P] [US2] Widget test: `_solicitarCorrida` bem-sucedido transiciona `_rideStatus` de
  `inicial` para `aguardandoOrcamentos`, persistindo `(aguardandoOrcamentos, solicitacaoId)`
  (FR-003), em `test/screens/map_screen_test.dart`
- [X] T009 [P] [US2] Widget test: `_aceitarOrcamento` transiciona `_rideStatus` de
  `aguardandoOrcamentos` para `orcamentoAceito` (FR-004), em `test/screens/map_screen_test.dart`
- [X] T010 [P] [US2] Widget test: a primeira `_processarLocalizacaoMotorista` (kind: 20005) para a
  corrida aceita transiciona `_rideStatus` de `orcamentoAceito` para `motoristaACaminho` (FR-005),
  em `test/screens/map_screen_test.dart`
- [X] T011 [P] [US2] Widget test: `_confirmarEncontro` bem-sucedido transiciona `_rideStatus` de
  `motoristaACaminho` para `encontroConfirmado` (FR-006), em `test/screens/map_screen_test.dart`
- [X] T012 [P] [US2] Widget test: `_confirmarDestino` bem-sucedido transiciona `_rideStatus` de
  `encontroConfirmado` para `destinoConfirmadoAguardandoAvaliacao` (FR-007), em
  `test/screens/map_screen_test.dart`
- [X] T013 [P] [US2] Widget test: um `kind: 20002` (orçamento) recebido depois que a solicitação já
  foi decidida (`_rideStatus` além de `aguardandoOrcamentos`) não altera `_rideStatus` (FR-010, Edge
  Case 2 do spec.md), em `test/screens/map_screen_test.dart`
- [X] T014 [P] [US2] Widget test: uma confirmação de encontro ou de destino chegando fora de ordem
  (`_rideStatus` diferente do exigido por `PassengerRideRules.canConfirmMeeting`/
  `canConfirmDestinationArrival`) é ignorada, sem alterar `_rideStatus` (FR-010, Edge Case 3 do
  spec.md), em `test/screens/map_screen_test.dart`
- [X] T015 [US2] Teste de contrato: `PassengerRideStateStore` persiste e restaura corretamente cada
  um dos estados intermediários do ciclo (`aguardandoOrcamentos` até
  `destinoConfirmadoAguardandoAvaliacao`), simulando um reinício do app entre duas transições
  (FR-008/FR-009), em `test/services/passenger_ride_state_store_test.dart`

### Implementation for User Story 2

- [X] T016 [US2] `_solicitarCorrida`: validar `PassengerRideRules.canRequestRide(_rideStatus)` antes
  de publicar; em sucesso, atualizar `_rideStatus = aguardandoOrcamentos` e persistir via
  `PassengerRideStateStore.save` (depende de T003, T007)
- [X] T017 [US2] `_aceitarOrcamento`: validar `PassengerRideRules.canAcceptQuote(_rideStatus)`; em
  sucesso, atualizar `_rideStatus = orcamentoAceito`, persistir `(orcamentoAceito, null)` via
  `PassengerRideStateStore` e `quoteId`/`driverPubkey` via `AcceptedRideStore` (depende de T004,
  T016)
- [X] T018 [US2] `_processarLocalizacaoMotorista`: validar
  `PassengerRideRules.canNotifyMovement(_rideStatus)` antes de tratar o evento; descartar
  silenciosamente se a guarda falhar (FR-010); em sucesso, atualizar `_rideStatus =
  motoristaACaminho` e persistir (depende de T017)
- [X] T019 [US2] `_confirmarEncontro`: validar
  `PassengerRideRules.canConfirmMeeting(_rideStatus)`; em sucesso, atualizar `_rideStatus =
  encontroConfirmado` e persistir (depende de T018)
- [X] T020 [US2] `_confirmarDestino`: validar
  `PassengerRideRules.canConfirmDestinationArrival(_rideStatus)`; em sucesso, atualizar
  `_rideStatus = destinoConfirmadoAguardandoAvaliacao` e persistir (depende de T019)
- [X] T021 [US2] `_processarOrcamentoRecebido`/`_processarChegadaMotorista`/
  `_processarChegadaDestino`: acrescentar a mesma guarda de `PassengerRideRules` correspondente
  antes de processar cada evento recebido, descartando silenciosamente quando `_rideStatus` não é o
  esperado (FR-010) (depende de T018, T019, T020)

**Checkpoint**: US1 e US2 completas — ciclo inteiro migrado ao novo estado único, com exclusividade
mútua garantida e eventos fora de ordem ignorados.

---

## Phase 4: User Story 3 - Retorno ao estado inicial após concluir o ciclo (Priority: P2)

**Goal**: ao avaliar ou pular a avaliação a partir de `destinoConfirmadoAguardandoAvaliacao`,
`_rideStatus` volta a `inicial`, liberando uma nova solicitação imediatamente (FR-008, SC-003).

**Independent Test**: a partir de `destinoConfirmadoAguardandoAvaliacao`, chamar `_avaliarCorrida`
(ou `_pularAvaliacao`) e verificar que `_rideStatus` volta a `inicial` e que `_solicitarCorrida`
funciona normalmente em seguida.

### Tests for User Story 3

- [X] T022 [P] [US3] Widget test: `_avaliarCorrida` a partir de
  `destinoConfirmadoAguardandoAvaliacao` transiciona `_rideStatus` para `inicial` (FR-008, US3
  cenário 1), em `test/screens/map_screen_test.dart`
- [X] T023 [P] [US3] Widget test: `_pularAvaliacao` a partir de
  `destinoConfirmadoAguardandoAvaliacao` transiciona `_rideStatus` para `inicial` (FR-008, US3
  cenário 2), em `test/screens/map_screen_test.dart`
- [X] T024 [P] [US3] Widget test: depois do retorno a `inicial`, `_solicitarCorrida` funciona
  normalmente (mesmo comportamento de T008), sem resquício de `AcceptedRide`/estado da corrida
  anterior (SC-003), em `test/screens/map_screen_test.dart`

### Implementation for User Story 3

- [X] T025 [US3] `_avaliarCorrida`: validar `PassengerRideRules.canFinishRating(_rideStatus)`; em
  sucesso (nota persistida ou não), atualizar `_rideStatus = inicial` e persistir (depende de T020)
- [X] T026 [US3] `_pularAvaliacao`: mesma transição de T025, sem persistir nota (depende de T025)

**Checkpoint**: as três user stories completas — ciclo inteiro do passageiro, do `inicial` de volta
ao `inicial`, garantidamente em um único estado por vez.

---

## Phase 5: Polish & Cross-Cutting Concerns

- [X] T027 `flutter analyze` sem apontamentos (gate 1 da constituição) — "No issues found!"
- [X] T028 `flutter test` — suíte completa passando, sem teste ignorado (gate 2 da constituição) —
  265/265 testes
- [ ] T029 Executar os cenários de `quickstart.md`; relatar explicitamente os que não puderam ser
  executados (gate 3 da constituição) — **pendente**: requer dois aparelhos/emuladores com relay em
  comum
- [X] T030 Commit de implementação desta feature (código + testes)
- [X] T031 Atualizar `../../CLAUDE.md` (raiz do repositório) registrando a feature 014 do
  passageiro, em commit próprio, separado do código (Padrão de Commits, item 6)

---

## Dependencies & Execution Order

- **Foundational (Phase 1)**: T003 depende de T001; T004 depende de T002; nenhuma dependência
  externa a outra feature
- **US1 (Phase 2)**: depende do Foundational (T003, T004)
- **US2 (Phase 3)**: depende de US1 (T007) e do Foundational (T003, T004)
- **US3 (Phase 4)**: depende de US2 completa (T020)
- **Polish (Phase 5)**: depende de US1, US2 e US3 completas

### Parallel Opportunities

- T001 e T002 podem começar imediatamente, em paralelo (arquivos diferentes); T003 depende de T001,
  T004 depende de T002
- T005 e T006 (testes de US1) podem ser escritos em paralelo entre si; sua implementação (T007) é
  única e precede logicamente as demais stories
- T008-T014 (testes de US2) podem ser escritos em paralelo entre si
- T022-T024 (testes de US3) podem ser escritos em paralelo entre si

---

## Implementation Strategy

### MVP First (User Story 1)

1. Completar Phase 1 (fundação)
2. Completar Phase 2 (US1) — já garante o requisito explicitamente confirmado (estado "Inicial" na
   instalação) e a robustez contra estado corrompido entre os dois stores (D5)
3. Validar de forma independente pelo `quickstart.md`, cenário 1

### Incremental Delivery

1. Foundational → `PassengerRideStatus`/`PassengerRideRules`/`PassengerRideStateStore` prontos,
   `AcceptedRide` simplificada
2. US1 → estado inicial correto na instalação (MVP mínimo do pedido original), robusto a
   divergência entre stores
3. US2 → ciclo inteiro migrado ao estado único, exclusividade mútua garantida
4. US3 → retorno a `inicial` depois da avaliação, fechando o ciclo

## Notes

- [P] = arquivos diferentes, sem dependência
- Commit separado para: código (T030) e `CLAUDE.md` (T031) — Padrão de Commits, item 6
- Verificar que os testes falham antes de implementar (T005, T006, T008-T015, T022-T024)
- Sem diretório `contracts/`: nenhum evento Nostr novo ou alterado por esta feature
- FR-001 (exclusividade mútua) não tem task dedicada: é garantido por construção, já que
  `PassengerRideStatus` é um único campo enum (achado A1 do `/speckit-analyze`; ver data-model.md)

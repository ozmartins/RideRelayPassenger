# Tasks: Confirmar encontro com o motorista e chegada ao destino

**Input**: Design documents from `/specs/010-confirmar-encontro-destino/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/README.md,
quickstart.md — **e** a feature `012-confirmar-encontro-destino` do motorista, cujo contrato
(emenda 11) esta feature consome/publica contra.

**Tests**: **obrigatórias**, não opcionais (constituição, Princípio II) para
`EventFeed.publishMeetingConfirmation`/`publishDestinationConfirmation` e para as decisões de
exibir (ou não) cada modal a partir de um evento recebido.

**Organization**: duas user stories (ambas P1); tarefas em Foundational → US1 → US2 → Polish. Sem
fase de Setup própria: o contrato já está escrito pela feature irmã do motorista.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependência entre si)
- Caminhos de arquivo sempre relativos a `Prototipo/passenger/`, exceto onde indicado

---

## Phase 1: Foundational (Blocking Prerequisites)

**Pré-condição**: a emenda 11 do contrato (feature 012 do motorista, T001-T003 de `tasks.md` dela)
já está commitada — Princípio IV.

- [X] T001 [P] Acrescentar `driverArrivalKind = 20007`, `meetingConfirmedKind = 20008`,
  `destinationArrivalKind = 20009` e `destinationConfirmedKind = 20010` em
  `lib/services/event_feed.dart`
- [X] T002 [P] Acrescentar `meetingConfirmed` e `destinationConfirmed` a `AcceptedRide`
  (`lib/domain/accepted_ride.dart`), atualizando `copyWith`/`==`/`hashCode`/`toString`; testes em
  `test/domain/accepted_ride_test.dart`
- [X] T003 Atualizar `AcceptedRideStore` (`lib/services/accepted_ride_store.dart`) para
  (de)serializar os dois campos novos; testes em `test/services/accepted_ride_store_test.dart`
  cobrindo round-trip (depende de T002)
- [X] T004 [P] `EventFeed.publishMeetingConfirmation` e `publishDestinationConfirmation` (por
  analogia a `publishQuoteAcceptance`) em `lib/services/event_feed.dart`; testes em
  `test/services/event_feed_test.dart` cobrindo kind/tags corretos para os dois (Princípio II,
  depende de T001)
- [X] T005 Acrescentar `driverArrivalKind`, `meetingConfirmedKind`, `destinationArrivalKind` e
  `destinationConfirmedKind` a `EventFeed.acceptedKinds` (injetado em `main.dart`) (depende de T001)

**Checkpoint**: fundação pronta — as user stories podem começar.

---

## Phase 2: User Story 1 - Confirmar que encontrei o motorista (Priority: P1) 🎯 MVP

**Goal**: `kind: 20007` recebido da corrida aceita exibe a modal, cujo botão publica `kind: 20008`
(FR-001 a FR-004, FR-009, FR-010).

**Independent Test**: com uma corrida aceita, simular o recebimento da chegada do motorista à
origem e verificar que a modal aparece; tocar o botão e verificar que a confirmação é publicada.

### Tests for User Story 1

- [X] T006 [P] [US1] Widget test: `kind: 20007` referenciando o `quoteId` da corrida aceita exibe
  `DriverArrivedModal` (FR-001, FR-002), em `test/screens/map_screen_test.dart`
- [X] T007 [P] [US1] Widget test: tocar o botão publica `kind: 20008` com as tags corretas e fecha
  a modal (FR-003), em `test/screens/map_screen_test.dart`
- [X] T008 [P] [US1] Widget test: uma segunda `kind: 20007` (reentrega), com a modal já exibida,
  não reabre (FR-004), em `test/screens/map_screen_test.dart`
- [X] T009 [P] [US1] Widget test: `kind: 20007` de um motorista diferente do aceito não exibe
  modal (FR-009), em `test/screens/map_screen_test.dart`
- [X] T010 [P] [US1] Widget test: sem relay conectado ao tocar o botão, a modal permanece aberta
  com mensagem de falha (Edge Case do `spec.md`), em `test/screens/map_screen_test.dart`

### Implementation for User Story 1

- [X] T011 [US1] Criar `DriverArrivedModal` (mensagem + botão "Confirmo que encontrei o
  motorista") em `lib/screens/driver_arrived_modal.dart`, por analogia a `DriverMovingModal`
- [X] T012 [US1] `MapScreen` reconhece `kind: 20007`: se `evento.referencedEventId ==
  _corridaAceita?.quoteId` e `meetingConfirmed == false`, marca `meetingConfirmed: true`
  (persistido) e exibe `DriverArrivedModal` (renderizada em `Stack`, mesmo padrão de
  `RideQuotesModal`/`DriverMovingModal`); dedup por `id` do evento (depende de T005, T011)
- [X] T013 [US1] Ao tocar o botão, `MapScreen` chama
  `EventFeed.publishMeetingConfirmation(quoteId, driverPubkey, identity)`; fecha a modal só se ao
  menos um relay aceitar, devolvendo mensagem de erro sem fechar caso contrário (mesmo padrão de
  `_aceitarOrcamento`) (depende de T004, T012)

**Checkpoint**: US1 completa e testável de forma independente.

---

## Phase 3: User Story 2 - Confirmar que chegamos ao destino (Priority: P1)

**Goal**: `kind: 20009` recebido da corrida aceita (depois do encontro confirmado) exibe a modal,
cujo botão publica `kind: 20010` (FR-005 a FR-010).

**Independent Test**: com o encontro já confirmado, simular o recebimento da chegada ao destino e
verificar que a modal aparece; tocar o botão e verificar que a confirmação é publicada.

### Tests for User Story 2

- [X] T014 [P] [US2] Widget test: `kind: 20009` referenciando o `quoteId` da corrida aceita, com
  `meetingConfirmed == true`, exibe `DestinationArrivedModal` (FR-005, FR-006), em
  `test/screens/map_screen_test.dart`
- [X] T015 [P] [US2] Widget test: tocar o botão publica `kind: 20010` com as tags corretas e fecha
  a modal (FR-007), em `test/screens/map_screen_test.dart`
- [X] T016 [P] [US2] Widget test: uma segunda `kind: 20009` (reentrega), com a modal já exibida,
  não reabre (FR-008), em `test/screens/map_screen_test.dart`
- [X] T017 [P] [US2] Widget test: `kind: 20009` recebido antes de `meetingConfirmed == true`
  (Edge Case do `spec.md`) não exibe modal, em `test/screens/map_screen_test.dart`

### Implementation for User Story 2

- [X] T018 [US2] Criar `DestinationArrivedModal` (mensagem + botão "Confirmo que chegamos ao
  destino") em `lib/screens/destination_arrived_modal.dart`, por analogia a `DriverArrivedModal`
- [X] T019 [US2] `MapScreen` reconhece `kind: 20009`: se `evento.referencedEventId ==
  _corridaAceita?.quoteId`, `_corridaAceita?.meetingConfirmed == true` e
  `destinationConfirmed == false`, marca `destinationConfirmed: true` (persistido) e exibe
  `DestinationArrivedModal` (mesma fila/`Stack`); dedup por `id` (depende de T005, T012, T018)
- [X] T020 [US2] Ao tocar o botão, `MapScreen` chama
  `EventFeed.publishDestinationConfirmation(quoteId, driverPubkey, identity)`; mesmo tratamento de
  falha de T013 (depende de T004, T019)

**Checkpoint**: US1 + US2 completas e testáveis de forma independente.

---

## Phase 4: Polish & Cross-Cutting Concerns

- [X] T021 `flutter analyze` sem apontamentos (gate 1 da constituição)
- [X] T022 `flutter test` — suíte completa passando, sem teste ignorado (gate 2 da constituição)
- [ ] T023 Executar os cenários de `quickstart.md`; relatar explicitamente os que não puderam ser
  executados (gate 3 da constituição) — requer a feature 012 do motorista já implementada
- [X] T024 Commit de implementação desta feature (código + testes) — sem commit de contrato
  próprio (já feito pela feature 012 do motorista); separado do commit de documentação (T025)
- [X] T025 Atualizar `../../CLAUDE.md` (raiz do repositório) registrando a feature 010 do
  passageiro, em commit próprio, separado do código (Padrão de Commits, item 6)

---

## Dependencies & Execution Order

- **Foundational (Phase 1)**: depende da emenda 11 do motorista já commitada — bloqueia as duas
  user stories
- **US1 (Phase 2)**: depende do Foundational
- **US2 (Phase 3)**: depende do Foundational **e** de T012 (US1, `meetingConfirmed` precisa já
  existir em `_corridaAceita` para a checagem de FR-005/Edge Case) — mesmo padrão de dependência
  sequencial já aceito nas features 010/011/012 do motorista para o mesmo fluxo
- **Polish (Phase 4)**: depende das duas user stories completas

### Parallel Opportunities

- T001, T002, T004 podem ser feitos em paralelo entre si (arquivos diferentes); T003 depende de
  T002; T005 depende de T001
- T006-T010 (testes US1) e T014-T017 (testes US2) podem ser escritos em paralelo dentro de cada
  grupo

---

## Implementation Strategy

### MVP First (User Story 1)

1. Completar Phase 1 (fundação)
2. Completar Phase 2 (US1)
3. Validar US1 de forma independente

### Incremental Delivery

1. Foundational → base pronta
2. US1 → confirmação de encontro (MVP)
3. US2 → confirmação de destino, fechando o ciclo junto da feature 012 do motorista
4. Cada incremento soma valor sem quebrar o anterior

## Notes

- [P] = arquivos diferentes, sem dependência
- Commit separado para: código (T024) e `CLAUDE.md` (T025) — Padrão de Commits, item 6
- Verificar que os testes falham antes de implementar (T006-T010, T014-T017)

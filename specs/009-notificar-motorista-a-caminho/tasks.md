# Tasks: Notificar que o motorista está a caminho

**Input**: Design documents from `/specs/009-notificar-motorista-a-caminho/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/README.md, quickstart.md

**Tests**: **obrigatórias**, não opcionais (constituição, Princípio II) para código que decide
descartar uma mensagem recebida — aplica-se aqui à decisão de reconhecer (ou não) um `kind: 20005`
como o sinal de início do deslocamento.

**Organization**: única user story (P1); tarefas em Setup → Foundational → US1 → Polish.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependência entre si)
- Caminhos de arquivo sempre relativos a `Prototipo/passenger/`, exceto onde indicado

---

## Phase 1: Setup — emenda ao contrato antes do código (Princípio IV)

- [X] T001 Escrever a emenda 10 do contrato único em
  `../driver/specs/002-nostr-relay-connection/contracts/nostr-events.md` (arquivo canônico): nova
  linha na tabela "Histórico de emendas"; parágrafo "Consumo pelo passageiro (emenda 10)" na seção
  *Conteúdo do kind 20005 — Localização do motorista*; atualizar "Forma da inscrição" para incluir
  `20005` na lista de kinds do passageiro
- [X] T002 [P] Replicar a emenda 10 de forma idêntica em
  `specs/002-nostr-relay-connection/contracts/nostr-events.md` (cópia do passageiro; cabeçalho de
  procedência à parte; conferir os corpos por diff antes de prosseguir)
- [X] T003 Commit da emenda 10 (driver + passenger), separado de qualquer código desta feature

**Checkpoint**: contrato escrito e replicado — nenhuma tarefa de código abaixo pode começar antes
deste checkpoint.

---

## Phase 2: Foundational (Blocking Prerequisites)

- [X] T004 [P] Acrescentar `const driverLocationKind = 20005;` em `lib/services/event_feed.dart`,
  por analogia às constantes de kind já existentes ali
- [X] T005 [P] Criar `AcceptedRide` (quoteId, driverPubkey, movementNotified) em
  `lib/domain/accepted_ride.dart`, com `copyWith`, `==`/`hashCode`/`toString`; teste em
  `test/domain/accepted_ride_test.dart`
- [X] T006 Criar `AcceptedRideStore` (abstração + implementação sobre `KeyValueStore`, JSON
  serializado) em `lib/services/accepted_ride_store.dart`, com dublê em memória e teste em
  `test/services/accepted_ride_store_test.dart` (depende de T005)
- [X] T007 [P] Criar `DriverMovingModal` (mensagem informativa + botão "OK") em
  `lib/screens/driver_moving_modal.dart`, por analogia a `RideQuotesModal`

**Checkpoint**: fundação pronta — a user story pode começar.

---

## Phase 3: User Story 1 - Ser avisado de que o motorista começou a se deslocar (Priority: P1) 🎯 MVP

**Goal**: reconhecer a primeira localização do motorista aceito e exibir a modal uma única vez por
corrida (FR-001 a FR-007).

**Independent Test**: com o passageiro tendo aceitado um orçamento de um motorista específico,
simular o recebimento da primeira localização publicada por aquele motorista e verificar que a
modal aparece, e só uma vez.

### Tests for User Story 1

- [X] T008 [P] [US1] Widget test: `MapScreen._aceitarOrcamento` grava `AcceptedRide` (quoteId,
  driverPubkey, movementNotified: false) ao aceitar um orçamento, em
  `test/screens/map_screen_test.dart`
- [X] T009 [P] [US1] Widget test: `kind: 20005` referenciando o `quoteId` da corrida aceita exibe
  `DriverMovingModal` (FR-001, FR-002), em `test/screens/map_screen_test.dart`
- [X] T010 [P] [US1] Widget test: tocar "OK" fecha a modal (FR-003), em
  `test/screens/map_screen_test.dart`
- [X] T011 [P] [US1] Widget test: uma segunda localização do mesmo motorista, depois da primeira
  modal já exibida, não reabre a modal (FR-004), em `test/screens/map_screen_test.dart`
- [X] T012 [P] [US1] Widget test: `kind: 20005` de um motorista diferente do aceito (ex.: um
  orçamento recebido mas não escolhido) não exibe modal (FR-005, SC-003), em
  `test/screens/map_screen_test.dart`
- [X] T013 [P] [US1] Widget test: `kind: 20005` recebido sem nenhuma corrida aceita não exibe modal
  (FR-005), em `test/screens/map_screen_test.dart`
- [X] T014 [P] [US1] Widget test: com `AcceptedRideStore` (dublê) pré-carregado com
  `movementNotified: true` (simulando reinício após já ter avisado), uma nova localização do
  motorista aceito não exibe modal (FR-007), em `test/screens/map_screen_test.dart`

### Implementation for User Story 1

- [X] T015 [US1] `MapScreen` passa a receber `AcceptedRideStore` por injeção de construtor;
  `main.dart` injeta a implementação real (depende de T006)
- [X] T016 [US1] `MapScreen._aceitarOrcamento` grava `AcceptedRide` via `AcceptedRideStore.save`
  logo após a aceitação ser confirmada por ao menos um relay (mesmo ponto em que `_corridaDecidida`
  já é marcado) (depende de T005, T006, T015)
- [X] T017 [US1] `MapScreen` carrega a `AcceptedRide` persistida (`AcceptedRideStore.load()`) em
  `initState`/`_iniciar`, expondo o estado carregado no `State` (depende de T015)
- [X] T018 [US1] `EventFeed.acceptedKinds` (injetado em `main.dart`) passa a incluir
  `driverLocationKind` (depende de T004)
- [X] T019 [US1] `MapScreen` reconhece `kind: 20005` cujo `referencedEventId` bate com o `quoteId`
  da `AcceptedRide` carregada e, se `movementNotified == false`, exibe `DriverMovingModal`
  (renderizada em `Stack`, mesmo padrão de `RideQuotesModal`, T019 de
  `specs/008-receber-orcamentos/tasks.md`) e grava `movementNotified: true` via
  `AcceptedRideStore.save` (depende de T007, T016, T017, T018)

**Checkpoint**: US1 completa e testável de forma independente — única user story desta feature.

---

## Phase 4: Polish & Cross-Cutting Concerns

- [X] T020 `flutter analyze` sem apontamentos (gate 1 da constituição)
- [X] T021 `flutter test` — suíte completa passando, sem teste ignorado (gate 2 da constituição)
- [ ] T022 Executar os cenários de `quickstart.md`; relatar explicitamente os que não puderam ser
  executados (gate 3 da constituição)
- [X] T023 Commit de implementação desta feature (código + testes), separado do commit da emenda
  de contrato (T003) e do commit de documentação (T024)
- [X] T024 Atualizar `../../CLAUDE.md` (raiz do repositório) registrando a feature 009 do
  passageiro, em commit próprio, separado do código (Padrão de Commits, item 6)

---

## Dependencies & Execution Order

- **Setup (Phase 1)**: sem dependências — bloqueia tudo abaixo (Princípio IV)
- **Foundational (Phase 2)**: depende do Setup — bloqueia a user story
- **US1 (Phase 3)**: depende do Foundational; dentro dela, T016 depende de T005/T006/T015, T017
  depende de T015, T018 depende de T004, T019 depende de T007/T016/T017/T018
- **Polish (Phase 4)**: depende de US1 completa

### Parallel Opportunities

- T001/T002 podem ser feitos em paralelo (arquivos diferentes), mas commitados juntos (T003)
- T004, T005, T007 podem ser feitos em paralelo entre si (arquivos diferentes); T006 depende de T005
- T008-T014 (testes da US1) podem ser escritos em paralelo entre si

---

## Implementation Strategy

Única user story: completar Phase 1 (contrato) → Phase 2 (fundação) → Phase 3 (US1) → Phase 4
(polish). Não há incremento intermediário além deste — a feature inteira é o MVP.

## Notes

- [P] = arquivos diferentes, sem dependência
- Commit separado para: emenda de contrato (T003), código (T023) e `CLAUDE.md` (T024) — Padrão de
  Commits, item 6
- Verificar que os testes falham antes de implementar (T008-T014)

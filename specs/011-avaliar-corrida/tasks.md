# Tasks: Avaliar corrida (passageiro)

**Input**: Design documents from `/specs/011-avaliar-corrida/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: **obrigatórias**, não opcionais (constituição, Princípio II via Fluxo de
Desenvolvimento e Gates — item 2, `flutter test` sem exceção).

**Organization**: uma única user story (P1); tarefas em Foundational → US1 → Polish.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependência entre si)
- Caminhos de arquivo sempre relativos a `Prototipo/passenger/`

---

## Phase 1: Foundational (Blocking Prerequisites)

- [X] T001 [P] Criar entidade `RideRating` (`rideId`, `stars` 1-5, `ratedAt`) em
  `lib/domain/ride_rating.dart`, recusando `stars` fora de 1-5 no construtor; testes em
  `test/domain/ride_rating_test.dart`
- [X] T002 Criar `RideRatingStore` (abstrata: `save`, `forRide`) e `SqfliteRideRatingStore`
  (tabela `ride_ratings`, banco `ride_ratings.db`, `ride_id` como chave primária, D1/D2 de
  `research.md`) em `lib/services/ride_rating_store.dart`, por analogia direta a
  `received_quote_store.dart` — **desvio da redação original desta tarefa**: nenhum teste de
  integração SQLite real foi escrito, por descoberta durante a implementação de que
  `SqfliteReceivedQuoteStore` (o próprio modelo citado) também não tem um — nem no motorista
  (`SqfliteCadastroStore`) — e adicionar `sqflite_common_ffi` só para isso violaria o Princípio
  III (dependência nova sem decisão registrada) e o V (estrutura sem consumidor real no projeto).
  O dublê em memória (`FakeRideRatingStore`, em `test/screens/map_screen_test.dart`) cobre os
  testes de tela; `SqfliteRideRatingStore` fica sem teste direto, mesma situação de
  `SqfliteReceivedQuoteStore` (depende de T001)

**Checkpoint**: fundação pronta — a user story pode começar.

---

## Phase 2: User Story 1 - Avaliar a corrida ao final (Priority: P1) 🎯 MVP

**Goal**: ao confirmar com sucesso a chegada ao destino, exibir a tela de avaliação; confirmar uma
nota de 1 a 5 persiste em `ride_ratings`; pular fecha sem persistir nada; nunca reexibir para uma
corrida já avaliada dentro da mesma sessão (FR-001 a FR-009).

**Independent Test**: simular `_confirmarDestino` bem-sucedido e verificar que a tela de avaliação
aparece; tocar numa estrela e confirmar, e verificar a nota persistida associada ao `quoteId` da
corrida; em outro cenário, pular e verificar que nada é persistido.

### Tests for User Story 1

- [X] T003 [P] [US1] Widget test: `_confirmarDestino` bem-sucedido (modal de chegada ao destino
  fecha) exibe `RideRatingModal` com cinco estrelas, nenhuma pré-selecionada (FR-001, FR-002), em
  `test/screens/map_screen_test.dart`
- [X] T004 [P] [US1] Widget test: tocar a estrela de posição N seleciona as estrelas 1..N e
  nenhuma das demais (FR-003), em `test/screens/map_screen_test.dart`
- [X] T005 [P] [US1] Widget test: selecionar uma nota e confirmar persiste `RideRating(rideId:
  quoteId, stars: nota)` via `RideRatingStore` e fecha a tela (FR-004, FR-005), em
  `test/screens/map_screen_test.dart`
- [X] T006 [P] [US1] Widget test: tocar pular/fechar sem selecionar nota fecha a tela sem chamar
  `RideRatingStore.save` (FR-008), em `test/screens/map_screen_test.dart`

### Implementation for User Story 1

- [X] T007 [US1] Criar `RideRatingModal` (cinco estrelas selecionáveis, botões "Confirmar" e
  "Pular", `onConfirm(int stars)`/`onSkip` callbacks) em `lib/screens/ride_rating_modal.dart`
- [X] T008 [US1] `MapScreen` abre `RideRatingModal` (`Stack`, mesmo padrão de
  `DestinationArrivedModal`) no mesmo `setState` que fecha a modal de chegada ao destino, dentro
  de `_confirmarDestino`, guardando o `quoteId` da corrida confirmada (depende de T007)
- [X] T009 [US1] `MapScreen` chama `RideRatingStore.save` ao confirmar uma nota (fecha a tela em
  seguida) e só fecha a tela, sem chamar `save`, ao pular (depende de T002, T008)

**Checkpoint**: US1 completa e testável de forma independente — MVP da feature.

---

## Phase 3: Polish & Cross-Cutting Concerns

- [X] T010 `flutter analyze` sem apontamentos (gate 1 da constituição)
- [X] T011 `flutter test` — suíte completa passando, sem teste ignorado (gate 2 da constituição)
- [ ] T012 Executar os cenários de `quickstart.md`; relatar explicitamente os que não puderam ser
  executados (gate 3 da constituição) — **pendente**: requer aparelho/emulador Android
- [ ] T013 Commit de implementação desta feature (código + testes)
- [ ] T014 Atualizar `../../CLAUDE.md` (raiz do repositório) registrando a feature 011 do
  passageiro, em commit próprio, separado do código (Padrão de Commits, item 6)

---

## Dependencies & Execution Order

- **Foundational (Phase 1)**: T002 depende de T001; nenhuma dependência externa a outra feature
- **US1 (Phase 2)**: depende do Foundational
- **Polish (Phase 3)**: depende de US1 completa

### Parallel Opportunities

- T001 pode começar imediatamente; T002 depende dele
- T003-T006 (testes de US1) podem ser escritos em paralelo entre si

---

## Implementation Strategy

### MVP First (User Story 1)

1. Completar Phase 1 (fundação)
2. Completar Phase 2 (única user story) — já é a feature inteira
3. Validar de forma independente pelo `quickstart.md`

### Incremental Delivery

1. Foundational → `RideRating`/`RideRatingStore` prontos
2. US1 → tela de avaliação completa, encerrando o pedido do usuário para o lado do passageiro
3. Contrapartida do motorista: feature de spec-kit separada, dentro de `driver/`

## Notes

- [P] = arquivos diferentes, sem dependência
- Commit separado para: código (T013) e `CLAUDE.md` (T014) — Padrão de Commits, item 6
- Verificar que os testes falham antes de implementar (T003-T006)

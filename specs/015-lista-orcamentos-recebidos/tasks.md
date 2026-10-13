# Tasks: Tela de orçamentos recebidos e cancelamento da solicitação

**Input**: Design documents from `/specs/015-lista-orcamentos-recebidos/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: incluídas para toda transição/comportamento novo, por decisão de projeto (mesmo padrão
já seguido pelas features 009-014) — não exigidas pelo Princípio II (nenhuma assinatura/verificação
nesta feature), mas obrigatórias pelo gate 2 do Fluxo de Desenvolvimento (`flutter test` completo,
sem teste ignorado).

**Organization**: três user stories, todas P1 (spec.md); tarefas em
Foundational → US1 → US2 → US3 → Polish.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependência entre si)
- Caminhos de arquivo sempre relativos a `Prototipo/passenger/`

---

## Phase 1: Foundational (Blocking Prerequisites)

**Purpose**: guarda de transição nova e o widget da tela dedicada — nenhuma user story pode
começar antes desta fase.

- [X] T001 [P] Acrescentar `PassengerRideRules.canCancelRequest` (válida só a partir de
  `aguardandoOrcamentos`, D3 de `research.md`) em `lib/domain/passenger_ride_status.dart`; testes
  (permitida/negada a partir de cada estado) em `test/domain/passenger_ride_status_test.dart`
- [X] T002 Criar `ReceivedQuotesScreen` (lista condensada via
  `ValueListenable<List<ReceivedQuote>>`, mesmos campos de `_LinhaDeOrcamento` da modal antiga,
  botão "Aceitar" por item, botão "Cancelar" fixo na parte inferior, sempre visível — D1/D5 de
  `research.md`) em `lib/screens/received_quotes_screen.dart`; testes de widget (lista vazia com
  "Cancelar" visível; item aparece com os campos esperados; "Aceitar"/"Cancelar" chamam os
  callbacks) em `test/screens/received_quotes_screen_test.dart`
- [X] T003 Remover `lib/screens/ride_quotes_modal.dart` e
  `test/screens/ride_quotes_modal_test.dart` (FR-007, D5 de `research.md`); atualizar as
  referências a `RideQuotesModal` nos comentários de `lib/screens/driver_arrived_modal.dart` e
  `lib/screens/driver_moving_modal.dart` para `ReceivedQuotesScreen` (depende de T002)

**Checkpoint**: fundação pronta — as user stories podem começar.

---

## Phase 2: User Story 1 - O painel de solicitação só aparece na fase inicial (Priority: P1)

**Goal**: o painel com destino, forma de pagamento e "Solicitar corrida" só é visível enquanto
`_rideStatus == PassengerRideStatus.inicial` (FR-001, FR-002).

**Independent Test**: percorrer cada fase de uma corrida e verificar, a cada uma, se o painel de
solicitação está visível ou não, comparando com o esperado.

### Tests for User Story 1

- [X] T004 [P] [US1] Widget test: painel de solicitação (`TextField` de destino, seletor de
  pagamento, botão "Solicitar corrida") visível em `inicial` e ausente em cada uma das demais fases
  (`aguardandoOrcamentos`, `orcamentoAceito`, `motoristaACaminho`, `encontroConfirmado`,
  `destinoConfirmadoAguardandoAvaliacao`) (FR-001, FR-002, SC-001), em
  `test/screens/map_screen_test.dart`

### Implementation for User Story 1

- [X] T005 [US1] `MapScreen.build()`: condicionar a exibição do painel de solicitação (o
  `Positioned` com destino/pagamento/"Solicitar corrida") a `_rideStatus ==
  PassengerRideStatus.inicial` (depende de T001, herdado da feature 014)

**Checkpoint**: US1 completa e testável de forma independente.

---

## Phase 3: User Story 2 - Acompanhar os orçamentos recebidos numa tela dedicada (Priority: P1)

**Goal**: ao solicitar uma corrida, `ReceivedQuotesScreen` substitui o mapa por completo, começa
vazia e cresce com cada orçamento recebido; aceitar pela lista tem o mesmo efeito de sempre; a
modal antiga nunca mais aparece (FR-003 a FR-007, FR-012).

**Independent Test**: solicitar uma corrida (com duplês de teste para os orçamentos recebidos) e
verificar que a tela dedicada aparece vazia, cresce a cada orçamento, permite aceitar por um item,
e que nenhuma modal antiga aparece em nenhum momento; separadamente, simular um reinício do app
nessa fase e verificar que a lista é restaurada a partir do que já foi persistido.

### Tests for User Story 2

- [X] T006 [P] [US2] Widget test: `_solicitarCorrida` bem-sucedido exibe `ReceivedQuotesScreen`
  vazia, com "Cancelar" visível, e a modal antiga (`RideQuotesModal`/texto "Orçamentos recebidos")
  não aparece em nenhum momento (FR-003, FR-007), em `test/screens/map_screen_test.dart`
- [X] T007 [P] [US2] Widget test: o primeiro orçamento recebido aparece como item condensado na
  lista, com os mesmos dados já exibidos hoje (nome do motorista, veículo, total, tempo estimado)
  (FR-004, FR-005), em `test/screens/map_screen_test.dart`
- [X] T008 [P] [US2] Widget test: um segundo orçamento é adicionado à lista sem remover ou
  substituir o primeiro (FR-004), em `test/screens/map_screen_test.dart`
- [X] T009 [P] [US2] Widget test: tocar "Aceitar" num item da lista publica a aceitação, recusa os
  demais orçamentos da mesma solicitação e avança a corrida de fase — mesmo efeito já validado para
  a modal antiga (FR-006), em `test/screens/map_screen_test.dart`
- [X] T010 [P] [US2] Widget test: reiniciar o app (remontar `MapScreen`) com `_rideStatus`
  persistido como `aguardandoOrcamentos` e orçamentos já persistidos em `ReceivedQuoteStore`
  restaura a lista com esses orçamentos, em vez de mostrá-la vazia (FR-012, Clarification), em
  `test/screens/map_screen_test.dart`

### Implementation for User Story 2

- [X] T011 [US2] `MapScreen.build()`: retornar `ReceivedQuotesScreen(...)` diretamente (sem
  `Stack`/dim, D1 de `research.md`) quando `_rideStatus ==
  PassengerRideStatus.aguardandoOrcamentos`, antes de montar o `scaffold` do mapa; remover o bloco
  condicional de `_modalOrcamentosVisivel`/`RideQuotesModal` (depende de T002, T003)
- [X] T012 [US2] `_carregarEstadoCorrida`: ao restaurar `aguardandoOrcamentos`, chamar
  `widget.receivedQuoteStore.byRequest(solicitacaoId)` e inicializar `_orcamentosRecebidos.value`
  com o resultado (D4 de `research.md`, FR-012) (depende de T011) — **desvio da redação original
  desta tarefa**: `_solicitarCorrida` não chama `byRequest` (só a restauração chama), porque uma
  solicitação recém-criada nunca tem orçamento persistido para o seu `requestId`; a chamada seria
  incondicionalmente vazia, achado A2 (LOW) do `/speckit-analyze` desta feature — `setState` já
  zera `_orcamentosRecebidos.value` diretamente nesse caminho.
- [X] T013 [US2] `_processarOrcamentoRecebido`: remover a manipulação de
  `_modalOrcamentosVisivel`; a condição `PassengerRideRules.canAcceptQuote(_rideStatus)` passa a
  decidir apenas se o orçamento é adicionado a `_orcamentosRecebidos.value` (persistência
  incondicional inalterada) (depende de T011)

**Checkpoint**: US1 e US2 completas — a tela dedicada substitui a modal por completo, com
restauração após reinício.

---

## Phase 4: User Story 3 - Cancelar a solicitação a partir da tela de orçamentos (Priority: P1)

**Goal**: tocar "Cancelar" devolve o passageiro à fase inicial e avisa cada motorista que já havia
enviado orçamento para a solicitação cancelada (FR-008 a FR-011).

**Independent Test**: solicitar uma corrida, receber um ou mais orçamentos, tocar "Cancelar" e
verificar que o passageiro volta ao mapa e que uma recusa é publicada para cada orçamento que
estava na lista; separadamente, cancelar com a lista ainda vazia e verificar que nenhuma recusa é
publicada.

### Tests for User Story 3

- [X] T014 [P] [US3] Widget test: tocar "Cancelar" com a lista vazia volta `_rideStatus` a
  `inicial` (mapa e painel de solicitação reaparecem) e não publica nenhuma recusa (FR-009, cenário
  3 do spec.md), em `test/screens/map_screen_test.dart`
- [X] T015 [P] [US3] Widget test: tocar "Cancelar" com um ou mais orçamentos na lista publica uma
  recusa (`kind: 20004`) para cada um deles e volta `_rideStatus` a `inicial` (FR-010, SC-003), em
  `test/screens/map_screen_test.dart`
- [X] T016 [P] [US3] Widget test: depois de cancelar, `_solicitarCorrida` funciona normalmente para
  uma nova corrida, sem nenhum orçamento da solicitação cancelada na nova tela de orçamentos
  (SC-004), em `test/screens/map_screen_test.dart`

### Implementation for User Story 3

- [X] T017 [US3] Criar `_cancelarSolicitacao`: validar
  `PassengerRideRules.canCancelRequest(_rideStatus)`; para cada `ReceivedQuote` em
  `_orcamentosRecebidos.value`, publicar recusa via `widget.eventFeed.publishQuoteRejection` (D2 de
  `research.md`); atualizar `_rideStatus = inicial`, persistir via
  `PassengerRideStateStore.save(inicial, null)`, e limpar `_solicitacaoAtivaId`,
  `_orcamentosRecebidos.value` e `_idsOrcamentosProcessados` (depende de T001)
- [X] T018 [US3] Passar `_cancelarSolicitacao` como `onCancel` de `ReceivedQuotesScreen` (depende
  de T011, T017)

**Checkpoint**: as três user stories completas — painel condicional, tela dedicada crescente e
cancelamento com recusa aos motoristas, tudo funcionando em conjunto.

---

## Phase 5: Polish & Cross-Cutting Concerns

- [X] T019 `flutter analyze` sem apontamentos (gate 1 da constituição)
- [X] T020 `flutter test` — suíte completa passando, sem teste ignorado (gate 2 da constituição)
- [ ] T021 Executar os cenários de `quickstart.md`; relatar explicitamente os que não puderam ser
  executados (gate 3 da constituição) — **pendente**: requer aparelho/emulador Android com um
  segundo aparelho/emulador do motorista com relay em comum
- [X] T022 Commit de implementação desta feature (código + testes)
- [ ] T023 Atualizar `../../CLAUDE.md` (raiz do repositório) registrando a feature 015 do
  passageiro, em commit próprio, separado do código (Padrão de Commits, item 6)

## Ajustes feitos durante a implementação, fora da redação original das tarefas

- Dois testes existentes em `test/screens/map_screen_test.dart`, escritos antes desta feature,
  ficaram obsoletos porque a tela de orçamentos passou a ocupar a tela inteira assim que
  `_rideStatus == aguardandoOrcamentos` (não mais condicionada a um orçamento ter chegado):
  - "orçamento de outra solicitação não é persistido nem exibido" (grupo da feature 008) —
    ajustado para verificar que o orçamento não é persistido nem adicionado à lista (a tela em si
    já está visível desde a solicitação), em vez de checar a ausência da tela.
  - "tentar solicitar uma segunda corrida com uma já em andamento é impedido" (grupo da feature
    014) — removido: ficou impossível de exercitar pela UI, já que o botão "Solicitar corrida" nem
    existe mais fora da fase `inicial` (FR-001/FR-002 desta feature). A guarda
    `PassengerRideRules.canRequestRide` continua coberta por
    `test/domain/passenger_ride_status_test.dart`.

---

## Dependencies & Execution Order

- **Foundational (Phase 1)**: T003 depende de T002; nenhuma dependência externa a outra feature
- **US1 (Phase 2)**: depende do Foundational (T001, herdado da feature 014)
- **US2 (Phase 3)**: depende do Foundational (T002, T003) e de US1 (T005, mesmo `build()`)
- **US3 (Phase 4)**: depende de US2 completa (T011) e do Foundational (T001)
- **Polish (Phase 5)**: depende de US1, US2 e US3 completas

### Parallel Opportunities

- T001 e T002 podem começar imediatamente, em paralelo (arquivos diferentes); T003 depende de T002
- T004 (teste de US1) pode ser escrito em paralelo aos testes de outras stories
- T006-T010 (testes de US2) podem ser escritos em paralelo entre si
- T014-T016 (testes de US3) podem ser escritos em paralelo entre si

---

## Implementation Strategy

### MVP First (User Story 1)

1. Completar Phase 1 (fundação)
2. Completar Phase 2 (US1) — painel condicional já cumpre parte do pedido
3. Validar de forma independente pelo `quickstart.md`, cenário 1

### Incremental Delivery

1. Foundational → `PassengerRideRules.canCancelRequest` e `ReceivedQuotesScreen` prontos, modal
   antiga removida
2. US1 → painel de solicitação só na fase inicial
3. US2 → tela dedicada crescente, substituindo a modal, com restauração após reinício
4. US3 → cancelamento com recusa aos motoristas, fechando o ciclo pedido

## Notes

- [P] = arquivos diferentes, sem dependência
- Commit separado para: código (T022) e `CLAUDE.md` (T023) — Padrão de Commits, item 6
- Verificar que os testes falham antes de implementar (T004, T006-T010, T014-T016)
- Sem diretório `contracts/`: nenhum evento Nostr novo ou alterado por esta feature

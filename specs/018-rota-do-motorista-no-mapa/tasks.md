# Tasks: Rota da corrida enviada pelo motorista, no mapa do passageiro

**Input**: Design documents from `/specs/018-rota-do-motorista-no-mapa/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/README.md, quickstart.md

**Tests**: **obrigatórios** (Princípio II; nenhum teste toca rede). Validação do `content` e regra de estado têm teste de domínio direto; o comportamento do mapa usa os dublês de `test/support/` e os helpers já existentes em `test/screens/map_screen_test.dart` (grupo "posição do motorista no mapa (feature 016)", que pré-carrega estado e entrega eventos).

**Organization**: dependência bloqueante (contrato) → fundação (domínio, `kind`, inscrição) → US1 (traçar) → US2 (não calcular) → US3 (só rota legítima e só em "Em corrida"). Setup vazio (nenhuma dependência nova).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo
- Caminhos relativos a `Prototipo/passenger/`, salvo indicação

---

## Phase 1: Dependência bloqueante — contrato (Princípio IV)

- [X] T001 Verificar que a emenda 13 (`kind: 20011`, seção *Conteúdo do kind 20011*) já consta, idêntica, em `specs/002-nostr-relay-connection/contracts/nostr-events.md` e em `../driver/specs/002-nostr-relay-connection/contracts/nostr-events.md` (`grep -c 20011` em ambos > 0; `diff` ignorando o cabeçalho de procedência do passageiro vazio). Se não constar, **parar**: implementar antes as tarefas T001/T002 da feature `017-publicar-rota-ao-passageiro` do motorista (`../driver/specs/017-publicar-rota-ao-passageiro/tasks.md`). Nenhuma tarefa abaixo começa sem isto.

---

## Phase 2: Foundational — domínio, `kind` e inscrição (bloqueia as histórias)

- [X] T002 [P] Escrever `test/domain/ride_route_test.dart`: `RideRoute.fromNostrEvent` aceita `{"points":[[-28.9,-49.4],[-28.8,-49.3]]}` (2 pontos) e 1000 pontos; lança `FormatException` com 1 ponto, 1001 pontos, JSON inválido, `points` ausente ou não lista, item que não é par, item não numérico, `lat` 90,1 / −90,1, `lon` 180,1 / −180,1, `NaN`/infinito; guarda `reportedAt = event.createdAt`; `isNewerThan` é `true` sem rota anterior e com `created_at` estritamente posterior, e `false` com igual ou anterior; a lista `points` é não modificável. Devem falhar antes de T004.
- [X] T003 [P] Acrescentar a `test/domain/passenger_ride_status_test.dart` os casos de `PassengerRideRules.canShowDriverRoute`: `true` só para `emCorrida`; `false` para `inicial`, `aguardandoOrcamentos`, `orcamentoAceito`, `motoristaACaminho` e `destinoConfirmadoAguardandoAvaliacao`. Deve falhar antes de T005.
- [X] T004 Criar `lib/domain/ride_route.dart` com `RideRoute` conforme `data-model.md` (campos `points` imutável e `reportedAt`, `fromNostrEvent`, `isNewerThan`), usando `dart:convert`, `latlong2` e `NostrEvent` do projeto; sem `dart_nostr`. T002 passa.
- [X] T005 Acrescentar `canShowDriverRoute` a `PassengerRideRules` em `lib/domain/passenger_ride_status.dart` (`status == PassengerRideStatus.emCorrida`), com doc comment no padrão dos vizinhos. T003 passa.
- [X] T006 [P] Acrescentar `const rideRouteKind = 20011;` em `lib/services/event_feed.dart` (doc comment: emenda 13, definida pela feature 017 do motorista, consumida por esta feature) e incluí-lo em `acceptedKinds` em `lib/main.dart`, atualizando o comentário da lista (feature 018). Acrescentar a `test/event_feed_test.dart` o caso de que um `kind: 20011` com marcador, assinatura válida e kind em `acceptedKinds` chega ao feed, e sem estar em `acceptedKinds` é ignorado (regra 4 de recepção).

**Checkpoint**: `flutter test test/domain test/event_feed_test.dart` verde.

---

## Phase 3: User Story 1 — Ver no mapa o caminho até o destino durante a corrida (Priority: P1) 🎯 MVP

**Goal**: em `emCorrida`, a rota válida mais nova recebida do motorista é traçada; cada rota nova substitui a anterior; rota mais antiga ou igual não troca.

**Independent Test**: cenários 1 e 2 de `quickstart.md`.

- [X] T007 [US1] Escrever em `test/screens/map_screen_test.dart` o grupo `MapScreen — rota do motorista no mapa (feature 018)`, caso "traça a rota recebida em emCorrida": pré-carregar o estado em `emCorrida` com `AcceptedRide` (usar o mesmo helper/pré-carregamento do grupo da feature 016), entregar um `kind: 20011` (autor = `driverPubkey`, `["e", quoteId]`, `points` válidos) e esperar uma `Polyline` extra no mapa, de cor `IdentidadeVisual.roxo` e largura 5, com exatamente os pontos recebidos; com uma segunda rota de `created_at` posterior, esperar uma só `Polyline` de rota com os pontos novos; com uma terceira de `created_at` anterior (e outra de igual), os pontos não mudam; a mesma rota (mesmo `id`) entregue duas vezes é processada uma só vez. Deve falhar antes de T008.
- [X] T008 [US1] Em `lib/screens/map_screen.dart`: declarar `RideRoute? _rotaDoMotorista` e `final _idsRotaProcessados = <String>{}`; despachar `evento.kind == rideRouteKind` em `_aoAtualizarOrcamentos` para um novo `_processarRotaDoMotorista(NostrEvent)` que, na ordem de D1 de `research.md`, deduplica por `id`, exige `_corridaAceita`, `referencedEventId == quoteId`, `authorPublicKey == driverPubkey`, `PassengerRideRules.canShowDriverRoute(_rideStatus)`, decodifica com `RideRoute.fromNostrEvent` (descartando em `FormatException`) e só então, se `nova.isNewerThan(_rotaDoMotorista)`, guarda dentro de `setState`; acrescentar à árvore do `FlutterMap`, junto da rota local, uma `PolylineLayer` com `Polyline(points: _rotaDoMotorista!.points, strokeWidth: 5, color: IdentidadeVisual.roxo)` visível só se `PassengerRideRules.canShowDriverRoute(_rideStatus) && _rotaDoMotorista != null`. T007 passa.
- [X] T009 [US1] Zerar `_rotaDoMotorista` em `_limparPosicaoMotorista()` (já chamado quando a corrida aceita muda ou termina) e ao sair de `emCorrida` em `_confirmarDestino` (dentro do `setState` da transição para `destinoConfirmadoAguardandoAvaliacao`); atualizar o doc comment de `_limparPosicaoMotorista`. Cobertura no teste de US3 (T014).

**Checkpoint**: US1 funcional; MVP.

---

## Phase 4: User Story 2 — O passageiro não calcula a rota (Priority: P1)

**Goal**: em `emCorrida`, nenhuma consulta de rota do passageiro e nenhuma linha de rota local; fora dela, a feature 007 segue igual.

**Independent Test**: cenário 3 de `quickstart.md`.

- [X] T010 [US2] Escrever no mesmo grupo de T007: (a) com destino escolhido, rota local traçada (via `FakeRouteService` da feature 007) em `inicial`/antes do encontro, ao transicionar para `emCorrida` (via `_confirmarEncontro` ou pré-carregando o estado) a `Polyline` local some; (b) em `emCorrida`, entregar posições do passageiro separadas por > 50 m e confirmar que o `FakeRouteService` recebe **zero** chamadas novas; (c) em `emCorrida` sem nenhuma rota recebida, não há `Polyline` de rota; (d) um cálculo local em voo (completer manual) que completa depois da entrada em `emCorrida` não desenha nada; (e) fora de `emCorrida` (ex.: `inicial` com destino), a rota local continua calculada e desenhada como antes. Devem falhar antes de T011.
- [X] T011 [US2] Em `lib/screens/map_screen.dart` (D4 de `research.md`): em `_talvezRecalcularRota`, retornar logo se `PassengerRideRules.canShowDriverRoute(_rideStatus)`; em `_confirmarEncontro` (ao mudar para `emCorrida`) e no ramo de restauração do estado persistido em `emCorrida`, zerar `_rota`, `_falhaRota` e incrementar `_rotaToken`; condicionar a `PolylineLayer` da rota local a `!PassengerRideRules.canShowDriverRoute(_rideStatus)`. T010 passa.

---

## Phase 5: User Story 3 — Só rota legítima e só durante a corrida (Priority: P1)

**Goal**: autor errado, orçamento diferente, conteúdo inválido e estado diferente de `emCorrida` não alteram o mapa; sair de `emCorrida` apaga o traçado.

**Independent Test**: cenários 4 e 5 de `quickstart.md`.

- [X] T012 [US3] Escrever no mesmo grupo: com `emCorrida` e uma rota já traçada, entregar `kind: 20011` (i) assinado por outra chave, (ii) com `["e", ...]` de outro orçamento, (iii) com `content` inválido (1 ponto; 1001 pontos; `lat` 200; JSON quebrado), e confirmar que a `Polyline` de rota não muda em nenhum caso; sem a tag/marcador do protótipo é descartado pelo `EventFeed` (nada muda).
- [X] T013 [US3] Escrever no mesmo grupo: em `motoristaACaminho`, `orcamentoAceito`, `inicial` e `destinoConfirmadoAguardandoAvaliacao`, entregar uma rota válida do motorista aceito e confirmar que nenhuma `Polyline` de rota é desenhada, **e** que ela não reaparece ao transicionar depois para `emCorrida` (a rota recebida cedo não é guardada).
- [X] T014 [US3] Escrever no mesmo grupo: com `emCorrida` e rota traçada, confirmar o destino (`_confirmarDestino`, via `kind: 20009` e toque no botão da modal) e verificar que a `Polyline` some e que uma rota tardia (válida) entregue em seguida não a faz reaparecer; reiniciar o mapa já em `emCorrida` (estado pré-carregado) começa sem rota (FR-007). T009 deve estar feito.

---

## Phase 6: Polish & cross-cutting

- [X] T015 Rodar `flutter analyze` ("No issues found!") e `flutter test` (suíte completa; anotar o total) em `Prototipo/passenger/`.
- [ ] T016 (PENDENTE: sem emulador Android na sessão; ver "Estado da validação" do quickstart) Ponta a ponta (cenários de `quickstart.md`) com os dois apps, quando houver dois aparelhos/emuladores: registrar o resultado, ou deixar a validação como **pendente** no `quickstart.md` se não for possível.
- [X] T017 Atualizar `../CLAUDE.md` (raiz do repositório): entrada da feature `018-rota-do-motorista-no-mapa` do passageiro e a contrapartida `017-publicar-rota-ao-passageiro` do motorista, em commit separado, no padrão das entradas anteriores; marcar a validação em aparelho como pendente.

---

## Dependencies & Execution Order

- T001 (contrato commitado pela 017 do motorista) → bloqueia tudo.
- Phase 2: T002 ∥ T003 ∥ T006; T004 depois de T002; T005 depois de T003.
- Phase 3: T007 → T008 → T009 (depende de T004, T005, T006).
- Phase 4 depende de T005 e T008 (mesmo arquivo `map_screen.dart`: sequenciar T008 → T009 → T011).
- Phase 5 depende de T008/T009; T012–T014 são testes no mesmo arquivo (sequenciar).
- Polish depois de tudo.

### Parallel opportunities
- T002 ∥ T003 ∥ T006 (arquivos diferentes).

## Implementation Strategy

1. Confirmar o contrato (T001); se a 017 do motorista ainda não o escreveu, fazê-lo primeiro.
2. MVP = Phase 2 + Phase 3 (T002–T009): a rota do motorista é traçada em `emCorrida`.
3. Phase 4 remove a duplicação com a rota local; Phase 5 trava as condições negativas.
4. Ponta a ponta só com as duas apps implementadas (T016); sem isso, fica pendente e documentado.

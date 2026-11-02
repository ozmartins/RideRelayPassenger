---

description: "Task list for 008-receber-orcamentos"

---

# Tasks: Receber, persistir e decidir entre orçamentos

**Contrato**: emenda 07 (kinds 20003/20004) já escrita e replicada no motorista (Princípio IV).

**Tests**: incluídos, mesmo padrão já usado pelas features 002–007 deste app.

**Organization**: US1 é P1, US2 é P1.

---

## Phase 1: Setup

- [x] T001 Adiciona `sqflite: ^2.4.4` e `path` a `pubspec.yaml`, roda `flutter pub get` (D1 de
  `research.md`)

## Phase 2: Foundational

- [x] T002 [P] Acrescenta `tags` (`List<List<String>>`) a `NostrEvent`, em
  `lib/domain/nostr_event.dart`
- [x] T003 [P] Cria `ReceivedQuote` (campos de `data-model.md`; fábrica `fromNostrEvent` que
  decodifica `content` e a tag `e`, lança `FormatException` se malformado) em
  `lib/domain/received_quote.dart`
- [x] T004 [P] Cria a abstração `ReceivedQuoteStore` (`save`, `byRequest(requestId)`) e
  `SqfliteReceivedQuoteStore` (esquema de D2 de `research.md`) em
  `lib/services/received_quote_store.dart` (depende de T003)
- [x] T005 [P] Cria dublê em memória de `ReceivedQuoteStore` para os testes de tela, em
  `test/screens/map_screen_test.dart` (ou arquivo próprio, seguindo a convenção já usada)
- [x] T006 Torna `EventFeed.acceptedKinds` configurável (constructor, default `{1}`); atualiza
  `subscriptionRequest()` para instância (usa `acceptedKinds`); `_onEvent` passa a checar
  `acceptedKinds.contains(kind)` em vez do `kind != 1` fixo; constrói `NostrEvent` com `tags`, em
  `lib/services/event_feed.dart` (depende de T002)
- [x] T007 Acrescenta `rideQuoteKind = 20002` (constante já existe informalmente; formaliza ao
  lado de `rideRequestKind`) em `lib/services/event_feed.dart`
- [x] T008 Atualiza `test/services/event_feed_test.dart` para o novo `acceptedKinds` e para a
  aceitação de `kind: 20002` com `tags` (depende de T006, T007)
- [x] T009 Acrescenta `publishQuoteAcceptance(quote, identity)` e
  `publishQuoteRejection(quote, identity)` a `EventFeed` (generaliza `_publish` para aceitar tags
  extras — `["e", quote.quoteId]` e `["p", quote.driverPubkey]`; `content` vazio), em
  `lib/services/event_feed.dart` (depende de T003)
- [x] T010 Testa `publishQuoteAcceptance`/`publishQuoteRejection`: `kind`, tags (`t`, `e`, `p`) e
  `content` vazio corretos, assinatura válida, em `test/services/event_feed_test.dart` (depende
  de T009)
- [x] T011 Acrescenta `NostrEvent.kindRideQuote` (20002) ao `acceptedKinds` do `EventFeed`
  construído em `lib/main.dart` (depende de T006, T007)

**Checkpoint**: app aceita e verifica `kind: 20002`; nenhuma tela ainda reage a ele.

---

## Phase 3: User Story 1 — Ver todos os orçamentos da solicitação ativa (Priority: P1) 🎯 MVP

### Tests

- [x] T012 [P] [US1] Teste: `ReceivedQuote.fromNostrEvent` decodifica `content`/tag `e` válidos e
  lança `FormatException` para malformado, em `test/domain/received_quote_test.dart`
- [x] T013 [P] [US1] Teste: `SqfliteReceivedQuoteStore.save` seguido de `byRequest` devolve os
  orçamentos daquele `requestId`, em `test/services/received_quote_store_test.dart`
- [x] T014 [US1] Teste: orçamento referenciando a solicitação ativa abre a modal com os dados
  esperados (nome, marca, modelo, ano, total, eta), em `test/screens/map_screen_test.dart`
- [x] T015 [US1] Teste: segundo orçamento da mesma solicitação atualiza a modal já aberta, sem
  substituir o primeiro, em `test/screens/map_screen_test.dart`
- [x] T016 [US1] Teste: orçamento de outra solicitação (ou sem solicitação ativa) não é
  persistido nem exibido, em `test/screens/map_screen_test.dart`
- [x] T017 [P] [US1] Teste: `RideQuotesModal` exibe "não disponível" (nunca zero) quando
  `etaMinutes` é `null`, em `test/screens/ride_quotes_modal_test.dart`

### Implementação

- [x] T018 [US1] Cria `RideQuotesModal` (recebe `ValueListenable<List<ReceivedQuote>>` e
  `onAccept`; lista cada orçamento com nome/marca/modelo/ano/total/eta e botão "Aceitar") em
  `lib/screens/ride_quotes_modal.dart` (depende de T003)
- [x] T019 [US1] Em `MapScreen`: após `_solicitarCorrida` publicar com sucesso, guarda
  `_solicitacaoAtivaId` e reinicia `_orcamentosRecebidos`; escuta `eventFeed.events` filtrando
  `kind: 20002` com `requestId == _solicitacaoAtivaId`; persiste via `ReceivedQuoteStore`; exibe
  `RideQuotesModal` no primeiro orçamento, em `lib/screens/map_screen.dart` (depende de T004,
  T006, T018). **Desvio da tarefa original**: não usa `showDialog`/`Navigator` — a modal é
  renderizada condicionalmente na própria árvore (`Stack` sobre o `Scaffold`, controlada por
  `_modalOrcamentosVisivel`). Motivo: em teste de widget, a entrega do evento atravessa três
  `StreamController` em cadeia enquanto o `FlutterMap` mantém requisições HTTP reais de tiles em
  voo; sob essas condições o `Navigator.push` do `showDialog` nunca chega a construir a rota
  dentro da janela do relógio falso do `flutter_test` — reprodutível de forma isolada, não
  contornável só ajustando o teste. Renderizar a modal como parte do próprio `build()` depende
  apenas de `setState`, sem essa dependência.
- [x] T020 [US1] Passa `receivedQuoteStore` real para `MapScreen` em `lib/main.dart` (depende de
  T004, T019)

**Checkpoint**: US1 completa — modal exibe e atualiza com os orçamentos recebidos; "Aceitar"
ainda não publica nada.

---

## Phase 4: User Story 2 — Aceitar um orçamento (Priority: P1)

### Tests

- [x] T021 [P] [US2] Teste: tocar "Aceitar" em um orçamento publica aceitação para ele e recusa
  para cada outro já recebido da mesma solicitação, em `test/screens/map_screen_test.dart`
- [x] T022 [US2] Teste: sem relay conectado, "Aceitar" informa a falha, sem fechar a modal, em
  `test/screens/map_screen_test.dart`
- [x] T023 [US2] Teste: aceitação confirmada fecha a modal, em `test/screens/map_screen_test.dart`
- [x] T024 [US2] Teste: depois de aceito, um novo orçamento da mesma solicitação é persistido mas
  não reabre a modal nem gera recusa automática, em `test/screens/map_screen_test.dart`

### Implementação

- [x] T025 [US2] Implementa o callback `onAccept` de `RideQuotesModal` em `MapScreen`: valida
  relay conectado, publica aceitação (escolhido) e recusa (demais da lista atual), marca
  `_corridaDecidida = true`, fecha a modal em sucesso, em `lib/screens/map_screen.dart` (depende
  de T009, T019)

**Checkpoint**: US1 + US2 completas — feature 008 do passageiro pronta ponta a ponta.

---

## Phase 5: Polish

- [x] T026 [P] `flutter analyze`
- [x] T027 `flutter test` completo
- [ ] T028 Executa os cinco cenários do `quickstart.md` em dois aparelhos/emuladores
- [ ] T029 Registra a feature no `CLAUDE.md` da raiz, em commit separado

---

description: "Task list for 006-solicitar-corrida"

---

# Tasks: Solicitar corrida

**Input**: Design documents from `specs/006-solicitar-corrida/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md),
[contracts/ride-request-event.md](./contracts/ride-request-event.md),
[quickstart.md](./quickstart.md)

**Contrato de interoperabilidade**: `specs/002-nostr-relay-connection/contracts/nostr-events.md`
(emenda 04, `kind: 20001`) já foi escrito e replicado de forma idêntica na app do motorista durante o
planejamento desta feature (Princípio IV — contrato antes do código). Nenhuma tarefa abaixo o
recria; T029 apenas confere que a replicação permanece íntegra antes de considerar a feature
concluída.

**Tests**: incluídos, seguindo o mesmo padrão já usado pelas features 002–005 deste app (dublê de
transporte/rede, nunca rede real nos testes automatizados — Princípio II). O Princípio II torna
obrigatório o teste da parte que assina o evento (`EventFeed.publishRideRequest`); os demais testes
seguem a convenção do projeto, não uma exigência não-negociável da constituição.

**Organization**: tarefas agrupadas por user story do `spec.md` (US1 é P1, US2 é P2, US3 é P3).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependência entre si)
- **[Story]**: US1, US2 ou US3, conforme `spec.md`
- Caminhos de arquivo exatos, relativos a `Prototipo/passenger/`

## Path Conventions

Projeto mobile único (`lib/`, `test/`), estrutura já em uso pelas features 001–005: `lib/domain/`,
`lib/services/`, `lib/screens/`, espelhados em `test/domain/`, `test/services/`, `test/screens/`
(exceto `test/event_feed_test.dart` e `test/home_screen_test.dart`, que ficam na raiz de `test/` por
convenção já estabelecida nas features anteriores).

---

## Phase 1: Setup

Não aplicável — esta feature não introduz nenhuma dependência nova em `pubspec.yaml` (Constitution
Check, Princípio III por vacuidade). Nenhuma tarefa nesta fase.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: entidades, extensão dos serviços existentes e plumbing de `MapScreen` que as três user
stories usam

**⚠️ CRITICAL**: nenhuma user story pode começar antes desta fase

- [X] T001 [P] Criar o enum `PaymentMethod` (`cash`/`pix`/`card`), com rótulo de exibição em
      português e o valor de contrato (`"dinheiro"`/`"pix"`/`"cartao"`) de cada opção, em
      `lib/domain/payment_method.dart`, conforme `data-model.md` (D3 de `research.md`)
- [X] T002 [P] Criar o teste de `PaymentMethod` (rótulo de exibição e valor de contrato de cada
      opção) em `test/domain/payment_method_test.dart`
- [X] T003 [P] Criar a entidade `RideRequest` (`origin`, `destination`, `payment`) em
      `lib/domain/ride_request.dart`, conforme `data-model.md`
- [X] T004 [P] Criar o teste de `RideRequest` em `test/domain/ride_request_test.dart`
- [X] T005 [P] Estender `AddressSuggestion` com `latitude`/`longitude` (`double`) em
      `lib/domain/address_suggestion.dart`, conforme `data-model.md` (D4 de `research.md`)
- [X] T006 [P] Atualizar `test/domain/address_suggestion_test.dart` cobrindo os novos campos
      (igualdade continua só por `id`)
- [X] T007 [P] Estender `DestinationAddress` com `latitude`/`longitude`, atualizando `==`/`hashCode`
      para considerá-los, em `lib/domain/destination_address.dart`, conforme `data-model.md`
- [X] T008 [P] Atualizar `test/domain/destination_address_test.dart` cobrindo os novos campos e a
      nova igualdade (dois destinos com mesmo texto e coordenadas diferentes não são mais iguais)
- [X] T009 Atualizar `PhotonGeocodingService._paraSugestao` para ler `geometry.coordinates` (formato
      GeoJSON `[lon, lat]`) e preencher `latitude`/`longitude` de `AddressSuggestion`, em
      `lib/services/geocoding_service.dart` (depende de T005)
- [X] T010 Atualizar `test/services/geocoding_service_test.dart` cobrindo a leitura das coordenadas,
      incluindo um caso que falharia se a ordem `[lon, lat]` do GeoJSON fosse trocada (depende de
      T009)
- [X] T011 Acrescentar o campo `DestinationAddress? _destino` a `_MapScreenState`: definido (com
      lat/lon da sugestão) em `_selecionarSugestao`; limpo em `_aoMudarTexto` apenas quando o texto
      resultante fica vazio — preservando o destino anterior em edição parcial, mesma regra já
      estabelecida pela feature 005 (`quickstart.md` da feature 005, Cenário 4) — em
      `lib/screens/map_screen.dart` (depende de T007)
- [X] T012 [P] Acrescentar `Future<PublishReport> publishRideRequest(RideRequest request, Identity
      identity)` a `EventFeed` (`kind: 20001`, tag `["t", "tcc-ufsc-caronas"]`, `content` conforme
      `contracts/ride-request-event.md`) em `lib/services/event_feed.dart` (depende de T001, T003)
- [X] T013 Atualizar `test/event_feed_test.dart` cobrindo `publishRideRequest`: `kind` correto, tag de
      marcador presente, forma do `content` (incluindo a tradução de cada `PaymentMethod` para o
      valor de contrato), e relato com `byRelay` vazio quando nenhum relay está conectado (depende de
      T012)
- [X] T014 Ampliar o construtor de `MapScreen` para receber `EventFeed`, `Identity` e `RelayService`
      (obrigatórios), atualizando o comentário de topo do arquivo — que hoje afirma que a tela nunca
      recebe `RelayService`/`EventFeed` — para refletir a decisão da clarificação da sessão
      2026-09-20, em `lib/screens/map_screen.dart` (depende de T012)
- [X] T015 Passar `eventFeed`, `identity` e `relayService` (já instanciados em `_Shell`) para
      `MapScreen` em `lib/main.dart` (depende de T014)

**Checkpoint**: `flutter analyze` e `flutter test` passam com o que existe até aqui; a tela ainda não
tem botão nem seletor de pagamento — isso é US1

---

## Phase 3: User Story 1 — Solicitar corrida com destino e pagamento definidos (Priority: P1) 🎯 MVP

**Goal**: com posição atual, destino e forma de pagamento disponíveis, tocar "Solicitar corrida"
monta, assina e publica o evento `kind: 20001` nos relays conectados, com confirmação visível

**Independent Test**: cenário 2 de `quickstart.md` — escolher destino e forma de pagamento, tocar
"Solicitar corrida", observar a confirmação

### Tests for User Story 1

> Escrever estes testes primeiro; devem falhar até a implementação desta fase

- [X] T016 [P] [US1] Teste de widget: o seletor de forma de pagamento mostra "Dinheiro"
      pré-selecionado e permite trocar para "PIX" ou "Cartão", em
      `test/screens/map_screen_test.dart`
- [X] T017 [P] [US1] Teste de widget: com posição, destino (via `FakeGeocodingService` + seleção) e
      forma de pagamento disponíveis, e um relay conectado (`EventFeed` real + `RelayService` real +
      `FakeTransport`, mesmo padrão de `test/home_screen_test.dart`), tocar "Solicitar corrida" chama
      `EventFeed.publishRideRequest` com `origin` = última posição, `destination` = destino
      selecionado (com lat/lon) e `payment` = forma selecionada, e mostra confirmação, em
      `test/screens/map_screen_test.dart`
- [X] T018 [P] [US1] Teste de widget: sem nenhum relay conectado, tocar "Solicitar corrida" não
      publica nada e mostra mensagem de "nenhum relay conectado" (FR-010), em
      `test/screens/map_screen_test.dart`

### Implementation for User Story 1

- [X] T019 [US1] Acrescentar `SegmentedButton<PaymentMethod>` (D5 de `research.md`) à faixa inferior
      da tela, junto do campo de destino, com `PaymentMethod.cash` pré-selecionado, em
      `lib/screens/map_screen.dart` (depende de T001, T016)
- [X] T020 [US1] Acrescentar o botão "Solicitar corrida" à faixa inferior da tela, em
      `lib/screens/map_screen.dart`
- [X] T021 [US1] Implementar o manipulador do botão: checar `relayService.hasAnyConnected` (mensagem
      de erro e não prosseguir se falso — FR-010), montar `RideRequest` a partir de `_posicao`,
      `_destino` e a forma de pagamento selecionada, chamar `eventFeed.publishRideRequest`, mostrar
      confirmação com a contagem de relays que aceitaram (mesmo padrão de `HomeScreen._publicar`) ou
      mensagem de falha, com estado de carregamento que desabilita o botão durante a chamada (FR-009,
      FR-010), em `lib/screens/map_screen.dart` (depende de T011, T014, T017, T018, T019, T020)

**Checkpoint**: US1 funcional e testável de forma independente — cenário 2 do `quickstart.md`

---

## Phase 4: User Story 2 — Tentar solicitar corrida sem destino escolhido (Priority: P2)

**Goal**: tocar "Solicitar corrida" sem destino escolhido não publica nada e explica o motivo

**Independent Test**: cenário 3 de `quickstart.md` — campo de destino vazio ou com texto sem seleção,
tocar "Solicitar corrida", observar a mensagem, sem nenhum evento montado

### Tests for User Story 2

- [X] T022 [P] [US2] Teste de widget: com o campo de destino vazio, tocar "Solicitar corrida" não
      chama `publishRideRequest` e mostra mensagem orientando a escolher um destino, em
      `test/screens/map_screen_test.dart`
- [X] T023 [P] [US2] Teste de widget: com texto digitado no campo de destino mas nenhuma sugestão
      tocada, tocar "Solicitar corrida" tem o mesmo efeito do teste anterior (FR-004/FR-005 da
      feature 005 — `DestinationAddress` só existe por seleção explícita), em
      `test/screens/map_screen_test.dart`
- [X] T024 [P] [US2] Teste de widget: selecionar uma sugestão e depois apagar todo o campo de destino
      faz "Solicitar corrida" voltar a se comportar como sem destino escolhido (Edge Case do
      `spec.md`), em `test/screens/map_screen_test.dart`

### Implementation for User Story 2

- [X] T025 [US2] No manipulador de T021, checar `_destino == null` **antes** de montar `RideRequest`;
      se nulo, mostrar a mensagem de destino ausente e não chamar `publishRideRequest`, em
      `lib/screens/map_screen.dart` (depende de T021, T022, T023)
- [X] T026 [US2] Confirmar, a partir de T024, que `_aoMudarTexto` zera `_destino` quando o texto fica
      vazio (comportamento já introduzido em T011); ajustar se o teste encontrar lacuna, em
      `lib/screens/map_screen.dart` (depende de T011, T024)

**Checkpoint**: US1 + US2 funcionais juntas — falta só a validação de posição ausente (US3)

---

## Phase 5: User Story 3 — Tentar solicitar corrida sem posição atual disponível (Priority: P3)

**Goal**: tocar "Solicitar corrida" sem posição atual disponível não publica nada e explica o motivo

**Independent Test**: cenário 4 de `quickstart.md` — negar permissão de localização, escolher
destino, tocar "Solicitar corrida", observar a mensagem, sem nenhum evento montado

### Tests for User Story 3

- [X] T027 [P] [US3] Teste de widget: com destino e forma de pagamento definidos, mas
      `LocationService` dublê que nunca emite posição, tocar "Solicitar corrida" não chama
      `publishRideRequest` e mostra mensagem de posição indisponível, em
      `test/screens/map_screen_test.dart`

### Implementation for User Story 3

- [X] T028 [US3] No manipulador de T021/T025, checar `_posicao == null` **depois** da checagem de
      destino e **antes** de montar `RideRequest`; se nula, mostrar mensagem de posição indisponível
      (reaproveitando o texto já usado por `_mensagemIndisponibilidade`) e não chamar
      `publishRideRequest`, em `lib/screens/map_screen.dart` (depende de T021, T025, T027)

**Checkpoint**: as três user stories funcionam de forma independente e juntas

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: fechar os gates da constituição e a rastreabilidade acadêmica

- [X] T029 [P] Conferir por diff que `specs/002-nostr-relay-connection/contracts/nostr-events.md`
      permanece idêntico entre `driver/` e `passenger/` (exceto o cabeçalho de procedência do
      passageiro) — Princípio IV
- [X] T030 Rodar `flutter analyze` — esperado "No issues found!"
- [X] T031 Rodar `flutter test` — esperado todos os testes passando, incluindo os desta feature
- [ ] T032 Executar os cenários 2 a 6 do `quickstart.md` em aparelho/emulador com rede real (relays
      configurados e Photon), incluindo a verificação de não vazamento (Princípio I) e a verificação
      de privacidade do `content` publicado (Cenário 5, com um segundo cliente Nostr inscrito em
      `kind: 20001`), e registrar os resultados
- [X] T033 Registrar a feature 006 no `CLAUDE.md` da raiz do repositório, em commit separado desta
      implementação (Padrão de Commits, granularidade)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: não aplicável
- **Foundational (Phase 2)**: bloqueia as três user stories — nenhuma pode montar/publicar um evento
  sem `PaymentMethod`, `RideRequest`, as coordenadas de destino ou `publishRideRequest`
- **US1 (Phase 3)**: depende do Foundational; é a base de US2 e US3 — o manipulador do botão (T021)
  nasce nesta fase e é estendido, não reescrito, pelas fases seguintes
- **US2 (Phase 4)**: depende de US1 (T021, o manipulador) — acrescenta a checagem de destino antes da
  checagem já existente de relay conectado
- **US3 (Phase 5)**: depende de US1 e US2 (T021/T025) — acrescenta a checagem de posição, na ordem
  definida pelo `spec.md` (destino antes de posição)
- **Polish (Phase 6)**: depende de US1, US2 e US3 completas

### Parallel Opportunities

- T001–T008 (Foundational, entidades) em paralelo entre si
- T012 (Foundational, `EventFeed`) em paralelo com T005–T011 (arquivos diferentes)
- T016, T017, T018 (testes de US1) em paralelo entre si, antes de T019–T021
- T022, T023, T024 (testes de US2) em paralelo entre si, depois de T021
- T027 (teste de US3) pode começar assim que T021/T025 existirem
- T029 pode rodar a qualquer momento a partir do início da implementação; T030–T033 são sequenciais
  entre si (T033 é commit separado, por definição)

---

## Parallel Example: Foundational

```bash
# Entidades em paralelo:
Task: "Criar PaymentMethod em lib/domain/payment_method.dart"
Task: "Criar RideRequest em lib/domain/ride_request.dart"
Task: "Estender AddressSuggestion com lat/lon em lib/domain/address_suggestion.dart"
Task: "Estender DestinationAddress com lat/lon em lib/domain/destination_address.dart"
```

## Parallel Example: User Story 1

```bash
# Testes de US1 em paralelo:
Task: "Teste do seletor de pagamento em test/screens/map_screen_test.dart"
Task: "Teste do caminho feliz de publicação em test/screens/map_screen_test.dart"
Task: "Teste de nenhum relay conectado em test/screens/map_screen_test.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Completar Phase 2 (Foundational)
2. Completar Phase 3 (US1) — solicitar corrida com tudo disponível
3. **PARAR e VALIDAR**: cenário 2 de `quickstart.md`
4. US1 sozinha já cumpre o requisito central do pedido de feature (montar e publicar a solicitação),
   mas sem as validações de US2/US3 o botão pode tentar publicar com destino ou posição ausentes de
   forma menos amigável — não é um estado final entregável

### Incremental Delivery

1. Foundational → base pronta (entidades, `publishRideRequest`, plumbing de `MapScreen`)
2. US1 → validar cenário 2 → solicitação completa publicada com confirmação
3. US2 → validar cenário 3 → destino ausente bloqueado com mensagem clara (aqui a feature cumpre a
   validação que o pedido original nomeia explicitamente)
4. US3 → validar cenário 4 → posição ausente também bloqueada
5. Polish → validar cenários 5 e 6, gates da constituição, e registrar no `CLAUDE.md`

---

## Notes

- [P] = arquivos diferentes, sem dependência entre as tarefas marcadas
- Commits seguem a seção Padrão de Commits da constituição — uma mudança lógica por commit; T033 é
  necessariamente um commit à parte, depois desta implementação
- Verificar que os testes falham antes de implementar (T016–T018, T022–T024, T027)
- O contrato de eventos (`kind: 20001`) já foi replicado na app do motorista durante o planejamento
  (Princípio IV); T029 apenas confere que a replicação permanece íntegra, não a refaz

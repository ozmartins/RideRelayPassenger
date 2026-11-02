---

description: "Task list for 007-rota-ate-destino"

---

# Tasks: Rota real até o destino

**Input**: Design documents from `specs/007-rota-ate-destino/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [quickstart.md](./quickstart.md)

**Sem contrato de evento**: esta feature não cria, altera nem consome nenhum evento Nostr (FR-009) —
não há `contracts/` nem tarefa de replicação para o motorista.

**Tests**: incluídos, seguindo o mesmo padrão já usado pelas features 002–006 deste app (dublê de
serviço, nunca rede real nos testes automatizados — Princípio II aplicado por analogia a
`RouteService`, mesmo padrão de `GeocodingService`/`LocationService`).

**Organization**: tarefas agrupadas por user story do `spec.md` (US1 é P1, US2 é P2, US3 é P3).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependência entre si)
- **[Story]**: US1, US2 ou US3, conforme `spec.md`
- Caminhos de arquivo exatos, relativos a `Prototipo/passenger/`

## Path Conventions

Projeto mobile único (`lib/`, `test/`), estrutura já em uso pelas features 001–006: `lib/domain/`,
`lib/services/`, `lib/screens/`, espelhados em `test/domain/`, `test/services/`, `test/screens/`.

---

## Phase 1: Setup

- [x] T001 Adiciona `open_route_service: ^1.2.9` a `pubspec.yaml` e roda `flutter pub get`
  (já feito nesta sessão, antes do spec-kit; decisão registrada em `research.md` D1)

---

## Phase 2: Foundational (bloqueante para todas as user stories)

- [x] T002 [P] Cria `RouteResult` em `lib/domain/route_result.dart` (campos `points`,
  `distanceMeters`, `originUsed`, `destination` — `data-model.md`)
- [x] T003 [P] Cria a abstração `RouteService` (método `route({origin, destination})`, lança em
  qualquer falha) em `lib/services/route_service.dart`
- [x] T004 [US1][US2][US3] Implementa `OrsRouteService` (implementa `RouteService`, encapsula
  `open_route_service.OpenRouteService`, perfil `driving-car`, chave lida de
  `String.fromEnvironment('ORS_API_KEY')` — D1/D3 de `research.md`) em
  `lib/services/route_service.dart`
- [x] T005 [P] Cria `FakeRouteService` (dublê controlável: sucesso com `RouteResult` fixo, falha
  configurável, atraso configurável para testar descarte de resposta tardia — FR-008) em
  `test/services/route_service_test.dart`

**Checkpoint**: `RouteService`/`RouteResult`/`FakeRouteService` prontos; nenhuma tela ainda os usa.

---

## Phase 3: User Story 1 — Ver a distância real até o destino (Priority: P1) 🎯 MVP

**Goal**: exibir a distância do trajeto rodoviário na tela do mapa sempre que posição atual e destino
estiverem disponíveis, recalculando ao trocar de destino ou a cada 50 m de deslocamento.

**Independent Test**: escolher um destino com posição atual disponível e verificar que a distância
exibida é maior ou igual à distância em linha reta entre os dois pontos (quickstart.md, cenário 1).

### Tests para User Story 1

- [x] T006 [P] [US1] Teste: `RouteResult` guarda `points`/`distanceMeters`/`originUsed`/`destination`
  corretamente, em `test/domain/route_result_test.dart`
- [x] T007 [P] [US1] Teste: `MapScreen` exibe a distância retornada por `RouteService.route` quando
  um destino é escolhido com posição atual disponível, em `test/screens/map_screen_test.dart`
- [x] T008 [US1] Teste: trocar de destino dispara novo cálculo e substitui a distância exibida (não
  mistura resultado de dois destinos — FR-003, FR-008), em `test/screens/map_screen_test.dart`
- [x] T009 [US1] Teste: limpar o destino remove a distância exibida (FR-005), em
  `test/screens/map_screen_test.dart`
- [x] T010 [US1] Teste: recálculo só ocorre após deslocamento maior que 50 m da origem usada no
  último cálculo, nunca a cada atualização de posição (D2 de `research.md`, FR-003), em
  `test/screens/map_screen_test.dart`

### Implementação para User Story 1

- [x] T011 [US1] Adiciona estado de rota calculada (`RouteResult?`) e a lógica de disparo do cálculo
  (posição + destino disponíveis, troca de destino, threshold de 50 m) em
  `lib/screens/map_screen.dart`
- [x] T012 [US1] Exibe a distância (`distanceMeters` formatado) na tela do mapa, associada ao destino
  atual, em `lib/screens/map_screen.dart`

**Checkpoint**: US1 completa e testável de forma independente — distância exibida, sem traçado no
mapa ainda.

---

## Phase 4: User Story 2 — Ver o trajeto traçado no mapa (Priority: P2)

**Goal**: desenhar o trajeto calculado no `flutter_map` como uma linha contínua entre a posição atual
e o destino.

**Independent Test**: com um destino escolhido e a distância exibida (US1), verificar que uma linha
contínua aparece no mapa seguindo vias reais (quickstart.md, cenário 2).

### Tests para User Story 2

- [x] T013 [P] [US2] Teste: `MapScreen` desenha um `Polyline` com os `points` de `RouteResult` quando
  o cálculo termina, em `test/screens/map_screen_test.dart`
- [x] T014 [US2] Teste: trocar de destino substitui o `Polyline` anterior pelo novo (não acumula
  linhas), em `test/screens/map_screen_test.dart`

### Implementação para User Story 2

- [x] T015 [US2] Adiciona `PolylineLayer` ao `FlutterMap` de `lib/screens/map_screen.dart`,
  desenhando `RouteResult.points` quando disponível

**Checkpoint**: US1 + US2 completas — distância e traçado exibidos juntos.

---

## Phase 5: User Story 3 — Lidar com rota indisponível (Priority: P3)

**Goal**: absorver falha do cálculo de rota sem bloquear nenhuma outra ação da tela, em especial
"Solicitar corrida" (feature 006).

**Independent Test**: simular indisponibilidade do serviço de rota com um destino já escolhido e
verificar que a tela permanece funcional e "Solicitar corrida" continua operante (quickstart.md,
cenário 4).

### Tests para User Story 3

- [x] T016 [P] [US3] Teste: falha de `RouteService.route` (via `FakeRouteService` configurado para
  lançar) resulta em indicação não bloqueante na tela, sem exceção não tratada, em
  `test/screens/map_screen_test.dart`
- [x] T017 [US3] Teste: com falha de cálculo de rota já ocorrida, "Solicitar corrida" continua
  disponível e publica o evento normalmente (integração com a feature 006), em
  `test/screens/map_screen_test.dart`

### Implementação para User Story 3

- [x] T018 [US3] Adiciona tratamento de exceção ao redor da chamada de `RouteService.route` em
  `lib/screens/map_screen.dart`, exibindo indicação não bloqueante de falha em vez de propagar erro

**Checkpoint**: US1 + US2 + US3 completas — feature 007 pronta ponta a ponta.

---

## Phase 6: Polish

- [x] T019 [P] Roda `flutter analyze` e corrige qualquer apontamento
- [ ] T020 Executa os cinco cenários do `quickstart.md` em aparelho/emulador real (com chave de API
  válida via `--dart-define=ORS_API_KEY=...`) e relata resultado no próprio `quickstart.md` — inclui
  o cenário 5 (origem e destino coincidentes). **Pendente**: nenhum emulador/aparelho disponível
  nesta sessão; requer chave de API real de <https://openrouteservice.org/dev/#/signup>.
- [x] T021 Confere que nenhum dado de usuário além das coordenadas de origem/destino é enviado ao
  serviço de roteamento (verificação da exceção da constituição 2.3.0 — inspeção do tráfego/URL
  montada por `OrsRouteService`). Verificado por leitura de código: `directions.dart` do pacote monta
  a URL só com `start=lng,lat&end=lng,lat` e a chave vai no cabeçalho `Authorization` — nenhum
  `pubkey`, nome ou apelido de exibição é referenciado em `OrsRouteService` nem no restante do
  caminho de chamada em `MapScreen._calcularRota`.

---

## Dependencies

- **Phase 1 → Phase 2**: T001 já concluída; Phase 2 pode começar imediatamente.
- **Phase 2 → todas as user stories**: T002–T005 bloqueiam T006 em diante (US1, US2, US3 dependem de
  `RouteResult`/`RouteService`/`FakeRouteService`).
- **US1 → US2**: US2 depende do estado de rota calculada que US1 introduz em `MapScreen` (T011); não
  há como desenhar o traçado sem ele.
- **US1 → US3**: US3 trata falha do mesmo ponto de disparo que US1 cria (T011); implementada depois.
- **US2 e US3 entre si**: independentes uma da outra — podem ser feitas em qualquer ordem depois de
  US1.

## Parallel Execution Examples

- Dentro da Phase 2: T002, T003 e T005 tocam arquivos diferentes e podem ser feitas em paralelo;
  T004 depende de T003 (a abstração precisa existir antes da implementação real).
- Dentro da Phase 3: T006 e T007 tocam arquivos diferentes ([P]); T008–T010 tocam o mesmo arquivo de
  teste que T007 e por isso não são [P] entre si.
- T019 (Phase 6) pode rodar em paralelo com T020/T021, que dependem de aparelho/emulador.

## Implementation Strategy

**MVP** = Phase 1 + Phase 2 + Phase 3 (User Story 1): distância real exibida, sem traçado no mapa e
sem tratamento especial de falha além do que `RouteService` já lança. Entrega o valor central da
feature (saber a distância real antes de solicitar) e é demonstrável isoladamente.

**Incremento seguinte** = Phase 4 (US2): reforço visual do traçado.

**Fechamento** = Phase 5 (US3) + Phase 6: robustez a falha do serviço externo e validação em
aparelho real, incluindo os cenários que só aparecem fora de teste automatizado (T020).

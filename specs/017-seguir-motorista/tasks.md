# Tasks: Seguir o motorista no mapa do passageiro

**Input**: documentos em `specs/017-seguir-motorista/` (`plan.md`, `spec.md`, `research.md`, `data-model.md`, `quickstart.md`)

**Tests**: pedidos pelo Princípio II/V da constituição apenas onde há decisão a verificar; aqui, testes de widget em `test/screens/map_screen_test.dart`, escritos antes do código de cada história.

Todos os caminhos são relativos a `Prototipo/passenger/`.

## Phase 1: Setup

- [X] T001 Rodar `flutter test test/screens/map_screen_test.dart` e `flutter analyze` e registrar a linha de base (tudo verde) antes de alterar qualquer arquivo

## Phase 2: Foundational

- [X] T002 Em `test/screens/map_screen_test.dart`, remover o grupo `enquadramento e "Centralizar" (FR-007)` (comportamento revogado pelo FR-006 desta feature) — os cenários que o substituem entram nas fases das histórias

## Phase 3: User Story 1 — Acompanhar o motorista sem mexer no mapa (P1) 🎯 MVP

**Goal**: em "motorista a caminho", a câmera fica no motorista e o segue; o GPS do passageiro não a move.

**Independent Test**: duas posições distantes do motorista → centro do mapa = primeira, depois = segunda; GPS do passageiro não altera o centro.

- [X] T003 [US1] Em `test/screens/map_screen_test.dart`, novo grupo `seguir o motorista (feature 017)`: (a) primeira posição válida centraliza no motorista; (b) posição seguinte move o centro para o novo ponto e o zoom se mantém; (c) `gps.emitir(...)` não altera o centro; (d) em "motorista a caminho" sem posição válida do motorista o GPS ainda move o mapa (FR-005); (e) posição inválida/duplicada/mais antiga não move a câmera; (f) SC-004: 10 posições consecutivas, sem nenhum gesto no mapa (`tester.drag`/`tester.tap` ausentes), terminam com o centro na décima; (g) reabrir o app já em `motoristaACaminho` com o mapa ainda carregando (`_carregando`) e só então chegar a primeira posição: o mapa nasce centrado no motorista (`initialCenter`, D2)
- [X] T004 [US1] Em `lib/screens/map_screen.dart`, substituir `_enquadrarMotorista` por um método que faz `_mapController.move(ponto do motorista, _mapController.camera.zoom)` quando o mapa está montado (guarda `camera.zoom.isNaN`), chamado em `_processarLocalizacaoMotorista` a cada posição aceita (`nova != null`) (D2)
- [X] T005 [US1] Em `lib/screens/map_screen.dart`, ajustar `_aoReceberPosicao` para mover a câmera só quando **não** estiver seguindo o motorista (`_rideStatus == motoristaACaminho && _posicaoMotorista != null`, D1/D3), e usar a posição do motorista como `initialCenter` do `MapOptions` nesse caso, para a primeira posição não se perder se o mapa ainda não estiver montado
- [X] T006 [US1] Rodar `flutter test test/screens/map_screen_test.dart` — T003 deve passar

## Phase 4: User Story 2 — Sem botão "Centralizar" (P1)

**Goal**: o botão não existe em "motorista a caminho" e, como só existia ali, deixa de existir no app.

**Independent Test**: em "motorista a caminho", com e sem posição do motorista, `find.byIcon(Icons.my_location)` não encontra nada.

- [X] T007 [US2] Em `test/screens/map_screen_test.dart`, cenários: sem `Icons.my_location` antes da primeira posição, depois dela e depois de arrastar o mapa (`tester.drag`); a próxima posição do motorista traz a câmera de volta a ele
- [X] T008 [US2] Em `lib/screens/map_screen.dart`, remover o `Positioned` do botão (condição `!_seguindoPassageiro`), a classe `_BotaoCentralizar`, `_centralizarNoPassageiro`, `_enquadrarMotorista` (se ainda restar), os campos `_seguindoPassageiro` e `_motoristaEnquadrado` e suas atribuições em `_limparPosicaoMotorista` (D1); remover imports que ficarem sem uso
- [X] T009 [US2] Rodar `flutter analyze` ("No issues found!") e `flutter test test/screens/map_screen_test.dart`

## Phase 5: User Story 3 — Voltar ao normal ao sair do estado (P2)

**Goal**: fora de "motorista a caminho" o mapa volta a seguir o passageiro; nova corrida não herda posição.

**Independent Test**: de "motorista a caminho" a "encontro confirmado", o próximo GPS volta a mover o mapa.

- [X] T010 [US3] Em `test/screens/map_screen_test.dart`, cenários: (a) após confirmar o encontro, `gps.emitir(...)` volta a centralizar no passageiro e o marcador do motorista some; (b) nova corrida depois do fim da anterior chega a "motorista a caminho" sem herdar a posição antiga (câmera segue o passageiro até a primeira posição nova)
- [X] T011 [US3] Se T010 falhar, corrigir em `lib/screens/map_screen.dart` (`_limparPosicaoMotorista` e seus pontos de chamada, D1); caso contrário, registrar que a derivação de D1 já cobre o cenário

## Phase 6: Polish

- [X] T012 Rodar a suíte completa (`flutter test`) e `flutter analyze`; anotar o total de testes
- [X] T013 Atualizar `specs/017-seguir-motorista/quickstart.md` se algum cenário manual mudou durante a implementação e deixar a validação em aparelho marcada como pendente
- [X] T014 Atualizar o `CLAUDE.md` da raiz do repositório: (a) acrescentar a entrada da feature `017-seguir-motorista` do passageiro (substitui o enquadramento e o botão "Centralizar"; sem contrato, sem contrapartida no motorista); (b) corrigir na entrada da `016-posicao-do-motorista` do passageiro a frase sobre enquadrar os dois e parar de seguir o passageiro até o botão "Centralizar", marcando-a como superada pela 017; commit à parte do código (Padrão de Commits)

## Dependencies

T001 → T002 → US1 (T003 → T004 → T005 → T006) → US2 (T007 → T008 → T009) → US3 (T010 → T011) → Polish.
Tudo no mesmo arquivo de produção e no mesmo arquivo de teste: sem tarefas paralelas.

## Implementation Strategy

MVP = US1 (a câmera segue o motorista). US2 remove o botão e o estado morto; US3 é a verificação das bordas, em geral já coberta pela derivação de D1.

# Tasks: Posição do motorista no mapa do passageiro

**Input**: Design documents from `/specs/016-posicao-do-motorista/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: **obrigatórios** (Princípio II; nenhum teste toca rede) para a validação do `content`, a conferência de autor/corrida/estado e o comportamento do mapa.

**Organization**: Setup (contrato antes do código, Princípio IV) → Foundational → US1 → US2 → US3 → Polish.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependência entre si)
- Caminhos relativos a `Prototipo/passenger/`, salvo indicação

---

## Phase 1: Setup — contrato antes do código (Princípio IV)

- [X] T001 Escrever a emenda 12 do contrato **nas duas cópias, de forma idêntica**: em `Prototipo/driver/specs/002-nostr-relay-connection/contracts/nostr-events.md` (fonte) e em `specs/002-nostr-relay-connection/contracts/nostr-events.md` (cópia; atualizar o cabeçalho de procedência para a emenda 12). Acrescentar a linha 12 na tabela "Histórico de emendas" (nenhum formato muda; o passageiro passa a exibir `lat`/`lon` do `kind: 20005`, só em "motorista a caminho", só em memória — feature 016 do passageiro) e reescrever a nota "Consumo pelo passageiro (emenda 10)" da seção *Conteúdo do kind 20005*, que hoje diz "não decodifica nem exibe `lat`/`lon`". Conferir com `diff` que as cópias só diferem no cabeçalho.

---

## Phase 2: Foundational — domínio

- [X] T002 [P] Escrever `test/domain/driver_location_test.dart`: `fromNostrEvent` aceita `{"lat":-28.9,"lon":-49.4}` e guarda `reportedAt` = `createdAt`; recusa (`FormatException`) JSON inválido, não-objeto, `lat`/`lon` ausentes, string/`null`/NaN/infinito, `lat` fora de −90..90 e `lon` fora de −180..180; `isNewerThan` é `true` com `other == null` ou instante estritamente posterior, e `false` para igual ou anterior. Deve falhar antes de T003.
- [X] T003 Criar `lib/domain/driver_location.dart` (`DriverLocation`, `fromNostrEvent`, `isNewerThan`, conforme `data-model.md`) até T002 passar; sem tipos de `dart_nostr`/Flutter.

**Checkpoint**: `flutter analyze` limpo; `flutter test test/domain` verde.

---

## Phase 3: User Story 1 — Ver onde o motorista está (P1) 🎯 MVP

**Goal**: marcador do motorista no mapa, na posição recebida, em "motorista a caminho".

**Independent Test**: corrida aceita + localização válida do motorista → marcador nas coordenadas.

### Tests (escrever primeiro; devem falhar)

- [X] T004 [P] [US1] Em `test/screens/map_screen_test.dart` (reaproveitando `montarComCorridaAceita`/`localizacaoDeTeste`, ajustando o helper para aceitar `lat`/`lon`/`createdAt`): a localização que leva de "orçamento aceito" a "motorista a caminho" já mostra o marcador no ponto recebido (FR-001, FR-002); uma segunda, mais nova, move o marcador sem duplicá-lo (FR-003); mais antiga, igual ou repetida (mesmo `id`) não o move (FR-008).
- [X] T005 [P] [US1] Mesmo arquivo: restaurar `motoristaACaminho` de `PassengerRideStateStore`/`AcceptedRideStore` sem marcador; a próxima localização o faz aparecer (reinício, FR-009); malformada (JSON ruim, sem `lat`, fora de faixa) não cria nem altera o marcador e não gera erro visível (FR-008), mas, vinda do motorista aceito em "orçamento aceito", ainda causa a transição para "motorista a caminho" (G1).
- [X] T006 [P] [US1] Mesmo arquivo: o aviso "motorista a caminho" (feature 009) continua aparecendo uma única vez por corrida, e o toque em "OK" continua funcionando com o marcador na tela (FR-011).
- [X] T007 [P] [US1] Mesmo arquivo — enquadramento (FR-007, D6): na primeira exibição, a câmera passa a conter motorista e passageiro; uma nova posição de GPS do passageiro **não** recentraliza o mapa; uma nova posição do motorista **não** reenquadra; o botão "Centralizar" aparece só então, move a câmera para a posição do passageiro e volta a fazer o mapa segui-lo; sem posição do passageiro, centraliza no motorista.

### Implementation

- [X] T008 [US1] Em `lib/screens/map_screen.dart`, acrescentar `_posicaoMotorista`, `_motoristaEnquadrado` e `_seguindoPassageiro` (`data-model.md`) e reescrever `_processarLocalizacaoMotorista`: manter o `id` deduplicado e a transição de estado existentes; depois de conferir o estado (`orcamentoAceito` — com a transição — ou `motoristaACaminho`), aplicar `DriverLocation.fromNostrEvent` (descartando `FormatException` sem tocar o marcador) e `isNewerThan` (D4), e guardar a posição.
- [X] T009 [US1] Em `_MapScreenState`, limpar `_posicaoMotorista`/`_motoristaEnquadrado` e religar `_seguindoPassageiro` quando `_corridaAceita` muda (aceitar orçamento, `_finalizarAvaliacao`, restauração) e ao sair de `motoristaACaminho` (D5).
- [X] T010 [US1] Em `build()`, desenhar o marcador do motorista numa `MarkerLayer` própria, acima da do passageiro, só com `_rideStatus == motoristaACaminho && _posicaoMotorista != null`; usar o widget `_MarcadorCircular` com `Icons.directions_car` (criado em T013).
- [X] T011 [US1] Enquadramento (D6): `_aoReceberPosicao` só chama `_mapController.move` se `_seguindoPassageiro`; na primeira exibição do marcador por corrida, `fitCamera(CameraFit.coordinates(...))` (padding 48/96/48/170, `maxZoom: 17`), `_motoristaEnquadrado = true` e `_seguindoPassageiro = false`, protegido pela mesma checagem de `camera.zoom.isNaN` já usada.
- [X] T012 [US1] Botão "Centralizar" (círculo branco de 48 px, ícone `roxo`, `semanticLabel: 'Centralizar no mapa'`) visível só em `motoristaACaminho && !_seguindoPassageiro`, no canto inferior direito; ao tocar, `move` para a posição do passageiro (zoom 16) e `_seguindoPassageiro = true`.

**Checkpoint**: T004–T007 passam; quickstart 1–3.

---

## Phase 4: User Story 2 — Mesmo símbolo do app do motorista (P1)

**Goal**: o motorista é desenhado como no app dele, distinto do passageiro.

**Independent Test**: comparar a decoração e o ícone do marcador.

- [X] T013 [US2] Criar, em `lib/screens/map_screen.dart`, o widget privado `_MarcadorCircular({icon, semanticLabel})` com o desenho do motorista (D7: `Container` circular, `IdentidadeVisual.fundo`, borda branca 2 px, sombra `0x33000000`/blur 6/offset (0, 2), ícone 24 px em `destaque`); usá-lo no marcador do motorista (T010). Não alterar o marcador do próprio passageiro.
- [X] T014 [P] [US2] Em `test/screens/map_screen_test.dart`: o marcador do motorista tem 44×44, `BoxShape.circle`, cor `IdentidadeVisual.fundo`, borda branca de 2 px, ícone `Icons.directions_car` em `destaque` com `semanticLabel`; e o marcador do passageiro (`Icons.person_pin_circle`) segue sendo outro, distinguível (FR-004, FR-012).

**Checkpoint**: T014 passa; quickstart 4.

---

## Phase 5: User Story 3 — Só o motorista certo, só no momento certo (P2)

**Goal**: filtrar por autor, corrida e estado.

**Independent Test**: eventos de outro autor/corrida/estado não alteram o mapa.

- [X] T015 [P] [US3] Em `test/screens/map_screen_test.dart`: localização referenciando a corrida aceita mas assinada por **outra chave** não cria marcador nem causa a transição de estado (D3, FR-005); referenciando outra corrida, ignorada; em "inicial", "aguardando orçamentos" e depois de "encontro confirmado"/"destino confirmado" nenhum marcador aparece; em "orçamento aceito", uma localização rejeitada pelos filtros (autor ou corrida errados) não cria marcador nem causa transição; ao confirmar o encontro em "motorista a caminho", o marcador some e o mapa volta a seguir o passageiro (FR-006); ao finalizar a corrida e iniciar outra, a posição anterior não reaparece.
- [X] T016 [US3] Em `_processarLocalizacaoMotorista` (`lib/screens/map_screen.dart`), exigir `evento.authorPublicKey == corridaAceita.driverPubkey`, além da referência `["e", quoteId]`, **antes** da transição de estado (D3); ajustar, se algum teste existente da feature 009/014 assinar a localização com outra chave, o helper do teste — não o código.

**Checkpoint**: T015 passa; quickstart 5 e 6.

---

## Phase 6: Polish & cross-cutting

- [X] T017 `flutter analyze` ("No issues found!") e `flutter test` integral verdes; confirmar no diff que nenhuma linha do `driver/lib` mudou e que o formato de nenhum evento mudou (FR-010).
- [ ] T018 (PENDENTE: só havia alvo `linux`; registrado no quickstart) Executar o `quickstart.md` em aparelho/emulador e preencher a tabela de Medições (SC-001 ≤ 1 s, SC-004 5 de 5, SC-005); sem aparelho, registrar "validação em aparelho pendente" no próprio arquivo.
- [X] T019 Commit da emenda do contrato (T001, as duas cópias juntas) à parte; commit de implementação (T002–T016) em português, direto na `master`, com trailer `Co-Authored-By:` (Padrão de Commits).
- [X] T020 Commit à parte atualizando `../CLAUDE.md` (raiz do TCC) com a feature `016-posicao-do-motorista` do passageiro: marcador do motorista, conferência de autor (aperto da 009/014), enquadramento e botão "Centralizar", emenda 12, testes passando, validação em aparelho pendente.

---

## Dependencies & Execution Order

- T001 antes de qualquer código (Princípio IV). T002 → T003. US1 depende de T003; T010 usa o widget de T013 (fazer T013 junto de T010).
- US2 e US3 dependem do marcador de US1 em código, mas cada uma é verificável sozinha.
- Testes [P] da mesma história escrevem no mesmo arquivo: agrupar em uma edição, não rodar em paralelo de fato.

## Implementation Strategy

- **MVP**: T001–T013 (marcador visível, com o aspecto certo e o enquadramento).
- **Incremental**: US2 trava a aparência por teste; US3 fecha o filtro de autor/estado, que também endurece o gatilho da 009/014.

## Notes

- Verificar que T002, T004–T007, T014 e T015 falham antes de implementar.
- Commits separados: contrato (T001), implementação (T019) e `CLAUDE.md` (T020). Sem emenda de constituição.

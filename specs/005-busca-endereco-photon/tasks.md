---

description: "Task list for 005-busca-endereco-photon"

---

# Tasks: Busca de Endereço via Photon

**Input**: Design documents from `specs/005-busca-endereco-photon/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/geocoding-service.md](./contracts/geocoding-service.md),
[quickstart.md](./quickstart.md)

**Tests**: incluídos. O `plan.md` (Technical Context) já descreve os testes de unidade e de widget
desta feature, e o padrão do projeto (feature 004, `README.md`) cobre serviço e tela com dublê —
seguido aqui, embora o Princípio II não torne testes obrigatórios para este código (não é
assinatura/verificação).

**Organization**: tarefas agrupadas por user story do `spec.md` (US1 e US2 são ambas P1; US3 é P2).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependência entre si)
- **[Story]**: US1, US2 ou US3, conforme `spec.md`
- Caminhos de arquivo exatos, relativos a `Prototipo/passenger/`

## Path Conventions

Projeto mobile único (`lib/`, `test/`), estrutura já em uso pelas features 001–004: `lib/domain/`,
`lib/services/`, `lib/screens/`, espelhados em `test/domain/`, `test/services/`, `test/screens/`.

---

## Phase 1: Setup

**Purpose**: preparar a dependência HTTP antes de qualquer código da feature

- [X] T001 Promover `http` de dependência transitiva a direta em `pubspec.yaml`, fixando
      `http: ^1.6.0` (D1 de `research.md`), e rodar `flutter pub get`

**Checkpoint**: `flutter pub get` conclui sem erro e `pubspec.lock` continua resolvendo `http` em
`1.6.0`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: entidade e interface de serviço que as três user stories usam

**⚠️ CRITICAL**: nenhuma user story pode começar antes desta fase

- [X] T002 [P] Criar a entidade `AddressSuggestion` (`id`, `displayText`, igualdade por `id`) em
      `lib/domain/address_suggestion.dart`, conforme `data-model.md`
- [X] T003 [P] Criar o teste da entidade (igualdade por `id`, não por `displayText`) em
      `test/domain/address_suggestion_test.dart`
- [X] T004 [P] Definir a interface `GeocodingService` (`Future<List<AddressSuggestion>> search(String
      text)`) em `lib/services/geocoding_service.dart`, conforme `contracts/geocoding-service.md`
- [X] T005 [P] Criar o dublê de `GeocodingService` para os testes de tela (respostas programadas:
      lista de sugestões, lista vazia, exceção) em `test/support/fake_geocoding_service.dart`

**Checkpoint**: `flutter analyze` e `flutter test` passam com o que existe até aqui; nenhuma tela ou
serviço real ainda depende disso

---

## Phase 3: User Story 1 — Ver sugestões de endereço enquanto digita (Priority: P1) 🎯 MVP

**Goal**: ao digitar no campo de destino, o passageiro vê uma lista de endereços sugeridos pela
Photon, atualizada conforme o texto muda, sem publicar nada em relay

**Independent Test**: cenário 2 de `quickstart.md` — digitar um trecho de endereço real e observar a
lista de sugestões aparecer, sem nenhum destino ainda registrado

### Tests for User Story 1

> Escrever estes testes primeiro; devem falhar até a implementação desta fase

- [X] T006 [P] [US1] Teste de `PhotonGeocodingService.search`: sucesso com resultados (monta
      `AddressSuggestion.displayText` a partir de `name`/`street`/`housenumber`/`city`ou`county`/
      `state`/`country`), sucesso com lista vazia, erro HTTP, corpo malformado e timeout de 5 s —
      usando um `http.Client` dublê, em `test/services/geocoding_service_test.dart` (contratos de
      `contracts/geocoding-service.md`)
- [X] T007 [P] [US1] Teste de widget: sugestões aparecem depois do debounce de 400 ms e a partir de 3
      caracteres digitados (D3 de `research.md`), lista atualiza ao continuar digitando ou apagar
      parte do texto, nenhuma sugestão com campo vazio, usando `FakeGeocodingService`, em
      `test/screens/map_screen_test.dart`

### Implementation for User Story 1

- [X] T008 [US1] Implementar `PhotonGeocodingService` (chamada HTTPS a
      `https://photon.komoot.io/api/` com `q`, `lang=pt`, `limit=5`, timeout de 5 s, parsing da
      resposta GeoJSON em `AddressSuggestion`, exceção em qualquer falha) em
      `lib/services/geocoding_service.dart` (depende de T004, T006)
- [X] T009 [US1] Adicionar debounce (`Timer`, 400 ms) e mínimo de 3 caracteres antes de chamar
      `GeocodingService.search` a partir do `_destinoController` em `lib/screens/map_screen.dart`
      (depende de T007)
- [X] T010 [US1] Exibir a lista de sugestões retornada abaixo do campo de destino, substituindo o
      `onChanged: (_) => setState(() {})` da feature 004, em `lib/screens/map_screen.dart` (depende
      de T009)
- [X] T011 [US1] Injetar `GeocodingService` em `MapScreen` (mesmo padrão de `locationService`:
      obrigatório no construtor, dublê nos testes) e passar `PhotonGeocodingService()` a partir de
      `main.dart`

**Checkpoint**: US1 funcional e testável de forma independente — sugestões aparecem ao digitar;
nenhuma seleção ainda existe (isso é US2)

---

## Phase 4: User Story 2 — Selecionar um endereço sugerido como destino (Priority: P1)

**Goal**: tocar uma sugestão registra aquele endereço exato como destino; o texto bruto digitado
nunca vira destino por si só

**Independent Test**: cenários 3 e 4 de `quickstart.md` — selecionar uma sugestão define o destino;
editar o texto depois preserva o destino anterior até nova seleção

### Tests for User Story 2

- [X] T012 [P] [US2] Teste de widget: tocar uma sugestão define o destino com o `displayText` exato
      dela (mesmo quando difere do texto digitado) e fecha a lista, em `test/screens/map_screen_test.dart`
- [X] T013 [P] [US2] Teste de widget: destino permanece o da última seleção ao editar o texto de novo
      sem tocar outra sugestão; nova seleção substitui o destino anterior, em
      `test/screens/map_screen_test.dart`
- [X] T014 [P] [US2] Teste de widget: digitar sem tocar nenhuma sugestão nunca registra destino, em
      `test/screens/map_screen_test.dart`

### Implementation for User Story 2

- [X] T015 [US2] Ao tocar uma sugestão da lista (T010), construir `DestinationAddress` a partir do seu
      `displayText`, mostrar esse texto no campo e fechar a lista de sugestões, em
      `lib/screens/map_screen.dart` (depende de T010, T012)
- [X] T016 [US2] Garantir que editar o texto depois de uma seleção reinicia a busca (T009) sem apagar
      o destino já registrado, só substituindo-o quando uma nova sugestão for tocada, em
      `lib/screens/map_screen.dart` (depende de T015, T013)
- [X] T017 [US2] Atualizar o comentário de `lib/domain/destination_address.dart` — deixa de aceitar
      "qualquer texto... sem validação" e passa a documentar que só é construído a partir do
      `displayText` de uma `AddressSuggestion` selecionada (`data-model.md`)

**Checkpoint**: US1 + US2 funcionais juntas — busca e seleção completas; falta só o tratamento de
exceção (US3) e o desfazer-destino (Edge Case, fase de Polish)

---

## Phase 5: User Story 3 — Lidar com buscas sem resultado ou com falha (Priority: P2)

**Goal**: mensagens claras quando a busca não encontra nada ou o serviço falha, sem travar a tela

**Independent Test**: cenários 5 e 6 de `quickstart.md` — texto sem correspondência mostra "nenhum
resultado"; rede desligada mostra mensagem de falha, sem travamento

### Tests for User Story 3

- [X] T018 [P] [US3] Teste de widget: busca sem resultado mostra mensagem de "nenhum endereço
      encontrado" (`FakeGeocodingService` retornando lista vazia), em
      `test/screens/map_screen_test.dart`
- [X] T019 [P] [US3] Teste de widget: falha da busca (`FakeGeocodingService` lançando exceção) mostra
      mensagem de falha sem travar a tela, e uma nova tentativa depois de editar o texto funciona, em
      `test/screens/map_screen_test.dart`

### Implementation for User Story 3

- [X] T020 [US3] Tratar o retorno vazio de `GeocodingService.search` mostrando a mensagem de "nenhum
      endereço encontrado" em vez de lista vazia silenciosa, em `lib/screens/map_screen.dart`
      (depende de T009, T018)
- [X] T021 [US3] Capturar exceção de `GeocodingService.search`, mostrar mensagem de falha (reaproveitando
      o padrão de `_AvisoIndisponibilidade`/mensagem inline já usado para localização) sem travar a
      tela, e permitir nova tentativa ao editar o texto, em `lib/screens/map_screen.dart` (depende de
      T009, T019)

**Checkpoint**: as três user stories funcionam de forma independente e juntas

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: cobrir o Edge Case restante e fechar os gates da constituição

- [X] T022 [P] Teste de widget: apagar todo o texto do campo depois de uma seleção volta ao estado
      "sem destino definido", sem nenhuma sugestão visível (FR-012, Edge Case do `spec.md`), em
      `test/screens/map_screen_test.dart`
- [X] T023 Implementar o comportamento de T022 em `lib/screens/map_screen.dart`
- [X] T024 Rodar `flutter analyze` — esperado "No issues found!"
- [X] T025 Rodar `flutter test` — esperado todos os testes passando, incluindo os desta feature
- [X] T026 Executar os cenários 2 a 8 do `quickstart.md` em aparelho/emulador com rede real até a
      Photon, incluindo a verificação de não vazamento (inspeção da requisição HTTP: só `q`, `lang`,
      `limit` — nunca chave pública, nome de exibição ou posição), e registrar os resultados
- [ ] T027 Registrar a feature 005 no `CLAUDE.md` da raiz do repositório, em commit separado desta
      implementação (Padrão de Commits, granularidade)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sem dependências — pode começar imediatamente
- **Foundational (Phase 2)**: depende do Setup — bloqueia as três user stories
- **US1 (Phase 3)**: depende do Foundational; é a base de US2 (não há sugestão para selecionar sem
  busca funcionando)
- **US2 (Phase 4)**: depende de US1 (T010, a lista de sugestões) — ambas são P1, mas seleção não existe
  sem a lista que a busca produz
- **US3 (Phase 5)**: depende do Foundational e de T009 (o ponto onde a busca é disparada); independente
  de US2 — trata o caminho de exceção da mesma chamada que US1 usa no caminho de sucesso
- **Polish (Phase 6)**: depende de US1, US2 e US3 completas

### Parallel Opportunities

- T002–T005 (Foundational) em paralelo entre si
- T006, T007 (testes de US1) em paralelo entre si, antes de T008–T011
- T012, T013, T014 (testes de US2) em paralelo entre si, depois de T010
- T018, T019 (testes de US3) em paralelo entre si, depois de T009
- T024 e T025 podem rodar em sequência simples; T026 e T027 não são paralelizáveis com o resto (T027
  é commit separado, por definição)

---

## Parallel Example: User Story 1

```bash
# Testes de US1 em paralelo:
Task: "Teste de PhotonGeocodingService.search em test/services/geocoding_service_test.dart"
Task: "Teste de widget de sugestões ao digitar em test/screens/map_screen_test.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Completar Phase 1 (Setup) e Phase 2 (Foundational)
2. Completar Phase 3 (US1) — sugestões aparecem ao digitar
3. **PARAR e VALIDAR**: cenário 2 de `quickstart.md`
4. US1 sozinha não substitui a feature 004 por completo (destino ainda não é registrado por seleção)
   — é um incremento observável, não um estado final entregável

### Incremental Delivery

1. Setup + Foundational → base pronta
2. US1 → validar cenário 2 → sugestões visíveis
3. US2 → validar cenários 3 e 4 → destino só por seleção explícita (aqui a feature já cumpre FR-004,
   seu requisito central)
4. US3 → validar cenários 5 e 6 → caminhos de exceção cobertos
5. Polish → validar cenário 7, gates da constituição, e registrar no CLAUDE.md

---

## Notes

- [P] = arquivos diferentes, sem dependência entre as tarefas marcadas
- Commits seguem a seção Padrão de Commits da constituição — uma mudança lógica por commit; T027 é
  necessariamente um commit à parte, depois desta implementação
- Verificar que os testes falham antes de implementar (T006/T007, T012–T014, T018/T019, T022)
- Nenhuma tarefa desta feature introduz ou altera evento Nostr, lista de relays ou marcador — nada a
  replicar em `driver/`

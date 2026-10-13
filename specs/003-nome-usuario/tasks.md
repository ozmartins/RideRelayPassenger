---

description: "Task list for feature 003-nome-usuario"
---

# Tasks: Nome do Usuário no Passageiro

**Input**: Design documents from `/specs/003-nome-usuario/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md (sem `contracts/`
— feature não toca o contrato de eventos, ver plan.md)

**Tests**: Incluídos. Não são exigidos pelo Princípio II (esta feature não assina nem verifica
eventos), mas seguem a convenção já estabelecida no projeto — todo serviço e toda tela novos têm
teste automatizado (`test/services/`, `test/screens/`).

**Organization**: Tarefas agrupadas por user story (US1 = primeira execução, US2 = alteração de
nome), conforme `spec.md`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Pode rodar em paralelo (arquivos diferentes, sem dependência pendente)
- **[Story]**: US1 ou US2, conforme `spec.md`
- Caminhos de arquivo são relativos a `passenger/`

## Path Conventions

Projeto único Flutter (`passenger/`): `lib/` para código, `test/` para testes, espelhando a
estrutura de `domain/` + `services/` + `screens/` já em uso.

---

## Phase 1: Setup

**Purpose**: Confirmar que nenhuma configuração ou dependência nova é necessária

- [X] T001 Confirmar que `shared_preferences` já está declarado em `pubspec.yaml` e que nenhuma
      dependência nova precisa ser adicionada (decisão D1 de `specs/003-nome-usuario/research.md`)
      — sem alteração de arquivo se a confirmação for positiva

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Entidade e serviço compartilhados pelas duas user stories

**⚠️ CRITICAL**: Nenhuma user story pode começar antes desta fase estar completa

- [X] T002 [P] Criar a entidade `UserProfile` (campo `displayName`) em
      `lib/domain/user_profile.dart`, conforme `specs/003-nome-usuario/data-model.md`
- [X] T003 [P] Escrever teste de `NameService` (carregar nome inexistente retorna `null`; salvar
      e recarregar retorna o valor salvo; salvar nome vazio/só espaços é rejeitado; salvar nome
      acima de 60 caracteres é rejeitado) usando um dublê de `KeyValueStore` em
      `test/services/name_service_test.dart` — escrever ANTES da implementação, e confirmar que
      falha
- [X] T004 Implementar `NameService` em `lib/services/name_service.dart`, recebendo um
      `KeyValueStore` por injeção (mesmo padrão de `RelayRepository`), com `Future<String?>
      loadName()` e `Future<void> saveName(String name)` que faz trim, valida não-vazio e limite
      de 60 caracteres (lança exceção de validação se inválido) antes de persistir sob uma chave
      fixa (depende de T002, T003)

**Checkpoint**: `NameService` testado e funcionando isoladamente — as user stories podem começar

---

## Phase 3: User Story 1 - Pedir o nome na primeira execução (Priority: P1) 🎯 MVP

**Goal**: Ao abrir o app sem nome salvo, a pessoa vê uma tela pedindo o nome antes da tela
principal; ao confirmar um nome válido, o nome é salvo e a tela principal aparece.

**Independent Test**: Instalar o app do zero, abrir, confirmar que a tela de nome aparece antes
da tela principal, informar um nome válido, confirmar, e verificar que a tela principal é
exibida e que o nome persiste numa reabertura (ver `quickstart.md`, Cenário 1).

### Tests for User Story 1 ⚠️

> **NOTE: escrever estes testes PRIMEIRO, confirmar que falham antes de implementar**

- [X] T005 [P] [US1] Teste de widget da `NameScreen` em modo de criação (`initialName: null`):
      botão de confirmar desabilitado/recusado com campo vazio, habilita/aceita com texto válido,
      chama o callback de salvar com o texto (trimado) em `test/screens/name_screen_test.dart`
- [X] T006 [P] [US1] Teste de widget da `NameScreen`: erro de validação exibido ao tentar
      confirmar com campo vazio ou só espaços em branco, em
      `test/screens/name_screen_test.dart`
- [X] T007 [P] [US1] Teste de widget da `NameScreen`: erro de validação exibido ao tentar
      confirmar com nome acima de 60 caracteres, em `test/screens/name_screen_test.dart`
- [X] T008 [P] [US1] Teste de widget da `NameScreen`: mensagem de erro exibida e tela mantida
      quando o salvamento falha (callback de salvar lança exceção), em
      `test/screens/name_screen_test.dart`

### Implementation for User Story 1

- [X] T009 [US1] Criar `NameScreen` em `lib/screens/name_screen.dart`: campo de texto, validação
      de não-vazio (trim) e limite de 60 caracteres, botão de confirmar que chama um callback
      assíncrono `onSave(String)` recebido por parâmetro, exibindo indicador de carregamento
      durante o salvamento e mensagem de erro (via `SnackBar`, mesmo padrão de `home_screen.dart`)
      se o callback lançar exceção (depende de T005-T008 escritos e falhando)
- [X] T010 [US1] Em `lib/main.dart`, no `_Bootstrap`, carregar o nome salvo (via `NameService`)
      junto da identidade e, quando não houver nome salvo, exibir `NameScreen` (modo criação,
      `initialName: null`) com `onSave` chamando `NameService.saveName` e então navegando para a
      `HomeScreen`; quando já houver nome salvo, ir direto para a `HomeScreen` como hoje (depende
      de T004, T009)

**Checkpoint**: US1 completa e testável de forma independente — instalar do zero, informar o
nome, chegar à tela principal, nome persiste numa reabertura

---

## Phase 4: User Story 2 - Alterar o nome já salvo (Priority: P2)

**Goal**: A partir da tela principal, a pessoa acessa uma tela com o nome atual preenchido, pode
trocá-lo e salvar, ou sair sem salvar mantendo o nome anterior.

**Independent Test**: Com um nome já salvo, abrir a tela de alteração, verificar o campo
preenchido com o nome atual, trocar e salvar, reabrir o app e verificar que o novo nome
persiste; em outra passagem, trocar o texto e sair sem salvar, verificando que o nome anterior
permanece (ver `quickstart.md`, Cenário 2).

### Tests for User Story 2 ⚠️

- [X] T011 [P] [US2] Teste de widget da `NameScreen` em modo de edição (`initialName:
      "<nome atual>"`): campo aparece pré-preenchido com o nome atual, em
      `test/screens/name_screen_test.dart`
- [X] T012 [P] [US2] Teste de widget: ao salvar um novo nome válido em modo de edição, o callback
      `onSave` é chamado com o novo valor (trimado), em `test/screens/name_screen_test.dart`
- [X] T013 [P] [US2] Teste de widget: ao sair da tela sem confirmar (`Navigator.pop` sem tocar em
      salvar), `onSave` NÃO é chamado, em `test/screens/name_screen_test.dart`
- [X] T014 [P] [US2] Teste de widget da `HomeScreen`: ação para abrir a tela de alteração de nome
      está presente e navega para `NameScreen` com o nome atual, em
      `test/home_screen_test.dart`

### Implementation for User Story 2

- [X] T015 [US2] Em `lib/screens/home_screen.dart`, acrescentar uma ação (ícone na `AppBar`, mesmo
      padrão das ações de identidade/relays) que navega para `NameScreen` em modo de edição,
      passando o nome atual e um `onSave` que persiste via `NameService` e retorna (`pop`) ao
      concluir (depende de T004, T009, T011-T014 escritos e falhando)
- [X] T016 [US2] Repassar o nome atual (carregado por T010) e o `NameService` para a `HomeScreen`
      a partir de `_Bootstrap` em `lib/main.dart`, para que a ação de T015 tenha o que precisa
      (depende de T010, T015)

**Checkpoint**: US1 e US2 funcionando de forma independente e em conjunto

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Verificação final exigida pelos gates da constituição

- [X] T017 Rodar `flutter analyze` a partir de `passenger/` e confirmar "No issues found!"
- [X] T018 Rodar `flutter test` a partir de `passenger/` e confirmar que toda a suíte passa, sem
      teste ignorado
- [X] T019 Executar os três cenários de `specs/003-nome-usuario/quickstart.md` em
      aparelho/emulador Android e registrar o resultado (o que passou, o que falhou, se algo
      falhou) no commit ou no relatório de implementação, conforme Princípio V — executado no
      emulador `Pixel_6_API34_1` em 2026-09-17: os três cenários passaram integralmente (tela de
      nome antes da principal, validação de vazio, confirmação com nome válido, persistência
      entre reaberturas, edição pré-preenchida, edição rejeitando campo vazio, saída sem salvar
      preservando o nome anterior, e reabertura após interrupção sem nome confirmado voltando a
      pedir o nome)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sem dependências — T001 é só uma confirmação
- **Foundational (Phase 2)**: depende do Setup — BLOQUEIA as duas user stories
- **User Story 1 (Phase 3)**: depende do Foundational; é o MVP
- **User Story 2 (Phase 4)**: depende do Foundational e reaproveita a `NameScreen` criada em US1
  (T009) — não é implementável isoladamente de US1 porque ambas compartilham a mesma tela por
  design (decisão D2 de `research.md`), mas é testável e entregável como incremento separado
  depois de US1 pronta
- **Polish (Phase 5)**: depende de US1 e US2 completas

### Parallel Opportunities

- T002 e T003 (Foundational) podem rodar em paralelo — arquivos diferentes
- T005-T008 (testes de US1) podem rodar em paralelo entre si
- T011-T014 (testes de US2) podem rodar em paralelo entre si
- T009 (implementação da `NameScreen`) só pode começar depois que T005-T008 estiverem escritos e
  falhando

---

## Parallel Example: User Story 1

```bash
# Testes de US1 em paralelo (escrever antes da implementação):
Task: "Teste de widget: validação de campo vazio em test/screens/name_screen_test.dart"
Task: "Teste de widget: validação de limite de 60 caracteres em test/screens/name_screen_test.dart"
Task: "Teste de widget: erro de salvamento exibido em test/screens/name_screen_test.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Completar Phase 1 (Setup) e Phase 2 (Foundational)
2. Completar Phase 3 (US1)
3. **PARAR E VALIDAR**: rodar o Cenário 1 de `quickstart.md` em aparelho/emulador
4. US1 já é um incremento demonstrável: primeira execução pede o nome e ele persiste

### Incremental Delivery

1. Setup + Foundational → `NameService` pronto e testado
2. US1 → validar Cenário 1 → MVP demonstrável
3. US2 → validar Cenário 2 → feature completa
4. Polish → gates da constituição (T017-T019)

---

## Notes

- [P] = arquivos diferentes, sem dependência pendente
- [Story] mapeia a tarefa à user story correspondente, para rastreabilidade
- Escrever os testes antes da implementação e confirmar que falham, por convenção do projeto
  (Princípio II não exige aqui, mas o padrão já estabelecido nas features anteriores é seguido)
- Commitar cada mudança lógica separadamente, seguindo a seção "Padrão de Commits" da
  constituição — em particular, T002-T004 (fundação) e cada user story completa são candidatos
  naturais a commits próprios
- Parar em qualquer checkpoint para validar a story isoladamente antes de seguir

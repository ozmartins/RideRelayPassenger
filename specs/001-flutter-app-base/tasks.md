---

description: "Task list for feature 001-flutter-app-base (passenger)"
---

# Tasks: Base do Aplicativo do Passageiro

**Input**: Design documents from `specs/001-flutter-app-base/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md (sem `contracts/` — a
feature não expõe interface externa)

**Tests**: incluídos. FR-006 exige explicitamente uma suíte de testes automatizados executável, e SC-003
faz dela um critério de sucesso mensurável.

**Organization**: tarefas agrupadas por user story, para que cada uma seja implementável e testável
independentemente.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependências pendentes)
- **[Story]**: a qual user story a tarefa pertence (US1, US2, US3)
- Todos os caminhos são relativos à raiz do repositório do TCC

## Path Conventions

Projeto Flutter único em `Prototipo/passenger/`: código em `lib/`, testes em `test/`, projeto Android
gerado em `android/`. Conforme a Structure Decision de `plan.md`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: gerar o esqueleto do projeto Flutter sobre o diretório existente do spec-kit.

- [X] T001 Gerar o projeto Flutter sobre o diretório existente executando, em `Prototipo/passenger/`: `flutter create . --project-name passenger --org br.ufsc.tcc.corridas --platforms android --description "Aplicativo do passageiro do protótipo de corridas P2P sobre Nostr (TCC UFSC)"` — cria `lib/main.dart`, `test/`, `android/`, `pubspec.yaml`, `analysis_options.yaml`, `.gitignore` (decisões D2, D3, D4, D5 de `specs/001-flutter-app-base/research.md`)
- [X] T002 Verificar com `git status` na raiz do repositório que o scaffold não alterou nem removeu nada em `Prototipo/passenger/.specify/`, `Prototipo/passenger/.claude/` ou `Prototipo/passenger/specs/`; reverter seletivamente se tiver alterado (mitigação do risco registrado em D5)
- [X] T003 Confirmar que `Prototipo/passenger/` não contém `ios/`, `web/`, `linux/`, `macos/` nem `windows/`; remover se o scaffold tiver gerado algum (FR-005)
- [X] T004 Baixar as dependências executando `flutter pub get` em `Prototipo/passenger/` e confirmar que conclui sem erro

**Checkpoint**: projeto Flutter gerado, apenas com plataforma Android, scaffold do spec-kit intacto.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: identidade do aplicativo e gate de análise estática — pré-requisitos de todas as stories.

- [X] T005 Verificar em `Prototipo/passenger/android/app/build.gradle.kts` que `namespace` e `applicationId` são `br.ufsc.tcc.corridas.passenger`; corrigir se o scaffold divergir (FR-010)
- [X] T006 Definir o nome de exibição do aplicativo alterando `android:label` para `Corridas Passageiro` em `Prototipo/passenger/android/app/src/main/AndroidManifest.xml` (FR-010, US1 cenário 4)
- [X] T007 Conferir em `Prototipo/passenger/android/app/src/main/AndroidManifest.xml` que nenhuma permissão além do padrão do scaffold é declarada — em especial nenhuma de rede ou localização (FR-004, FR-011)
- [X] T008 Conferir em `Prototipo/passenger/pubspec.yaml` que o nome do pacote é `passenger` e que não há nenhuma dependência de terceiros além de `cupertino_icons`, `flutter_test` e `flutter_lints` (FR-011, decisão D9)
- [X] T009 Confirmar que `Prototipo/passenger/analysis_options.yaml` inclui `package:flutter_lints/flutter.yaml` e executar `flutter analyze` em `Prototipo/passenger/` como baseline (FR-007)

**Checkpoint**: app identificado como "Corridas Passageiro" / `br.ufsc.tcc.corridas.passenger`, sem permissões extras, sem dependências de terceiros, análise estática ativa.

---

## Phase 3: User Story 1 — Abrir o aplicativo do passageiro (Priority: P1) 🎯 MVP

**Goal**: o app compila, instala e abre em um dispositivo Android exibindo uma tela inicial vazia identificada como o app do passageiro.

**Independent Test**: instalar em emulador/aparelho e verificar que abre sem erros exibindo "Corridas Passageiro", sem contador e sem diálogo de permissão.

- [X] T010 [US1] Criar `Prototipo/passenger/lib/shared/app_info.dart` com as constantes de identidade do app: nome de exibição `'Corridas Passageiro'` e a mensagem de placeholder da tela inicial (FR-008, data-model.md)
- [X] T011 [US1] Criar `Prototipo/passenger/lib/screens/home_screen.dart` com um `StatelessWidget` `HomeScreen`: `Scaffold` com `AppBar` exibindo o nome de exibição vindo de `app_info.dart` e corpo centralizado com a mensagem de placeholder; sem `FloatingActionButton`, sem `setState`, sem contador (FR-002, FR-003, decisão D6)
- [X] T012 [US1] Reescrever `Prototipo/passenger/lib/main.dart` removendo todo o boilerplate de contador do template: `main()` chamando `runApp`, widget raiz `CorridasPassengerApp` com `MaterialApp` usando `title` de `app_info.dart`, `themeMode: ThemeMode.system` e `home: const HomeScreen()` (FR-002, FR-003, edge case de tema escuro)
- [X] T013 [US1] Substituir o teste gerado `Prototipo/passenger/test/widget_test.dart` por `Prototipo/passenger/test/home_screen_test.dart`, com um teste nomeado "exibe o título da tela inicial" que monta `CorridasPassengerApp`, verifica que "Corridas Passageiro" é exibido e que não existe nenhum widget de contador remanescente do template; apagar `widget_test.dart` (FR-006, decisão D8)
- [X] T014 [US1] Executar `flutter analyze` e `flutter test` em `Prototipo/passenger/` e corrigir o que acusarem, até zero violações e 100% dos testes passando (SC-003)
- [X] T015 [US1] Executar `flutter run` em `Prototipo/passenger/` com um dispositivo/emulador Android e confirmar: o app abre sem erro, exibe "Corridas Passageiro", não há contador nem botão flutuante (US1 cenário 1, SC-005)
- [X] T015a [US1] Medir o cold start com `flutter run --profile --trace-startup` em `Prototipo/passenger/` e confirmar em `build/start_up_info.json` que `timeToFirstFrameMicros` fica abaixo de 3 s; registrar o valor medido no `README.md` junto da identificação do aparelho usado (SC-002)
- [X] T016 [US1] Com o app rodando, validar os cenários restantes da US1: enviar para segundo plano e retornar mantém a tela responsiva (cenário 2); o app aparece na gaveta de aplicativos como "Corridas Passageiro" (cenário 4)
- [X] T017 [US1] Validar os edge cases de runtime com o app instalado: abrir com Wi-Fi e dados móveis desligados (FR-004); alternar o tema do sistema entre claro e escuro e confirmar legibilidade; girar o dispositivo e confirmar que o conteúdo não se sobrepõe

**Checkpoint**: MVP entregue — o app do passageiro existe, roda e está pronto para receber as features de Nostr.

---

## Phase 4: User Story 2 — Executar o projeto em ambiente de desenvolvimento (Priority: P2)

**Goal**: qualquer pessoa consegue, a partir de um clone limpo, rodar, analisar e testar o app seguindo apenas a documentação.

**Independent Test**: a partir de um clone limpo, seguir o README e obter o app rodando em um emulador.

- [X] T018 [US2] Criar `Prototipo/passenger/README.md` documentando: pré-requisitos (Flutter 3.47.4 / Dart 3.13.3), `flutter doctor` como primeiro passo com a ressalva de que só o grupo "Android toolchain" precisa estar ✓, e os comandos `flutter pub get`, `flutter run`, `flutter analyze`, `flutter test`, `flutter test test/home_screen_test.dart` e `flutter test --plain-name "<nome>"` para rodar um único teste (FR-009, SC-001, decisões D1 e D10)
- [X] T019 [US2] Documentar no `README.md` o propósito de cada diretório de `lib/` (`main.dart` como ponto de entrada, `screens/` para telas, `shared/` para código compartilhado), para que a estrutura exigida por FR-008 seja descobrível (US3 cenário 2)
- [X] T020 [US2] Registrar no `README.md` a identidade do app ("Corridas Passageiro" / `br.ufsc.tcc.corridas.passenger`) e a nota de que a app irmã do motorista usa `br.ufsc.tcc.corridas.driver`, podendo as duas coexistir no mesmo aparelho (FR-010, data-model.md)
- [X] T021 [US2] Validar o README executando seus comandos do zero em `Prototipo/passenger/` (`flutter pub get`, `flutter analyze`, `flutter test`) e confirmar que todos funcionam exatamente como documentados (US2 cenários 1 e 2)

**Checkpoint**: projeto reprodutível por terceiros a partir da documentação.

---

## Phase 5: User Story 3 — Base preparada para as próximas funcionalidades (Priority: P3)

**Goal**: a estrutura de pastas e a suíte de testes estão prontas para receber as features de Nostr sem reorganização.

**Independent Test**: verificar que a estrutura documentada existe e que `flutter test` roda e passa.

- [X] T022 [US3] Confirmar que `Prototipo/passenger/lib/` contém exatamente `main.dart`, `screens/` e `shared/`, sem diretórios vazios antecipando camadas (`models/`, `services/`, `repositories/`) que não têm consumidor nesta feature (FR-008, decisão D7)
- [X] T023 [US3] Confirmar que `flutter test` em `Prototipo/passenger/` executa até o fim com todos os testes passando, servindo de ponto de extensão para as próximas features (US3 cenário 1, FR-006)
- [X] T024 [US3] Registrar em `Prototipo/passenger/README.md` a nota de arquitetura de `data-model.md`: não há backend, e todo contrato entre passageiro e motorista é um formato de evento Nostr que precisa ser replicado de forma idêntica nas duas apps

**Checkpoint**: base organizada e documentada para as features seguintes.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: fechamento da feature e integração com o restante do repositório do TCC.

- [X] T025 Percorrer a tabela de critérios de validação de `specs/001-flutter-app-base/quickstart.md` (itens 1 a 15) e confirmar que todos se verificam
- [X] T026 Atualizar `CLAUDE.md` na raiz do repositório: o `passenger/` deixou de estar vazio, registrar os comandos de build, execução, lint e teste da app do passageiro (incluindo como rodar um único teste), conforme o próprio CLAUDE.md pede
- [X] T027 Corrigir também em `CLAUDE.md` a descrição desatualizada do estado do `driver/` e do `passenger/` (ambos já têm feature especificada e planejada; o `driver/` já tem a pipeline completa rodada)
- [X] T028 Revisar os arquivos gerados pelo scaffold que não foram tocados (`.gitignore`, `analysis_options.yaml`, `pubspec.yaml`) e remover comentários de template que não se aplicam ao projeto
- [X] T029 Commitar as mudanças com mensagem descritiva em português, conforme a convenção do repositório (ex.: "Adiciona a aplicação base do passageiro em Flutter")

---

## Dependencies

**Ordem de fases**: Phase 1 → Phase 2 → Phase 3 (US1) → Phase 4 (US2) → Phase 5 (US3) → Phase 6.

- **Phase 1 (Setup)** não tem dependências; T002/T003/T004 dependem de T001.
- **Phase 2 (Foundational)** bloqueia todas as user stories: sem o projeto gerado e identificado, nada
  pode ser implementado. T005–T009 dependem de T001.
- **US1 (Phase 3)** depende apenas da Phase 2. É o MVP e não depende de nenhuma outra story.
- **US2 (Phase 4)** depende de US1 na prática: o README documenta comandos que só podem ser validados
  (T021) depois que o app roda e os testes passam.
- **US3 (Phase 5)** é majoritariamente verificação do que US1 produziu; depende de US1. T024 depende de
  T018 (o README precisa existir).
- **Phase 6** depende de todas as anteriores.

**Dentro da US1**: T010 → T011 (a tela consome as constantes) → T012 (o main consome a tela) → T013 (o
teste monta o app) → T014 → T015 → T015a → T016/T017 (validação manual no dispositivo).

## Parallel Opportunities

A feature é pequena e majoritariamente sequencial — um único arquivo `lib/` depende do anterior. As
oportunidades reais de paralelismo são:

- **Phase 2**: T005, T007 e T008 tocam arquivos diferentes (`build.gradle.kts`, `AndroidManifest.xml`,
  `pubspec.yaml`) e podem ser verificados em paralelo; T006 conflita com T007 (mesmo arquivo), então não
  devem ser paralelizados entre si.
- **Phase 6**: T026 e T027 **não** são paralelizáveis entre si — ambos tocam `CLAUDE.md` e devem ser
  feitos na mesma edição. T028 é independente dos dois e pode correr em paralelo com eles.
- **US1**: nenhuma. A cadeia `app_info → home_screen → main → teste` é estritamente sequencial.

## Implementation Strategy

**MVP = Phase 1 + Phase 2 + Phase 3 (US1)**, 18 tarefas. Ao final delas o TCC já tem a app do passageiro
existindo e rodando em um aparelho — que é exatamente o que a feature pede. US2 e US3 são incrementos de
reprodutibilidade e manutenibilidade, entregáveis logo em seguida mas sem bloquear a demonstração.

Recomenda-se rodar `flutter analyze` e `flutter test` ao final de cada fase, e não só em T014, para que
uma regressão seja atribuída à fase que a introduziu.

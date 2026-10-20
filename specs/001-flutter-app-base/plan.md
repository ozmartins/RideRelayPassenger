# Implementation Plan: Base do Aplicativo do Passageiro

**Branch**: `master` (feature dir `001-flutter-app-base`) | **Date**: 2026-09-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-flutter-app-base/spec.md`

## Summary

Criar o esqueleto executável do aplicativo do passageiro do protótipo de corridas P2P: um projeto
Flutter mínimo em `Prototipo/passenger`, com uma única tela inicial sem lógica de negócio, identificado
como "Corridas Passageiro" (`br.ufsc.tcc.corridas.passenger`), rodando apenas em Android, com um teste de
widget de sanidade, análise estática limpa e um `README.md` documentando instalação, execução e testes.

A abordagem é usar o scaffold oficial (`flutter create`) restrito a Android, remover o boilerplate de
contador gerado pelo template, substituí-lo por uma tela inicial vazia organizada em
`main.dart` / `screens/` / `shared/` (FR-008) e converter o teste de contador gerado em um teste de
sanidade da tela inicial. Nenhuma dependência externa é adicionada nesta etapa — Nostr, rede,
permissões e persistência ficam para features posteriores (FR-011).

## Technical Context

**Language/Version**: Dart 3.13.3 (Flutter 3.47.4, canal stable — verificado nesta sessão via `flutter --version`)

**Primary Dependencies**: apenas `flutter` SDK + `flutter_test` e `flutter_lints` (dev). Zero pacotes de terceiros nesta etapa (FR-011)

**Storage**: N/A — a feature não persiste dados

**Testing**: `flutter test` (widget test via `flutter_test`) + `flutter analyze` como gate de análise estática

**Target Platform**: Android apenas (minSdk padrão do Flutter; `flutter doctor` confirma Android SDK 37.0.0 e 1 dispositivo conectado). iOS/web/desktop fora de escopo (FR-005)

**Project Type**: mobile-app (uma das duas apps do protótipo; a app do motorista é um projeto independente que não compartilha código com esta)

**Performance Goals**: cold start até a primeira tela em ≤ 3 s no dispositivo de referência (SC-002); UI a 60 fps (padrão do framework, sem carga nesta etapa)

**Constraints**: nenhuma permissão Android declarada além do padrão do scaffold; nenhum acesso a rede (FR-004); sem backend próprio; o app não pode depender da app do motorista nem importar código dela

**Scale/Scope**: 1 tela, 0 entidades de domínio, 1 teste de widget, 3 arquivos em `lib/`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Estado da constituição**: `.specify/memory/constitution.md` é o **template não preenchido** — todos os
princípios ainda são placeholders (`[PRINCIPLE_1_NAME]`, …) e não há versão ratificada.

**Resultado do gate (pré-Fase 0)**: PASS por vacuidade — não existe nenhum princípio ratificado que este
plano possa violar. Nenhuma violação a justificar, portanto a seção Complexity Tracking permanece vazia.

**Resultado do gate (pós-Fase 1)**: PASS. O design gerado (3 arquivos em `lib/`, 1 teste, zero
dependências, zero contratos externos) não introduz nada que exigisse justificativa mesmo sob os
princípios conservadores típicos de uma constituição spec-kit (simplicidade, testabilidade, ausência de
complexidade especulativa).

**Ressalva registrada**: até que `/speckit-constitution` seja executado, este projeto não tem gates de
governança (ex.: TDD obrigatório, exigência de observabilidade, política de dependências). O plano adota
por conta própria os padrões conservadores coerentes com um protótipo de TCC: zero dependências de
terceiros, análise estática ativa e ao menos um teste automatizado. Se uma constituição for ratificada
depois, este plano deve ser reavaliado contra ela. A mesma ressalva consta no plano do motorista.

## Project Structure

### Documentation (this feature)

```text
specs/001-flutter-app-base/
├── plan.md              # Este arquivo
├── research.md          # Fase 0
├── data-model.md        # Fase 1
├── quickstart.md        # Fase 1
├── checklists/
│   └── requirements.md  # Checklist de qualidade do spec
└── tasks.md             # Fase 2 (/speckit-tasks)
```

Nenhum diretório `contracts/` é gerado: o app base não expõe nenhuma interface externa (sem API, sem
CLI, sem formato de evento Nostr nesta etapa) — a regra do template manda pular contratos para projetos
puramente internos. Os contratos de eventos Nostr entre motorista e passageiro serão definidos nas
features de comunicação e, por não haver backend, terão de ser replicados de forma idêntica nos dois
projetos.

### Source Code (repository root)

O repositório do TCC é a raiz do git; a app do passageiro vive em `Prototipo/passenger`, que já hospeda
o scaffold do spec-kit. O `flutter create` é aplicado **sobre esse diretório existente**, adicionando:

```text
Prototipo/passenger/
├── lib/
│   ├── main.dart                 # ponto de entrada + widget raiz (CorridasPassengerApp)
│   ├── screens/
│   │   └── home_screen.dart      # tela inicial vazia (HomeScreen)
│   └── shared/
│       └── app_info.dart         # constantes de identidade do app (nome de exibição)
├── test/
│   └── home_screen_test.dart     # teste de sanidade: a tela inicial monta e exibe o título
├── android/                      # projeto Android gerado (applicationId br.ufsc.tcc.corridas.passenger)
├── pubspec.yaml                  # nome do pacote: passenger; sem dependências de terceiros
├── analysis_options.yaml         # flutter_lints
├── README.md                     # comandos de setup, execução e teste (FR-009)
├── .gitignore                    # ignora build/, .dart_tool/, etc.
├── .specify/                     # pré-existente (spec-kit) — não tocar
├── .claude/                      # pré-existente (skills) — não tocar
└── specs/                        # pré-existente (documentação de features)
```

**Structure Decision**: projeto Flutter único com `lib/` dividido em ponto de entrada, `screens/` e
`shared/`, conforme FR-008 — a divisão mínima que já tem consumidor real, sem antecipar camadas
(`models/`, `services/`, `repositories/`) que ficariam vazias numa feature com zero entidades de
domínio. A separação arquitetural que de fato importa neste protótipo existe em nível de repositório:
`driver/` e `passenger/` são projetos independentes que só se falam por relays Nostr, de modo que não há
código compartilhado a fatorar entre eles — e não haverá, por decisão de arquitetura. A camada de
domínio será introduzida quando a primeira feature de eventos Nostr exigir.

Diretórios de plataforma fora de escopo (`ios/`, `web/`, `linux/`, `macos/`, `windows/`) **não** são
gerados, conforme FR-005.

**Nota de divergência em relação ao motorista**: a app do motorista usa `lib/` plano (tudo em
`main.dart`). O passageiro usa a divisão acima porque seu spec traz FR-008 explicitamente. A divergência
é de organização interna e não afeta nenhum contrato entre as duas apps — que, nesta feature, ainda não
existe.

## Complexity Tracking

> Nenhuma violação de constituição a justificar (ver Constitution Check).

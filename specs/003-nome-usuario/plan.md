# Implementation Plan: Nome do Usuário no Passageiro

**Branch**: `003-nome-usuario` | **Date**: 2026-09-17 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-nome-usuario/spec.md`

## Summary

O app do passageiro passa a pedir um nome/apelido do usuário na primeira execução, antes de
mostrar a tela principal, e ganha uma tela própria para trocar esse nome depois. O nome é um
dado puramente local e de exibição (não é a identidade criptográfica Nostr, não entra no
contrato de eventos), persistido com o mesmo mecanismo de chave-valor já usado para as
preferências de relay (`KeyValueStore` → `PrefsKeyValueStore`, decisão D3 já registrada). Um
novo `NameService` decide se o nome já existe e o `_Bootstrap` de `main.dart` passa a mostrar a
`NameScreen` antes da `HomeScreen` quando não existir; a `HomeScreen` ganha uma ação para abrir a
mesma tela em modo de edição.

## Technical Context

**Language/Version**: Dart 3.13 / Flutter (SDK conforme `pubspec.yaml`, `^3.13.3`)

**Primary Dependencies**: `flutter` (SDK), `shared_preferences` ^2.5.5 (já presente, via
`PrefsKeyValueStore`) — nenhuma dependência nova.

**Storage**: `shared_preferences`, por meio do `KeyValueStore` já existente (`services/`).

**Testing**: `flutter_test` (widget tests + testes de serviço com dublê de `KeyValueStore`)

**Target Platform**: Android (mesmo escopo do restante do protótipo)

**Project Type**: Mobile app (Flutter, projeto único `passenger/`)

**Performance Goals**: Não há meta de desempenho própria; a tela é local e sem chamada de rede
(SC-002 do spec: fluxo completo em menos de 15s, dominado pela digitação do usuário).

**Constraints**: Nome não pode ficar vazio (após trim); limite de 60 caracteres (FR-006); nenhum
dado de nome pode ser enviado a relay ou a qualquer serviço externo (Restrições de Segurança e
Privacidade da constituição — mesmo o nome sendo dado não sensível, a regra de não enviar dados a
serviços que não sejam relay configurado se aplica por igual).

**Scale/Scope**: 1 tela nova (`NameScreen`, reutilizada para criação e edição), 1 serviço novo
(`NameService`), 1 pequeno ajuste em `main.dart` e `home_screen.dart`. Sem mudança de contrato de
eventos, sem mudança na app do motorista.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Segredo criptográfico não vaza** — N/A. O nome não é material criptográfico; nenhuma
  chave, semente ou assinatura é tocada por esta feature. PASS.
- **II. Assinatura e verificação nascem com teste** — N/A. Esta feature não assina, não verifica
  assinatura, não deriva chave e não decide descartar evento recebido. PASS por vacuidade.
- **III. Dependência de terceiros exige decisão registrada** — Nenhuma dependência nova é
  adicionada ao `pubspec.yaml`; reaproveita `shared_preferences`, já decidido (D3). PASS, sem
  necessidade de nova entrada em `research.md` além de referenciar a decisão existente.
- **IV. O contrato de evento vem antes do código** — N/A. O nome não é publicado em evento Nostr,
  não é lido de relay e não altera a lista padrão de relays nem o marcador do protótipo. Não há
  nada a replicar no app do motorista, porque esta feature não toca o contrato de
  interoperabilidade. PASS.
- **V. Simplicidade proporcional e rastreabilidade acadêmica** — A estrutura proposta (um
  serviço, uma tela, um dublê de teste) tem consumidor direto e não introduz abstração sem
  segunda implementação. Nenhuma medição é reivindicada por esta feature além do already-required
  `quickstart.md`. PASS.

Nenhuma violação a justificar. Constitution Check inicial: **PASS**.

## Project Structure

### Documentation (this feature)

```text
specs/003-nome-usuario/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md         # Phase 1 output (/speckit-plan command)
└── tasks.md              # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

Sem `contracts/`: esta feature não introduz nem altera nenhum evento Nostr, então não há
interface entre as duas apps para documentar (Princípio IV não se aplica).

### Source Code (repository root)

```text
passenger/
├── lib/
│   ├── domain/
│   │   └── user_profile.dart        # NOVO — entidade simples com o nome do usuário
│   ├── services/
│   │   ├── key_value_store.dart     # existente, reaproveitado
│   │   ├── prefs_key_value_store.dart  # existente, reaproveitado
│   │   └── name_service.dart        # NOVO — carrega/salva o nome via KeyValueStore
│   ├── screens/
│   │   ├── home_screen.dart         # AJUSTADO — ação para abrir a tela de nome
│   │   └── name_screen.dart         # NOVO — tela única para 1ª execução e edição
│   └── main.dart                    # AJUSTADO — _Bootstrap decide NameScreen vs HomeScreen
└── test/
    ├── services/
    │   └── name_service_test.dart   # NOVO
    └── screens/
        └── name_screen_test.dart    # NOVO
```

**Structure Decision**: projeto único Flutter já existente (`passenger/`), seguindo a mesma
divisão `domain/` + `services/` + `screens/` usada pelas features anteriores. Nenhum diretório
novo de alto nível é criado — a feature só acrescenta arquivos dentro da estrutura já em vigor.

## Complexity Tracking

*Sem violações do Constitution Check — seção não aplicável.*

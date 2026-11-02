# Implementation Plan: Avaliar corrida (passageiro)

**Branch**: `master` (commits diretos, sem branch de feature — Padrão de Commits da constituição) | **Date**: 2026-09-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/011-avaliar-corrida/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Ao confirmar com sucesso a chegada ao destino (`_confirmarDestino`, feature 010 — publica
`kind: 20010`), o app do passageiro passa a exibir, na sequência, uma tela de avaliação da corrida
com cinco estrelas. Selecionar uma estrela de posição N marca as estrelas 1..N; confirmar persiste
a nota (1 a 5) numa tabela SQLite nova, associada ao identificador do orçamento aceito
(`AcceptedRide.quoteId`, já usado para correlacionar toda a corrida). Uma ação de pular fecha a
tela sem persistir nada. Nenhum estado novo é adicionado a `AcceptedRide`/`AcceptedRideStore`: a
exibição é disparada uma única vez, no mesmo instante em que a modal de chegada ao destino fecha,
e não é retomada depois de o app fechar (decisão da Clarification session 2026-09-22) — dispensa
qualquer sinalizador persistido de "já visto". Nenhum evento Nostr novo é definido; a contrapartida
do motorista é a feature irmã `driver/specs/0NN-avaliar-corrida` (spec-kit separado).

## Technical Context

**Language/Version**: Dart 3 / Flutter (mesma versão já fixada no `pubspec.yaml` do projeto)

**Primary Dependencies**: `sqflite` (já em uso pelo passageiro desde a feature
`008-receber-orcamentos`, mesmo padrão de tabela isolada) — nenhuma dependência nova.

**Storage**: SQLite, nova tabela `ride_ratings` (um banco próprio, `ride_ratings.db`, mesmo padrão
de `SqfliteReceivedQuoteStore`) — sem alteração ao esquema de `driver_profile`/tabelas existentes.

**Testing**: `flutter_test`, com um dublê em memória de `RideRatingStore` para os testes de tela e
teste de integração dedicado do `SqfliteRideRatingStore` — nenhum teste toca SQLite real fora
desse arquivo (Princípio II, por analogia a `ReceivedQuoteStore`).

**Target Platform**: Android (sem mudança)

**Project Type**: mobile-app (Flutter, Android apenas) — mesma estrutura já usada pelo passageiro.

**Performance Goals**: a tela de avaliação aparece em até 2 s do fechamento da modal de chegada ao
destino (SC-001); a nota confirmada é encontrada no banco local imediatamente depois (SC-002) —
mesma ordem de grandeza já observada nas demais persistências locais do protótipo.

**Constraints**: nenhum evento Nostr novo, nenhuma informação da avaliação trafega para o outro
app nem para relay (FR-005) — persistência estritamente local.

**Scale/Scope**: protótipo de avaliação de viabilidade — sem requisito de escala além do já
estabelecido; uma corrida ativa por vez (mesma premissa de `AcceptedRide`).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio | Avaliação |
|---|---|
| I. Segredo criptográfico não vaza | PASS por vacuidade. Nenhum material de chave é tocado — a avaliação nunca é assinada nem publicada, é só uma nota numérica em SQLite local. |
| II. Assinatura e verificação nascem com teste | PASS por vacuidade — não há assinatura nem verificação nesta feature. A regra geral de teste automatizado (não a específica de assinatura) ainda cobre o fluxo, via o Fluxo de Desenvolvimento e Gates. |
| III. Dependência de terceiros exige decisão registrada | PASS. Nenhuma dependência nova ao `pubspec.yaml` — `sqflite` já está registrado (D1 de `specs/008-receber-orcamentos/research.md`); reaproveitado sem nova decisão. |
| IV. O contrato de evento vem antes do código | PASS por vacuidade. Nenhum evento Nostr novo — a avaliação nunca sai do app que a coletou (FR-005), então não há contrato a definir nem replicar. |
| V. Simplicidade proporcional e rastreabilidade acadêmica | PASS. Reaproveita o padrão já estabelecido por `SqfliteReceivedQuoteStore` (tabela isolada, uma responsabilidade) em vez de generalizar um mecanismo de persistência comum; nenhum sinalizador "já avaliado" persistido é introduzido, porque a Clarification já resolveu que a oportunidade se perde ao fechar o app — estado em memória basta. |

**Resultado do gate inicial**: PASS — sem violação a justificar em Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/011-avaliar-corrida/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

Sem diretório `contracts/`: nenhum evento Nostr novo é definido por esta feature.

### Source Code (repository root)

```text
passenger/lib/
├── domain/
│   └── ride_rating.dart          # NOVO — rideId (= AcceptedRide.quoteId), stars (1-5), ratedAt
├── services/
│   └── ride_rating_store.dart    # NOVO — RideRatingStore (abstrata) + SqfliteRideRatingStore,
│                                  # mesmo padrão de received_quote_store.dart
└── screens/
    ├── ride_rating_modal.dart    # NOVO — cinco estrelas selecionáveis, "Confirmar" e "Pular"
    └── map_screen.dart           # ALTERADO — ao fechar a modal de chegada ao destino com
                                   # sucesso (_confirmarDestino), abre a modal de avaliação
                                   # (Stack, mesmo padrão de DestinationArrivedModal); persiste
                                   # via RideRatingStore ao confirmar, ou só fecha ao pular

passenger/test/
├── domain/
│   └── ride_rating_test.dart           # NOVO
├── services/
│   └── ride_rating_store_test.dart     # NOVO — dublê em memória + teste de integração SQLite
│                                        # real do SqfliteRideRatingStore (por analogia a
│                                        # received_quote_store_test.dart)
└── screens/
    └── map_screen_test.dart            # ALTERADO — cenários das duas acceptance scenarios novas
                                         # (confirmar nota, pular)
```

**Structure Decision**: mesma estrutura de três camadas já usada desde a feature 002 do
passageiro, sem novo diretório de topo. Nenhum arquivo de contrato Nostr é tocado.

## Complexity Tracking

*Nenhuma violação de princípio a justificar — tabela omitida (Constitution Check: PASS).*

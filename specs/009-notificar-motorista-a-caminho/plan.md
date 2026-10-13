# Implementation Plan: Notificar que o motorista está a caminho

**Branch**: `master` (commits diretos, sem branch de feature — Padrão de Commits da constituição) | **Date**: 2026-09-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/009-notificar-motorista-a-caminho/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

O passageiro passa a consumir, pela primeira vez, o `kind: 20005` (Localização do motorista,
definido e replicado desde a feature 010 do motorista) — sem exibir a posição em si, só para
reconhecer sua primeira ocorrência referenciando o orçamento que o passageiro aceitou como o sinal
de que o motorista começou a se deslocar, e então mostrar uma modal informativa com um botão "OK".
Exige, antes de qualquer código de UI, um dado hoje inexistente no passageiro: qual orçamento foi
aceito (`quoteId` + chave pública do motorista) — persistido a partir do toque em "Aceitar"
(feature 008), reaproveitando o `KeyValueStore` já existente, mesmo padrão do `RideStateStore` do
motorista (features 010/011). A notificação já exibida também é persistida, para nunca reaparecer,
inclusive através de um reinício do app.

## Technical Context

**Language/Version**: Dart 3 / Flutter (mesma versão já fixada no `pubspec.yaml` do projeto)

**Primary Dependencies**: `dart_nostr` (assinatura/verificação, já em uso), `shared_preferences`
(via `KeyValueStore`/`PrefsKeyValueStore`, já em uso) — nenhuma dependência nova.

**Storage**: `shared_preferences`, através da abstração `KeyValueStore` já existente, para o novo
estado local persistido "corrida aceita" — mesmo mecanismo já usado para a lista de relays.
`sqflite` (via `ReceivedQuoteStore`, feature 008) continua servindo só os orçamentos recebidos, sem
mudança.

**Testing**: `flutter_test`, com dublês para `KeyValueStore`/`EventFeed`/`RelayService`/
`LocationService` — nenhum teste toca rede, relay ou `SharedPreferences` real (Princípio II).

**Target Platform**: Android (sem mudança)

**Project Type**: mobile-app (Flutter, Android apenas) — mesma estrutura `lib/domain` +
`lib/services` + `lib/screens` + `lib/shared` já usada pelo passageiro.

**Performance Goals**: modal exibida em até 1 s da chegada da primeira localização referenciando a
corrida aceita (SC-001) — mesma ordem de grandeza já medida para outros eventos do protótipo.

**Constraints**: nenhum evento novo publicado por esta feature — só consumo de um kind já definido
(20005); nenhum dado além do já recebido é enviado a qualquer serviço.

**Scale/Scope**: protótipo de avaliação de viabilidade — sem requisito de escala além do já
estabelecido.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio | Avaliação |
|---|---|
| I. Segredo criptográfico não vaza | PASS. Nenhum material de chave é tocado por esta feature. |
| II. Assinatura e verificação nascem com teste | PASS por reaproveitamento — a verificação de assinatura e a deduplicação de `kind: 20005` já são feitas pelo `EventFeed` existente (mesmo código que já processa `kind: 20002`); esta feature só acrescenta o kind à lista de inscrição e decide, a partir do evento já verificado, se exibe a modal — decisão testada como qualquer outro código que decide descartar/aceitar (Princípio II por analogia). |
| III. Dependência de terceiros exige decisão registrada | PASS por vacuidade. Nenhuma dependência nova. |
| IV. O contrato de evento vem antes do código | GATE ATIVO — ver Phase 1. `kind: 20005` já está definido (emenda 08 do motorista); esta feature é a primeira consumidora do lado do passageiro, o que MUST ser registrado como emenda ao contrato único (mesmo padrão já usado quando o motorista passou a consumir `kind: 20003`, emenda 08) — sem isso, a seção "Forma da inscrição" ficaria desatualizada quanto a quem consome o quê. |
| V. Simplicidade proporcional e rastreabilidade acadêmica | PASS. O novo estado "corrida aceita" reaproveita `KeyValueStore` já existente, em vez de estender o `sqflite` já usado por `ReceivedQuoteStore` — decisão registrada em `research.md` (D2), pelo mesmo raciocínio que levou o motorista a não misturar esse tipo de dado com sua tabela SQLite de cadastro. |

**Resultado do gate inicial**: PASS, condicionado ao cumprimento do Princípio IV no Phase 1 (emenda de consumo registrada e replicada) — sem violação a justificar em Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/009-notificar-motorista-a-caminho/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command) — aponta para a emenda no
│                         # contrato único do protótipo
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
passenger/lib/
├── domain/
│   └── accepted_ride.dart           # NOVO — quoteId + driverPubkey + movementNotified
├── services/
│   ├── accepted_ride_store.dart     # NOVO — abstração + implementação sobre KeyValueStore
│   │                                 # (por analogia a ride_state_store.dart do motorista)
│   └── event_feed.dart              # ALTERADO — nova constante driverLocationKind (20005)
└── screens/
    ├── driver_moving_modal.dart     # NOVO — mensagem informativa + botão "OK"
    └── map_screen.dart              # ALTERADO — persiste AcceptedRide ao aceitar (feature 008);
                                      # reconhece a primeira localização referenciando a corrida
                                      # aceita e exibe a nova modal, renderizada em Stack como
                                      # RideQuotesModal (mesmo motivo já documentado: T019 de
                                      # specs/008-receber-orcamentos/tasks.md)

passenger/test/
├── domain/
│   └── accepted_ride_test.dart           # NOVO
├── services/
│   └── accepted_ride_store_test.dart     # NOVO
└── screens/
    └── map_screen_test.dart              # ALTERADO — cenários da user story

driver/specs/002-nostr-relay-connection/contracts/nostr-events.md   # ALTERADO (mesma alteração,
    # Princípio IV) — emenda registrando o consumo do kind 20005 pelo passageiro; réplica idêntica
    # já em passenger/specs/002-.../contracts/nostr-events.md
```

**Structure Decision**: mesma estrutura de três camadas já usada pelo passageiro desde a feature
002 (`domain/` + `services/` + `screens/` + `shared/`), sem novo diretório de topo. O único
artefato fora de `passenger/` é a emenda ao contrato, espelhada em `driver/` por já existir lá como
o arquivo canônico (mesma direção inversa já usada quando o passageiro registrou o consumo do
`kind: 20002`, feature 008 — a emenda é escrita no arquivo do motorista, canônico, e replicada no
do passageiro).

## Complexity Tracking

*Nenhuma violação de princípio a justificar — tabela omitida (Constitution Check: PASS).*

# Implementation Plan: Confirmar encontro com o motorista e chegada ao destino

**Branch**: `master` (commits diretos, sem branch de feature — Padrão de Commits da constituição) | **Date**: 2026-09-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/010-confirmar-encontro-destino/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

O passageiro passa a consumir `kind: 20007` (Chegada do motorista, definido pela feature 011 do
motorista, nunca consumido até agora) pela primeira vez: ao chegar, exibe uma modal com o botão
"Confirmo que encontrei o motorista", que publica `kind: 20008` (Encontro confirmado, novo,
definido pela feature 012 do motorista). Ao consumir depois `kind: 20009` (Chegada ao destino,
também definido por aquela feature), exibe uma segunda modal com "Confirmo que chegamos ao
destino", que publica `kind: 20010` (Destino confirmado, novo). `AcceptedRide` (feature 009) ganha
dois booleanos novos para nunca reexibir cada modal mais de uma vez, mesmo padrão já usado por
`movementNotified`. Nenhum kind novo é definido por esta feature — os três já estão especificados
pela feature 012 do motorista; aqui só se implementa o lado do passageiro contra esse contrato.

## Technical Context

**Language/Version**: Dart 3 / Flutter (mesma versão já fixada no `pubspec.yaml` do projeto)

**Primary Dependencies**: `dart_nostr` (assinatura/verificação, já em uso), `shared_preferences`
(via `KeyValueStore`, já em uso) — nenhuma dependência nova.

**Storage**: `shared_preferences`, através de `AcceptedRideStore` (feature 009) — `AcceptedRide`
ganha dois campos novos, sem novo mecanismo de persistência.

**Testing**: `flutter_test`, com dublês para `KeyValueStore`/`EventFeed`/`RelayService`/
`LocationService` — nenhum teste toca rede, relay ou `SharedPreferences` real (Princípio II).

**Target Platform**: Android (sem mudança)

**Project Type**: mobile-app (Flutter, Android apenas) — mesma estrutura já usada pelo passageiro.

**Performance Goals**: cada modal aparece em até 1 s do evento que a dispara, e cada confirmação é
publicada em até 1 s do toque no botão, quando há relay conectado (SC-001 a SC-003) — mesma ordem
de grandeza já medida para os demais eventos do protótipo.

**Constraints**: nenhum evento novo definido nem publicado sem seguir o contrato já escrito pela
feature 012 do motorista; nenhum dado além dos identificadores de correlação já usados pelos kinds
anteriores.

**Scale/Scope**: protótipo de avaliação de viabilidade — sem requisito de escala além do já
estabelecido.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio | Avaliação |
|---|---|
| I. Segredo criptográfico não vaza | PASS. Nenhum material de chave é tocado além da assinatura já existente via `Identity.privateKey`, mesmo mecanismo de `publishQuoteAcceptance`/`publishQuoteRejection`. |
| II. Assinatura e verificação nascem com teste | PASS (obrigação). As decisões de exibir (ou não) cada modal a partir de um evento recebido MUST ter teste cobrindo os casos aceitos e ignorados, por analogia às decisões já testadas nas features 008/009. A publicação das duas confirmações reaproveita `EventFeed._publish`, já testado; os dois métodos novos (`publishMeetingConfirmation`/`publishDestinationConfirmation`) MUST ter teste cobrindo kind/tags corretos. |
| III. Dependência de terceiros exige decisão registrada | PASS por vacuidade. Nenhuma dependência nova. |
| IV. O contrato de evento vem antes do código | GATE ATIVO — mas já cumprido: os três kinds usados por esta feature (20007, consumido; 20008 e 20010, publicados) já estão especificados pela feature 012 do motorista (emenda 11, a ser commitada antes desta implementação). Esta feature não introduz nenhum formato novo — só publica/consome contra o contrato já escrito. |
| V. Simplicidade proporcional e rastreabilidade acadêmica | PASS. Reaproveita `AcceptedRide`/`AcceptedRideStore`/`EventFeed` já existentes, sem novo mecanismo de persistência ou transporte — só dois campos novos e dois métodos de publicação (decisão registrada em `research.md`, D1). Nenhuma entidade de domínio nova para os avisos recebidos, mesmo raciocínio já usado pela feature 012 do motorista (D3 do `research.md` dela): correlação por `quoteId` já é suficiente. |

**Resultado do gate inicial**: PASS — sem violação a justificar em Complexity Tracking, e sem gate pendente (o contrato já está definido pela feature irmã do motorista).

## Project Structure

### Documentation (this feature)

```text
specs/010-confirmar-encontro-destino/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command) — aponta para o contrato já
│                         # escrito pela feature 012 do motorista
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
passenger/lib/
├── domain/
│   └── accepted_ride.dart           # ALTERADO — meetingConfirmed, destinationConfirmed
├── services/
│   ├── accepted_ride_store.dart     # ALTERADO — (de)serializa os dois campos novos
│   └── event_feed.dart              # ALTERADO — driverArrivalKind (20007),
│                                     # meetingConfirmedKind (20008),
│                                     # destinationArrivalKind (20009),
│                                     # destinationConfirmedKind (20010);
│                                     # publishMeetingConfirmation, publishDestinationConfirmation
└── screens/
    ├── driver_arrived_modal.dart         # NOVO — mensagem + botão "Confirmo que encontrei o
    │                                     # motorista"
    ├── destination_arrived_modal.dart    # NOVO — mensagem + botão "Confirmo que chegamos ao
    │                                     # destino"
    └── map_screen.dart                  # ALTERADO — consome kind 20007/20009, exibe as duas
                                          # modais novas (Stack, mesmo padrão de
                                          # RideQuotesModal/DriverMovingModal)

passenger/test/
├── domain/
│   └── accepted_ride_test.dart           # ALTERADO
├── services/
│   ├── accepted_ride_store_test.dart     # ALTERADO — round-trip dos campos novos
│   └── event_feed_test.dart              # ALTERADO — dois métodos de publicação novos
└── screens/
    └── map_screen_test.dart              # ALTERADO — cenários das duas user stories

driver/specs/002-nostr-relay-connection/contracts/nostr-events.md   # já alterado pela feature
    # 012 do motorista (emenda 11) — esta feature não toca o contrato de novo, só implementa
    # contra ele
```

**Structure Decision**: mesma estrutura de três camadas já usada desde a feature 002 do
passageiro, sem novo diretório de topo. Nenhum arquivo de contrato é tocado por esta feature — a
emenda 11 já é responsabilidade da feature 012 do motorista, commitada antes desta implementação.

## Complexity Tracking

*Nenhuma violação de princípio a justificar — tabela omitida (Constitution Check: PASS).*

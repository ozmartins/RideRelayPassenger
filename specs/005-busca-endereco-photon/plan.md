# Implementation Plan: Busca de Endereço via Photon

**Branch**: `005-busca-endereco-photon` (a criar) | **Date**: 2026-09-17 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/005-busca-endereco-photon/spec.md`

## Summary

Substituir o campo de destino de texto livre da feature 004 por um campo de busca com sugestões:
conforme o passageiro digita, o app consulta a API pública do geocodificador Photon
(`https://photon.komoot.io/api/`) com o texto digitado e mostra os endereços retornados como uma
lista selecionável. O destino da corrida passa a ser sempre o endereço de uma sugestão explicitamente
tocada pelo usuário — nunca o texto bruto — mantendo as garantias já existentes de que o destino só
existe em memória local e nunca é publicado em relay Nostr.

A chamada à Photon é a primeira vez que este app envia dado de usuário a um serviço que não é relay
Nostr; isso só é permitido pela exceção aberta na emenda 2.2.0 da constituição (texto de busca e
endereço selecionado, por HTTPS, sem identificador do usuário, sem persistência além da sessão).

## Technical Context

**Language/Version**: Dart 3.13.3 (Flutter, stable) — inalterado em relação às features anteriores

**Primary Dependencies**:
- `http ^1.6.0` — cliente HTTP para consultar a API Photon (a promover de dependência transitiva para
  direta; D1 de `research.md`)

**Storage**: nenhuma. Sugestões e destino selecionado existem só em memória, durante a sessão
(`data-model.md`) — mesma garantia da feature 004.

**Testing**: `flutter test` com testes de unidade do serviço de geocodificação usando um
`http.Client` dublê (sem rede real, mesmo padrão de isolamento já usado para `RelayTransport`),
cobrindo: sucesso com resultados, sucesso sem resultados, falha de rede, resposta malformada e
timeout. Testes de widget da tela de mapa cobrindo: sugestões aparecem ao digitar, destino só é
registrado ao tocar uma sugestão (nunca ao digitar), destino permanece o da última seleção ao editar
o texto de novo, campo volta a "sem destino" se o texto for apagado, mensagens de "sem resultado" e
de falha aparecem nos casos correspondentes. `flutter analyze` como gate.

**Target Platform**: Android apenas (inalterado). Nenhuma permissão nova — a chamada HTTP usa a
permissão de Internet já concedida por padrão a apps Android (não é uma permissão perigosa).

**Project Type**: mobile-app

**Performance Goals**: sugestões atualizadas em até 1 s após o fim da digitação, na rede do
emulador/aparelho de teste (consistente com SC-003 do `spec.md`, medido na validação do
`quickstart.md` — não estimado)

**Constraints**: sem hospedar instância própria do Photon (Assumptions do `spec.md`); nenhuma chamada
à API MUST incluir identificador do usuário (chave pública, nome de exibição, posição atual — exceção
da constituição 2.2.0); nada de sugestão ou destino persistido ou enviado a relay nesta feature.

**Scale/Scope**: uma tela (`MapScreen`), um serviço novo (`GeocodingService`), uma entidade nova
(`AddressSuggestion`); não introduz nenhum evento Nostr novo, logo não toca o Princípio IV.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio / Restrição | Avaliação |
|---|---|
| I. Segredo criptográfico não vaza | PASS por vacuidade — a feature não toca chave, semente nem material de assinatura. |
| II. Assinatura e verificação nascem com teste | PASS por vacuidade — a feature não assina, não verifica assinatura nem descarta evento recebido. |
| III. Dependência de terceiros exige decisão registrada | Aplicável. `http` promovida a dependência direta; decisão registrada em D1 de `research.md`, com alternativas, versões e datas de publicação. Tipo `http.Client`/`http.Response` confinado a `lib/services/`. |
| IV. O contrato de evento vem antes do código | PASS por vacuidade — a feature não introduz nem altera evento Nostr, lista de relays ou marcador; não há nada a replicar no motorista. |
| V. Simplicidade proporcional e rastreabilidade acadêmica | Aplicável. Nenhuma abstração além de uma interface `GeocodingService` com uma implementação real e uma de teste (mesmo padrão de `LocationService`). SC-003 será medido de fato no `quickstart.md`, não estimado. |
| Restrições de Segurança e Privacidade — dado de usuário só a relay Nostr | Exceção aplicável, aberta pela emenda 2.2.0 (2026-09-17) especificamente para geocodificação. Cumprida por construção: só o texto de busca e a seleção resultante trafegam, por HTTPS, sem `pubkey`/nome/posição anexados, sem persistência além da sessão — ver D2 de `research.md`. |

Nenhuma violação sem exceção registrada. Gate PASS.

## Project Structure

### Documentation (this feature)

```text
specs/005-busca-endereco-photon/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
lib/
├── domain/
│   ├── address_suggestion.dart      # novo — endereço candidato retornado pela busca
│   └── destination_address.dart     # inalterado na forma; passa a só ser construído a
│                                     # partir do texto de uma AddressSuggestion selecionada
├── services/
│   └── geocoding_service.dart       # novo — interface GeocodingService + PhotonGeocodingService
│                                     # (único arquivo, além de main.dart e do teste, que conhece
│                                     # package:http e o formato de resposta da Photon)
└── screens/
    └── map_screen.dart              # modificado — campo de destino passa a mostrar sugestões,
                                      # tratar seleção, "sem resultado" e falha

test/
├── services/
│   └── geocoding_service_test.dart  # novo — PhotonGeocodingService com http.Client dublê
└── screens/ (ou test/map_screen_test.dart, conforme convenção já usada)
    └── map_screen_test.dart         # modificado — cobre os novos cenários de sugestão/seleção
```

**Structure Decision**: mantém a mesma divisão em `domain/` + `services/` + `screens/` já usada nas
features anteriores do passageiro. Não introduz `shared/` novo nem camada adicional — a única peça
nova é o serviço de geocodificação, colocado ao lado de `location_service.dart` em `services/`, e uma
entidade nova ao lado de `destination_address.dart` em `domain/` (Princípio V).

## Complexity Tracking

Nenhuma violação de constituição sem exceção já registrada — tabela não aplicável. A exceção às
Restrições de Segurança e Privacidade está coberta pela emenda 2.2.0 (2026-09-17), citada na tabela
de Constitution Check acima, não por uma justificativa ad-hoc deste plano.

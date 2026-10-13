# Implementation Plan: Solicitar corrida

**Branch**: `006-solicitar-corrida` (a criar) | **Date**: 2026-09-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/006-solicitar-corrida/spec.md`

## Summary

Acrescentar um botão "Solicitar corrida" à tela do mapa do passageiro. Ao tocar, o app valida que há
destino escolhido (feature 005) e posição atual disponível (feature 004); se ambos estiverem
presentes, monta e publica nos relays configurados o primeiro evento de domínio deste protótipo —
`kind: 20001`, "Solicitação de carona" — contendo a posição atual, as coordenadas do destino e a
forma de pagamento escolhida (dinheiro, PIX ou cartão, com "Dinheiro" pré-selecionado). O evento é
efêmero e não criptografado: é um anúncio a qualquer motorista interessado, não uma mensagem a um
destinatário já escolhido (justificativa completa no `spec.md`).

## Technical Context

**Language/Version**: Dart 3.13.3 (Flutter, stable) — inalterado em relação às features anteriores

**Primary Dependencies**: nenhuma nova. Reaproveita `dart_nostr` (já usado por `EventFeed`/
`IdentityService`) para montar e assinar o evento, e `package:flutter` (Material 3
`SegmentedButton`) para a seleção de pagamento — ambos já dependências do projeto.

**Storage**: nenhuma. `RideRequest` existe só entre o toque no botão e a publicação (Key Entities do
`spec.md`); não é persistido.

**Testing**: `flutter test` com testes de unidade de `EventFeed.publishRideRequest` (kind, tags,
`content`, ausência de relay conectado — dublê de `RelayTransport`, sem rede real), de
`PhotonGeocodingService`/`AddressSuggestion` cobrindo a leitura de `geometry.coordinates` (D4 de
`research.md`, incluindo teste de que a ordem GeoJSON `[lon, lat]` não é trocada), e testes de widget
de `MapScreen` cobrindo as três User Stories do `spec.md` (solicitar com tudo disponível, destino
ausente, posição ausente) e a troca de forma de pagamento. `flutter analyze` como gate.

**Target Platform**: Android apenas (inalterado). Nenhuma permissão nova.

**Project Type**: mobile-app

**Performance Goals**: solicitação completa (toque no botão até confirmação visível) em uma única
interação, sem passos adicionais (SC-001 do `spec.md`, medido no `quickstart.md`).

**Constraints**: coordenadas sem truncamento de precisão (D2/D4 de `research.md`); `content` sem
criptografia (justificativa de privacidade do `spec.md`); evento efêmero, não retido pelo relay para
inscrições futuras (D1 de `research.md`).

**Scale/Scope**: uma tela modificada (`MapScreen`), um serviço estendido (`EventFeed`, novo método),
duas entidades novas (`RideRequest`, `PaymentMethod`), duas entidades existentes estendidas
(`AddressSuggestion`, `DestinationAddress` ganham lat/lon), um evento Nostr novo (`kind: 20001`,
Princípio IV — replicado no motorista na mesma alteração).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio / Restrição | Avaliação |
|---|---|
| I. Segredo criptográfico não vaza | Aplicável — a feature assina um evento novo com a identidade local. Cumprida pelo mesmo caminho já testado de `EventFeed.publish`/`IdentityService` (a chave privada nunca sai do `SecureStore` nem é serializada no evento); `quickstart.md` inclui a verificação de não vazamento específica desta feature. |
| II. Assinatura e verificação nascem com teste | Aplicável — `publishRideRequest` assina. Testes automatizados cobrem a montagem do evento (kind, tags, `content`) com dublê de transporte, sem rede real. Esta feature não introduz recepção/verificação nova (o motorista consumir o evento é trabalho futuro), então a metade "verificação" do Princípio II não se aplica aqui. |
| III. Dependência de terceiros exige decisão registrada | PASS por vacuidade — nenhuma dependência nova em `pubspec.yaml`; `dart_nostr` e `package:flutter` já são dependências registradas em features anteriores. |
| IV. O contrato de evento vem antes do código | Aplicável — evento novo (`kind: 20001`). Especificado em `specs/002-nostr-relay-connection/contracts/nostr-events.md` (emenda 04) **antes** desta tarefa de implementação, e replicado de forma idêntica no motorista na mesma alteração (corpos conferidos por diff). A lista de relays e o marcador do protótipo não mudam nesta feature. |
| V. Simplicidade proporcional e rastreabilidade acadêmica | Aplicável. Publicação reaproveita `EventFeed` existente em vez de um serviço novo (D6 de `research.md`); nenhuma abstração sem consumidor. SC-001 a SC-004 serão medidos de fato no `quickstart.md`, não estimados. |
| Restrições de Segurança e Privacidade — dado sensível sem criptografia em relay público | Aplicável e justificada por escrito na seção "Justificativa de privacidade" do `spec.md`, conforme a constituição exige: a solicitação é um anúncio (broadcast), não uma mensagem a destinatário escolhido; nenhum identificador além da `pubkey` (já pública por definição) é incluído. |

Nenhuma violação sem justificativa registrada. Gate PASS.

## Project Structure

### Documentation (this feature)

```text
specs/006-solicitar-corrida/
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
│   ├── payment_method.dart          # novo — enum PaymentMethod (cash/pix/card) + rótulos
│   ├── ride_request.dart            # novo — agrupa origin/destination/payment antes de publicar
│   ├── address_suggestion.dart      # modificado — ganha latitude/longitude (D4 de research.md)
│   └── destination_address.dart     # modificado — ganha latitude/longitude, copiadas da
│                                     # AddressSuggestion selecionada
├── services/
│   ├── geocoding_service.dart       # modificado — PhotonGeocodingService passa a ler
│                                     # geometry.coordinates ao montar AddressSuggestion
│   └── event_feed.dart              # modificado — novo método publishRideRequest(RideRequest,
│                                     # Identity), ao lado do publish() já existente
└── screens/
    └── map_screen.dart              # modificado — botão "Solicitar corrida", seletor de forma de
                                      # pagamento (SegmentedButton), validação e chamada de
                                      # publishRideRequest; passa a receber EventFeed, Identity e
                                      # RelayService

lib/main.dart                        # modificado — _Shell passa EventFeed, Identity e RelayService
                                      # (já instanciados) para MapScreen

test/
├── domain/
│   ├── address_suggestion_test.dart     # modificado — cobre lat/lon
│   └── destination_address_test.dart    # modificado — cobre lat/lon e igualdade
├── services/
│   ├── geocoding_service_test.dart      # modificado — cobre leitura de geometry.coordinates
│   └── event_feed_test.dart             # modificado — cobre publishRideRequest
└── screens/ (ou test/map_screen_test.dart, conforme convenção já usada)
    └── map_screen_test.dart             # modificado — cobre as três User Stories e o seletor de
                                          # pagamento
```

**Structure Decision**: mantém a mesma divisão em `domain/` + `services/` + `screens/` já usada nas
features anteriores do passageiro; nenhuma camada nova. A publicação do evento de domínio é um método
a mais em `EventFeed`, não um serviço novo (D6 de `research.md`, Princípio V). `MapScreen` deixa de
ser a única tela sem acesso a `RelayService`/`EventFeed` — mudança deliberada, decidida na
clarificação da sessão 2026-09-20, e não mais uma garantia estrutural do arquivo (o comentário de
topo de `map_screen.dart` será atualizado para não afirmar o contrário).

## Complexity Tracking

Nenhuma violação de constituição sem justificativa já registrada — tabela não aplicável. A exposição
de dado sensível sem criptografia está coberta pela seção "Justificativa de privacidade" do
`spec.md`, citada na tabela de Constitution Check acima, não por uma justificativa ad-hoc deste
plano.

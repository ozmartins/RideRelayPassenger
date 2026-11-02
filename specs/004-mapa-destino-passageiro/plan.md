# Implementation Plan: Mapa e Destino do Passageiro

**Branch**: `004-mapa-destino-passageiro` (a criar) | **Date**: 2026-09-17 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/004-mapa-destino-passageiro/spec.md`

## Summary

Tornar a tela inicial do aplicativo do passageiro um mapa centrado na posição real do aparelho, com um
ícone de carro marcando essa posição e atualizado continuamente, e um campo de texto na mesma tela para
o passageiro informar o endereço para onde deseja ir. Nenhuma mensagem é publicada em relay como
consequência de informar o destino — essa comunicação fica para uma feature futura.

A abordagem reutiliza as mesmas dependências já decididas pelo motorista na feature equivalente
(`driver/specs/004-mapa-status-motorista`): `geolocator` para permissão e leitura contínua de posição, e
`flutter_map` com mosaicos do OpenStreetMap para o mapa, sem exigir chave nem conta de nenhum provedor
de terceiro. O campo de destino não introduz nenhuma dependência nova (D3 de `research.md`).

## Technical Context

**Language/Version**: Dart 3.13.3 (Flutter, stable) — inalterado em relação às features anteriores

**Primary Dependencies**:
- `geolocator ^14.0.3` — permissão e leitura contínua de posição (a adicionar; D1 de `research.md`,
  mesma versão do motorista)
- `flutter_map ^8.3.2` + `latlong2 ^0.10.1` — mapa com mosaicos do OpenStreetMap (a adicionar; D2,
  mesma versão do motorista)

**Storage**: nenhuma. Posição e endereço de destino existem só em memória, durante a sessão
(`data-model.md`) — ao contrário do nome de exibição (feature 003), que fica em `shared_preferences`.

**Testing**: `flutter test` com testes de unidade cobrindo, via dublê de `LocationService` (sem sensor
real, Princípio II por analogia): posição exibida quando disponível, mensagem quando indisponível, e
indicador acompanhando a posição. Testes de widget da tela de mapa cobrindo o campo de destino: texto
refletido ao digitar, campo funcionando com e sem localização disponível, e nenhuma chamada ao
`RelayService`/`EventFeed` disparada pela digitação (FR-008, verificável com dublê que falha o teste se
qualquer publicação for solicitada). `flutter analyze` como gate.

**Target Platform**: Android apenas (inalterado). Nova permissão exigida: localização em primeiro
plano (`ACCESS_FINE_LOCATION`, com `ACCESS_COARSE_LOCATION` como alternativa de menor precisão que o
próprio `geolocator` já solicita em conjunto) — permissão perigosa, com diálogo ao usuário, justificada
por esta feature.

**Project Type**: mobile-app

**Performance Goals**: posição exibida em ≤ 5 s após abrir o app (SC-001); indicador reflete
deslocamento em ≤ 10 s (SC-002); texto do campo de destino refletido em ≤ 1 s por caractere (SC-003)

**Constraints**: sem chave nem conta de provedor de mapa de terceiro (D2); nada de posição ou destino
persistido ou enviado a relay nesta feature (Assumptions e FR-008 do `spec.md`); campo de destino não
depende de posição disponível (FR-010)

**Scale/Scope**: 1 tela nova (mapa, tela inicial), 1 serviço de localização, 2 entidades de domínio
(`PassengerPosition`, `DestinationAddress`), 1 permissão nova no manifesto

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Estado da constituição**: em vigor na versão **2.1.0** (5 princípios, dois deles NÃO NEGOCIÁVEIS).

**Resultado do gate**: PASS.

| Princípio | Avaliação desta feature |
|-----------|-------------------------|
| I. Segredo criptográfico não vaza | **Não se aplica**: esta feature não toca chave privada nem material de assinatura. |
| II. Assinatura e verificação nascem com teste | **Não se aplica diretamente**: não há assinatura nem verificação de evento aqui. Por analogia, o teste que garante que digitar o destino nunca dispara publicação (FR-008) MUST existir antes de considerar a feature concluída, com dublê de relay — sem rede real. |
| III. Dependência de terceiros exige decisão registrada | **Atendido**: `geolocator` (D1) e `flutter_map`/`latlong2` (D2) registrados em `research.md`, reaproveitando a decisão já registrada e datada do motorista, com a mesma rejeição explícita de `google_maps_flutter` e `mapbox_maps_flutter`. O campo de destino (D3) explicitamente não introduz dependência nova. Tipos de ambos os pacotes ficam confinados a `lib/services/` e à tela de mapa (Structure Decision). |
| IV. O contrato de evento vem antes do código | **Não se aplica**: nenhum evento Nostr é criado ou alterado. Posição e destino permanecem locais ao aparelho (FR-008, Assumptions do `spec.md`). Nada precisa ser replicado em `Prototipo/driver`. |
| V. Simplicidade proporcional e rastreabilidade acadêmica | **Atendido com justificativa**: `research.md` reaproveita a rejeição já feita pelo motorista de duas alternativas de mapa por exigirem infraestrutura de terceiro desproporcional a um protótipo acadêmico, e rejeita explicitamente trazer geocodificação/autocompletar para o campo de destino, sem requisito que o justifique. Nenhuma camada nova além do padrão já existente (`domain/services/screens/shared`). |

**Restrições de Segurança e Privacidade**: esta feature é a que **justifica por escrito** o acesso à
localização do aparelho no app do passageiro — dado sensível que a constituição proíbe acessar sem
feature própria que o declare. A Assumption correspondente do `spec.md` descreve o dado coletado
(coordenadas atuais), seu uso (centrar o mapa, ícone de posição) e seu tempo de vida (memória da sessão,
nunca persistido nem enviado a terceiros). A permissão de localização é solicitada somente ao abrir a
tela de mapa, nunca antecipadamente. O endereço de destino não é dado sensível de localização do
aparelho (é texto informado deliberadamente pelo usuário), mas segue a mesma restrição de não ser
enviado a terceiros nesta feature (FR-008).

**Fluxo de Desenvolvimento e Gates**: `flutter analyze` e `flutter test` limpos, e execução dos 7
cenários do `quickstart.md` com relato honesto de falhas — condições para declarar a feature concluída.

## Project Structure

### Documentation (this feature)

```text
specs/004-mapa-destino-passageiro/
├── plan.md              # Este arquivo
├── research.md          # Fase 0 — D1 (geolocator), D2 (flutter_map + latlong2), D3 (sem dependência para o destino)
├── data-model.md         # Fase 1
├── quickstart.md         # Fase 1
├── checklists/
│   └── requirements.md
└── tasks.md              # Fase 2 (/speckit-tasks)
```

Sem `contracts/`: esta feature não expõe nem consome nenhuma interface externa — nenhum evento Nostr
está envolvido (Princípio IV, avaliado acima).

### Source Code (repository root)

```text
Prototipo/passenger/
├── lib/
│   ├── main.dart                          # + carrega LocationService no bootstrap; MapScreen
│   │                                       #   passa a ser a primeira aba da navegação (barra de
│   │                                       #   navegação inferior, mesmo padrão do motorista); a
│   │                                       #   HomeScreen atual (lista de eventos) vira a segunda aba
│   ├── domain/
│   │   ├── passenger_position.dart        # PassengerPosition (latitude, longitude, capturedAt)
│   │   └── destination_address.dart       # DestinationAddress (text)
│   ├── services/
│   │   ├── location_service.dart          # interface LocationService (injetável nos testes) +
│   │   │                                   #   exceções de permissão negada / indisponibilidade
│   │   └── geolocator_location_service.dart  # implementação real sobre geolocator (único
│   │                                          #   arquivo que conhece package:geolocator,
│   │                                          #   Princípio III)
│   └── screens/
│       └── map_screen.dart                # mapa (flutter_map) + ícone de carro + campo de destino;
│                                           #   único arquivo que conhece package:flutter_map além
│                                           #   de main.dart
├── test/
│   ├── services/
│   │   └── location_service_test.dart     # dublê em memória; cobre permissão negada e
│   │                                       #   indisponibilidade
│   ├── domain/
│   │   └── destination_address_test.dart  # aceita texto livre, inclusive vazio e inválido
│   └── screens/
│       └── map_screen_test.dart           # ícone de posição exibido/ausente, campo de destino
│                                           #   refletindo o texto digitado, campo funcionando sem
│                                           #   posição disponível, e nenhuma chamada de publicação
│                                           #   disparada pela digitação (dublê de RelayService que
│                                           #   falha o teste se `publish` for chamado)
└── android/app/src/main/AndroidManifest.xml   # + permissão de localização em primeiro plano
```

O único arquivo que conhece tipos de `geolocator` é `geolocator_location_service.dart`; o único que
conhece tipos de `flutter_map` é `map_screen.dart` — nem `domain/`, nem o restante de `services/`, nem
qualquer outra tela os importam (Princípio III).

**Structure Decision**: mantém-se a separação `domain/` + `services/` + `screens/` + `shared/` já
estabelecida. `MapScreen` passa a ocupar a primeira posição da navegação em `main.dart`, com uma barra
de navegação inferior análoga à do motorista; a `HomeScreen` atual (lista de eventos) desloca-se para a
posição seguinte, e as telas de Identidade e Relays continuam acessíveis, sem serem removidas
(Assumptions do `spec.md`). O `MapScreen` **não** usa `RelayService` nem `EventFeed` para o campo de
destino — só recebe `LocationService` — o que já evidencia estruturalmente que nada ali pode publicar
em relay (FR-008).

## Complexity Tracking

> Nenhuma violação de constituição a justificar (ver Constitution Check).

# Implementation Plan: Rota real até o destino

**Branch**: `007-rota-ate-destino` | **Date**: 2026-09-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/007-rota-ate-destino/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Calcular a distância real do trajeto rodoviário (não linha reta) entre a posição atual do passageiro
e o `DestinationAddress` escolhido (feature 005), usando a API openrouteservice via o pacote
`open_route_service`, e desenhar essa rota como uma `Polyline` no `flutter_map` já usado pela tela do
mapa (feature 004). Cálculo inteiramente local ao aparelho: nenhum evento Nostr é publicado, lido ou
alterado por esta feature (FR-009). Recalcula ao trocar de destino e a cada 50 m de deslocamento da
origem usada no último cálculo (Clarifications, sessão 2026-09-20), nunca a cada atualização de GPS,
para respeitar o limite de requisições do nível gratuito do serviço. Falha do serviço de rota é
absorvida sem bloquear "Solicitar corrida" (US3, FR-006/FR-007).

## Technical Context

**Language/Version**: Dart 3.x / Flutter (mesmo SDK do restante do `passenger/`, sem mudança de
versão mínima)

**Primary Dependencies**: `open_route_service ^1.2.9` (novo — cliente da API openrouteservice,
Princípio III, ver `research.md` D1); `flutter_map` e `latlong2` (já usados pela feature 004, reuso
do `Polyline` nativo do `flutter_map` para o traçado, sem dependência nova)

**Storage**: N/A — resultado do cálculo de rota existe só em memória durante a sessão (Key Entities
do `spec.md`), não persistido

**Testing**: `flutter_test`, com o mesmo padrão de dublê do restante do projeto (`FakeRouteService`
implementando a abstração `RouteService` do projeto — nenhum teste chama a rede real, Princípio II
aplicado por analogia: mesmo padrão de `GeocodingService`/`LocationService`)

**Target Platform**: Android (único suportado pelo projeto)

**Project Type**: mobile-app (Flutter), único projeto — sem frontend/backend separados

**Performance Goals**: distância exibida em até 3 s em condição normal de rede (SC-001); no máximo
uma requisição de rota por troca de destino ou por 50 m de deslocamento (FR-003, evita exceder o
limite de requisições do nível gratuito do serviço)

**Constraints**: cálculo de rota MUST ser local ao app — MUST NOT publicar, alterar nem depender de
evento Nostr, nem alterar o contrato de eventos ou o formato do `kind: 20001` (FR-009); falha do
serviço de rota MUST NOT bloquear nenhuma outra ação da tela, incluindo "Solicitar corrida" (FR-006,
FR-007)

**Scale/Scope**: uma rota calculada por vez, entre dois pontos; sem suporte a múltiplas paradas ou
perfis de transporte além de carro de passeio (Assumptions do `spec.md`)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Avaliação contra `.specify/memory/constitution.md` v2.3.0:

| Princípio / Restrição | Avaliação |
|---|---|
| I. Segredo criptográfico não vaza | N/A — esta feature não toca chave privada nem material de assinatura. |
| II. Assinatura e verificação nascem com teste | N/A — nenhum código de assinatura/verificação de evento é criado ou alterado. |
| III. Dependência de terceiros exige decisão registrada | **Aplica-se.** `open_route_service` é dependência nova no `pubspec.yaml`. Decisão registrada em `research.md` D1, com alternativas avaliadas, versões e confinamento de tipos à camada de serviços. **PASS.** |
| IV. O contrato de evento vem antes do código | N/A — nenhum evento Nostr novo, alterado ou consumido; FR-009 torna isso explícito no próprio spec. |
| V. Simplicidade proporcional e rastreabilidade acadêmica | **Aplica-se.** O throttle de 50 m (D2) e o perfil único de rota (carro) são decisões registradas com alternativas descartadas em `research.md`. **PASS.** |
| Restrições de Segurança e Privacidade — exceção de roteamento (emenda 2.3.0) | **Aplica-se e é o motivo desta emenda.** A chamada envia lat/lon de origem (posição atual) e destino ao serviço openrouteservice. Condições da exceção: HTTPS (endpoint `https://api.openrouteservice.org`, D1), nenhum identificador do usuário além das coordenadas (D3 — sem `pubkey`, nome ou apelido de exibição na chamada), sem persistência da resposta além da sessão (Key Entities do `spec.md`), decisão registrada em `research.md` citando a exceção. **PASS**, condicionado à emenda 2.3.0 já commitada separadamente do código desta feature. |

**Resultado**: PASS. Nenhuma entrada em Complexity Tracking é necessária.

## Project Structure

### Documentation (this feature)

```text
specs/007-rota-ate-destino/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

Sem `contracts/`: esta feature não expõe nem consome nenhum contrato de evento Nostr entre as apps
(FR-009) — o único contrato relevante é com o serviço externo openrouteservice, documentado em
`research.md` como decisão de dependência (Princípio III), não como contrato entre driver/passenger.

### Source Code (repository root)

```text
lib/
├── domain/
│   └── route_result.dart          # novo — Entidade "Rota calculada" (data-model.md)
├── services/
│   └── route_service.dart         # novo — abstração RouteService + OrsRouteService (open_route_service confinado aqui)
├── screens/
│   └── map_screen.dart            # alterado — consome RouteService, desenha Polyline, exibe distância
└── shared/
    # sem alteração — default_relays.dart e prototype_marker.dart não são tocados por esta feature

test/
├── services/
│   └── route_service_test.dart    # novo — FakeRouteService, casos de sucesso/falha/throttle
├── domain/
│   └── route_result_test.dart     # novo
└── screens/
    └── map_screen_test.dart       # alterado — cobre exibição de distância, traçado e falha não bloqueante
```

**Structure Decision**: segue o layout já existente (`domain/` + `services/` + `screens/`), sem
introduzir camada nova. `RouteService` é uma abstração de projeto, seguindo o mesmo padrão de
`GeocodingService`/`LocationService`: tipos de `open_route_service` (`ORSCoordinate`,
`OpenRouteService`) ficam confinados a `lib/services/route_service.dart` (Princípio III); `domain/` e
`screens/` só veem `RouteResult`, tipo próprio do projeto.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Nenhuma violação — seção não aplicável.

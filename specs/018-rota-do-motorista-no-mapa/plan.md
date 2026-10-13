# Implementation Plan: Rota da corrida enviada pelo motorista, no mapa do passageiro

**Branch**: `master` (commits diretos, sem branch de feature — Padrão de Commits da constituição) | **Date**: 2026-10-03 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/018-rota-do-motorista-no-mapa/spec.md`

## Summary

O passageiro passa a se inscrever em `kind: 20011` ("Rota da corrida", emenda 13, definida pela
feature 017 do motorista) e, em `emCorrida`, traça no mapa a rota válida mais nova recebida do
motorista da corrida aceita. Um valor de domínio novo (`RideRoute`) valida o `content` (2 a 1000
pontos, coordenadas em faixa); `MapScreen` confere autor e orçamento (como já faz com o
`kind: 20005`), guarda só a rota mais nova em memória e a desenha numa `PolylineLayer` própria. Em
`emCorrida` o app deixa de calcular e de desenhar a rota local da feature 007 (nenhuma consulta ao
serviço de rotas nesse estado). Sem mudança no motorista além da 017; sem formato de evento novo —
só consumo.

## Technical Context

**Language/Version**: Dart 3 / Flutter (versão já fixada no `pubspec.yaml`)

**Primary Dependencies**: `flutter_map` (`PolylineLayer`), `latlong2`, `dart_nostr` — todas já em
uso; **nenhuma dependência nova**.

**Storage**: N/A — rota só em memória (FR-007).

**Testing**: `flutter_test` com os dublês de `test/support/` (transporte, localização, rota);
nenhum teste toca rede (Princípio II). Validação do `content` é lógica pura em `domain/`.

**Target Platform**: Android

**Project Type**: mobile-app (Flutter)

**Performance Goals**: traçado visível em até 2 s do recebimento; some em até 1 s da saída de
`emCorrida` (SC-001, SC-005).

**Constraints**: zero consultas de rota do passageiro em `emCorrida` (SC-004); rota recebida no
máximo 1000 pontos (validado, não confiado); nenhuma permissão nova.

**Scale/Scope**: um motorista, uma corrida, uma rota por vez.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio / restrição | Avaliação |
|---|---|
| I. Segredo criptográfico não vaza | N/A — nenhuma chave é tocada. |
| II. Assinatura/verificação com teste | Passa — a verificação de assinatura e `id` já ocorre em `EventFeed`; o novo teste cobre a conferência de autor e de `quoteId` (FR-003) e o descarte de conteúdo inválido. |
| III. Dependência exige decisão registrada | Passa — nenhuma dependência nova. |
| IV. Contrato antes do código, replicado | **GATE ATIVO — dependência bloqueante.** A emenda 13 (kind `20011`) é escrita pela feature 017 do motorista (tarefas T001/T002, nas duas cópias) e **ainda não consta em nenhuma cópia**. Nenhum código desta feature começa antes de ela estar commitada; a primeira tarefa verifica isso. Esta feature não altera formato (só consumo). |
| V. Simplicidade e medição | Passa — reuso do padrão da feature 016 (autor + `quoteId` + mais novo por `created_at`), do `EventFeed` e da camada de polilinha existente; nenhuma abstração nova além de um valor de domínio. |
| Restrições de Segurança e Privacidade | Passa sem emenda — nada novo sai do aparelho; **diminui** o uso da exceção de roteamento (menos consultas). |
| Identidade Visual e Design | Passa — mesma rota `roxo` de 5 px já definida; sem componente novo (D5). |

Pós-design (Phase 1): inalterado.

## Project Structure

### Documentation (this feature)

```text
specs/018-rota-do-motorista-no-mapa/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/README.md      # sem contrato novo: aponta para a emenda 13 e lista a conferência
├── checklists/requirements.md
└── tasks.md                 # /speckit-tasks
```

### Source Code

```text
lib/
├── domain/
│   ├── ride_route.dart               # NOVO: RideRoute — valida o content do kind 20011
│   └── passenger_ride_status.dart    # + PassengerRideRules.canShowDriverRoute (só emCorrida)
├── services/
│   └── event_feed.dart               # + const rideRouteKind = 20011
├── main.dart                         # + rideRouteKind em acceptedKinds
└── screens/
    └── map_screen.dart               # processa 20011; PolylineLayer da rota do motorista;
                                      # em emCorrida suprime cálculo/desenho da rota local (007)

test/
├── domain/ride_route_test.dart                    # NOVO
├── domain/passenger_ride_status_test.dart         # + canShowDriverRoute
└── screens/map_screen_test.dart                   # + grupo "rota do motorista (feature 018)"
```

**Structure Decision**: mesma divisão `domain/` + `services/` + `screens/` do app; sem serviço novo.
O estado `emCorrida` já existe (feature 014); nada novo em `AcceptedRide` nem em
`PassengerRideStateStore`.

## Complexity Tracking

Sem violações a justificar.

# Implementation Plan: Posição do motorista no mapa do passageiro

**Branch**: `master` (commits diretos, sem branch de feature — Padrão de Commits da constituição) | **Date**: 2026-09-30 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/016-posicao-do-motorista/spec.md`

## Summary

Em "motorista a caminho", o passageiro passa a decodificar e exibir o `lat`/`lon` do `kind: 20005`
que hoje só serve de sinal de "o motorista saiu" (features 009/014). Um valor de domínio novo
(`DriverLocation`) valida o `content`; `MapScreen` guarda a última posição válida e mais nova do
motorista aceito (autor e corrida conferidos), desenha o marcador com o mesmo aspecto do app do
motorista (círculo de 44 px, ícone de carro) e, na primeira exibição, enquadra motorista e
passageiro — o que obriga o mapa do passageiro a parar de recentralizar a cada GPS e a ganhar o
botão "Centralizar" que a constituição já prevê. Nenhum formato de evento muda; a nota de consumo do
`kind: 20005` no contrato é atualizada (emenda 12) nas duas cópias.

## Technical Context

**Language/Version**: Dart 3 / Flutter (versão já fixada no `pubspec.yaml`)

**Primary Dependencies**: `flutter_map` (`MarkerLayer`, `CameraFit`), `latlong2`, `dart_nostr`
(já em uso) — **nenhuma dependência nova**.

**Storage**: N/A — posição só em memória (FR-009).

**Testing**: `flutter_test` com os dublês de `test/support/` (transporte, localização, rota); nenhum
teste toca rede (Princípio II). Validação do `content` é lógica pura em `domain/`.

**Target Platform**: Android

**Project Type**: mobile-app (Flutter)

**Performance Goals**: marcador visível em até 1 s depois de a mensagem chegar ao app (SC-001).

**Constraints**: nenhum dado novo sai do aparelho; nenhuma permissão nova.

**Scale/Scope**: um motorista, uma corrida ativa.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio / restrição | Avaliação |
|---|---|
| I. Segredo criptográfico não vaza | N/A — nenhuma chave é tocada. |
| II. Assinatura/verificação com teste | Passa — a verificação já ocorre em `EventFeed`; o novo teste cobre a conferência de autor (FR-005). |
| III. Dependência exige decisão registrada | Passa — nenhuma dependência nova. |
| IV. Contrato antes do código | Passa com tarefa dedicada: formato inalterado, mas a nota "não decodifica nem exibe `lat`/`lon`" (emenda 10) fica falsa; emenda 12 nas **duas** cópias, antes do código (D1). |
| V. Simplicidade e medição | Passa — reusa estado, `EventFeed` e inscrição existentes; SC-001/SC-005 medidos no quickstart. |
| Segurança e Privacidade | Passa — dado já recebido e público no relay; nada novo é enviado a terceiro nem persistido; sem permissão nova. |
| Identidade Visual e Design | Passa — marcador de 44 px, `fundo`, borda branca 2 px, ícone `destaque` e botão circular de 48 px já constam; sem emenda. |

Pós-design (Phase 1): inalterado.

## Project Structure

### Documentation (this feature)

```text
specs/016-posicao-do-motorista/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks
```

Sem `contracts/` próprio: o contrato é o único arquivo compartilhado
(`specs/002-nostr-relay-connection/contracts/nostr-events.md`, nas duas apps).

### Source Code

```text
lib/
├── domain/
│   └── driver_location.dart       # NOVO: valida o content do kind 20005 (lat/lon), instante declarado
└── screens/
    └── map_screen.dart            # estado da posição, conferência de autor, marcador, enquadramento, "Centralizar"

test/
├── domain/driver_location_test.dart   # NOVO
└── screens/map_screen_test.dart       # + cenários da feature 016

(driver) Prototipo/driver/specs/002-nostr-relay-connection/contracts/nostr-events.md   # emenda 12
passenger specs/002-nostr-relay-connection/contracts/nostr-events.md                    # cópia
```

**Structure Decision**: mesma divisão `domain/` + `screens/` das features 008/009 do passageiro
(`ReceivedQuote.fromNostrEvent` é o precedente direto de `DriverLocation.fromNostrEvent`). Nenhum
serviço novo: a inscrição em `20005` já existe desde a emenda 10.

## Complexity Tracking

Sem violações.

# Implementation Plan: Seguir o motorista no mapa do passageiro

**Branch**: `master` (commits diretos, sem branch de feature — Padrão de Commits da constituição) | **Date**: 2026-10-01 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/017-seguir-motorista/spec.md`

## Summary

Em "motorista a caminho" e com posição do motorista exibida, `MapScreen` passa a centralizar o mapa
em cada posição nova do motorista (mantendo o zoom vigente) e a ignorar o GPS do passageiro para
mover a câmera. O botão "Centralizar" e todo o estado que o sustentava (`_seguindoPassageiro`,
`_motoristaEnquadrado`, `_enquadrarMotorista`, `_centralizarNoPassageiro`, `_BotaoCentralizar`)
deixam de existir: a regra "quem o mapa segue" passa a ser derivada de `_rideStatus` e
`_posicaoMotorista`, sem flag própria. Mudança só de apresentação: nenhum evento, contrato,
dependência ou dado persistido muda.

## Technical Context

**Language/Version**: Dart 3 / Flutter (versão já fixada no `pubspec.yaml`)

**Primary Dependencies**: `flutter_map` (`MapController.move`), `latlong2` — **nenhuma dependência nova**.

**Storage**: N/A.

**Testing**: `flutter_test`, mesmos dublês de `test/support/`; reescreve o grupo `enquadramento e
"Centralizar" (FR-007)` de `test/screens/map_screen_test.dart` (feature 016), hoje obsoleto.

**Target Platform**: Android

**Project Type**: mobile-app (Flutter)

**Performance Goals**: câmera no motorista no mesmo quadro em que o marcador é atualizado.

**Constraints**: nenhum dado novo sai do aparelho; nenhuma permissão nova.

**Scale/Scope**: um motorista, uma corrida ativa; um arquivo de produção (`map_screen.dart`).

## Constitution Check

| Princípio / restrição | Avaliação |
|---|---|
| I. Segredo criptográfico não vaza | N/A — nenhuma chave é tocada. |
| II. Assinatura/verificação com teste | N/A — verificação e conferência de autor (feature 016) intactas. |
| III. Dependência exige decisão registrada | Passa — nenhuma dependência nova. |
| IV. Contrato antes do código | N/A — nenhum formato de evento muda (FR-010); sem emenda, sem contrapartida no motorista. |
| V. Simplicidade e medição | Passa — **remove** estado e um widget em vez de acrescentar; SC medidos por teste de widget e quickstart. |
| Segurança e Privacidade | Passa — nada novo enviado, gravado ou pedido. |
| Identidade Visual e Design | Passa — a menção a "botão de centralizar" na constituição descreve a medida do componente, não exige que ele exista em todo estado; nenhuma emenda. |

Pós-design: inalterado.

## Project Structure

### Documentation (this feature)

```text
specs/017-seguir-motorista/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks
```

Sem `contracts/`: nenhuma interface compartilhada muda.

### Source Code

```text
lib/screens/map_screen.dart        # remove flags/botão; centraliza no motorista; GPS condicionado

test/screens/map_screen_test.dart  # reescreve o grupo de enquadramento/"Centralizar" da 016
```

**Structure Decision**: tudo em `MapScreen`, onde já vive o estado da feature 016; sem arquivo novo.

## Complexity Tracking

Sem violações.

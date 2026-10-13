# Implementation Plan: Botões de cancelar corrida em roxo (passageiro)

**Branch**: `master` (commits diretos) | **Date**: 2026-10-07 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/024-botao-cancelar-roxo/spec.md`

## Summary

O botão "Cancelar corrida" do mapa (`_BotaoCancelarCorrida`) e o "Cancelar" da lista de orçamentos
(`ReceivedQuotesScreen`) passam a `FilledButton.icon` com `IdentidadeVisual.estiloAcaoPrimaria(altura: 48)`, o
mesmo estilo do botão de confirmação de `CancelRideModal`. Só cores/tipo de botão mudam. Constituição já emendada
(2.12.0). Sem contrato, estado ou persistência.

## Technical Context

**Language/Version**: Dart 3 / Flutter · **Dependencies**: nenhuma nova · **Storage**: N/A ·
**Testing**: `flutter_test` · **Target**: Android · **Project Type**: mobile-app ·
**Constraints**: contraste ≥ 4,5:1; geometria, rótulos, chaves e cartão intactos · **Scope**: 2 widgets.

## Constitution Check

| Princípio / restrição | Avaliação |
|---|---|
| I, II, III | PASS por vacuidade (sem cripto, sem assinatura, sem dependência). |
| IV. Contrato antes do código, replicado | PASS. Nenhum contrato muda; a emenda 2.12.0 foi replicada nas duas apps (`662fda7`). |
| V. Simplicidade | PASS. Reaproveita o estilo existente. |
| Segurança e Privacidade | PASS. Nada trafega. |
| Identidade Visual e Design | PASS. Segue o componente "Botão de cancelamento de corrida" (2.12.0). |
| Governance | PASS. Emenda anterior e separada do código. |

## Project Structure

```text
specs/024-botao-cancelar-roxo/{plan,research,data-model,quickstart,tasks}.md, contracts/README.md, checklists/requirements.md

lib/screens/map_screen.dart                  # _BotaoCancelarCorrida
lib/screens/received_quotes_screen.dart      # botão "Cancelar"
test/screens/map_screen_test.dart            # aparência; localizador `confirmar`
test/screens/received_quotes_screen_test.dart
test/screens/cancel_ride_modal_test.dart
```

**Structure Decision**: sem arquivo novo em `lib/`.

## Complexity Tracking

Sem violações.

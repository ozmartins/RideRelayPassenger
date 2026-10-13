# Tasks: Botões de cancelar corrida em roxo (passageiro)

**Tests**: incluídos (gate de conclusão da constituição; SC-002/SC-003).
**Pré-requisito**: emenda 2.12.0 já commitada (`662fda7`).

## Phase 1: US1 — Botão do mapa (P1) 🎯 MVP

- [x] T001 [US1] Em `test/screens/map_screen_test.dart`, grupo "cancelar corrida (feature 023)": ajustar o localizador `confirmar` para `FilledButton` com texto "Cancelar corrida" **sem** a chave `botao-cancelar-corrida`; acrescentar teste (vermelho primeiro) que, nos três estados em que o botão existe, lê o `ButtonStyle` do `FilledButton` de chave `botao-cancelar-corrida`, espera fundo `IdentidadeVisual.roxo`, texto branco, razão WCAG ≥ 4,5:1, rótulo "Cancelar corrida", altura 48.
- [x] T002 [US1] Em `lib/screens/map_screen.dart`, `_BotaoCancelarCorrida`: trocar `TextButton.icon` por `FilledButton.icon` com `IdentidadeVisual.estiloAcaoPrimaria(altura: 48)`, mantendo cartão, chave, rótulo e `Icons.cancel_outlined`, sem cor de erro; atualizar o comentário da classe.
- [x] T003 [US1] Rodar `flutter test test/screens/map_screen_test.dart --plain-name "cancelar"`; os testes de comportamento da 023/019/020/021 seguem verdes sem alteração.

## Phase 2: US2 — Lista de orçamentos (P2)

- [x] T004 [P] [US2] Em `test/screens/received_quotes_screen_test.dart`, teste que o `FilledButton` "Cancelar" tem fundo `IdentidadeVisual.roxo`, texto branco e contraste ≥ 4,5:1, com a lista vazia e com orçamentos.
- [x] T005 [US2] Em `lib/screens/received_quotes_screen.dart`, trocar o `styleFrom` em erro por `IdentidadeVisual.estiloAcaoPrimaria(altura: 48)`; manter `SizedBox`, rótulo, `Icons.close` e `onCancel`.

## Phase 3: US3 — Igualdade com a confirmação (P2)

- [x] T006 [P] [US3] Em `test/screens/cancel_ride_modal_test.dart`, teste do botão "Cancelar corrida": fundo roxo e texto branco.
- [x] T007 [US3] Em `test/screens/map_screen_test.dart`, teste que compara fundo e texto do botão do mapa com os do botão da confirmação aberta (SC-003).

## Phase 4: Polish

- [x] T008 `flutter analyze` ("No issues found!") e `flutter test` integral (em lotes se necessário).
- [x] T009 Preencher "Estado da validação" do `quickstart.md`; validação em aparelho **pendente**.
- [x] T010 Commitar código e testes num commit próprio; depois registrar as features 022 (motorista) e 024 (passageiro) e a emenda 2.12.0 no `../CLAUDE.md`, commit à parte.

## Dependencies

T001→T002→T003; T004→T005; T006 [P]; T007 depende de T002; T008→T009→T010.
MVP = US1.

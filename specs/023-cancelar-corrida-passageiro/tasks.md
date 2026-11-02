# Tasks: Cancelar corrida (passageiro)

**Input**: `specs/023-cancelar-corrida-passageiro/` (spec, plan, research, data-model, quickstart)
**Tests**: incluídos — Princípio II e o padrão do projeto.
**Convenção**: `[P]` = arquivos diferentes, sem dependência de tarefa incompleta; `[USn]` = história de `spec.md`.

## Phase 1: Setup

- [x] T001 Conferir a emenda 19 nas duas cópias do contrato, idênticas (`diff <(tail -n +12 specs/002-nostr-relay-connection/contracts/nostr-events.md) ../driver/specs/002-nostr-relay-connection/contracts/nostr-events.md` sem saída) e o commit `747f944` antes de qualquer código desta feature (Princípio IV).

## Phase 2: Foundational

- [x] T002 [P] Acrescentar `PassengerRideRules.canCancelRide` (`orcamentoAceito`, `motoristaACaminho`, `emCorrida`) em `lib/domain/passenger_ride_status.dart` e testes no arquivo de teste existente dessa classe em `test/`.
- [x] T003 [P] Em `lib/services/event_feed.dart`, acrescentar `const rideCancelledByPassengerKind = 20013;` e `publishRideCancellation(quoteId, driverPubkey, identity)` copiando `publishMeetingConfirmation` (`content: ''`, `recipientPubkey`, tags `e` e `p`); testes em `test/event_feed_test.dart`: kind 20013, tags `t`/`e`/`p`, assinatura válida, `content` cifrado que o motorista decifra para `{}`, e `PublishReport` vazio sem relay.
- [x] T004 [P] Criar `lib/screens/cancel_ride_modal.dart` (confirmação apresentacional: `ModalTematizado`, título "Cancelar corrida?", mensagem "O motorista será avisado de que você cancelou a corrida.", ações "Voltar" e "Cancelar corrida" → `onBack`/`onConfirm`), no padrão de `ride_cancelled_modal.dart` e do `CancelRideModal` do motorista; e `test/screens/cancel_ride_modal_test.dart`.

## Phase 3: US1 — Cancelar antes do motorista chegar (P1) 🎯 MVP

**Teste independente**: em "orçamento aceito" e "motorista a caminho", cancelar e confirmar → estado `inicial`, corrida aceita e posição do motorista zeradas, um `20013` publicado ao motorista certo.

- [x] T005 [US1] Em `lib/screens/map_screen.dart`: estado `_modalConfirmarCancelamentoVisivel`; `_cancelarCorrida()` (guardas `_corridaAceita != null` e `canCancelRide`, captura da corrida, `_encerrarCorridaAceita(() {})`, depois `unawaited(_publicarCancelamento(corrida))`); `_publicarCancelamento` (sem relay conectado não publica; exceção e recusa absorvidas); `_encerrarCorridaAceita` passa a limpar `_modalConfirmarCancelamentoVisivel`.
- [x] T006 [US1] Em `lib/screens/map_screen.dart`: botão "Cancelar corrida" (`Key('botao-cancelar-corrida')`, cartão `folha`, ícone e texto `ColorScheme.error`) em painel inferior visível só com `canCancelRide(_rideStatus)` e sem modal da corrida aberta; e a confirmação em `Stack` no `build()` (`CancelRideModal`, precedência D5).
- [x] T007 [US1] Testes em `test/screens/map_screen_test.dart`: botão existe em "orçamento aceito" e "motorista a caminho"; tocar abre a confirmação; "Voltar" não muda nada nem publica; confirmar volta a `inicial` persistido, zera posição/rota do motorista, painel de solicitação volta e exatamente um `20013` com tags `e`/`p` corretas e `content` que o motorista decifra para `{}` é publicado.

## Phase 4: US2 — Cancelar em andamento (P1)

- [x] T008 [US2] Teste em `test/screens/map_screen_test.dart`: em "em corrida", confirmar → `inicial`, rota do motorista removida do mapa, `20013` publicado, **nenhuma** `RideRatingModal`.

## Phase 5: US3 — Definitivo, único, sem efeitos colaterais (P2)

- [x] T009 [US3] Testes em `test/screens/map_screen_test.dart`: botão ausente em `aguardandoOrcamentos`, `inicial` e `destinoConfirmadoAguardandoAvaliacao`; duplo toque em "Cancelar corrida" publica um único aviso; reinício após cancelar reabre em `inicial` sem corrida aceita; eventos do motorista (`20005`, `20012`) depois do cancelamento são ignorados, sem modal.
- [x] T010 [US3] Testes de concorrência e falha em `test/screens/map_screen_test.dart`: com a confirmação aberta, chegar o `20012` do motorista (ou a expiração por silêncio) fecha a confirmação, abre a modal do desfecho e não publica `20013`; sem relay conectado e com publicação recusada o cancelamento local acontece, sem erro nem reenvio.

## Phase 6: Polish

- [x] T011 `flutter analyze` ("No issues found!") e suíte completa (`map_screen_test.dart` em segundo plano; o resto em lote separado); anotar contagens em `quickstart.md`.
- [x] T012 Marcar em `quickstart.md` a validação em aparelho como **pendente**; conferir de novo o `diff` do contrato (T001) e que nenhum arquivo do motorista foi tocado por esta feature.

## Dependências

- Phase 2 antes de tudo (T002, T003, T004 em paralelo); T005–T007 dependem delas; T008–T010 dependem de T005–T006.
- MVP = Phases 1–3.

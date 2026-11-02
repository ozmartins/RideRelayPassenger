# Research — Corrida cancelada pelo motorista (passageiro)

## D1 — Inscrição

**Decision**: `const rideCancelledKind = 20012;` em `lib/services/event_feed.dart` (junto dos
demais `*Kind`) e inclusão em `acceptedKinds` de `lib/main.dart`; `MapScreen._aoAtualizarOrcamentos`
despacha esse kind para `_processarCancelamentoDoMotorista`.

**Rationale**: `EventFeed.acceptedKinds` é a única porta de entrada de kinds de corrida do
passageiro (features 008/009/010/018); o contrato (emenda 14, "Forma da inscrição") já inclui `20012`
na inscrição do passageiro. Sem isso o relay nem entregaria o evento.

**Alternatives**: nenhuma razoável — o padrão é único no app.

## D2 — Quem pode cancelar: autor + referência + fase

**Decision**: aceitar o evento só se `evento.authorPublicKey == corridaAceita.driverPubkey`,
`evento.referencedEventId == corridaAceita.quoteId`, o `id` ainda não foi processado
(`_idsCancelamentoProcessados`, padrão de `_idsRotaProcessados`) e
`PassengerRideRules.canBeCancelledByDriver(_rideStatus)` (`orcamentoAceito`, `motoristaACaminho`,
`emCorrida`). Em `destinoConfirmadoAguardandoAvaliacao`, `aguardandoOrcamentos` e `inicial`, ignora.

**Rationale**: a tag `["e", quoteId]` é pública no relay; sem checar o autor, qualquer um forjaria o
cancelamento (mesma razão da feature 016). A assinatura em si já foi verificada pelo `EventFeed`
(recalcula `id`, verifica Schnorr). Em `destinoConfirmadoAguardandoAvaliacao` a corrida já foi
concluída: cancelar depois não faz sentido e quebraria a avaliação (spec, Edge Cases).

**Alternatives**: não conferir o autor — rejeitado (forjável). Aceitar em
`destinoConfirmadoAguardandoAvaliacao` — rejeitado (corrida concluída).

## D3 — Efeito: no instante do recebimento, não no "OK"

**Decision**: ao aceitar, no mesmo `setState`: `_rideStatus = inicial`, `_corridaAceita = null`,
`_limparPosicaoMotorista()` (zera posição e rota do motorista), apaga `_modalMotoristaVisivel`,
`_modalChegadaMotoristaVisivel` e `_modalChegadaDestinoVisivel`, e liga
`_modalCorridaCanceladaVisivel`. Antes, `unawaited(rideStateStore.save(inicial, null))`. "OK" só
desliga a flag da modal. `AcceptedRideStore` não é limpo.

**Rationale**: igual a `movementNotified`/confirmações (marcar ao abrir, não ao tocar): fechar o app
com a modal aberta nunca reabre a corrida (FR-005, SC-003). O estado persistido `inicial` faz
`_carregarEstadoCorrida` retornar cedo, sem ler `AcceptedRideStore` (FR-004), então o registro
antigo é inofensivo e a próxima aceitação o sobrescreve — exatamente o que a conclusão normal
(`_finalizarAvaliacao`) já faz. Zerar `_corridaAceita` em memória faz todo evento tardio da corrida
(`20005`, `20007`, `20009`, `20011`) cair no `corridaAceita == null` dos processadores existentes
(FR-006). Confirmações em curso (`_confirmarEncontro`/`_confirmarDestino`) já se guardam por
`canConfirm…`, que passa a falhar com o estado `inicial`.

**Alternatives**: aplicar só ao tocar "OK" — rejeitado (reabre a corrida num reinício). Adicionar
`AcceptedRideStore.clear` — rejeitado (Princípio V; sem ganho observável).

## D4 — Modal

**Decision**: `RideCancelledModal` (`ModalTematizado`, título "Corrida cancelada", texto "O
motorista cancelou a corrida. Você pode solicitar outra.", botão "OK" primário 48 px), renderizada
em `Stack` na árvore do `MapScreen` como `DriverMovingModal` (e não por `showDialog`, pelo motivo de
T019 de `specs/008-receber-orcamentos/tasks.md`). No `build()`, a verificação dela vem **antes** das
demais modais.

**Rationale**: padrão estabelecido do app; precedência garante que o cancelamento domina qualquer
outra modal que ainda estivesse visível.

**Alternatives**: `showDialog` — rejeitado (problema documentado em teste de widget).

## D5 — Mapa e rota local depois do cancelamento

**Decision**: nenhuma lógica nova. Com `_rideStatus = inicial`, o marcador do motorista e a rota do
motorista já deixam de ser desenhados (condições por estado em `build()`), e a rota local da feature
007 volta a poder ser calculada no próximo GPS (`canShowDriverRoute` falso).

**Rationale**: a limpeza é consequência do estado; mesma situação da conclusão normal.

## D6 — Contrato

**Decision**: nenhuma alteração; o formato é o da emenda 14 (feature 018 do motorista).
`contracts/README.md` só registra o que esta feature consome e a pré-condição de que o contrato já
conste nas duas cópias.

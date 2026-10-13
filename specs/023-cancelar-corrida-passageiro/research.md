# Research — Cancelar corrida (passageiro)

## D1 — Kind e formato

**Decision**: publicar o `kind: 20013` como a emenda 19 o define: efêmero, tags `["t", marcador]`,
`["e", quoteId]`, `["p", <pubkey do motorista>]`; `content` vazio na API (`''`), que `EventFeed._publish`
transforma no marcador `{}` e cifra ao destinatário (emenda 17).

**Rationale**: mesmo caminho de `publishMeetingConfirmation`/`publishDestinationConfirmation`; a cifra, a
assinatura sobre o texto cifrado e as tags já são feitas por `_publish`.

**Alternatives**: reusar o `20004` — rejeitado: é anterior à aceitação e o motorista não o consome.

## D2 — Fases e o botão

**Decision**: `PassengerRideRules.canCancelRide(status)` = `orcamentoAceito`, `motoristaACaminho` ou
`emCorrida`. O botão "Cancelar corrida" (`Key('botao-cancelar-corrida')`) fica num painel sobreposto ao mapa,
embaixo, visível só quando a regra vale e **nenhuma modal da corrida está aberta** (as modais cobrem o mapa
com `Stack`). Tratamento de alerta: cartão `folha`, ícone e texto em `ColorScheme.error`, sem cor fixa.

**Rationale**: o painel de solicitação (estado `inicial`) ocupa a mesma área embaixo e some nas demais fases
(feature 015); o botão o substitui sem disputar espaço. Segue o botão do motorista (018, D2).

**Alternatives**: botão na barra superior/menu — rejeitado: o mapa é a superfície única da corrida; botão
flutuante `roxo` — rejeitado: a cor primária sugere avanço, não abandono.

## D3 — Efeito local

**Decision**: `_cancelarCorrida()` é síncrono até a primeira `await`: confere `_corridaAceita != null` e
`canCancelRide(_rideStatus)`, captura a corrida e chama `_encerrarCorridaAceita(() {})` (que persiste `inicial`,
zera corrida aceita, posição e rota do motorista, apaga as modais da corrida e cancela o silêncio); só então
publica. `_encerrarCorridaAceita` passa a apagar também o flag da confirmação aberta
(`_modalConfirmarCancelamentoVisivel`), de modo que cancelamento do motorista, indisponibilidade e silêncio
fecham a confirmação (FR-006).

**Rationale**: mudar o estado antes de qualquer `await` torna o duplo toque inofensivo (a segunda chamada vê
`inicial` e sai) e cumpre "um aviso por corrida" sem sinalizador próprio. Reaproveitar o método comum evita
um quarto caminho de encerramento.

**Alternatives**: marcar `AcceptedRide.cancelled` persistido — rejeitado (Princípio V): a corrida cancelada
deixa de existir; o estado `inicial` persistido já é a verdade que sobrevive ao reinício (SC-004).

## D4 — Falha de publicação

**Decision**: igual ao motorista (018): sem relay (`!relayService.hasAnyConnected`) não publica; nenhum relay
que aceite, ou exceção, é absorvido; sem fila, sem reenvio, sem mensagem de erro. O cancelamento local nunca é
desfeito (FR-007).

**Rationale**: reenvio exigiria persistir um aviso pendente e uma regra de expiração que o pedido não pede.
Consequência assumida: o motorista pode não saber (mitigação futura: relógio de silêncio no motorista).

## D5 — Confirmação e concorrência

**Decision**: a confirmação é renderizada em `Stack` no `build()` (flag `_modalConfirmarCancelamentoVisivel`),
não por `showDialog`, como as demais modais do passageiro (T019 de `specs/008-receber-orcamentos/tasks.md`),
e só aparece enquanto `canCancelRide(_rideStatus)`; a precedência no `build()` fica abaixo das modais
informativas (`RideCancelledModal`, `DriverUnavailableModal`, `DriverSilentModal`) e acima das de avanço.
Se a corrida terminar por outro caminho com a confirmação aberta, `_encerrarCorridaAceita` a fecha (D3).

**Rationale**: evita publicar um cancelamento sobre uma corrida que já não existe e evita duas modais
empilhadas.

## D6 — Contrato

**Decision**: nada novo — a emenda 19 já está nas duas cópias; o passageiro não muda a inscrição
(`acceptedKinds`), pois só publica. Conferir por `diff` ao fim.

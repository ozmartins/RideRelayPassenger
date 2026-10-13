# Feature Specification: Confirmar encontro com o motorista e chegada ao destino

> **Atualização (2026-10-13, emenda 24 do contrato):** a confirmação de chegada ao destino (US2) deixou de ser uma modal
> aberta pelo aviso `kind: 20009` do motorista. Agora é o botão "Confirmar chegada ao destino" no mapa
> (`_BotaoConfirmarDestino`), exibido em "Em corrida" enquanto a posição do próprio passageiro está a até 1 km do
> destino pedido; `DestinationArrivedModal` foi removida e o passageiro não reage mais ao `20009`. A avaliação (feature
> 011) continua em modal. O texto abaixo sobre a modal de chegada ao destino é o original, mantido como histórico.

**Feature Branch**: `010-confirmar-encontro-destino`

**Created**: 2026-09-21

**Status**: Draft

**Input**: User description (pedido original, que também toca o app do motorista — ver
Assumptions abaixo para a divisão de escopo): "Modifique o app do passageiro de modo que, quando
ele receber a mensagem informando que motorista chegou no ponto de partida da corrida, uma modal
seja exibida informando o passageiro sobre este fato. A modal deve possuir uma mensagem informativo
e um botão 'Confirmo que encontrei o motorista'. Quando este último botão for pressionado, uma
mensagem deve ser enviada ao app do motorista informando tal fato. quando o app do motorista
receber a mensagem, deve mudar o status do motorista para Em corrida'. Quando o veículo chegar a 5
metros do destino da corrida, o app do motorista deve enviar uma mensagem ao app do passageiro
informando tal fato. O app do passageiro deve exibir uma modal informativa que deve conter o botão
'Confirmo que chegamos ao destino'. quando este ultimo botão for pressionado, uma mensagem deve ser
enviada ao app do motorista. O app do motorista, então, deve mudar o status do motorista para o
estado inicial ('Aguardando solicitação de corrida', se não me engano)."

## Clarifications

### Session 2026-09-21 (decisões tomadas antes da especificação, na conversa que a originou)

- Q: O pedido descreve um fluxo bidirecional entre as duas apps — como dividir em specs de
  spec-kit? → A: duas features, uma por app (mesmo padrão já usado por toda feature anterior que
  toca o contrato de eventos). Esta (`passenger`) cobre o que o passageiro exibe e publica: duas
  modais informativas, cada uma com um botão que publica uma confirmação ao motorista. A
  contrapartida do motorista (consumir as duas confirmações, mudar de estado, detectar e publicar
  a chegada ao destino) é a feature `012-confirmar-encontro-destino` dele, já especificada,
  planejada e com tarefas geradas — o contrato dos três eventos novos usados aqui já está definido
  lá (D4 do `research.md` dela).
- Q: A modal de "motorista chegou" desta feature é a mesma que a `DriverMovingModal` da feature 009
  do passageiro (que já existe, disparada por `kind: 20005`)? → A: não — são gatilhos diferentes.
  `DriverMovingModal` (feature 009) reage à primeira localização (`kind: 20005`), sinalizando que o
  motorista **começou a se deslocar**, com um botão "OK" simples, sem resposta ao motorista. Esta
  feature reage a `kind: 20007` (Chegada do motorista, definido pela feature 011 do motorista,
  nunca consumido pelo passageiro até agora), sinalizando que o motorista **chegou** ao ponto de
  partida, com um botão que efetivamente responde ao motorista. São duas modais distintas, para
  dois eventos distintos já definidos no contrato.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Confirmar que encontrei o motorista (Priority: P1)

Como passageiro esperando o motorista, quando o app me avisa que ele chegou ao ponto de partida,
quero confirmar que o encontrei, para que ele saiba que pode iniciar a corrida.

**Why this priority**: é o primeiro gatilho de todo o fluxo — sem ele, o motorista nunca saberia
que a corrida começou de fato.

**Independent Test**: com uma corrida aceita, simular o recebimento da chegada do motorista à
origem e verificar que uma modal aparece com uma mensagem informativa e o botão "Confirmo que
encontrei o motorista"; tocar o botão e verificar que uma confirmação é publicada ao motorista.

**Acceptance Scenarios**:

1. **Given** o passageiro com uma corrida aceita, **When** chega o aviso de que o motorista chegou
   ao ponto de partida, **Then** uma modal aparece com uma mensagem informativa e o botão "Confirmo
   que encontrei o motorista".
2. **Given** a modal exibida, **When** o passageiro toca o botão, **Then** uma confirmação de
   encontro é publicada ao motorista daquela corrida, e a modal fecha.
3. **Given** a confirmação de encontro já foi publicada para a corrida aceita, **When** chega outro
   aviso de chegada à origem do mesmo motorista (reentrega), **Then** a modal não é exibida de
   novo.

---

### User Story 2 - Confirmar que chegamos ao destino (Priority: P1)

Como passageiro em corrida, quando o app me avisa que o motorista chegou ao destino, quero
confirmar isso, para encerrar a corrida do lado do motorista.

**Why this priority**: fecha o ciclo iniciado pela User Story 1 — mesma centralidade.

**Independent Test**: com uma confirmação de encontro já publicada, simular o recebimento da
chegada ao destino e verificar que uma modal aparece com o botão "Confirmo que chegamos ao
destino"; tocar o botão e verificar que uma confirmação de destino é publicada ao motorista.

**Acceptance Scenarios**:

1. **Given** o passageiro já confirmou o encontro com o motorista, **When** chega o aviso de que o
   motorista chegou ao destino, **Then** uma modal aparece com uma mensagem informativa e o botão
   "Confirmo que chegamos ao destino".
2. **Given** a modal exibida, **When** o passageiro toca o botão, **Then** uma confirmação de
   destino é publicada ao motorista daquela corrida, e a modal fecha.
3. **Given** a confirmação de destino já foi publicada, **When** chega outro aviso de chegada ao
   destino do mesmo motorista (reentrega), **Then** a modal não é exibida de novo.

### Edge Cases

- O que acontece se chegar um aviso de chegada ao destino (`kind: 20009`) antes de o passageiro ter
  confirmado o encontro (User Story 1 ainda não concluída)? É ignorado, sem modal — o pedido
  original descreve uma sequência (encontro, depois destino), e reagir fora dessa ordem não tem
  paralelo no motorista, que só publica a chegada ao destino depois de já estar "Em corrida"
  (dependente da confirmação de encontro).
- O que acontece se o aviso de chegada à origem ou de chegada ao destino vier de um motorista
  diferente do aceito? É ignorado, sem modal — mesmo raciocínio já usado pela feature 009
  (`DriverMovingModal`) para `kind: 20005`.
- O que acontece se não houver relay conectado no instante em que o passageiro toca um dos dois
  botões de confirmação? A modal permanece aberta, com uma mensagem explicando a falha — mesmo
  padrão já usado por `RideQuotesModal` (feature 008) ao aceitar um orçamento sem relay.
- O que acontece se o app reiniciar entre um aviso do motorista e o toque no botão correspondente
  (a modal ainda não tinha sido respondida)? A marca "modal já exibida" é gravada no instante em
  que a modal abre, não no toque do botão (mesmo padrão de `movementNotified` da feature 009) —
  reabrir o app não reexibe a modal sozinha, e o passageiro precisa confiar que a resposta não foi
  enviada; como o pedido original não cobre um mecanismo de reenvio manual, isto fica registrado
  como limitação conhecida do protótipo, não como defeito desta feature.
- O que acontece se um aviso de chegada (à origem ou ao destino) chegar duplicado (reentrega por
  mais de um relay)? Deduplicado por `id` do evento antes de agir — mesma regra de recepção 2 do
  contrato já usada em toda feature anterior.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O app MUST reconhecer um aviso de chegada à origem (`kind: 20007`) recebido do
  motorista da corrida aceita como o sinal para exibir a modal de confirmação de encontro.
- **FR-002**: A modal de confirmação de encontro MUST conter uma mensagem informativa e um botão
  "Confirmo que encontrei o motorista".
- **FR-003**: Ao tocar esse botão, o app MUST publicar uma confirmação de encontro dirigida ao
  motorista da corrida aceita, e fechar a modal.
- **FR-004**: O app MUST NOT exibir a modal de confirmação de encontro mais de uma vez para a
  mesma corrida aceita.
- **FR-005**: O app MUST reconhecer um aviso de chegada ao destino recebido do motorista da
  corrida aceita, depois que a confirmação de encontro já foi publicada, como o sinal para exibir
  a modal de confirmação de destino.
- **FR-006**: A modal de confirmação de destino MUST conter uma mensagem informativa e um botão
  "Confirmo que chegamos ao destino".
- **FR-007**: Ao tocar esse botão, o app MUST publicar uma confirmação de destino dirigida ao
  motorista da corrida aceita, e fechar a modal.
- **FR-008**: O app MUST NOT exibir a modal de confirmação de destino mais de uma vez para a mesma
  corrida aceita.
- **FR-009**: O app MUST NOT agir sobre um aviso de chegada (à origem ou ao destino) que não
  venha do motorista da corrida aceita.
- **FR-010**: O app MUST persistir se cada uma das duas modais (confirmação de encontro,
  confirmação de destino) já foi exibida para a corrida aceita corrente — marcado no instante em
  que a modal abre, não no toque do botão, mesmo padrão já usado por `movementNotified` (feature
  009) — de forma que sobreviva ao fechamento do app.

### Key Entities

- **Corrida aceita (ampliada)**: ganha duas marcas novas — "encontro confirmado" e "destino
  confirmado" — junto do que já existia desde a feature 009 (`quoteId`, chave do motorista,
  "motorista começou a se deslocar já avisado").

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% dos avisos de chegada à origem do motorista aceito resultam na modal de
  confirmação de encontro em até 1 segundo.
- **SC-002**: 100% dos toques no botão de confirmação de encontro publicam a confirmação em até 1
  segundo, quando há relay conectado.
- **SC-003**: 100% dos avisos de chegada ao destino, chegados depois da confirmação de encontro,
  resultam na modal de confirmação de destino em até 1 segundo.
- **SC-004**: Nenhuma corrida aceita gera mais de uma exibição de cada modal.

## Assumptions

- O pedido original descreve um fluxo bidirecional entre as duas apps; esta especificação cobre só
  o lado do passageiro (exibir as duas modais, publicar as duas confirmações). O lado do motorista
  (consumir as confirmações, mudar de estado, detectar e publicar a chegada ao destino) é a feature
  `012-confirmar-encontro-destino` dele, já especificada — mesma divisão por app já praticada em
  todo o histórico deste protótipo.
- Os três eventos usados por esta feature (chegada à origem, já existente desde a feature 011 do
  motorista; confirmação de encontro e confirmação de destino, novos) têm seu formato definido pela
  feature 012 do motorista (D4 do `research.md` dela) — esta feature publica/consome contra esse
  contrato já escrito, não define nada novo por conta própria.
- A modal desta feature (chegada à origem, com botão de confirmação) é distinta da já existente
  `DriverMovingModal` (feature 009, chegada = primeira localização recebida, botão "OK" sem
  resposta ao motorista) — gatilhos e propósitos diferentes, nenhuma delas substitui a outra.
- A ordem "encontro confirmado antes de destino confirmado" é assumida a partir da descrição do
  pedido e do próprio fluxo do motorista (que só publica a chegada ao destino depois de já estar
  "Em corrida", dependente da confirmação de encontro) — um aviso de chegada ao destino chegando
  antes da confirmação de encontro é tratado como Edge Case (ignorado), não como erro.

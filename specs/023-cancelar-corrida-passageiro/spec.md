# Feature Specification: Cancelar corrida (passageiro)

**Feature Branch**: `023-cancelar-corrida-passageiro` (sem branch git: trabalho direto na `master`)

**Created**: 2026-10-07

**Status**: Draft

**Input**: User description (pedido original, que também toca o app do motorista — ver Assumptions
para a divisão de escopo): "O kind 20012 avisa o passageiro que a corrida foi cancelada. Existe
algum kind que avisa o motorista que o passageiro cancelou a corrida? [Não existe.] Sim, monte
isso." O contrato do novo kind, `20013` ("Corrida cancelada pelo passageiro"), já foi definido pela
emenda 19 do contrato de eventos; esta feature é o lado do passageiro: oferecer o cancelamento,
encerrar a corrida e publicar o aviso.

## Clarifications

### Session 2026-10-07 (decisões tomadas antes da especificação, na conversa que a originou)

- Q: O pedido toca as duas apps. Como dividir em specs de spec-kit? → A: duas features, uma por
  app, mesmo padrão das features 018/019 — esta (`passenger`) cobre o que o passageiro faz e
  publica: o botão, a confirmação, a volta ao repouso e o evento; a contrapartida do motorista
  (receber, encerrar, avisar) é `020-corrida-cancelada-pelo-passageiro`, dentro de `driver/`.
- Q: Quem define o formato do evento? → A: o motorista, na emenda 19 do contrato, já commitada e
  replicada nas duas cópias antes do código (Princípio IV). O passageiro só o **publica** — mesmo
  precedente dos `kind: 20003`/`20008`/`20010`, definidos pelo outro lado.
- Q: Em quais fases o passageiro pode cancelar? → A: nas três fases de corrida aceita e não
  concluída — "orçamento aceito", "motorista a caminho" e "em corrida" —, as mesmas em que o
  motorista já pode cancelar. Em "aguardando orçamentos" já existe "Cancelar" (que recusa os
  orçamentos); em "destino confirmado, aguardando avaliação" a corrida já foi concluída.
- Q: Pede confirmação? → A: sim, modal de confirmação, como a do motorista (feature 018): cancelar
  uma corrida é ação destrutiva e o botão fica visível no mapa o tempo todo.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cancelar depois de aceitar, antes do motorista chegar (Priority: P1)

Como passageiro com um orçamento aceito ("orçamento aceito" ou "motorista a caminho"), quero poder
cancelar a corrida, para não deixar o motorista indo até um ponto onde não estarei.

**Why this priority**: hoje, depois de aceitar, o passageiro só sai do estado se o motorista
cancelar ou sumir; o motorista segue dirigindo até uma origem vazia.

**Independent Test**: com o passageiro nessas fases, tocar em "Cancelar corrida", confirmar, e
verificar que ele volta ao estado inicial, a corrida aceita e a posição e a rota do motorista são
descartadas, e um aviso de cancelamento é publicado ao motorista daquela corrida.

**Acceptance Scenarios**:

1. **Given** o passageiro em "orçamento aceito" ou "motorista a caminho", **When** ele toca em
   "Cancelar corrida" e confirma, **Then** volta ao estado inicial (pode solicitar outra corrida),
   a corrida aceita é descartada e um aviso é publicado ao motorista da corrida.
2. **Given** a modal de confirmação aberta, **When** o passageiro escolhe voltar, **Then** nada
   muda e nada é publicado.
3. **Given** o cancelamento concluído, **When** o mapa é exibido, **Then** o marcador e a rota do
   motorista não aparecem mais e o painel de solicitação volta.

---

### User Story 2 - Cancelar com a corrida em andamento (Priority: P1)

Como passageiro "em corrida", quero poder cancelar (por exemplo, por desistir da viagem), com os
mesmos efeitos.

**Why this priority**: mesmo valor da US1; hoje a corrida em andamento só termina com a confirmação
de destino.

**Independent Test**: com o passageiro "em corrida", cancelar e confirmar, e verificar o estado
inicial, a corrida descartada, a rota enviada pelo motorista removida do mapa e o aviso publicado.

**Acceptance Scenarios**:

1. **Given** o passageiro "em corrida", **When** ele cancela e confirma, **Then** volta ao estado
   inicial, a corrida é descartada e o aviso é publicado ao motorista.
2. **Given** o cancelamento concluído, **Then** a modal de avaliação **não** é aberta.

---

### User Story 3 - Cancelamento definitivo, único e sem efeitos colaterais (Priority: P2)

Como passageiro, quero que o cancelamento seja definitivo, publicado uma só vez e sem interferir
nas fases em que não se aplica.

**Independent Test**: cancelar, reiniciar o app e verificar o estado inicial sem corrida aceita;
tocar duas vezes em confirmar e verificar um único aviso; verificar que o botão não existe em
"aguardando orçamentos", no estado inicial e em "destino confirmado".

**Acceptance Scenarios**:

1. **Given** uma corrida cancelada, **When** o app é reiniciado, **Then** reabre no estado inicial,
   sem corrida aceita.
2. **Given** a confirmação aberta, **When** o passageiro toca duas vezes em "Cancelar corrida",
   **Then** exatamente um aviso é publicado.
3. **Given** o passageiro em "aguardando orçamentos", no estado inicial ou aguardando avaliação,
   **When** o mapa é exibido, **Then** o botão "Cancelar corrida" não existe.
4. **Given** a confirmação aberta, **When** chega o cancelamento do motorista (ou a corrida
   expira por silêncio), **Then** a confirmação é fechada e vale o desfecho que chegou primeiro; o
   passageiro **não** publica o seu aviso.
5. **Given** o cancelamento sem relay conectado ou com a publicação recusada, **Then** o
   cancelamento local prevalece (o passageiro fica livre), sem erro e sem reenvio.

---

### Edge Cases

- Cancelar enquanto o motorista publica a localização: o aviso do passageiro não depende da última
  localização; localizações que cheguem depois são ignoradas (não há mais corrida aceita).
- Aviso do motorista (`20012`/`20006`) chegando depois do cancelamento: ignorado, sem modal (já não
  há corrida aceita).
- Falha de publicação (sem relay, ou nenhum relay aceitou): o cancelamento local não é desfeito e
  não há fila nem reenvio (mesma decisão da feature 018 do motorista). O motorista pode não ser
  avisado nesse caso (ver Assumptions).
- Duplo toque em "Cancelar corrida" na modal: no máximo um aviso por corrida.
- O botão sobrepõe-se ao mapa sem cobrir a atribuição do mapa nem as modais da corrida (que ficam
  acima dele).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Em "orçamento aceito", "motorista a caminho" e "em corrida", o app MUST oferecer ao
  passageiro a ação "Cancelar corrida"; nos demais estados, MUST NOT oferecê-la.
- **FR-002**: Ao acionar "Cancelar corrida", o app MUST pedir confirmação explícita antes de
  efetivar, com opção de desistir sem efeito algum.
- **FR-003**: Ao confirmar, o app MUST voltar ao estado inicial e descartar a corrida aceita, a
  posição e a rota do motorista e as modais da corrida, persistindo isso de modo que sobreviva a um
  reinício e MUST cancelar qualquer contagem de silêncio do motorista.
- **FR-004**: Ao confirmar, o app MUST publicar ao motorista da corrida aceita um aviso de
  cancelamento (`kind: 20013`, emenda 19: tags de marcador, `["e", <orçamento aceito>]` e
  `["p", <motorista>]`, `content` cifrado ao motorista), uma única vez por corrida.
- **FR-005**: O cancelamento MUST NOT abrir a modal de avaliação.
- **FR-006**: Se a corrida deixar de existir enquanto a confirmação está aberta (cancelamento do
  motorista, indisponibilidade ou silêncio), a confirmação MUST ser fechada e nada MUST ser
  publicado pelo passageiro.
- **FR-007**: Falha ao publicar o aviso MUST NOT impedir nem desfazer o cancelamento local, e MUST
  NOT gerar mensagem de erro nem reenvio.
- **FR-008**: Depois do cancelamento, o app MUST ignorar, sem erro nem modal, eventos do motorista
  (`20005`, `20006`, `20007`, `20009`, `20011`, `20012`) referentes à corrida cancelada.
- **FR-009**: Depois do cancelamento, o passageiro MUST poder solicitar uma nova corrida
  normalmente.
- **FR-010**: O formato do aviso é o da emenda 19, já definido; esta feature MUST NOT alterá-lo,
  acrescentar kind novo nem mudar a inscrição do passageiro (ele só publica o `20013`).

### Key Entities

- **Corrida aceita (existente)**: orçamento aceito pelo passageiro (id do orçamento e chave do
  motorista), persistida junto do estado da corrida. Passa a poder ser encerrada também por
  cancelamento do próprio passageiro.
- **Aviso de cancelamento pelo passageiro (novo para o passageiro, definido pelo contrato)**:
  mensagem efêmera, cifrada ao motorista, que identifica a corrida pelo orçamento aceito; sem
  motivo nem posição.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Em 100% das confirmações nas três fases, o passageiro volta ao estado inicial sem
  corrida aceita em até 1 s.
- **SC-002**: Em 100% dos cancelamentos com ao menos um relay conectado, exatamente um aviso é
  publicado ao motorista da corrida correta e nenhum a outra corrida.
- **SC-003**: Em 0% dos casos o cancelamento é efetivado sem passar pela confirmação explícita.
- **SC-004**: Após o cancelamento e um reinício do app, 100% das aberturas mostram o passageiro no
  estado inicial, sem corrida aceita.
- **SC-005**: Depois de cancelar, o passageiro consegue solicitar e concluir uma nova corrida sem
  interferência da cancelada.

## Assumptions

- Divisão de escopo: esta feature é só o lado do passageiro; receber o aviso, encerrar a corrida e
  informar o motorista são a feature `020-corrida-cancelada-pelo-passageiro`, em `driver/`, já
  implementada. Para um teste ponta a ponta completo, as duas são necessárias.
- O kind, as tags e a cifra são os da emenda 19 (e da emenda 17); o texto de entrada cifrado é o
  marcador `{}`.
- Sem fila nem reenvio em falha de publicação (mesma decisão da 017/018 do motorista).
  Consequência aceita: sem relay no momento, o motorista pode não ser avisado.
- A confirmação é uma modal simples (mensagem + "Cancelar corrida" / "Voltar") no padrão visual das
  demais modais do app; o botão no mapa segue o tratamento de ação destrutiva da constituição.
- Dependência: reaproveita o estado persistido (`PassengerRideStatus`/`AcceptedRide`), a publicação
  cifrada por `EventFeed` e `_encerrarCorridaAceita` (019/020/021) já existentes.

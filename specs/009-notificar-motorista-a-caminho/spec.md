# Feature Specification: Notificar que o motorista está a caminho

**Feature Branch**: `009-notificar-motorista-a-caminho`

**Created**: 2026-09-21

**Status**: Draft

**Input**: User description: "Modifique o app do passageiro de modo que, quando ele receber a
mensagem informando o inicio do deslocamento do motorista, uma modal seja exibida informando o
passageiro sobre este fato. A modal deve possuir uma mensagem informativo e um botão OK."

## Clarifications

### Session 2026-09-21 (decisões tomadas antes da especificação, na conversa que a originou)

- Q: O contrato de eventos não define uma mensagem específica de "início do deslocamento" — o
  motorista, ao confirmar que está a caminho (feature 010 dele), só passa a publicar sua
  localização periodicamente (`kind: 20005`), sem nenhum evento distinto para o próprio instante da
  confirmação. Como o passageiro reconhece esse "início"? → A: pelo primeiro `kind: 20005`
  recebido, referenciando o orçamento que este passageiro aceitou — é o único sinal que já existe
  no contrato sem tocar o app do motorista, coerente com o pedido, que delimita a mudança só ao
  passageiro.
- Q: O passageiro hoje não guarda, em lugar nenhum, qual orçamento ele aceitou (só um sinalizador
  em memória, "já decidiu", sem o `quoteId`) — necessário para saber que um `kind: 20005` recebido
  é da corrida que ele próprio aceitou, e não de outro motorista qualquer. Onde registrar isso? → A:
  novo estado persistido "corrida aceita" (`quoteId` + chave pública do motorista), sobrevivendo a
  um reinício do app — mesmo padrão já adotado pelo motorista (`ActiveRide`/`RideStateStore`,
  features 010/011) para o mesmo tipo de necessidade.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ser avisado de que o motorista começou a se deslocar (Priority: P1)

Como passageiro que aceitou um orçamento, quando o motorista escolhido começa a se deslocar até
mim, quero ver uma modal avisando isso, para saber que a corrida está de fato em andamento.

**Why this priority**: é o pedido central da feature — sem essa modal, não há nada mais nesta spec.

**Independent Test**: com o passageiro tendo aceitado um orçamento de um motorista específico,
simular o recebimento da primeira localização publicada por aquele motorista e verificar que uma
modal aparece com uma mensagem informativa e um botão "OK".

**Acceptance Scenarios**:

1. **Given** o passageiro aceitou o orçamento de um motorista, **When** chega a primeira
   localização publicada por aquele motorista para aquela corrida, **Then** uma modal aparece com
   uma mensagem informando que o motorista começou a se deslocar e um botão "OK".
2. **Given** a modal exibida, **When** o passageiro toca em "OK", **Then** a modal fecha.
3. **Given** a modal já foi exibida e fechada para a corrida aceita, **When** chegam novas
   localizações do mesmo motorista, **Then** a modal não é exibida de novo.
4. **Given** o passageiro não aceitou orçamento nenhum, **When** chega uma localização de algum
   motorista, **Then** nenhuma modal é exibida.

### Edge Cases

- O que acontece se chegar uma localização de um motorista diferente do que foi aceito (ex.: um
  motorista que já tinha enviado orçamento antes da decisão)? É ignorada, sem modal — só a
  localização referenciando o orçamento efetivamente aceito conta.
- O que acontece se o app reiniciar depois que a corrida foi aceita, mas antes de qualquer
  localização chegar? A corrida aceita continua reconhecida (estado persistido); a primeira
  localização recebida depois do reinício ainda exibe a modal normalmente.
- O que acontece se o app reiniciar depois que a modal já foi exibida e fechada? Novas localizações
  do mesmo motorista não reabrem a modal — o registro de "já avisado" também sobrevive ao reinício,
  mesmo padrão já adotado pelo motorista para o aviso de chegada (feature 011 dele).
- O que acontece se a localização recebida estiver malformada (não seguir o formato do contrato)? É
  descartada sem exibir modal nem travar o app — mesma postura já usada para todo outro conteúdo
  malformado neste protótipo.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O app MUST reconhecer a primeira localização (`kind: 20005`) recebida que referencie
  o orçamento efetivamente aceito pelo passageiro como o sinal de que o motorista começou a se
  deslocar.
- **FR-002**: O app MUST exibir, nesse momento, uma modal com uma mensagem informativa e um botão
  "OK".
- **FR-003**: O app MUST fechar a modal quando o passageiro tocar em "OK".
- **FR-004**: O app MUST NOT exibir essa modal mais de uma vez para a mesma corrida aceita, mesmo
  que novas localizações do mesmo motorista continuem chegando depois.
- **FR-005**: O app MUST NOT exibir a modal para localizações que não referenciem o orçamento
  efetivamente aceito pelo passageiro (de outro motorista, ou antes de qualquer aceitação existir).
- **FR-006**: O app MUST persistir, a partir do momento em que um orçamento é aceito, o `quoteId` e
  a chave pública do motorista escolhido — dado hoje inexistente em qualquer armazenamento do
  passageiro — de forma que sobreviva ao fechamento do app.
- **FR-007**: O app MUST persistir se a modal já foi exibida para a corrida aceita corrente, de
  forma que sobreviva ao fechamento do app, para cumprir FR-004 mesmo através de um reinício.

### Key Entities

- **Corrida aceita**: representa o orçamento que o passageiro efetivamente aceitou — `quoteId` e
  chave pública do motorista — e se a notificação de início de deslocamento já foi exibida para
  ela. Não existe antes de uma aceitação; passa a existir no momento em que o passageiro toca
  "Aceitar" (feature 008).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% das vezes em que a primeira localização do motorista aceito chega, a modal
  aparece em até 1 segundo.
- **SC-002**: Nenhuma corrida aceita gera mais de uma exibição da modal, incluindo através de um
  reinício do app.
- **SC-003**: Nenhuma modal é exibida para localização de um motorista que não foi o aceito.

## Assumptions

- O contrato de eventos não define, e esta feature não introduz, nenhuma mensagem dedicada a
  "início do deslocamento" — o pedido original já delimita a mudança só ao app do passageiro, e o
  único sinal existente sem tocar o motorista é a primeira localização (`kind: 20005`, emenda 08)
  recebida para a corrida aceita.
- "Corrida aceita" (`quoteId` + chave pública do motorista) é um dado novo, sem equivalente hoje no
  passageiro (o estado atual, `_corridaDecidida`, é um sinalizador em memória sem o `quoteId`) —
  passa a ser persistido a partir da aceitação (feature 008), sobrevivendo a reinício, mesmo padrão
  já adotado pelo motorista (`ActiveRide`/`RideStateStore`, features 010/011) para o mesmo tipo de
  necessidade.
- O consumo do `kind: 20005` pelo passageiro se limita ao necessário para esta feature (reconhecer
  a primeira localização de uma corrida aceita); exibir a localização em si (ex.: no mapa) não faz
  parte deste pedido e fica fora de escopo.
- O que acontece depois desta notificação — acompanhar a posição do motorista, saber quando ele
  chega (o motorista já publica isso, `kind: 20007`, feature 011 dele) — continua fora de escopo,
  mesma delimitação já praticada pelas features anteriores: o pedido cobre só esta modal.

# Feature Specification: Seguir o motorista no mapa do passageiro

**Feature Branch**: `017-seguir-motorista` (trabalho direto na `master`; ver Padrão de Commits)

**Created**: 2026-10-01

**Status**: Draft

**Input**: User description: "Modifique o app do passageiro. Quando ele estiver no estado motoristaACaminho, o botão centralizar não deve ser exibido. No referido estado, o app deve focar e seguir a localização do motorista."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Acompanhar o motorista sem mexer no mapa (Priority: P1)

O passageiro aceitou um orçamento e o motorista está a caminho. O mapa passa a manter o motorista
em foco: a visão fica centrada nele e acompanha cada nova posição que ele informa, de modo que o
passageiro vê a aproximação sem precisar arrastar nem reenquadrar o mapa.

**Why this priority**: é o núcleo do pedido. Hoje, na primeira posição, o mapa enquadra motorista e
passageiro uma única vez e depois para de acompanhar qualquer um dos dois; o passageiro precisa
mover o mapa à mão para não perder o motorista de vista.

**Independent Test**: com o app em "motorista a caminho" e uma corrida aceita, entregar duas
posições seguidas e distantes do motorista e confirmar que a visão do mapa fica centrada na
primeira e depois passa a ficar centrada na segunda.

**Acceptance Scenarios**:

1. **Given** o estado "motorista a caminho" e a primeira posição válida do motorista, **When** ela
   chega, **Then** o mapa centraliza no motorista.
2. **Given** o mapa já centrado no motorista, **When** chega uma posição mais nova, **Then** a visão
   passa a ficar centrada no novo ponto, mantendo o nível de aproximação em que estava.
3. **Given** o estado "motorista a caminho", **When** o GPS do passageiro informa uma nova posição,
   **Then** o mapa **não** volta a centralizar no passageiro: continua no motorista.
4. **Given** o app reaberto em "motorista a caminho", **When** chega a primeira posição válida do
   motorista, **Then** o mapa centraliza nele e volta a acompanhá-lo.
5. **Given** o estado "motorista a caminho" e nenhuma posição válida do motorista ainda recebida,
   **When** o GPS do passageiro informa uma nova posição, **Then** o mapa segue o passageiro como
   em qualquer outro estado, até a primeira posição válida do motorista.

---

### User Story 2 - Sem botão "Centralizar" enquanto o motorista é seguido (Priority: P1)

Como o app já mantém o motorista em foco, o botão "Centralizar" (que levava o mapa de volta ao
passageiro) deixa de aparecer em "motorista a caminho". O mapa nunca fica com um controle cujo
único efeito seria desfazer o acompanhamento.

**Why this priority**: faz parte do pedido e evita um controle que contradiria o comportamento.

**Independent Test**: com o app em "motorista a caminho", com e sem posição do motorista já
exibida, confirmar que o botão "Centralizar" não existe na tela.

**Acceptance Scenarios**:

1. **Given** o estado "motorista a caminho" e o motorista em foco, **Then** o botão "Centralizar"
   não é exibido.
2. **Given** o estado "motorista a caminho" e o passageiro tendo arrastado o mapa para outro lugar,
   **Then** o botão "Centralizar" continua não sendo exibido.
3. **Given** a posição seguinte do motorista, **When** ela chega com o mapa arrastado pelo
   passageiro, **Then** o mapa volta a centralizar no motorista.

---

### User Story 3 - Voltar ao comportamento normal ao sair do estado (Priority: P2)

Quando a corrida deixa de estar em "motorista a caminho" (encontro confirmado, cancelamento ou
qualquer volta ao estado inicial), o mapa deixa de seguir o motorista e volta a seguir a posição do
passageiro, como em todos os outros estados.

**Why this priority**: sem isso o mapa ficaria preso numa posição antiga do motorista fora da fase
em que ela é exibida.

**Independent Test**: levar o app de "motorista a caminho" a "encontro confirmado" e confirmar que
a próxima posição do GPS do passageiro volta a mover o mapa.

**Acceptance Scenarios**:

1. **Given** o mapa seguindo o motorista, **When** o estado passa a "encontro confirmado", **Then**
   uma nova posição do GPS do passageiro volta a centralizar o mapa nele.
2. **Given** uma nova corrida depois de uma anterior, **When** ela chega a "motorista a caminho",
   **Then** o acompanhamento recomeça do zero (sem herdar a posição da corrida anterior).

---

### Edge Cases

- Posição do motorista malformada, fora de faixa, duplicada ou mais antiga que a exibida: continua
  descartada (regra da feature 016) e **não** move o mapa.
- Passageiro arrasta ou dá zoom no mapa em "motorista a caminho": a próxima posição do motorista
  recentraliza a visão, mantendo o zoom escolhido por ele.
- Mapa ainda não montado quando a primeira posição chega: a centralização é feita assim que o mapa
  existir, sem exigir nova posição.
- Motorista sai do alcance do relay e para de enviar posições: o mapa fica parado na última posição
  conhecida, sem erro nem retorno ao passageiro.
- O passageiro sem posição de GPS: o motorista continua sendo seguido normalmente.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Em "motorista a caminho", ao exibir uma posição válida e mais nova do motorista, o app
  MUST centralizar a visão do mapa nela.
- **FR-002**: Enquanto estiver em "motorista a caminho" e houver posição do motorista exibida, o
  app MUST NOT mover o mapa em resposta a atualizações do GPS do passageiro.
- **FR-003**: O acompanhamento MUST preservar o nível de aproximação vigente no mapa; só a
  primeira centralização de uma corrida pode definir um nível padrão, se o mapa ainda não tiver um.
- **FR-004**: Em "motorista a caminho", o botão "Centralizar" MUST NOT ser exibido, em nenhuma
  circunstância (com ou sem posição do motorista, com o mapa arrastado ou não).
- **FR-005**: Em "motorista a caminho" e **sem** posição válida do motorista exibida, o mapa MUST
  seguir o passageiro como nos demais estados.
- **FR-006**: O comportamento anterior da feature 016 de enquadrar motorista e passageiro na
  primeira exibição e parar de seguir o passageiro até o botão "Centralizar" MUST ser substituído
  por este: a visão passa a ser centrada só no motorista, sem enquadrar os dois.
- **FR-007**: Fora de "motorista a caminho", o mapa MUST seguir o passageiro como antes desta
  feature, e o marcador do motorista continua oculto (regra da feature 016).
- **FR-008**: Ao trocar a corrida aceita, o acompanhamento MUST recomeçar sem herdar posição da
  corrida anterior.
- **FR-009**: O marcador do próprio passageiro MUST continuar visível no mapa durante o
  acompanhamento, mesmo quando estiver fora da área visível.
- **FR-010**: Nenhum formato de evento é criado ou alterado, nenhum evento novo é publicado e nada
  novo é gravado em disco: a mudança é apenas de apresentação do mapa.

### Key Entities

- **Posição do motorista exibida**: última posição válida e mais nova do motorista aceito, já
  mantida em memória pela feature 016; passa a ser também o ponto de foco do mapa.
- **Modo de acompanhamento do mapa**: quem o mapa segue num dado momento — o motorista (em
  "motorista a caminho" com posição disponível) ou o passageiro (todos os demais casos).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Em "motorista a caminho", 100% das posições válidas e mais novas do motorista deixam
  a visão centrada nelas.
- **SC-002**: Durante "motorista a caminho" com posição do motorista disponível, nenhuma atualização
  de GPS do passageiro desloca a visão do mapa.
- **SC-003**: O botão "Centralizar" aparece em 0% das telas em "motorista a caminho".
- **SC-004**: Numa sequência de 10 posições consecutivas do motorista, sem nenhum gesto do
  passageiro no mapa (toque, arraste ou zoom), a visão termina centrada na décima — 10 de 10 posições
  acompanhadas.
- **SC-005**: Em todos os estados diferentes de "motorista a caminho", o comportamento do mapa é
  idêntico ao anterior a esta feature.

## Assumptions

- O estado "motorista a caminho" e a posição do motorista exibida existem desde as features 014 e
  016 do passageiro; esta feature só muda o que o mapa faz com eles.
- Como o botão "Centralizar" só existia em "motorista a caminho", sua remoção nesse estado o retira
  do app por completo.
- Se o passageiro arrastar o mapa, a próxima posição do motorista recentraliza a visão: não há
  modo de "soltar" o acompanhamento, já que o botão para retomá-lo deixa de existir.
- O nível de aproximação inicial, quando o mapa ainda não tem um definido, é o mesmo padrão já
  usado pelo app ao centralizar num ponto.
- Sem contrapartida no app do motorista e sem emenda ao contrato de eventos.

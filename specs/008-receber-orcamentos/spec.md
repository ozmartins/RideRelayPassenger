# Feature Specification: Receber, persistir e decidir entre orçamentos

**Feature Branch**: `008-receber-orcamentos`

**Created**: 2026-09-20

**Status**: Draft

**Input**: User description: "Modifique o app do passageiro. Quando ele receber uma mensagem que
representa o orçamento de uma corrida, ele deve persistir este orçamento. Em seguida uma modal deve
ser exibida mostrando todos os orçamentos para aquela corrida específica. Nesta modal devem
constar o nome do motorista, a marca do carro, o modelo do carro, o ano do carro, o preço da
corrida e o tempo estimado pro motorista chegar até o ponto de partida. A tela modal também deve
exibir os botão 'Aceitar' ao lado de cada orçamento. Quando o botão 'Aceitar' for usado, uma
mensagem de aceitação do orçamento deve ser enviada ao motorista selecionado. Além disso, os demais
motoristas devem ser avisados que suas propostas foram recusadas."

## Clarifications

### Session 2026-09-20 (decisões tomadas antes da especificação, na conversa que a originou)

- Q: O passageiro não tem armazenamento em disco hoje (só chave-valor para nome/relays) — até
  quando persistir os orçamentos recebidos? → A: em disco, sobrevive a reiniciar o app —
  introduz-se `sqflite` (decisão registrada em `research.md`, Princípio III), mesma biblioteca já
  usada pelo motorista.
- Q: "Aceitar"/"recusar" exigem pelo menos um evento Nostr novo — qual desenho? → A: dois kinds
  novos, "Aceitação de orçamento" e "Recusa de orçamento" (emenda 07 do contrato, já escrita e
  replicada no motorista). O consumo desses kinds pelo motorista fica fora de escopo — mesmo padrão
  já usado para o kind 20001 no motorista e o kind 20002 no passageiro.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver todos os orçamentos recebidos para a corrida solicitada (Priority: P1)

Como passageiro que solicitou uma corrida, quero ver, à medida que chegam, todos os orçamentos
recebidos para aquela solicitação especificamente, com os dados de cada motorista e o preço, para
poder escolher entre eles.

**Why this priority**: é o pedido central — sem isso, não há nada para decidir.

**Independent Test**: solicitar uma corrida e simular o recebimento de um orçamento (`kind:
20002`) referenciando essa solicitação; verificar que ele é persistido e que uma modal aparece
mostrando nome do motorista, marca/modelo/ano do carro, o preço e o tempo estimado.

**Acceptance Scenarios**:

1. **Given** uma corrida já solicitada, **When** um orçamento referenciando essa solicitação
   chega, **Then** ele é persistido e uma modal é exibida (ou atualizada, se já aberta) mostrando
   nome do motorista, marca, modelo, ano, preço e tempo estimado desse orçamento.
2. **Given** a modal já aberta com um orçamento, **When** um segundo orçamento para a mesma
   solicitação chega, **Then** a modal passa a mostrar os dois, sem substituir nem descartar o
   primeiro.
3. **Given** um orçamento referenciando uma solicitação diferente da que está ativa (ou nenhuma
   solicitação ativa), **When** ele chega, **Then** é ignorado — não persistido, não exibido.
4. **Given** um orçamento sem `etaMinutes` (o motorista não conseguiu calcular), **When** exibido
   na modal, **Then** o tempo estimado aparece como não disponível, nunca como um valor inventado
   ou zero.

---

### User Story 2 - Aceitar um orçamento (Priority: P1)

Como passageiro vendo os orçamentos, quero aceitar um deles, para confirmar aquele motorista para
minha corrida e liberar os demais.

**Why this priority**: é a ação que decide a corrida — sem ela, a modal só informa, não resolve
nada.

**Independent Test**: com dois ou mais orçamentos na modal, tocar em "Aceitar" em um deles e
verificar que uma aceitação (`kind: 20003`) é publicada referenciando aquele orçamento e o
motorista dele, e que uma recusa (`kind: 20004`) é publicada para cada um dos outros.

**Acceptance Scenarios**:

1. **Given** a modal com dois ou mais orçamentos, **When** o passageiro toca em "Aceitar" ao lado
   de um deles, **Then** um evento de aceitação é publicado referenciando aquele orçamento e o
   motorista que o enviou.
2. **Given** a mesma ação, **When** a aceitação é publicada, **Then** um evento de recusa é
   publicado para cada um dos demais orçamentos já recebidos para a mesma solicitação, cada um
   referenciando o orçamento e o motorista correspondentes.
3. **Given** a aceitação confirmada, **When** ela termina, **Then** a modal fecha.
4. **Given** um orçamento aceito, **When** outro orçamento para a mesma solicitação chega depois,
   **Then** ele ainda é persistido, mas não reabre a modal nem gera nova recusa automática — a
   decisão já foi tomada.

### Edge Cases

- Sem relay conectado no momento de aceitar: a aceitação (e as recusas) não são enviadas; o
  passageiro é informado, sem perder a escolha feita nem fechar a modal sozinha.
- Dois orçamentos do mesmo motorista para a mesma solicitação (reenvio, relay duplicado): cada um
  tem `id` de evento próprio — tratados como dois orçamentos distintos na lista (não há requisito
  de deduplicar por motorista nesta feature).
- App reiniciado com orçamentos já persistidos de uma solicitação anterior: fora de escopo desta
  feature reabrir a modal automaticamente ao reiniciar — a persistência garante que o dado não se
  perde, não que a interação recomece sozinha.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema MUST se inscrever em `kind: 20002` (Orçamento de corrida).
- **FR-002**: Ao receber um orçamento válido (assinatura verificada, marcador presente) que
  referencia a solicitação de corrida atualmente ativa, o sistema MUST persistir esse orçamento em
  armazenamento que sobrevive a reiniciar o app.
- **FR-003**: Um orçamento que não referencia a solicitação atualmente ativa (ou nenhuma
  solicitação estiver ativa) MUST ser ignorado — não persistido, não exibido.
- **FR-004**: Ao persistir o primeiro orçamento de uma solicitação, o sistema MUST exibir uma
  modal; ao persistir orçamentos seguintes da mesma solicitação enquanto a modal estiver aberta, a
  modal MUST ser atualizada para incluí-los, sem substituir os já exibidos.
- **FR-005**: A modal MUST exibir, para cada orçamento: nome do motorista, marca do carro, modelo
  do carro, ano do carro, o preço da corrida (total) e o tempo estimado até o ponto de partida.
- **FR-006**: Quando o tempo estimado não estiver presente no orçamento recebido, a modal MUST
  indicá-lo como não disponível, nunca como zero ou um valor calculado por outro meio.
- **FR-007**: A modal MUST exibir um botão "Aceitar" ao lado de cada orçamento listado.
- **FR-008**: Ao tocar em "Aceitar" para um orçamento, com ao menos um relay conectado, o sistema
  MUST publicar um evento de aceitação referenciando aquele orçamento e o motorista que o enviou.
- **FR-009**: Na mesma ação, o sistema MUST publicar um evento de recusa para cada um dos demais
  orçamentos já recebidos para a mesma solicitação, cada um referenciando o orçamento e o
  motorista correspondentes.
- **FR-010**: Se nenhum relay estiver conectado no momento de aceitar, o sistema MUST informar que
  a aceitação não foi enviada, sem fechar a modal e sem perder a escolha.
- **FR-011**: Uma aceitação publicada com sucesso MUST fechar a modal.
- **FR-012**: Depois de uma aceitação confirmada para uma solicitação, um orçamento que chegue
  depois para a mesma solicitação MUST continuar sendo persistido (FR-002), mas MUST NOT reabrir a
  modal nem gerar recusa automática.

### Key Entities

- **Orçamento recebido**: `id` do evento, `id` da solicitação referenciada, chave pública do
  motorista, nome do motorista, marca/modelo/ano do carro, preço por quilômetro, total, tempo
  estimado (opcional). Persistido em disco.
- **Aceitação / Recusa**: não são entidades persistidas — são a publicação de um evento
  referenciando um orçamento já persistido.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Todo orçamento recebido para a solicitação ativa aparece na modal em até 1 segundo
  após a persistência.
- **SC-002**: 100% dos orçamentos de outras solicitações (ou recebidos sem solicitação ativa) são
  ignorados — nunca aparecem na modal da solicitação atual.
- **SC-003**: Aceitar um orçamento sempre publica exatamente uma aceitação e uma recusa por cada
  outro orçamento já recebido para a mesma solicitação — nunca mais, nunca menos.
- **SC-004**: Uma vez aceito um orçamento, nenhum orçamento chegado depois para a mesma solicitação
  reabre a modal ou publica recusa automática.

## Assumptions

- "Solicitação atualmente ativa" é a última solicitação de corrida publicada com sucesso pelo
  próprio passageiro nesta sessão do app — não há suporte a múltiplas solicitações simultâneas
  nesta feature.
- O tempo estimado exibido é exatamente o que veio no orçamento (`etaMinutes`) — o passageiro não
  recalcula nada localmente.
- Não há requisito de notificar o passageiro (som, vibração) na chegada de um orçamento além de
  exibir/atualizar a modal.

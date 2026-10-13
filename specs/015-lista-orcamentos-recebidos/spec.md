# Feature Specification: Tela de orçamentos recebidos e cancelamento da solicitação

**Feature Branch**: `015-lista-orcamentos-recebidos`

**Created**: 2026-09-28

**Status**: Draft

**Input**: User description: "Modifique o app passageiro. A bottom sheet que possui o botão 'Solicitar corrida' deve ficar visível apenas quando o passageiro estiver no estado inicial. Quando o usuário clicar em 'Solicitar corrida', o estado do passageiro deve ser modificado para 'Aguardando orçamentos'. Quando o passageiro entrar no estado 'Aguardando orçamentos', uma nova tela deve ser exibida. Inicialmente a nova tela deve conter uma lista vazia e o botão 'Cancelar' na parte inferior. À medida que orçamentos chegarem ao app do passageiro, eles devem ser adicionados à lista da nova tela. Cada item da nova tela deve exibir os mesmos elementos da tela modal que é exibida quando o usuário recebe um orçamento (porém de forma mais condensada, para não ocupar muito espaço). Com a criação da nova tela, a modal que é exibida à medida que cada orçamento chega ao app do passageiro deve ser eliminada. O botão cancelar da nova tela deve mudar o status do passageiro para 'Inicial' (o que implica exibir novamente a tela inicial que mostra o mapa e o bottom sheet de solicitação de corrida) e também deve mandar uma mensagem de recusa para os motoristas que eventualmente tenham enviado orçamentos."

## Clarifications

### Session 2026-09-28

- Q: Ao reabrir o app na fase "Aguardando orçamentos", a tela dedicada deve recarregar os
  orçamentos já persistidos para aquela solicitação, ou começar vazia mesmo que já existam
  orçamentos gravados? → A: Recarrega os orçamentos já persistidos para aquela solicitação.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - O painel de solicitação só aparece quando não há corrida em andamento (Priority: P1)

O passageiro só vê o painel com o campo de destino, a forma de pagamento e o botão "Solicitar
corrida" quando não há nenhuma corrida em andamento — assim que ele solicita uma corrida, esse
painel desaparece, dando lugar à tela de acompanhamento de orçamentos.

**Why this priority**: É a mudança de visibilidade que evita o painel de solicitação aparecer por
cima (ou atrás) da nova tela de orçamentos, sobrepondo duas ações que não fazem sentido
simultaneamente.

**Independent Test**: Levar o passageiro por cada fase de uma corrida (aguardando orçamentos,
orçamento aceito, motorista a caminho etc.) e verificar que o painel de solicitação nunca aparece
fora da fase inicial.

**Acceptance Scenarios**:

1. **Given** o passageiro está na fase inicial (nenhuma corrida em andamento), **When** ele abre o
   mapa, **Then** o painel com destino, forma de pagamento e "Solicitar corrida" está visível.
2. **Given** o passageiro está em qualquer fase de uma corrida em andamento (aguardando
   orçamentos, orçamento aceito, motorista a caminho, encontro confirmado, destino confirmado),
   **When** ele olha a tela, **Then** o painel de solicitação não está visível.

---

### User Story 2 - Acompanhar os orçamentos recebidos numa tela dedicada (Priority: P1)

Ao solicitar uma corrida, o passageiro passa a ver uma tela dedicada ao acompanhamento dos
orçamentos daquela solicitação, que começa vazia e vai recebendo cada orçamento à medida que ele
chega — substituindo a notificação em modal usada até então.

**Why this priority**: É o núcleo do pedido — sem esta tela, o passageiro não tem como acompanhar
nem decidir entre os orçamentos recebidos.

**Independent Test**: Solicitar uma corrida (com duplês de teste para os orçamentos recebidos) e
verificar que a tela dedicada aparece vazia, depois recebe cada orçamento na lista, na ordem de
chegada, sem que nenhuma modal antiga apareça.

**Acceptance Scenarios**:

1. **Given** o passageiro acabou de solicitar uma corrida, **When** a tela de orçamentos aparece,
   **Then** ela mostra uma lista vazia e o botão "Cancelar" na parte inferior.
2. **Given** a tela de orçamentos está aberta e vazia, **When** o primeiro orçamento chega,
   **Then** ele aparece como um item na lista, num formato condensado com os mesmos dados já
   mostrados hoje por orçamento (nome do motorista, veículo, valor total e tempo estimado, quando
   disponível).
3. **Given** a tela de orçamentos já mostra um ou mais itens, **When** outro orçamento chega,
   **Then** ele é adicionado à lista sem remover nem substituir os itens já exibidos.
4. **Given** a tela de orçamentos mostra um item, **When** o passageiro aceita aquele orçamento
   pelo próprio item da lista, **Then** o mesmo comportamento de aceitar um orçamento já existente
   no app ocorre (aceitação publicada, demais orçamentos daquela solicitação recusados, corrida
   avança de fase).

---

### User Story 3 - Cancelar a solicitação a partir da tela de orçamentos (Priority: P1)

O passageiro pode desistir de uma solicitação ainda sem decisão, a qualquer momento enquanto
aguarda orçamentos, e os motoristas que já responderam são avisados de que não serão mais
atendidos.

**Why this priority**: Sem uma saída, o passageiro fica preso à espera de orçamentos mesmo quando
já não quer mais aquela corrida — mesma prioridade do núcleo da feature, por ser a única forma de
sair do estado "Aguardando orçamentos" sem aceitar ninguém.

**Independent Test**: Solicitar uma corrida, receber um ou mais orçamentos, tocar "Cancelar" e
verificar que o passageiro volta à tela inicial (mapa e painel de solicitação) e que cada motorista
que havia enviado orçamento recebe uma mensagem de recusa.

**Acceptance Scenarios**:

1. **Given** a tela de orçamentos está aberta, com ou sem itens na lista, **When** o passageiro
   toca "Cancelar", **Then** o passageiro volta à fase inicial e a tela de mapa com o painel de
   solicitação reaparece.
2. **Given** a tela de orçamentos tem um ou mais orçamentos recebidos, **When** o passageiro toca
   "Cancelar", **Then** cada motorista que enviou um desses orçamentos recebe uma mensagem de
   recusa.
3. **Given** a tela de orçamentos ainda está vazia (nenhum orçamento chegou), **When** o passageiro
   toca "Cancelar", **Then** o passageiro volta à fase inicial normalmente, sem nenhuma mensagem de
   recusa enviada (não há ninguém para avisar).

### Edge Cases

- O que acontece se o app for encerrado e reaberto enquanto a tela de orçamentos está ativa? A tela
  deve reaparecer (o estado "Aguardando orçamentos" já sobrevive a um reinício), com os orçamentos
  já recebidos antes do reinício de volta na lista — não uma lista vazia mostrando só os que
  chegarem depois de reabrir.
- O que acontece se um orçamento chegar exatamente no momento em que o passageiro toca
  "Cancelar"? Um orçamento que já havia sido adicionado à lista antes do toque em "Cancelar" recebe
  a mensagem de recusa; um orçamento que só é processado depois de a solicitação já ter sido
  cancelada não é exibido nem gera recusa (mesma regra já existente para eventos fora de ordem).
- O que acontece se o passageiro cancelar e, em seguida, solicitar uma nova corrida? Deve funcionar
  normalmente, como qualquer nova solicitação a partir da fase inicial — sem nenhum resquício da
  solicitação cancelada.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema MUST exibir o painel de solicitação de corrida (destino, forma de
  pagamento e botão "Solicitar corrida") somente enquanto o passageiro estiver na fase inicial
  (nenhuma corrida em andamento).
- **FR-002**: O sistema MUST ocultar esse painel de solicitação em qualquer outra fase da corrida.
- **FR-003**: Ao solicitar uma corrida com sucesso, o sistema MUST exibir uma tela dedicada ao
  acompanhamento dos orçamentos daquela solicitação, iniciando com uma lista vazia e um botão
  "Cancelar" fixo na parte inferior.
- **FR-004**: O sistema MUST adicionar cada orçamento recebido para a solicitação ativa a essa
  lista, na ordem de chegada, sem remover ou substituir itens já exibidos.
- **FR-005**: Cada item da lista MUST exibir, em formato condensado, os mesmos dados hoje exibidos
  por orçamento (nome do motorista, marca/modelo/ano do veículo, valor total e tempo estimado —
  quando disponível) e MUST permitir aceitar aquele orçamento diretamente pelo item.
- **FR-006**: Aceitar um orçamento pela lista MUST ter o mesmo efeito que aceitar um orçamento já
  tem hoje no aplicativo (publica a aceitação, recusa os demais orçamentos da mesma solicitação, e
  avança a corrida de fase).
- **FR-007**: O sistema MUST eliminar a notificação em modal usada até então para cada orçamento
  recebido — a tela dedicada passa a ser o único mecanismo de acompanhamento e decisão sobre
  orçamentos.
- **FR-008**: O botão "Cancelar" MUST estar sempre visível na parte inferior da tela dedicada,
  independentemente de quantos orçamentos (incluindo zero) já foram recebidos.
- **FR-009**: Tocar "Cancelar" MUST fazer o passageiro voltar à fase inicial, encerrando a tela
  dedicada e voltando a exibir o mapa com o painel de solicitação.
- **FR-010**: Tocar "Cancelar" MUST enviar uma mensagem de recusa para cada motorista que já havia
  enviado um orçamento exibido na lista no momento do cancelamento; se a lista estiver vazia,
  nenhuma mensagem é enviada.
- **FR-011**: O sistema MUST continuar garantindo que o passageiro tem exatamente uma fase de
  corrida corrente a qualquer momento (invariante já estabelecida) — "Cancelar" é mais uma
  transição válida de volta à fase inicial, a partir da fase "Aguardando orçamentos".
- **FR-012**: Se o aplicativo for encerrado e reaberto enquanto a fase for "Aguardando
  orçamentos", o sistema MUST recarregar na tela dedicada os orçamentos já recebidos e persistidos
  para aquela solicitação, em vez de exibir uma lista vazia (Clarification, sessão 2026-09-28).

### Key Entities

- **Tela de orçamentos recebidos**: substitui a notificação em modal por orçamento; acompanha a
  lista de orçamentos já recebidos para a solicitação ativa e expõe as ações de aceitar um deles ou
  cancelar a solicitação inteira.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Em 100% das fases além da inicial, o painel de solicitação de corrida não está
  visível.
- **SC-002**: Cada orçamento recebido aparece na lista da tela dedicada em até 2 segundos após ser
  processado pelo aplicativo, na mesma ordem grandeza da notificação em modal que ela substitui.
- **SC-003**: Ao cancelar, 100% dos motoristas que haviam enviado orçamento para aquela solicitação
  recebem a mensagem de recusa.
- **SC-004**: Depois de cancelar, o passageiro consegue solicitar uma nova corrida imediatamente,
  sem nenhum resquício visível da solicitação cancelada.

## Assumptions

- "Mesmos elementos" (FR-005) significa os mesmos dados já exibidos hoje por orçamento — nome do
  motorista, marca/modelo/ano do veículo, valor total e tempo estimado — sem remover nenhum campo;
  "mais condensado" diz respeito só ao espaço ocupado na tela, não aos dados mostrados.
- Cancelar não apaga nenhum orçamento já persistido localmente — apenas impede que a solicitação
  continue ativa e avisa os motoristas envolvidos; o histórico de orçamentos recebidos permanece
  gravado, como já ocorre hoje com orçamentos tardios.
- A mensagem de recusa enviada ao cancelar é a mesma já usada hoje para recusar um orçamento não
  escolhido ao aceitar outro — nenhum tipo de mensagem novo é necessário.
- Esta feature não introduz nenhum evento Nostr novo nem altera o contrato de eventos existente —
  reaproveita a aceitação e a recusa de orçamento já publicadas hoje.

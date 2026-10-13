# Feature Specification: Estado único de corrida do passageiro

**Feature Branch**: `014-estado-corrida-passageiro`

**Created**: 2026-09-28

**Status**: Draft

**Input**: User description: "O app do passageiro deve ter um único estado de corrida por vez (mutuamente exclusivo), análogo ao enum DriverRideStatus já existente no app do motorista. Hoje esse estado é implícito: vive espalhado em campos soltos de _MapScreenState — _solicitacaoAtivaId, _corridaDecidida — e nas três flags booleanas de AcceptedRide (movementNotified, meetingConfirmed, destinationConfirmed). Esta feature deve consolidar isso num modelo de estado único. Requisito já confirmado: quando o app for aberto pela primeira vez, logo após a instalação, o estado do passageiro deve ser 'Inicial'. O ciclo completo já implementado no passageiro, que o novo estado precisa cobrir, é: nenhuma solicitação ativa (estado inicial) → solicitação de corrida enviada / aguardando orçamentos → orçamento aceito → motorista a caminho → encontro confirmado → destino confirmado → avaliação da corrida. Esta feature é reorganização de estado local do passageiro; não deve tocar o contrato de eventos Nostr."

## Clarifications

### Session 2026-09-28

- Q: "Orçamento aceito" e "motorista a caminho" devem ser um único estado ou
  dois estados distintos? → A: Dois estados distintos — "orçamento aceito"
  (aguardando o motorista iniciar o deslocamento) e "motorista a caminho"
  (após a primeira confirmação de que ele começou a se deslocar).
- Q: Ao confirmar o destino, o estado deve voltar a "Inicial" de imediato
  (com a avaliação como modal independente, fora da máquina de estados,
  como no motorista) ou manter um estado dedicado "destino confirmado /
  aguardando avaliação" que só libera "Inicial" após avaliar ou pular? → A:
  Mantém o estado dedicado "destino confirmado / aguardando avaliação"; só
  volta a "Inicial" após o passageiro avaliar (ou pular) a corrida — a
  avaliação faz parte da máquina de estados, diferente do padrão do
  motorista.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Estado inicial ao instalar o app (Priority: P1)

O passageiro instala o app e o abre pela primeira vez, antes de qualquer
interação. O app deve refletir, de forma inequívoca, que nenhuma corrida está
em andamento nem foi solicitada — o estado "Inicial".

**Why this priority**: É o requisito explicitamente confirmado que originou
a feature; sem ele nenhum outro estado tem um ponto de partida definido.

**Independent Test**: Instalar o app do zero (sem dados de execuções
anteriores) e verificar que o estado de corrida reportado é "Inicial", com
nenhuma solicitação, orçamento ou corrida associada.

**Acceptance Scenarios**:

1. **Given** o app acabou de ser instalado e nunca foi aberto, **When** o
   passageiro o abre pela primeira vez, **Then** o estado de corrida é
   "Inicial".
2. **Given** o passageiro está no estado "Inicial", **When** ele consulta a
   tela principal, **Then** não há indicação de solicitação, orçamento ou
   corrida em qualquer fase.

---

### User Story 2 - Um único estado ativo por vez durante o ciclo da corrida (Priority: P1)

Enquanto o passageiro avança pelo ciclo de uma corrida (solicitar, receber
orçamentos, aceitar um, acompanhar o motorista a caminho, confirmar o
encontro, confirmar a chegada ao destino), o app deve sempre reportar
exatamente um estado corrente, nunca dois estados simultâneos nem nenhum.

**Why this priority**: É a garantia central da feature — sem
exclusividade mútua, o objetivo de consolidar o estado implícito em um
modelo único não é atingido.

**Independent Test**: Percorrer o ciclo completo de uma corrida (usando
duplês de teste para os eventos Nostr recebidos, sem tocar rede real) e, a
cada passo, verificar que existe exatamente um estado corrente e que ele
corresponde à fase em que a corrida realmente está.

**Acceptance Scenarios**:

1. **Given** o passageiro está no estado "Inicial", **When** ele solicita
   uma corrida, **Then** o estado passa a refletir "solicitação enviada /
   aguardando orçamentos", e apenas esse.
2. **Given** o passageiro está aguardando orçamentos, **When** ele aceita um
   orçamento recebido, **Then** o estado passa a refletir "orçamento
   aceito", e apenas esse.
3. **Given** o passageiro está no estado "orçamento aceito", **When** chega a
   primeira confirmação de que o motorista começou a se deslocar, **Then**
   o estado passa a refletir "motorista a caminho", e apenas esse.
4. **Given** o passageiro está acompanhando o motorista a caminho, **When**
   a chegada do motorista ao ponto de encontro é confirmada, **Then** o
   estado passa a refletir "encontro confirmado", e apenas esse.
5. **Given** o passageiro está no estado de encontro confirmado, **When** a
   chegada ao destino é confirmada, **Then** o estado passa a refletir
   "destino confirmado / aguardando avaliação", e apenas esse.

---

### User Story 3 - Retorno ao estado inicial após concluir o ciclo (Priority: P2)

Depois que o passageiro avalia a corrida concluída (ou opta por não
avaliar), o app deve voltar a um estado que permita solicitar uma nova
corrida, de forma consistente com o estado "Inicial" do início.

**Why this priority**: Fecha o ciclo e evita que o passageiro fique "presos"
em um estado terminal sem conseguir solicitar uma nova corrida; tem
prioridade menor que P1 porque o ciclo em si (US2) já entrega valor sem
isso, ainda que de forma incompleta para uso contínuo do app.

**Independent Test**: Concluir o ciclo de uma corrida (com duplês de teste)
até a avaliação, confirmar ou pular a avaliação, e verificar que o estado
resultante permite iniciar uma nova solicitação sem resquícios da corrida
anterior.

**Acceptance Scenarios**:

1. **Given** o passageiro está no estado "destino confirmado / aguardando
   avaliação", **When** ele confirma uma nota para a corrida, **Then** o
   estado volta a "Inicial".
2. **Given** o passageiro está no estado "destino confirmado / aguardando
   avaliação", **When** ele opta por pular a avaliação, **Then** o estado
   volta a "Inicial".

### Edge Cases

- O que acontece se o app for encerrado (fechado ou reiniciado) no meio do
  ciclo — por exemplo, enquanto aguarda orçamentos ou enquanto acompanha o
  motorista a caminho? O estado exibido ao reabrir precisa continuar
  refletindo a fase real da corrida em andamento, não voltar a "Inicial"
  incorretamente.
- O que acontece se um evento de orçamento (`kind: 20002`) chegar depois que
  o passageiro já aceitou outro orçamento (estado avançou além de
  "aguardando orçamentos")? O estado não deve retroceder nem ser afetado por
  esse evento tardio.
- O que acontece se uma confirmação de encontro ou de destino chegar fora de
  ordem (por exemplo, confirmação de destino sem confirmação de encontro
  prévia)? O estado deve permanecer no que já é conhecido como válido, sem
  transicionar para uma fase incoerente.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O app MUST expor, em todo momento, exatamente um estado de
  corrida corrente para o passageiro — nunca mais de um simultaneamente, nem
  nenhum.
- **FR-002**: O estado de corrida MUST ser "Inicial" na primeira abertura do
  app após a instalação, antes de qualquer solicitação de corrida.
- **FR-003**: O app MUST transicionar do estado "Inicial" para "solicitação
  enviada / aguardando orçamentos" no momento em que uma solicitação de
  corrida é enviada.
- **FR-004**: O app MUST transicionar de "aguardando orçamentos" para
  "orçamento aceito" no momento em que o passageiro aceita um orçamento
  recebido.
- **FR-005**: O app MUST transicionar de "orçamento aceito" para "motorista
  a caminho" no momento em que chega a primeira confirmação de que o
  motorista começou a se deslocar em direção à origem.
- **FR-006**: O app MUST transicionar de "motorista a caminho" para
  "encontro confirmado" no momento em que a confirmação de encontro com o
  motorista é registrada.
- **FR-007**: O app MUST transicionar de "encontro confirmado" para "destino
  confirmado / aguardando avaliação" no momento em que a chegada ao destino
  é confirmada.
- **FR-008**: O app MUST transicionar de "destino confirmado / aguardando
  avaliação" de volta para "Inicial" quando o passageiro concluir a
  avaliação da corrida (seja confirmando uma nota, seja optando por pular).
- **FR-009**: O app MUST persistir o estado de corrida em disco, de forma
  que ele sobreviva a um reinício do app durante o ciclo e continue
  coerente com a fase real da corrida em andamento ao reabrir — mesmo
  padrão de persistência explícita já usado pelo `RideStateStore` do app do
  motorista.
- **FR-010**: O app MUST ignorar, sem alterar o estado corrente, qualquer
  evento relativo à corrida que chegue fora de ordem ou depois que a fase
  correspondente já tenha sido superada (ver Edge Cases).
- **FR-011**: O modelo de estado único MUST substituir completamente as três
  flags booleanas hoje existentes em `AcceptedRide` (`movementNotified`,
  `meetingConfirmed`, `destinationConfirmed`); cada uma é derivável do
  próprio estado corrente (por exemplo, `movementNotified` equivale a o
  estado já ter alcançado "motorista a caminho" ou uma fase posterior), e a
  lógica de exibir cada modal "uma única vez" passa a se basear nisso, sem
  flags independentes.

### Key Entities

- **Estado de corrida do passageiro**: representa, em cada momento, a fase
  única e corrente em que a corrida do passageiro se encontra (Inicial,
  aguardando orçamentos, orçamento aceito, motorista a caminho, encontro
  confirmado, destino confirmado / aguardando avaliação). Substitui a
  combinação hoje implícita de múltiplos campos independentes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Em 100% das transições do ciclo de uma corrida (solicitar,
  aceitar orçamento, motorista a caminho, encontro confirmado, destino
  confirmado, avaliação), existe exatamente um estado corrente reportado
  pelo app, verificável sem ambiguidade.
- **SC-002**: Ao abrir o app pela primeira vez após a instalação, o estado
  "Inicial" é observado em 100% das vezes, antes de qualquer solicitação de
  corrida.
- **SC-003**: Após concluir a avaliação de uma corrida (com nota ou pulada),
  o passageiro consegue solicitar uma nova corrida imediatamente, sem
  resquícios visíveis da corrida anterior, em 100% dos ciclos testados.

## Assumptions

- O escopo desta feature é a consolidação do estado de corrida do
  passageiro em um único modelo; não inclui alterações ao contrato de
  eventos Nostr nem ao app do motorista.
- Os nomes de estado usados nesta especificação ("Inicial", "aguardando
  orçamentos", "motorista a caminho", "encontro confirmado", "destino
  confirmado / aguardando avaliação") são descritivos para fins de
  especificação; o nome técnico exato de cada valor será decidido na fase
  de planejamento, por analogia ao padrão já usado no app do motorista
  (`DriverRideStatus`).
- O ciclo de uma corrida, do ponto de vista do passageiro, é o mesmo já
  implementado nas features anteriores (006 a 012): solicitar, receber e
  aceitar orçamentos, acompanhar o motorista, confirmar encontro e destino,
  e avaliar.

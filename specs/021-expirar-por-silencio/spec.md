# Feature Specification: Expirar a corrida por silêncio do motorista (passageiro)

> **Removida (2026-10-12):** a pedido do autor, a funcionalidade deixou de ser necessária e foi retirada do código
> (`_armarSilencio`/`_expirarPorSilencio`, `driverSilenceTimeout`, `DriverSilentModal`,
> `PassengerRideRules.canExpireBySilence` e os testes). O passageiro volta a encerrar a corrida aceita só por aviso
> explícito do motorista (`20006`, `20012`) ou por cancelamento próprio (`023`). Este spec fica como histórico da decisão.

**Feature Branch**: `021-expirar-por-silencio`

**Created**: 2026-10-04

**Status**: Draft

**Input**: User description: "Modifique o app do passageiro de modo que, enquanto a corrida estiver
em 'orçamento aceito' ou 'motorista a caminho', se nenhuma localização do motorista da corrida
aceita (kind 20005) chegar por 3 minutos, o app expire a corrida por silêncio: encerre a corrida no
app do passageiro, volte ao estado inicial e avise o passageiro por modal. Em 'em corrida' a
expiração não se aplica. Nada é publicado."

## Clarifications

### Session 2026-10-04 (decisões tomadas antes da especificação, na conversa que a originou)

- Q: Qual mecanismo cobre o passageiro que fica preso em "orçamento aceito" (ou perde o motorista a
  caminho) quando nenhum aviso explícito chega — por exemplo, porque o `kind: 20006` ou o `20012` se
  perdeu num relay, ou porque o app do motorista foi fechado? → A: expirar por silêncio, entre as três
  opções apresentadas (botão de cancelar, expirar por silêncio, os dois), a preferida pelo usuário.
- Q: Quanto silêncio vale como "o motorista sumiu", e em quais fases? → A: 3 minutos, em "orçamento
  aceito" e "motorista a caminho" (sugestão aceita pelo usuário). Em "em corrida" a expiração não se
  aplica, para não encerrar uma viagem em andamento por uma falha de rede.
- Q: O passageiro avisa o motorista ou a rede de que expirou? → A: não — nada é publicado, mesma
  orientação já dada para o `kind: 20006` (a rede não precisa saber).
- Q: Precisa de evento novo no contrato? → A: não. A feature é puramente local: o tempo decorrido é
  medido no próprio app a partir dos `kind: 20005` já consumidos (feature 009/016).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Sair de "orçamento aceito" quando o motorista nunca aparece (Priority: P1)

Como passageiro que aceitou um orçamento, se o motorista nunca começar a se deslocar (nenhuma
localização dele chega) por 3 minutos, quero que o app encerre a corrida e me avise, para poder pedir
outra em vez de esperar indefinidamente.

**Why this priority**: é o caso que motivou a feature — hoje o passageiro nessa fase não tem saída
própria, e nenhum aviso explícito (`20006`, `20012`) é garantido.

**Independent Test**: com o passageiro em "orçamento aceito" e nenhuma localização chegando, avançar o
relógio 3 minutos e verificar que a modal aparece e o app está no estado inicial.

**Acceptance Scenarios**:

1. **Given** o passageiro em "orçamento aceito", **When** passam 3 minutos sem nenhuma localização do
   motorista da corrida aceita, **Then** uma modal informa que o motorista ficou sem sinal e a corrida
   foi encerrada, e o app está no estado inicial.
2. **Given** o passageiro em "orçamento aceito", **When** uma localização do motorista chega antes de
   completar 3 minutos, **Then** a corrida segue (o app passa a "motorista a caminho") e a contagem do
   silêncio recomeça do zero.
3. **Given** a modal de expiração aberta, **When** o passageiro toca "OK", **Then** a modal fecha e o
   painel "Solicitar corrida" fica disponível.

---

### User Story 2 - Sair de "motorista a caminho" quando o motorista some (Priority: P1)

Como passageiro com o motorista a caminho, se as localizações dele pararem de chegar por 3 minutos,
quero que o app encerre a corrida e me avise, em vez de manter um marcador congelado indefinidamente.

**Why this priority**: mesmo problema da US1, na fase seguinte: o motorista fecha o app, perde conexão
ou o relay cai, e o passageiro fica olhando um motorista parado que não virá.

**Independent Test**: com o passageiro em "motorista a caminho", entregar uma localização, depois
avançar o relógio 3 minutos sem novas localizações e verificar modal e estado inicial.

**Acceptance Scenarios**:

1. **Given** o passageiro em "motorista a caminho", **When** passam 3 minutos desde a última
   localização do motorista, **Then** o mesmo encerramento e a mesma modal da US1 ocorrem, e o marcador
   do motorista some.
2. **Given** o passageiro em "motorista a caminho", **When** localizações continuam chegando, **Then**
   a expiração nunca dispara (cada uma recomeça a contagem).

---

### User Story 3 - A expiração não atinge a viagem nem avisos já tratados (Priority: P2)

Como passageiro, não quero que a viagem em andamento seja encerrada por silêncio, nem que a contagem
sobreviva a um encerramento por outro motivo.

**Why this priority**: protege a corrida em andamento (a fase mais sensível) e evita modais duplicadas
ou fantasmas.

**Independent Test**: confirmar o encontro (estado "em corrida") e avançar o relógio bem além de 3
minutos sem localizações: nada acontece. Encerrar por cancelamento do motorista e avançar o relógio:
nenhuma modal extra.

**Acceptance Scenarios**:

1. **Given** o passageiro em "em corrida", **When** passam mais de 3 minutos sem localização do
   motorista, **Then** nada acontece: a viagem continua.
2. **Given** o passageiro que acabou de confirmar o encontro, **When** a contagem do silêncio estava
   em andamento, **Then** ela é cancelada na transição para "em corrida".
3. **Given** a corrida encerrada por outro motivo (cancelamento `20012`, aviso `20006`, conclusão),
   **When** o tempo passa, **Then** nenhuma modal de expiração aparece.
4. **Given** uma localização do motorista de outra corrida ou assinada por outra chave, **When**
   chega, **Then** não conta como sinal e não recomeça a contagem.

---

### Edge Cases

- App fechado e reaberto numa fase de expiração: a contagem recomeça do zero ao reabrir (não é
  persistida); se nenhuma localização chegar em 3 minutos, expira. O tempo em que o app ficou fechado
  não conta.
- Localização com `content` inválido (coordenadas fora de faixa): continua valendo como sinal de vida
  do motorista (mesma regra da feature 009, que não exige `content` válido para reconhecer a primeira
  localização); só não atualiza o marcador.
- Localização reentregue (mesmo `id`) por outro relay: não recomeça a contagem (já foi processada).
- O motorista ainda não viu a aceitação (a modal "Orçamento aceito" dele está na fila ou aberta) por
  mais de 3 minutos: o passageiro expira mesmo assim. Consequência aceita (ver Assumptions).
- O passageiro estava com a modal "motorista chegou" aberta quando a expiração dispara: a expiração
  prevalece e as modais da corrida são apagadas, como no cancelamento (feature 019).
- Expiração e aviso explícito quase simultâneos (por exemplo, `20012` chega no mesmo instante): o
  primeiro tratado encerra a corrida; o segundo, já sem corrida aceita, é ignorado.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Enquanto o passageiro estiver em "orçamento aceito" ou "motorista a caminho", o app MUST
  medir o tempo desde o último sinal do motorista da corrida aceita — o instante em que a corrida foi
  aceita (ou restaurada ao abrir o app) ou o da última localização recebida, o que for mais recente.
- **FR-002**: Um sinal só MUST contar se for um `kind: 20005` com assinatura verificada, assinado pelo
  motorista da corrida aceita e que referencia o orçamento aceito (as mesmas conferências da feature
  016), recebido pela primeira vez. A validade do `content` não é exigida.
- **FR-003**: Ao completar 3 minutos sem sinal nessas duas fases, o app MUST encerrar a corrida:
  voltar ao estado inicial, descartar a corrida aceita e a posição e a rota do motorista, apagar as
  modais da corrida e persistir esse estado, de modo que sobreviva a um reinício — no instante da
  expiração, não ao tocar "OK".
- **FR-004**: Ao expirar, o app MUST exibir uma modal informando que o motorista ficou sem sinal e a
  corrida foi encerrada, com um único botão "OK"; tocar "OK" só a fecha.
- **FR-005**: Cada sinal válido MUST recomeçar a contagem dos 3 minutos do zero.
- **FR-006**: Em "em corrida", e fora das duas fases (inicial, aguardando orçamentos, aguardando
  avaliação), o app MUST NOT contar silêncio nem expirar; ao sair das duas fases por qualquer motivo
  (encontro confirmado, cancelamento, aviso do `20006`, conclusão), a contagem MUST ser cancelada.
- **FR-007**: A expiração MUST NOT publicar nenhum evento nem abrir a avaliação da corrida.
- **FR-008**: Depois de expirar, o app MUST permitir uma nova solicitação de corrida normalmente, e
  eventos tardios da corrida expirada (localização, chegada, rota) MUST ser ignorados.
- **FR-009**: Esta feature MUST NOT alterar o formato de nenhum evento nem o contrato (Princípio IV).

### Key Entities

- **Corrida aceita (existente)**: orçamento aceito e a chave do motorista escolhido. Passa a poder ser
  encerrada também por silêncio do motorista.
- **Sinal do motorista (conceito, não persistido)**: o instante do último `kind: 20005` válido, ou o
  da aceitação/restauração. Só existe em memória.
- **Estado de corrida do passageiro (existente)**: ganha uma transição de "orçamento aceito" e
  "motorista a caminho" de volta ao estado inicial, por silêncio.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Em 100% dos casos de 3 minutos sem sinal em "orçamento aceito" ou "motorista a caminho",
  a modal aparece e o app já está no estado inicial no instante em que ela aparece.
- **SC-002**: Com localizações válidas chegando a menos de 3 minutos uma da outra, em 0% dos casos a
  expiração dispara.
- **SC-003**: Em "em corrida", em 0% dos casos a expiração dispara, por mais longo que seja o
  silêncio.
- **SC-004**: Depois da expiração e de um reinício do app, 100% das aberturas mostram o passageiro no
  estado inicial, sem corrida aceita e sem modal.
- **SC-005**: Em 100% das expirações, nenhum evento é publicado e a avaliação não abre.
- **SC-006**: Depois da expiração, o passageiro consegue solicitar e concluir uma nova corrida sem
  nenhuma interferência da expirada.

## Assumptions

- O tempo é medido no próprio app, a partir dos eventos já consumidos; não há evento novo nem mudança
  no motorista. A contagem não é persistida: ao reabrir o app em uma das duas fases, recomeça do zero.
- Risco conhecido do prazo em "orçamento aceito": o motorista precisa notar a aceitação e tocar
  "Iniciar corrida" na modal dele antes de a primeira localização sair; 3 minutos pode ser curto se ele
  estiver ocupado. O valor é uma constante única, fácil de ajustar, e foi escolhido pelo usuário.
- A modal é informativa, no padrão visual das demais (`DriverUnavailableModal`: mensagem + "OK"); texto
  sugerido: "O motorista ficou sem sinal e a corrida foi encerrada. Você pode solicitar outra."
- Nenhum evento é publicado pelo passageiro (decisão do usuário, mesma do `kind: 20006`); o motorista
  não é avisado de que a corrida expirou.
- Esta feature complementa, e não substitui, os avisos explícitos das features 019 (cancelamento
  `20012`) e 020 (motorista indisponível `20006`): quem chegar primeiro encerra a corrida.
- Dependência: reaproveita o estado persistido do passageiro, a corrida aceita e a conferência de autor
  da feature 016; o encerramento comum `_encerrarCorridaAceita` da feature 020.

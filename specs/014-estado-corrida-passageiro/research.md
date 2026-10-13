# Phase 0 — Research: Estado único de corrida do passageiro

## D1 — Persistência: novo `PassengerRideStateStore` sobre `KeyValueStore`, por analogia direta ao
`RideStateStore` do motorista (atende FR-009; resolve a clarificação Q1 da sessão de especificação)

**Decision**: novo par `PassengerRideStateStore` (abstrata) / `PreferencesPassengerRideStateStore`
(implementação real), sobre o mesmo `KeyValueStore` já usado por `AcceptedRideStore` e
`RelayRepository`, gravando um único valor JSON sob a chave `passenger_ride_state`.

**Contexto da decisão**: a especificação (FR-009, decidida na clarificação Q1 antes do plano) exige
que o estado sobreviva a um reinício do app durante o ciclo. O motorista já resolve exatamente esse
problema com `RideStateStore` (persiste `(DriverRideStatus, ActiveRide?)` como um único JSON) — a
mesma estrutura é reaproveitada aqui, adaptada à costura de injeção do passageiro (`KeyValueStore`
em vez do par `KeyStore`/armazenamento próprio do motorista).

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| Novo store dedicado sobre `KeyValueStore` (escolhida) | Mesmo padrão já validado pelo motorista e por `AcceptedRideStore`; nenhuma dependência nova. |
| Reaproveitar `AcceptedRideStore` para também guardar o status | Rejeitada: `AcceptedRide` só existe a partir da aceitação de um orçamento (feature 008); o estado `AguardandoOrcamentos` precisa persistir antes disso (o id da solicitação ativa), quando nenhuma `AcceptedRide` existe ainda. Misturar os dois exigiria tornar `AcceptedRide` opcionalmente parcial, perdendo a clareza de "corrida aceita" como conceito. |
| Recalcular em memória a cada abertura, sem persistir | Rejeitada pela própria clarificação Q1 (opção A, persistência explícita) — descartada antes do plano. |

### Riscos assumidos e mitigação

- Nenhum risco novo — mesmo padrão de robustez a estado corrompido já usado por
  `PreferencesAcceptedRideStore`/`RideStateStore` (volta ao estado inicial em caso de falha ao
  decodificar, sem travar o app).

## D2 — Remoção completa das três flags de `AcceptedRide` (atende FR-011; resolve a clarificação Q2
da sessão de especificação)

**Decision**: `AcceptedRide` perde `movementNotified`, `meetingConfirmed` e `destinationConfirmed`;
passa a conter só `quoteId` e `driverPubkey`. Cada flag removida é derivável do novo
`PassengerRideStatus`:

| Flag removida | Equivalente no novo estado |
|---|---|
| `movementNotified` | `status.index >= PassengerRideStatus.motoristaACaminho.index` |
| `meetingConfirmed` | `status.index >= PassengerRideStatus.encontroConfirmado.index` |
| `destinationConfirmed` | `status == PassengerRideStatus.destinoConfirmadoAguardandoAvaliacao` (ou já voltou a `inicial`, ou seja, a corrida já foi concluída) |

**Contexto da decisão**: a clarificação Q2 já decidiu isso explicitamente. Manter as flags ao lado
do novo estado criaria duas fontes de verdade para a mesma informação (Princípio V) — o risco real
que motivou a feature (estado implícito espalhado) reapareceria em miniatura dentro do próprio
`AcceptedRide`.

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| Remover completamente (escolhida) | Única opção compatível com a resposta da clarificação Q2. |
| Manter as três flags e adicionar o enum por cima | Rejeitada pela clarificação Q2 e pelo Princípio V (duplicação de fonte de verdade). |

### Riscos assumidos e mitigação

- Todo código que hoje lê `corridaAceita.movementNotified` (e as outras duas) precisa migrar para
  comparar `_rideStatus` — mapeado exaustivamente na seção "Source Code" do `plan.md`; cobertura
  garantida pelos testes alterados em `map_screen_test.dart`.

## D3 — Granularidade dos estados: seis valores, "orçamento aceito" e "motorista a caminho"
distintos (decidido na sessão de clarificação, antes deste plano)

**Decision**: `PassengerRideStatus` tem seis valores — `inicial`, `aguardandoOrcamentos`,
`orcamentoAceito`, `motoristaACaminho`, `encontroConfirmado`,
`destinoConfirmadoAguardandoAvaliacao` — nomeados em português, minúscula inicial (camelCase),
mesma convenção de `DriverRideStatus`.

**Contexto da decisão**: já resolvida na sessão de clarificação do `spec.md` (duas perguntas): a
primeira separou "orçamento aceito" de "motorista a caminho" (a `AcceptedRide` já existe antes do
motorista de fato começar a se deslocar); a segunda manteve "destino confirmado / aguardando
avaliação" como estado próprio da máquina, em vez de voltar a `inicial` antes da avaliação (diferente
do padrão do motorista). Este documento apenas registra a decisão já tomada como entrada para o
desenho do enum.

### Alternativas avaliadas

*Já avaliadas na sessão de clarificação do `spec.md` — ver seção Clarifications daquele arquivo; não
repetido aqui para evitar duas fontes da mesma decisão.*

## D4 — Guardas de transição: funções puras em `PassengerRideRules`, por analogia a
`DriverRideRules`

**Decision**: `abstract final class PassengerRideRules` com uma função por transição válida
(`canRequestRide`, `canAcceptQuote`, `canNotifyMovement`, `canConfirmMeeting`,
`canConfirmDestinationArrival`, `canFinishRating`), cada uma recebendo o `PassengerRideStatus`
corrente e retornando se a transição é permitida a partir dele — mesmo formato de
`DriverRideRules.canStartRide`/`canConfirmMeeting`/`canConfirmDestinationArrival` do motorista.

**Contexto da decisão**: reaproveita um padrão já testado e revisado no motorista em vez de inventar
um mecanismo de validação novo (Princípio V); dá a FR-010 (ignorar eventos fora de ordem) um ponto
único e testável de verificação, chamado antes de cada transição em `map_screen.dart`.

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| Funções puras em classe abstrata final (escolhida) | Mesmo padrão do motorista; testável sem I/O, sem instanciar nada. |
| Validação inline em cada método de `_MapScreenState` | Rejeitada: repetiria a mesma condição em vários pontos sem um nome nem um teste dedicado — o próprio problema de estado implícito que esta feature busca eliminar. |
| Método de instância em `PassengerRideStatus` (`status.canAcceptQuote()`) | Considerada equivalente; optou-se pela classe separada só para manter simetria literal com `DriverRideRules`, facilitando comparação entre os dois apps. |

### Riscos assumidos e mitigação

- Nenhum risco novo — mesmo padrão já em produção no motorista.

## D5 — Reconciliação no boot entre `PassengerRideStateStore` e `AcceptedRideStore` (atende FR-009;
achado C1 do `/speckit-analyze`)

**Decision**: ao carregar no boot, se `status` for `orcamentoAceito` ou posterior mas
`AcceptedRideStore.load()` retornar `null` (ou o inverso: `AcceptedRide` existe mas `status` é
`inicial`/`aguardandoOrcamentos`), tratar como estado corrompido e voltar ao default seguro
(`inicial`, sem `AcceptedRide`) — mesma postura de robustez já usada por ambos os stores para JSON
malformado.

**Contexto da decisão**: `_aceitarOrcamento` grava nos dois stores separadamente. Se o processo for
encerrado entre as duas escritas, as duas fontes podem divergir. Em vez de fundir os dois stores num
único valor atômico (contrariaria a separação de responsabilidades de D1, só para cobrir uma janela
de risco muito pequena), a leitura no boot detecta a divergência e resolve revertendo ao estado
seguro conhecido.

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| Detectar divergência no boot e voltar ao default (escolhida) | Reaproveita o padrão de robustez já existente nos dois stores; sem escrita nova, sem dependência nova. |
| Escrita atômica combinada (fundir os dois stores em um valor só) | Rejeitada: contraria a separação de responsabilidades de D1 (Princípio V) para cobrir uma janela de risco mínima. |
| Ignorar o risco, sem tratamento explícito | Rejeitada: deixaria o app bloqueando novas solicitações por acreditar haver uma corrida aceita sem dados para identificá-la — pior que voltar ao default. |

### Riscos assumidos e mitigação

- No cenário raro de o processo ser encerrado exatamente entre as duas escritas de
  `_aceitarOrcamento`, a corrida fica irrecuperável para o passageiro (precisa aceitar de novo, se
  o motorista ainda enviar orçamento) — aceito, mesma postura de robustez-sobre-continuidade já
  usada nos dois stores existentes.

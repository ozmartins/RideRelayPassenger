# Quickstart — Estado único de corrida do passageiro

Guia de validação manual desta feature, em `Prototipo/passenger/`. Requer dois
aparelhos/emuladores com relay em comum (um para o passageiro, um para o motorista rodando
`007-receber-solicitacao-corrida`/`010-iniciar-corrida`/`011-notificar-chegada`/
`012-confirmar-encontro-destino` já implementadas), já que a maioria das transições depende de
eventos recebidos do motorista. Nenhuma alteração ao contrato Nostr é necessária.

## Cenários de validação (referem os FR/SC de `spec.md`)

### 1. Estado "Inicial" logo após a instalação (US1, FR-002, SC-002)

1. Instalar o app do zero (desinstalar uma cópia anterior, se houver, para limpar dados locais).
2. Abrir o app pela primeira vez.
3. **Esperado**: nenhuma modal de corrida em andamento aparece; a tela do mapa não indica
   solicitação, orçamento ou corrida em qualquer fase — o estado interno (verificável via log ou
   inspeção do `PassengerRideStateStore`) é `PassengerRideStatus.inicial`.

### 2. Ciclo completo, um estado por vez (US2, FR-003 a FR-008, SC-001)

1. No estado `inicial`, tocar "Solicitar corrida". **Esperado**: estado passa a
   `aguardandoOrcamentos`.
2. No app do motorista, enviar um orçamento para a solicitação. No passageiro, aceitar esse
   orçamento na modal de orçamentos recebidos. **Esperado**: estado passa a `orcamentoAceito`.
3. No app do motorista, tocar "Iniciar corrida" (feature 010 dele). **Esperado**: ao chegar a
   primeira localização do motorista no passageiro, o estado passa a `motoristaACaminho` e a modal
   "motorista a caminho" (feature 009) aparece.
4. No app do motorista, aproximar-se da origem até a notificação de chegada (feature 011 dele,
   `kind: 20007`). No passageiro, confirmar o encontro na modal correspondente. **Esperado**:
   estado passa a `encontroConfirmado`.
5. No app do motorista, aproximar-se do destino até a notificação de chegada (feature 012 dele,
   `kind: 20009`). No passageiro, confirmar a chegada ao destino na modal correspondente.
   **Esperado**: estado passa a `destinoConfirmadoAguardandoAvaliacao`.
6. A cada passo 1-5, confirmar que existe exatamente um estado corrente (nunca dois, nunca nenhum) —
   inspecionável via `PassengerRideStateStore.load()`/log de depuração.

### 3. Retorno a "Inicial" após avaliar ou pular (US3, FR-008, SC-003)

1. A partir do estado `destinoConfirmadoAguardandoAvaliacao` (final do cenário 2), confirmar uma
   nota na modal de avaliação. **Esperado**: estado volta a `inicial`; o botão "Solicitar corrida"
   fica disponível imediatamente, sem resquício da corrida anterior.
2. Repetir o cenário 2 até o passo 5 novamente, mas desta vez pular a avaliação. **Esperado**: mesmo
   resultado — estado volta a `inicial`.

### 4. Estado sobrevive a reinício do app (Edge Case, FR-008/FR-009)

1. Repetir o cenário 2 até o passo 3 (estado `motoristaACaminho`).
2. Encerrar o processo do app do passageiro (não só minimizar) e reabri-lo.
3. **Esperado**: o estado volta a ser `motoristaACaminho` (não `inicial`), e o fluxo pode continuar
   normalmente a partir do passo 4 do cenário 2.

### 5. Evento tardio não altera o estado (Edge Case, FR-010)

1. Repetir o cenário 2 até o passo 2 (estado `orcamentoAceito`, um orçamento já aceito).
2. No app do motorista (um segundo motorista, se disponível, ou reenvio manual de teste), publicar
   um novo `kind: 20002` referenciando a mesma solicitação já decidida.
3. **Esperado**: o estado permanece `orcamentoAceito` — o orçamento tardio não é processado nem
   altera a fase corrente.

# Quickstart — Tela de orçamentos recebidos e cancelamento da solicitação

Guia de validação manual desta feature, em `Prototipo/passenger/`. Requer um segundo
aparelho/emulador rodando o motorista (`007-receber-solicitacao-corrida` implementada) com relay em
comum, para enviar orçamentos reais. Nenhuma alteração ao contrato Nostr é necessária.

## Cenários de validação (referem os FR/SC de `spec.md`)

### 1. Painel de solicitação só aparece na fase inicial (US1, FR-001, FR-002, SC-001)

1. Abrir o app do zero. **Esperado**: painel com destino, forma de pagamento e "Solicitar corrida"
   visível.
2. Escolher um destino e tocar "Solicitar corrida". **Esperado**: o painel desaparece
   imediatamente, dando lugar à tela de orçamentos.
3. Percorrer o restante do ciclo de uma corrida (aceitar um orçamento, motorista a caminho,
   encontro confirmado, destino confirmado). **Esperado**: o painel de solicitação não reaparece em
   nenhuma dessas fases.

### 2. Tela de orçamentos cresce conforme eles chegam (US2, FR-003 a FR-006, SC-002)

1. A partir do passo 2 do cenário 1, observar a tela de orçamentos. **Esperado**: lista vazia,
   botão "Cancelar" visível embaixo.
2. No motorista, enviar um orçamento. **Esperado**: em até 2 s, um item aparece na lista do
   passageiro, em formato condensado (nome do motorista, veículo, total, tempo estimado).
3. Enviar um segundo orçamento de outro motorista. **Esperado**: um segundo item é adicionado,
   sem remover o primeiro.
4. Tocar "Aceitar" num dos itens. **Esperado**: mesmo comportamento já conhecido — aceitação
   publicada, o outro orçamento recusado automaticamente, a tela de orçamentos dá lugar à fase
   seguinte da corrida.

### 3. Cancelar sem orçamentos (US3, FR-008, FR-009, cenário 3)

1. Solicitar uma corrida e, com a lista ainda vazia, tocar "Cancelar". **Esperado**: o passageiro
   volta imediatamente ao mapa com o painel de solicitação.

### 4. Cancelar com orçamentos recebidos (US3, FR-010, SC-003)

1. Solicitar uma corrida, receber um ou mais orçamentos (repetir passos do cenário 2), e tocar
   "Cancelar". **Esperado**: o passageiro volta ao mapa; no(s) motorista(s) que enviaram
   orçamento, verificar que uma recusa foi recebida (mesmo efeito já observável quando um
   orçamento não escolhido é recusado ao aceitar outro).

### 5. Reinício do app durante "Aguardando orçamentos" (Edge Case, FR-012)

1. Solicitar uma corrida, receber ao menos um orçamento.
2. Encerrar o processo do app do passageiro (não só minimizar) e reabri-lo.
3. **Esperado**: a tela de orçamentos reaparece (não o mapa), com o(s) orçamento(s) recebido(s)
   antes do reinício já na lista — não uma lista vazia.

### 6. Nova solicitação depois de cancelar (Edge Case, SC-004)

1. Repetir o cenário 3 ou 4 até voltar ao mapa.
2. Escolher um destino e tocar "Solicitar corrida" novamente. **Esperado**: funciona normalmente,
   como uma solicitação nova, sem nenhum orçamento da solicitação cancelada aparecendo na nova
   tela de orçamentos.

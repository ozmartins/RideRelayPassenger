# Quickstart — Confirmar encontro com o motorista e chegada ao destino

Guia de validação manual desta feature, em `Prototipo/passenger/`. Pressupõe dois
aparelhos/emuladores Android com um relay em comum, e a feature `012-confirmar-encontro-destino`
do motorista já implementada (fecha o ciclo completo).

## Cenários de validação (referem os FR/SC de `spec.md`)

### 1. Confirmar o encontro (US1, SC-001, SC-002)

1. Com uma corrida já aceita pelo passageiro, aguardar o motorista publicar a chegada à origem
   (`kind: 20007`, feature 011 dele — ex.: aproximar o motorista do ponto de partida).
2. **Esperado**: no app do passageiro, uma modal aparece com uma mensagem informativa e o botão
   "Confirmo que encontrei o motorista".
3. Tocar o botão. **Esperado**: a modal fecha; inspecionar (via
   `dart run tool/verify_published.dart <pubkey>` ou equivalente) um evento `kind: 20008`
   publicado, referenciando o orçamento aceito e dirigido ao motorista.
4. No app do motorista, confirmar que o estado mudou para "Em corrida" (feature 012 dele).

### 2. Confirmar a chegada ao destino (US2, SC-003)

1. Depois do cenário 1, levar o GPS do passageiro até 1 km do destino pedido (emenda 24; antes, uma modal
   aparecia ao chegar o `kind: 20009` do motorista).
2. **Esperado**: no mapa do passageiro, aparece o botão "Confirmar chegada ao destino" acima de "Cancelar
   corrida"; afastando o GPS para além de 1 km, o botão some.
3. Tocar o botão. **Esperado**: abre a avaliação; inspecionar um evento `kind: 20010` publicado.
4. No app do motorista, confirmar que o estado voltou a "Aguardando solicitação de corrida".

### 3. Nunca mais de uma exibição por corrida (SC-004)

1. Repetir a publicação de `kind: 20007` (ou `20009`, conforme o cenário já alcançado) para a
   mesma corrida.
2. **Esperado**: nenhuma modal reaparece.

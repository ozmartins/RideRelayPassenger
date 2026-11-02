# Quickstart — Notificar que o motorista está a caminho

Guia de validação manual desta feature, em `Prototipo/passenger/`. Pressupõe dois
aparelhos/emuladores Android com um relay em comum: passageiro com um orçamento já aceito (feature
008), e motorista com aquele orçamento aceito, no estado "Deslocando-se até o passageiro" (feature
010 dele).

## Cenários de validação (referem os FR/SC de `spec.md`)

### 1. Primeira localização exibe a modal (US1, SC-001, SC-003)

1. No app do motorista, tocar "Iniciar corrida" (feature 010 dele) para a corrida aceita por este
   passageiro.
2. **Esperado**: no app do passageiro, em até poucos segundos, uma modal aparece com uma mensagem
   informando que o motorista começou a se deslocar e um botão "OK".
3. Repetir o cenário com um **segundo** motorista (que também enviou orçamento, mas não foi o
   aceito) iniciando uma corrida seguida por outro passageiro. **Esperado**: nenhuma modal aparece
   neste passageiro para a localização desse outro motorista.

### 2. Tocar "OK" fecha a modal, sem reabrir depois (US1, SC-002)

1. Com a modal do cenário 1 aberta, tocar "OK".
2. **Esperado**: a modal fecha.
3. No app do motorista, mover o aparelho/emulador o suficiente para publicar uma nova localização
   (feature 010 dele, a cada 50 m).
4. **Esperado**: nenhuma modal aparece de novo no passageiro.

### 3. Sobrevive a um reinício (Edge Cases)

1. Repetir o cenário 2 até o passo 2 (modal fechada).
2. Fechar completamente o app do passageiro e reabri-lo.
3. No app do motorista, publicar uma nova localização.
4. **Esperado**: nenhuma modal aparece — o registro de "já avisado" sobreviveu ao reinício.

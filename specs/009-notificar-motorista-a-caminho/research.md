# Research: Notificar que o motorista está a caminho

## D1 — Sinal de "início do deslocamento"

**Decisão**: reconhecer a primeira ocorrência de `kind: 20005` (Localização do motorista, emenda
08 do contrato) cujo `["e", ...]` referencia o `quoteId` da corrida aceita, como o sinal de que o
motorista começou a se deslocar.

**Justificativa**: o pedido original delimita a mudança só ao app do passageiro; o contrato não
define, e não é alterado por esta feature para definir, nenhum evento dedicado a esse instante — o
motorista só passa a publicar localização periodicamente a partir de quando confirma "Iniciar
corrida" (feature 010 dele). A primeira dessas publicações é, por construção, simultânea ao início
do deslocamento (a primeira posição publicada é sempre a posição do instante da confirmação, sem
limiar de distância — FR-009/D3 de `driver/specs/010-iniciar-corrida/research.md`), então é um
proxy fiel, não uma aproximação arriscada.

**Alternativas avaliadas**:
- **Pedir um novo evento dedicado do motorista** ("iniciei o deslocamento"): rejeitada — exigiria
  alterar o app do motorista, fora do escopo explicitamente declarado pelo pedido do usuário.
- **Qualquer `kind: 20005` recebido, não só o primeiro**: rejeitada — geraria uma modal a cada
  atualização de localização (a cada 50 m, D3 de `010-iniciar-corrida/research.md`), quando o
  pedido é claramente por um aviso único do início.

## D2 — Onde persistir a corrida aceita

**Decisão**: novo par domínio/serviço, `AcceptedRide` (`quoteId`, `driverPubkey`,
`movementNotified`) persistido por um novo `AcceptedRideStore`, sobre o `KeyValueStore` já
existente (mesmo mecanismo da lista de relays) — por analogia direta a `ActiveRide`/
`RideStateStore` do motorista (features 010/011).

**Justificativa**: o passageiro não tem, hoje, nenhum registro do orçamento aceito além de um
booleano em memória (`_corridaDecidida`, sem o `quoteId`) — perdido ao fechar o app e insuficiente
para correlacionar um `kind: 20005` recebido à corrida certa. `KeyValueStore` já é dependência do
projeto (relays) e já serve exatamente este tipo de dado pequeno e único por vez no motorista
(`RideStateStore`); estender o `sqflite` de `ReceivedQuoteStore` para isto misturaria um dado
singular ("qual é a corrida aceita agora") com uma tabela pensada para uma coleção (todos os
orçamentos recebidos de uma solicitação).

**Alternativas avaliadas**:
- **Adicionar uma coluna "aceito" à tabela `received_quotes`**: rejeitada — description do FR-006
  precisa também da chave do motorista já isolada (sem reconsultar a linha aceita a cada checagem)
  e do sinalizador `movementNotified`, dados que não descrevem o orçamento em si, mas a decisão
  tomada sobre ele; misturar as duas coisas na mesma tabela acopla dois ciclos de vida diferentes
  (o orçamento nunca muda depois de recebido; a decisão e a notificação mudam depois).
- **Manter só em memória**: rejeitada — descumpre FR-006/FR-007 (sobreviver a reinício), mesma
  classe de defeito que motivou a persistência equivalente no motorista (achado C1 do
  `/speckit-analyze` da feature 010 dele).

## D3 — Emenda ao contrato

**Decisão**: nenhum kind novo — `kind: 20005` já está definido (emenda 08). Uma emenda (10) só
registra, na tabela de "Histórico de emendas" e na seção *Conteúdo do kind 20005*, que o passageiro
passa a consumi-lo (feature 009 dele) e que sua inscrição passa a incluir esse kind.

**Justificativa**: mesmo padrão já usado quando o motorista passou a consumir `kind: 20003`
(emenda 08) — um kind já definido ganhando um novo consumidor ainda é uma mudança ao contrato
(a seção "Forma da inscrição" muda), só não introduz formato novo.

## D4 — Consumo do `content` do kind 20005

**Decisão**: esta feature não decodifica `content` (`{"lat":, "lon":}`) — só precisa do `kind` e da
tag `["e", ...]` para reconhecer o sinal (D1). Exibir a posição em si fica fora de escopo
(Assumptions do `spec.md`).

**Justificativa**: Princípio V — decodificar e guardar coordenadas que nada nesta feature usa seria
estrutura sem consumidor.

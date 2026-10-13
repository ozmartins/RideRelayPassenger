# Research: Confirmar encontro com o motorista e chegada ao destino

## D1 — Onde persistir "modal já exibida" para cada uma das duas confirmações

**Decisão**: `AcceptedRide` (feature 009) ganha `meetingConfirmed` e `destinationConfirmed`
(`bool`, falso por padrão), marcados como `true` no instante em que a modal correspondente abre —
não no toque do botão — e persistidos por `AcceptedRideStore`, já existente.

**Justificativa**: mesmo mecanismo exato de `movementNotified` (feature 009): `AcceptedRide` já é
o lugar natural para dado por-corrida do passageiro, e marcar no instante de abertura (não na
resposta) evita reabrir a modal a cada nova entrega do mesmo aviso, mesmo que o passageiro nunca
tenha tocado o botão — consequência aceita e registrada como limitação conhecida nos Edge Cases do
`spec.md` (sem mecanismo de reenvio manual neste protótipo).

**Alternativas avaliadas**:
- **Marcar só no toque do botão**: rejeitada — um aviso duplicado (reentrega por mais de um relay)
  chegando antes do toque reabriria a modal por cima da já aberta; a deduplicação por `id` do
  `EventFeed` não evita isso, porque dois eventos de avisos diferentes (não duplicados entre si)
  poderiam, em tese, chegar antes de qualquer resposta.
- **Nova entidade separada para o estado das confirmações**: rejeitada por proporcionalidade — são
  dois booleanos a mais no mesmo registro por-corrida que `AcceptedRide` já existe para guardar.

## D2 — Dois métodos de publicação novos em `EventFeed`

**Decisão**: `publishMeetingConfirmation(quoteId, driverPubkey, identity)` e
`publishDestinationConfirmation(quoteId, driverPubkey, identity)`, por analogia direta a
`publishQuoteAcceptance`/`publishQuoteRejection` — mesma assinatura, mesmo uso de `_publish` com
`extraTags: [["e", quoteId], ["p", driverPubkey]]` e `content: ''`.

**Justificativa**: os dois eventos (kinds 20008/20010) têm exatamente o mesmo formato de tags e
`content` vazio já usado por `publishQuoteAcceptance`/`publishQuoteRejection` — reaproveitar o
método privado `_publish` evita duplicar a lógica de assinatura/broadcast/espera de confirmação.

## D3 — Sem entidade de domínio nova para os avisos recebidos

**Decisão**: `MapScreen` reconhece `kind: 20007`/`20009` comparando diretamente
`evento.referencedEventId` (ou, para `kind: 20007`, o `authorPublicKey` do evento, já que ele não
carrega uma tag `e` — ver D4) com a corrida aceita, sem uma classe de domínio própria.

**Justificativa**: mesmo raciocínio da feature 012 do motorista (D3 do `research.md` dela) — a
`AcceptedRide` já existe no momento em que esses avisos chegam, e a correlação é só comparação de
`String`.

## D4 — Como correlacionar `kind: 20007`/`20009` à corrida aceita

**Decisão**: conferido em `driver/specs/002-nostr-relay-connection/contracts/nostr-events.md`,
seções *Conteúdo do kind 20007* e *20009* (emendas 09 e 11) — os dois carregam
`["e", "<id-do-orçamento>"]`, mesmo formato já usado pelo `kind: 20005` (feature 009). A
correlação usa `evento.referencedEventId == _corridaAceita?.quoteId`, idêntica à já usada para
`kind: 20005`.

**Alternativas avaliadas**: nenhuma — é leitura de um contrato já definido, não uma decisão de
design desta feature.

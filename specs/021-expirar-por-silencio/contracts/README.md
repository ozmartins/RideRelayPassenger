# Contrato — nenhuma alteração

Esta feature é puramente local ao passageiro: não define, não altera e não publica nenhum evento. Ela só
consome o `kind: 20005` ("Localização do motorista", emendas 08 e 12 do contrato único em
`specs/002-nostr-relay-connection/contracts/nostr-events.md`) como sinal de vida do motorista, com as
mesmas conferências de autor e de `["e", quoteId]` da feature 016. O passageiro já se inscreve em
`20005`; a inscrição não muda.

Princípio IV: nada a replicar no motorista, nenhuma emenda.

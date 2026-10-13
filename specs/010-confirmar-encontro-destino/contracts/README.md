# Contratos desta feature

Esta feature não define nem altera nenhum kind — os três eventos que usa (consome `kind: 20007` e
`20009`; publica `kind: 20008` e `20010`) já estão especificados pela emenda 11 do contrato único,
escrita pela feature `012-confirmar-encontro-destino` do motorista (commitada antes desta
implementação, conforme o Princípio IV).

Ver `../../../driver/specs/002-nostr-relay-connection/contracts/nostr-events.md`, seções
*Conteúdo do kind 20007* (emenda 09, consumido pela primeira vez aqui), *Conteúdo do kind 20008 —
Encontro confirmado*, *Conteúdo do kind 20009 — Chegada ao destino* e *Conteúdo do kind 20010 —
Destino confirmado* (emenda 11).

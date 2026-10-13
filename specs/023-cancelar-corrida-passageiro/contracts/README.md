# Contrato — emenda 19: `kind: 20013` "Corrida cancelada pelo passageiro"

Esta feature **não altera o contrato**: a emenda 19 já foi escrita nas duas cópias de
`specs/002-nostr-relay-connection/contracts/nostr-events.md` (commit `747f944`, 2026-10-07), antes do código
(Princípio IV). O passageiro só **publica** o kind; o consumo é da feature `020` do motorista.

O que o passageiro publica, segundo a seção *Conteúdo do kind 20013*:

- Efêmero; tags `["t", "tcc-ufsc-caronas"]`, `["e", "<id-do-orçamento-aceito>"]`, `["p", "<pubkey-do-motorista>"]`.
- `content` cifrado com NIP-44 ao motorista, texto de entrada `{}` (emenda 17).
- Uma única vez por corrida, em "orçamento aceito", "motorista a caminho" ou "em corrida".

Conferir ao fim: `diff <(tail -n +12 specs/002-nostr-relay-connection/contracts/nostr-events.md)
../driver/specs/002-nostr-relay-connection/contracts/nostr-events.md` não deve imprimir nada.

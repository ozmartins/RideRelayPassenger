# Contrato — emenda 17 (`content` cifrado, NIP-44)

O formato **não é definido aqui**: é a emenda 17 de
`Prototipo/driver/specs/019-mensagens-cifradas/contracts/README.md`, escrita nas duas cópias do contrato
pelas tarefas de gate da feature do motorista (T003/T004) — Princípio IV.

Nesta feature, **verificar** na cópia do passageiro
(`specs/002-nostr-relay-connection/contracts/nostr-events.md`):

- linha 17 no *Histórico de emendas* e cabeçalho de procedência atualizado (2026-10-06, "emenda 17,
  feature 019 do motorista, replicada pela feature 022 do passageiro");
- seção *Cifragem do `content`*, regra de recepção 7, coluna "Proteção" na tabela de kinds, tag `p` no
  `20002`, notas de privacidade `20002`–`20012` "cifrado ao destinatário", `20001` como exceção;
- `diff` com a cópia do motorista, menos o cabeçalho: vazio.

Se o código do passageiro divergir do texto, corrige-se o texto **nas duas** cópias.

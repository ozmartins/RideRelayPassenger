# Research — Mensagens cifradas entre as apps (passageiro)

As decisões D1, D2, D4, D5 (verificação), D6 (medição), D7 (constituição) e D8 (metadados) são as de
`Prototipo/driver/specs/019-mensagens-cifradas/research.md`; aqui só o que é específico do passageiro.

## D1 — Dependência (Princípio III)

**Decision**: igual à do motorista — implementar NIP-44 v2 no app sobre `pointycastle` e `crypto`,
promovidos de transitivos a diretos em `pubspec.yaml`. Verificado de novo no passageiro: `dart_nostr
10.0.1` não tem NIP-44 e o pacote `nostr` 2.x não resolve junto dele (`pointycastle ^3` × `^4`).

**Rationale**: mesma do motorista; cópia do algoritmo é inevitável (apps independentes, sem pacote
compartilhado).

**Alternatives**: as do motorista; mais: pacote local compartilhado em `Prototipo/` — rejeitado: as
apps são projetos independentes e a constituição quer o contrato, não o código, como ponto de contato.

## D2 — Cifra duplicada entre as apps

**Decision**: `lib/services/nip44.dart` do passageiro é cópia do do motorista com imports
`package:passenger/...`; os vetores oficiais são os mesmos arquivos. Um defeito corrigido numa cópia
MUST ser conferido na outra (nota repetida no `CLAUDE.md`).

**Rationale**: custo de ~150 linhas duplicadas contra o de um pacote interno que ninguém pediu.

## D3 — Onde decifrar e o que persistir

**Decision**: decifrar em `MapScreen`, na entrada de cada tratador (`_processarOrcamento…`,
`_processarLocalizacao…`, e os de chegada, rota, cancelamento, indisponível), por
`EventFeed.decrypted(evento, identity, {emptyMarker})`, que antes confere a tag `p` (no passageiro o `MapScreen` não recebe `IdentityService`; o `EventFeed` já tem o `MessageCipher` — decisão da implementação, no lugar do `IdentityService.decryptContent` do motorista). O texto decifrado substitui
`evento.content` ao construir `ReceivedQuote`/`DriverLocation`/`RideRoute` (cada `fromNostrEvent` passa a
receber o texto decifrado ou um evento com `content` já decifrado). `SqfliteReceivedQuoteStore` continua
gravando campos decodificados.

**Rationale**: `EventFeed.start()` não tem identidade no recebimento e é compartilhado com `kind: 1`/`20001`;
decifrar no consumo preserva o Princípio I e a ordem do FR-005. Persistir campos decodificados evita
migração e mantém os orçamentos antigos válidos.

**Alternatives**: decifrar no `EventFeed` com decifrador injetado — rejeitado (superfície do segredo);
persistir o `content` cifrado — rejeitado (obrigaria decifrar a cada leitura).

## D4 — Publicar cifrado sem tela nova

**Decision**: `EventFeed._publish` ganha `recipientPubkey` opcional; quando presente, cifra
(`MessageCipher.encryptFor`, vazio → `{}`) antes de `fromPartialData`; se a cifragem lançar, devolve
`PublishReport(byRelay: {})`, que `anyAccepted` lê como falso — o chamador já mostra a mensagem de
"nenhum relay aceitou". `publishRideRequest` não passa destinatário (exceção). O destinatário é o `p`
já passado em `extraTags` (um só ponto de verdade): `recipientPubkey` é derivado dele nos quatro
publicadores.

**Rationale**: reaproveita o caminho de falha existente (FR-004) sem estado novo.

## D5 — Relógio de silêncio e "a caminho" só com decifração (FR-007)

**Decision**: em `MapScreen`, o tratador de `20005` decifra **antes** de rearmar o relógio da 021 e de
disparar "motorista a caminho" (016/014); `20005` que não decifra não faz nenhum dos dois. `content`
decifrado inválido continua rearmando, como a 021 já define para `content` inválido.

**Rationale**: um evento que o passageiro não consegue ler não é uma mensagem do motorista para ele;
usá-lo como sinal de vida deixaria o relógio ser mantido por lixo assinado com a chave certa (ex.:
reexibição de evento antigo). Mantém a garantia da 016 (o gatilho depende de autenticidade).

**Alternatives**: rearmar mesmo sem decifrar — rejeitado: o sinal passaria a depender só de assinatura
+ tag pública.

## D6 — Medição

**Decision**: a sonda `tool/probe_cipher_size.dart` do motorista mede tempo e tamanho; no passageiro,
medir no emulador o custo do primeiro ECDH e de decifrar uma `20005` e uma `20011` de 1000 pontos,
registrar aqui na implementação. Se o primeiro ECDH passar de ~100 ms, `Isolate`.

**Referência (2026-10-06):** a cifra é a mesma do motorista; a sonda dele
(`driver/tool/probe_cipher_size.dart`, VM do computador) deu primeiro ECDH ≈ 5 ms, decifrar uma `20005`
≈ 0,06 ms e decifrar a rota de 1000 pontos ≈ 1,9 ms — ver `D6` do motorista. **A medição do SC-004 no
emulador/aparelho do passageiro continua pendente** (precisa de execução no app em modo release).

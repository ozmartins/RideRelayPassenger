# Phase 0 — Research: Integridade das avaliações (Row Signing)

## D1 — Assinatura: reaproveitar `Nostr.instance.services.keys.sign`/`.verify` (atende FR-002/
FR-003; nenhuma dependência nova ao `pubspec.yaml`)

**Decision**: usar `Nostr.instance.services.keys.sign(privateKey: ..., message: ...)` e
`.verify(publicKey: ..., message: ..., signature: ...)`, do `dart_nostr` (já dependência do
projeto desde a feature 002) — a mesma identidade Nostr do usuário assina e valida as linhas de
`ride_ratings`, sem chave nova.

**Contexto da decisão**: o pedido do usuário descreve o mecanismo em três passos — canonicalizar,
gerar hash SHA-256, assinar o hash com a chave privada. Inspecionando `dart_nostr` (`nostr/instance
/keys/keys.dart`), o método `NostrKeys.sign` já faz exatamente isso internamente: recebe uma
`message` (string), calcula `NostrCryptoUtils.sha256Hash(message)` e assina o hash resultante com
`NostrKeyPairs.sign` (Schnorr sobre secp256k1, o mesmo esquema usado para assinar eventos Nostr);
`NostrKeys.verify` faz o inverso. Isso significa que os três passos pedidos pelo usuário
(canonicalizar → hash SHA-256 → assinar) mapeiam diretamente para "canonicalizar → chamar
`sign(message: canonicalizado)`" — o hashing SHA-256 acontece dentro da chamada, não como um passo
manual separado. Documentado aqui para que a correspondência com o pedido original fique
explícita, já que não aparece como código de hashing visível em `ride_rating_signature.dart`.

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| `Nostr.instance.services.keys.sign`/`.verify` (escolhida) | Já expõe exatamente o par SHA-256 + assinatura Schnorr pedido, sobre a mesma identidade já usada para tudo mais no app; nenhuma dependência nova, nenhum código de hashing manual a escrever ou testar. |
| `NostrKeyPairs.sign(hash)`/`NostrKeyPairs.verify(pubkey, hash, sig)` diretamente (API de baixo nível, usada por `NostrEventVerifier` para o `id` do evento) | Rejeitada: essa API espera um hash **já calculado** como `message` (é o que `NostrEvent.getEventId` devolve) — usá-la exigiria calcular o SHA-256 manualmente antes de chamar, código redundante com o que `NostrKeys.sign` já faz internamente, sem nenhum ganho. |
| Pacote de criptografia dedicado (ex.: `crypto` para SHA-256 + `pointycastle`/`elliptic` para assinar) | Rejeitada: dependência nova sem necessidade — o par sign/verify de alto nível do `dart_nostr` já resolve o problema exatamente como pedido, e introduzir uma segunda biblioteca de criptografia no projeto para o mesmo tipo de operação violaria o Princípio V (uma solução onde já existe uma). |

### Riscos assumidos e mitigação

- A assinatura resultante depende da identidade atual do usuário (`Identity.privateKey`/
  `publicKey`); se o usuário perder ou trocar de identidade, avaliações antigas deixam de validar
  — comportamento aceito e documentado no Edge Case do `spec.md` (mesma regra de qualquer
  violação, sem tratamento especial).

## D2 — Canonicalização: concatenação de campos em ordem fixa, com separador dedicado (atende
FR-001)

**Decision**: `canonicalPayload(rating) = '${rating.rideId}|${rating.stars}|
${rating.ratedAt.toIso8601String()}'` — os três campos de dado de `RideRating`, sempre nesta
ordem, unidos por `|`.

**Contexto da decisão**: o pedido do usuário pede concatenação "de forma estrita". Os três campos
têm formato controlado e não podem conter `|`: `rideId` é um `id` de evento Nostr (64 caracteres
hexadecimais), `stars` é um inteiro convertido para string (`toString()`), `ratedAt` é uma data
serializada em ISO-8601 (dígitos, `-`, `:`, `.`, `T`). Um separador que não ocorre em nenhum dos
três evita a ambiguidade citada no Edge Case do `spec.md` (dois valores diferentes nunca produzem
o mesmo payload concatenado).

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| Concatenação com separador dedicado, ordem fixa (escolhida) | Atende literalmente ao pedido ("concatenar de forma estrita"); simples de auditar e testar; segura para os tipos de campo específicos desta entidade (não é uma solução genérica para qualquer entidade futura — ver risco abaixo). |
| JSON canônico (`jsonEncode` de um mapa com chaves em ordem fixa) | Rejeitada: mais estrutura do que o pedido pede, e o pedido explicitamente descreve concatenação, não serialização estruturada — introduziria uma dependência implícita da ordem de iteração de um `Map`, menos direta de auditar que uma concatenação literal. |
| Concatenação sem separador (`'$rideId$stars$ratedAt'`) | Rejeitada: viola a própria exigência de "forma estrita" — sem separador, dois conjuntos de valores diferentes podem colidir na mesma string concatenada em teoria (ex.: um valor terminando em dígito seguido de outro começando em dígito é ambíguo na borda) — exatamente o Edge Case citado no `spec.md`. |

### Riscos assumidos e mitigação

- Esta canonicalização é específica dos três campos de `RideRating`, com tipos que não podem
  conter `|` — não é uma função genérica seguro para qualquer entidade futura. Se outra tabela
  adotar Row Signing depois, a canonicalização dela precisa ser revisada campo a campo (mesmo
  cuidado, não reaproveito cego desta função) — nenhuma abstração genérica introduzida agora,
  porque não há um segundo consumidor real hoje (Princípio V).

## D3 — Estratégia de teste: lógica de decisão em funções puras, mecânica SQL sem teste de
integração real (atende ao Princípio II sem contradizer o D1 de `specs/011-avaliar-corrida/
research.md`)

**Decision**: `RideRatingSignature` (canonicalização, assinatura, verificação) é um conjunto de
funções puras, sem `sqflite`, testadas diretamente com casos válido e inválido. O contrato de
`RideRatingStore` (persistir assinatura; validar, marcar e excluir na leitura) é testado contra um
dublê em memória que usa as mesmas funções puras. `SqfliteRideRatingStore` continua sem teste de
integração SQLite real — a mecânica de ler/escrever uma coluna é a mesma categoria de código já
aceita sem teste direto (`SqfliteReceivedQuoteStore`, D1 de `specs/011-avaliar-corrida/
research.md`), mas agora a decisão de segurança em si (válido/inválido) fica isolada em código
testável sem SQLite.

**Contexto da decisão**: o Princípio II da constituição é não negociável para código que assina
ou verifica assinaturas — exige teste cobrindo o caso válido e o inválido, sem rede nem relay real.
Separar a decisão criptográfica (pura, testável) da persistência (SQL, já confiada por analogia às
demais stores do projeto) cumpre a letra do princípio sem duplicar SQLite real em teste, que nunca
foi feito em nenhuma outra feature deste protótipo.

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| Funções puras testadas + dublê em memória do contrato da store (escolhida) | Cumpre o Princípio II diretamente; mantém a consistência com a ausência de teste de integração SQLite já estabelecida no projeto. |
| `sqflite_common_ffi` + teste de integração real de `SqfliteRideRatingStore` | Rejeitada pela mesma razão já registrada em `specs/011-avaliar-corrida/research.md` (D1): nenhuma outra feature do protótipo paga esse custo, e adicionar a dependência só para esta feature violaria os Princípios III e V. |
| Testar só via `MapScreen` (widget test) | Rejeitada: `MapScreen` só chama `save`, nunca `forRide` (leitura fora do escopo de UI, FR-010) — não haveria como exercitar a validação/exclusão na leitura por esse caminho. |

### Riscos assumidos e mitigação

- A mecânica SQL de `SqfliteRideRatingStore` (ler a coluna `signature`/`tampered`, gravar o
  `UPDATE` de violação) fica sem verificação automatizada direta — mesmo risco já aceito para
  todas as demais stores SQLite do protótipo, mitigado pela simplicidade do código (poucas linhas,
  sem lógica condicional além do já coberto pelas funções puras).

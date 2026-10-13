# Data Model — Mensagens cifradas entre as apps (passageiro)

Nenhuma entidade persistida nova, nenhuma migração, nenhum campo novo em `AcceptedRide` nem em
`ReceivedQuote`. Formato e tabela de kinds: `Prototipo/driver/specs/019-mensagens-cifradas/data-model.md`.

## Do lado do passageiro

| Kind | Direção | Passageiro | Chave usada |
|---|---|---|---|
| `20001` | publica | **claro, só assinado — exceção** | — |
| `20002` | recebe | `p` == passageiro; decifra → JSON do orçamento → `ReceivedQuote` | pública do autor (motorista) |
| `20003` | publica | cifra `{}` | pública do motorista do orçamento |
| `20004` | publica | cifra `{}` (um por motorista recusado, cada um a si) | pública do respectivo motorista |
| `20005` | recebe | decifra → `{"lat","lon"}` → `DriverLocation` | pública do autor |
| `20006` | recebe | decifra → exatamente `{}` | idem |
| `20007` | recebe | decifra → exatamente `{}` | idem |
| `20008` | publica | cifra `{}` | pública do motorista |
| `20009` | recebe | decifra → exatamente `{}` | autor |
| `20010` | publica | cifra `{}` | pública do motorista |
| `20011` | recebe | decifra → `{"points":…}` → `RideRoute` | autor |
| `20012` | recebe | decifra → exatamente `{}` | autor |

## Serviços

- `Nip44` / `MessageCipher`: iguais, em contrato, aos do motorista (`conversationKey`, `encrypt`,
  `decrypt`, cache em memória, `{}` para vazio, `null` em qualquer falha de decifração).
- `EventFeed.decrypted(NostrEvent, Identity, {bool emptyMarker})` → `NostrEvent?` (cópia com o texto
  decifrado, via `NostrEvent.withContent`): confere a tag `p` == `identity.publicKey`, decifra com a
  pública do autor; nunca lança, nunca loga.
- `EventFeed._publish({..., String? recipientPubkey})`: cifra antes de assinar; falha → relatório vazio.

## Regras de recepção (por tratador do `MapScreen`)

Verificação de assinatura, marcador e dedupe (`EventFeed`) → `p` == passageiro → decifração →
confere autor/`["e", quoteId]`/estado, como hoje → efeito. Falha em qualquer passo da decifração:
descarte silencioso, e (no `20005`) sem tocar o relógio de silêncio (FR-007).

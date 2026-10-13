# Phase 1 — Data Model: Receber, persistir e decidir entre orçamentos

## `ReceivedQuote` (novo, `lib/domain/received_quote.dart`)

| Campo | Tipo | Observação |
|---|---|---|
| `quoteId` | `String` | O `id` do evento `kind: 20002` — chave primária na persistência. |
| `requestId` | `String` | Extraído da tag `["e", ...]` do evento — a solicitação respondida. |
| `driverPubkey` | `String` | `event.authorPublicKey` — destinatário da aceitação/recusa (tag `["p", ...]`). |
| `driverName`, `carBrand`, `carModel` | `String` | Do `content` (emenda 06). |
| `carYear` | `int` | Do `content`. |
| `pricePerKm`, `total` | `double` | Do `content`. |
| `etaMinutes` | `int?` | Do `content` — `null` quando a chave não está presente (emenda 06, D2 de `specs/009-detalhes-do-orcamento/research.md`, do motorista). |

**Criação**: `ReceivedQuote.fromNostrEvent(NostrEvent event)` — decodifica `content` e extrai a
tag `e`; lança `FormatException` se `content` malformado ou a tag `e` estiver ausente (mesma
postura de `RideRequestReceived.fromNostrEvent` no motorista: conteúdo malformado é descartado,
nunca processado).

## `NostrEvent` (existente) — ganha `tags`

| Campo novo | Tipo | Observação |
|---|---|---|
| `tags` | `List<List<String>>` | Necessário para `ReceivedQuote` extrair a referência `["e", ...]`; antes desta feature, nenhum consumidor de `NostrEvent` no passageiro precisava de tags. |

## Esquema SQLite — `received_quotes` (novo)

Ver D2 de `research.md` para o `CREATE TABLE` completo.

## Estado de solicitação ativa e orçamentos (em `MapScreen`, sem entidade de domínio própria — D3
de `research.md`)

- `String? _solicitacaoAtivaId`: `eventId` da última solicitação publicada com sucesso.
- `ValueNotifier<List<ReceivedQuote>> _orcamentosRecebidos`: orçamentos da solicitação ativa,
  reiniciado (lista vazia) a cada nova solicitação publicada.
- `bool _corridaDecidida`: verdadeiro depois de uma aceitação confirmada — impede a modal reabrir
  ou gerar nova recusa automática para orçamentos que cheguem depois (FR-012).

# Modelo de dados: 027-recibos-de-reputacao

Nomes e campos idênticos aos do app do motorista (`lib/domain/`). `fromJson` estrito: lança `FormatException`
em qualquer campo ausente, de tipo errado ou fora de faixa (quem chama descarta e conta).

## Domínio

### `Receipt` (`receipt.dart`)
| Campo | Tipo | Regra |
|---|---|---|
| `v` | int | `1` |
| `guidCorrida` | String hex(64) | `id` do `20002` aceito |
| `pubkeyAvaliador` / `pubkeyAvaliado` | String hex(64) | distintos |
| `nota` | int? | 1–5; ausente = só corrida |
| `criadoEm` | int | epoch s, informativo |
| `seq` | int ≥ 0 | posição na cadeia do avaliado |
| `hashAnterior` | String? hex(64) | omitido se `seq = 0` |
| `idRecibo` | String hex(64) | SHA-256 de `canonical` |
| `assinatura` | String hex(128) | Schnorr do avaliador sobre `idRecibo` |

Métodos: `canonical` (`tcc-recibo-v1|…`), `computeId()`, `toJson()`/`fromJson()` (chaves em português do
contrato: `guid_corrida`, `pubkey_avaliador`, …; chaves opcionais omitidas, nunca `null`).

### `Reputation` (`reputation.dart`)
`corridas`, `avaliacoes`, `media?` (omitida se `avaliacoes = 0`), `seqProximo`, `head?` (omitido se
`seqProximo = 0`), `recibos` (≤ `kReputacaoJanela = 5`, mais novo primeiro) e `ilegiveis` (só na leitura, não
serializado: recibos ilegíveis ou além da janela). Resumo estrito; recibo ruim é descartado e contado (D9).

### `ReputationView` (`reputation_view.dart`)
Saída de `ReputationVerifier.verify`: `verifiedCount`, `verifiedRatings`, `verifiedAverage?`, `invalidDiscarded`,
`gaps` (recibos não apresentados), `inconsistent` e `declared` (`Reputation`); `hasHistory` derivado.
Nunca funde verificado e declarado.

## Persistência (`receipts.db`, v1)

| Tabela | Colunas | Observações |
|---|---|---|
| `recibos_recebidos` | `guid_corrida` PK, `id_recibo` UNIQUE, `seq`, `avaliador`, `nota`, `json` | imutável; id e assinatura revalidados ao ler |
| `recibos_emitidos` | `guid_corrida` PK, `id_recibo`, `avaliado`, `json`, `pendente` (0/1) | `pendente = 1` antes de publicar |
| `reputacao_declarada` | `quote_id` PK, `avaliado`, `json` | reputação do motorista no orçamento aceito |

`ReceiptStore`: `saveReceived`, `receivedFor`, `myReputation`, `saveIssued`, `pendingIssued`, `markAcked`,
`saveDeclared`, `declaredFor`. `myReputation()` recalcula `corridas/avaliacoes/media/seqProximo/head` dos recibos
recebidos que ainda conferem e devolve `Reputation.empty()` (`isEmpty`) se não houver nenhum (⇒ `20001` sem a chave).
Além dos métodos do app do motorista, `issuedFor(guid)`. `saveReceived` devolve `bool` (falso se a corrida já tem recibo).

## Estados do recibo emitido
`(não existe) → pendente=1 (gravado) → publicado (pendente=1, reenviando) → confirmado (pendente=0, ao chegar 20015 com o id_recibo)`.
Corrida cancelada ou reputação inconsistente: nunca sai de "não existe".

## Alterações em tipos existentes
- `ReceivedQuote`: `Reputation? reputation` (opcional; `reputacao` malformada ⇒ `null`, orçamento válido); persistida em
  `received_quotes.reputation_json` (banco v2, D3).
- `EventFeed`: constantes `receiptKind = 20014`, `receiptAckKind = 20015`; `publishRideRequest(..., {Reputation?})`.
- `passengerConsumedKinds` ganha `20014`, `20015`.

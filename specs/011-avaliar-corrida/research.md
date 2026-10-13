# Phase 0 — Research: Avaliar corrida (passageiro)

## D1 — Persistência: reaproveitar `sqflite`, banco próprio (atende FR-004/FR-005; nenhuma
dependência nova ao `pubspec.yaml`)

**Decision**: nova tabela `ride_ratings`, em um banco SQLite próprio (`ride_ratings.db`), usando
`sqflite` — mesma biblioteca já registrada pela feature `008-receber-orcamentos` (D1 daquele
`research.md`), sem nova entrada ao `pubspec.yaml` e sem novo tipo de terceiros exposto fora de
`lib/services/`.

**Contexto da decisão**: a avaliação é um dado local, estruturado (uma nota inteira por corrida,
correlacionada por `rideId`), o mesmo formato de problema já resolvido por
`SqfliteReceivedQuoteStore`. Um banco separado (em vez de uma tabela a mais em
`received_quotes.db`) mantém cada `Store` dona de um único banco, mesmo padrão de isolamento já
usado no projeto (nenhum dos stores existentes compartilha arquivo `.db`).

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| `sqflite`, tabela em banco próprio (escolhida) | Reaproveita a biblioteca e o padrão de implementação (`Store` abstrata + implementação `Sqflite*`) já validados por `received_quote_store.dart`; nenhuma dependência nova. |
| `sqflite`, tabela dentro de `received_quotes.db` | Rejeitada: misturaria a responsabilidade de dois stores no mesmo arquivo de banco sem nenhum ganho — nenhuma consulta desta feature precisa fazer join com orçamentos recebidos. |
| `shared_preferences` (chave-valor) | Rejeitada: exigiria serializar/filtrar manualmente uma lista crescente de avaliações a cada leitura por `rideId`, o mesmo raciocínio já descartado pelo D1 da feature 008 para os orçamentos. |
| Manter só em memória, sem persistir | Rejeitada: contraria FR-004 (persistência local explícita) e a redação literal do pedido do usuário ("fica salva no banco de dados"). |

### Riscos assumidos e mitigação

- Nenhum risco novo — mesmo padrão de uso já validado pela feature 008.

## D2 — Esquema: uma tabela plana, `ride_id` como chave primária (atende FR-004/FR-006)

**Decision**: tabela `ride_ratings`, com `ride_id` (o `AcceptedRide.quoteId` da corrida avaliada)
como chave primária — garante por construção, via `INSERT`/`ConflictAlgorithm.abort` (ou
verificação prévia), que uma corrida não é avaliada duas vezes (FR-006), sem precisar de um índice
separado.

```sql
CREATE TABLE ride_ratings (
  ride_id   TEXT PRIMARY KEY,
  stars     INTEGER NOT NULL CHECK (stars BETWEEN 1 AND 5),
  rated_at  TEXT NOT NULL
);
```

`rated_at` como texto ISO-8601 (`DateTime.toIso8601String()`), mesmo formato já usado nos demais
carimbos de tempo do projeto (nenhuma coluna `INTEGER`/Unix timestamp em uso hoje).

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| `ride_id` como chave primária (escolhida) | Uma avaliação por corrida é a própria regra de negócio (FR-006); a chave primária torna isso uma restrição de esquema, não só de código de aplicação. |
| `id` autoincremento + índice único em `ride_id` | Rejeitada por V (simplicidade): mesmo efeito prático, uma coluna e um índice a mais sem consumidor — nenhuma consulta desta feature precisa de um identificador de linha independente da corrida. |

### Riscos assumidos e mitigação

- Nenhum risco novo.

## D3 — Disparo da tela: estado em memória, sem sinalizador persistido de "já visto"

**Decision**: a tela de avaliação é aberta uma única vez, no mesmo `setState` que fecha a modal de
chegada ao destino ao final de `_confirmarDestino` (feature 010) — sem adicionar nenhum campo novo
a `AcceptedRide`/`AcceptedRideStore`.

**Contexto da decisão**: a Clarification de 2026-09-22 resolveu que, se o app fechar antes da
avaliação (ou de pulá-la), a oportunidade se perde — a tela não reaparece numa reabertura do app.
Isso elimina a necessidade do padrão até então repetido nas features 009/010
(`movementNotified`/`meetingConfirmed`/`destinationConfirmed`, um booleano persistido para nunca
reexibir uma modal): aqui, o próprio fato de `_confirmarDestino` só ser bem-sucedido uma vez por
corrida (guarda já existente, `if (corridaAceita.destinationConfirmed) return;` antes da chamada)
é suficiente para garantir no máximo uma exibição por corrida dentro da mesma sessão do app.

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| Estado em memória, sem persistência de "já visto" (escolhida) | Mais simples (Princípio V) e é exatamente o que a resposta da Clarification pede — qualquer persistência aqui seria estrutura sem requisito. |
| Sinalizador `ratingShown` persistido em `AcceptedRide`, mesmo padrão das features 009/010 | Rejeitada: resolveria um requisito que a Clarification explicitamente descartou (reexibir após reabrir o app). Reintroduzir o padrão sem esse requisito violaria o Princípio V. |
| Consultar `RideRatingStore` na inicialização da tela para decidir se reabre | Rejeitada pelo mesmo motivo — serviria só para *impedir* uma reexibição que, pela decisão tomada, já não deveria ocorrer de forma alguma (o processo não sobrevive o suficiente para reexibir a modal de chegada ao destino também, já que ela segue a mesma premissa). |

### Riscos assumidos e mitigação

- Se o processo do app for encerrado entre a persistência da confirmação de destino
  (`kind: 20010`, já publicado com sucesso antes da tela abrir) e a interação do usuário com a
  tela de avaliação, a corrida fica sem nota — comportamento intencional (FR-009, resposta da
  Clarification), não um defeito a mitigar.

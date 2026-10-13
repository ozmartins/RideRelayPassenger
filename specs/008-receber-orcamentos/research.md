# Phase 0 — Research: Receber, persistir e decidir entre orçamentos

## D1 — Persistência: `sqflite` (atende FR-002; exceção de armazenamento local, sem exceção de
segurança envolvida)

**Decision**: adotar `sqflite` (mesma versão usada pelo motorista, `^2.4.4`) como dependência
direta do passageiro, confinada a `lib/services/received_quote_store.dart`.

**Contexto da decisão**: decisão da conversa que originou esta feature — persistência em disco,
sobrevivendo a reiniciar o app. O passageiro hoje só tem armazenamento chave-valor
(`shared_preferences`, para nome/relays); orçamentos recebidos têm estrutura relacional simples
(vários por solicitação), o mesmo problema que `sqflite` já resolve para o cadastro do motorista.

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| `sqflite` (escolhida) | Já avaliada e em uso no motorista desde a feature 003 dele; reaproveitar a mesma biblioteca (ainda que sem compartilhar código) evita duas soluções diferentes para o mesmo problema dentro do protótipo. |
| `shared_preferences` com JSON serializado numa lista | Funcionaria para volume pequeno, mas exigiria reimplementar manualmente consultas por `requestId` (filtrar a lista toda na leitura) — sqflite já oferece isso com uma query indexada, sem código extra relevante. |
| Manter só em memória (sem persistir) | Rejeitada explicitamente: a decisão do usuário foi persistência que sobrevive a reiniciar o app, não em memória durante a sessão. |

### Riscos assumidos e mitigação

- Nenhum risco novo — mesmo padrão de uso já validado pelo motorista.

## D2 — Esquema: uma tabela, sem chave estrangeira para a solicitação (atende FR-002)

**Decision**: tabela `received_quotes` com colunas planas (sem tabela separada para solicitações,
que o passageiro não persiste) — `id` do orçamento como chave primária, `request_id` indexado para
a consulta por solicitação.

```sql
CREATE TABLE received_quotes (
  id             TEXT PRIMARY KEY,
  request_id     TEXT NOT NULL,
  driver_pubkey  TEXT NOT NULL,
  driver_name    TEXT NOT NULL,
  car_brand      TEXT NOT NULL,
  car_model      TEXT NOT NULL,
  car_year       INTEGER NOT NULL,
  price_per_km   REAL NOT NULL,
  total          REAL NOT NULL,
  eta_minutes    INTEGER
);
CREATE INDEX idx_received_quotes_request_id ON received_quotes (request_id);
```

**Contexto da decisão**: o passageiro não persiste a própria solicitação (Assumptions do
`spec.md`: só a última, em memória) — não há necessidade de uma tabela `requests` para uma
referência que nunca é consultada de volta.

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| Tabela única plana (escolhida) | Suficiente: a única consulta necessária é "todos os orçamentos de um `request_id`", que o índice já resolve. |
| Tabela normalizada com `requests` | Desproporcional (Princípio V): exigiria persistir também a solicitação, que esta feature não precisa reler. |

## D3 — Lista observável simples para a modal (atende FR-004, US1)

**Decision**: `MapScreen` mantém um `ValueNotifier<List<ReceivedQuote>>` para os orçamentos da
solicitação ativa; a modal recebe esse `ValueNotifier` e se reconstrói via `ValueListenableBuilder`
a cada novo orçamento — sem precisar que `showDialog` seja chamado de novo.

**Contexto da decisão**: `showDialog` não reconstrói seu conteúdo automaticamente quando o widget
que o abriu recebe um novo `setState` — o conteúdo da modal precisa observar sua própria fonte de
dados diretamente.

**Atualização (implementação)**: a modal terminou renderizada diretamente na árvore de
`MapScreen` (um `Stack` condicional no `build()`), não via `showDialog` — ver o desvio registrado
em T019 de `tasks.md`. O `ValueNotifier`/`ValueListenableBuilder` continuam exatamente como
decidido aqui; só o mecanismo de exibição (`Navigator` vs. `Stack` condicional) mudou, pelo motivo
descrito lá, não relacionado a este `D3`.

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| `ValueNotifier` + `ValueListenableBuilder` (escolhida) | Padrão nativo do Flutter para exatamente este problema, sem dependência nova. |
| Fechar e reabrir a modal a cada orçamento novo | Rejeitada: pisca a UI e perde qualquer estado de rolagem/foco a cada chegada — pior experiência sem necessidade. |

## D4 — Sem deduplicação por motorista (atende Edge Cases do `spec.md`)

**Decision**: dois orçamentos do mesmo motorista para a mesma solicitação aparecem como duas
entradas distintas na lista — nenhuma lógica de "manter só o mais recente por motorista".

**Contexto da decisão**: o contrato não impede um motorista de enviar mais de um orçamento
(reconsiderar o preço, por exemplo), e o `id` do evento já garante que cada orçamento é uma
entidade distinta. Resolver isso agora seria uma regra de negócio não pedida.

### Riscos assumidos e mitigação

- Risco de lista visualmente redundante se um motorista reenviar por engano: aceito como
  comportamento correto, não um defeito — o passageiro vê os dois e decide.

# Phase 0 — Research: Tela de orçamentos recebidos e cancelamento da solicitação

## D1 — Tela dedicada como retorno antecipado do `build()`, sem dim/overlay (atende FR-003, FR-007)

**Decision**: `ReceivedQuotesScreen` é retornada diretamente por `MapScreen.build()` quando
`_rideStatus == PassengerRideStatus.aguardandoOrcamentos`, antes de montar o `scaffold` do mapa —
diferente do padrão `Stack` + `Positioned.fill` com fundo escurecido usado pelas demais "modais"
do app (`RideQuotesModal` antiga, `DriverMovingModal`, etc.).

**Contexto da decisão**: o pedido do usuário distingue explicitamente "tela" de "modal" — a modal
antiga aparecia por cima do mapa, semitransparente; a nova tela deve substituir a visão do mapa por
completo enquanto a solicitação está em aberto, não apenas sobrepor um cartão a ela.

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| Retorno antecipado do `build()` (escolhida) | Reflete literalmente "tela" em vez de "modal"; mais simples que introduzir `Navigator`, que o projeto já evita para conteúdo dinâmico por HTTP real + relógio falso em teste (T019 de `specs/008-receber-orcamentos/tasks.md`). |
| Mesmo padrão `Stack`/`Positioned.fill` das demais modais | Rejeitada: continuaria parecendo uma modal sobre o mapa, contrariando a distinção que o próprio pedido faz entre "tela" e "modal". |
| `Navigator.push` de uma rota própria | Rejeitada pelo mesmo motivo já registrado na feature 008 (T019): a entrega de eventos via `StreamController` em cadeia, com o `FlutterMap` buscando tiles por HTTP real, não deixa uma rota `push`ada terminar de construir dentro do relógio falso do `flutter_test`. |

### Riscos assumidos e mitigação

- Nenhum risco novo — mesma técnica de renderização condicional já usada em todo o arquivo, só sem
  o `Stack` de dim.

## D2 — Recusa ao cancelar reaproveita `publishQuoteRejection`/`kind: 20004` (atende FR-010)

**Decision**: `_cancelarSolicitacao` chama `widget.eventFeed.publishQuoteRejection(quote,
widget.identity)` para cada `ReceivedQuote` presente em `_orcamentosRecebidos.value` no momento do
cancelamento — mesma chamada já usada em `_aceitarOrcamento` para recusar os orçamentos não
escolhidos.

**Contexto da decisão**: a Assumption do `spec.md` já resolve isso — nenhuma mensagem nova é
necessária; "recusado" já significa a mesma coisa nos dois casos (motorista não será atendido
nesta solicitação).

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| Reaproveitar `publishQuoteRejection` (escolhida) | Sem contrato novo, sem dependência nova; mesmo significado semântico (Princípio IV, V). |
| Novo `kind` para "solicitação cancelada" | Rejeitada: exigiria emendar o contrato (Princípio IV) para uma distinção que os motoristas não precisam fazer — de qualquer forma, para eles, o resultado é "este orçamento não será aceito". |

### Riscos assumidos e mitigação

- Nenhum risco novo — mesmo padrão de publicação "melhor esforço" (`unawaited`) já usado para as
  recusas automáticas ao aceitar outro orçamento.

## D3 — Nova guarda `PassengerRideRules.canCancelRequest` (atende FR-009, FR-011)

**Decision**: `canCancelRequest(PassengerRideStatus current) => current ==
PassengerRideStatus.aguardandoOrcamentos` — mesmo padrão das demais guardas da feature 014.

**Contexto da decisão**: "Cancelar" é uma transição nova (`aguardandoOrcamentos` → `inicial`) que
não existia antes desta feature; segue o mesmo formato das guardas já testadas de
`PassengerRideRules`, em vez de uma checagem solta dentro de `_cancelarSolicitacao`.

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| Guarda dedicada em `PassengerRideRules` (escolhida) | Mesma simetria e testabilidade das demais guardas; um único lugar concentra toda regra de transição do enum. |
| Checagem inline em `_cancelarSolicitacao` | Rejeitada: repetiria o padrão que a própria feature 014 eliminou (condições soltas sem nome nem teste dedicado). |

### Riscos assumidos e mitigação

- Nenhum risco novo.

## D4 — Restaurar orçamentos persistidos ao entrar/restaurar `aguardandoOrcamentos` via
`ReceivedQuoteStore.byRequest` (atende FR-012, Clarification da sessão 2026-09-28)

**Decision**: ao entrar em `aguardandoOrcamentos` (seja pela solicitação recém-enviada, seja pela
restauração em `_carregarEstadoCorrida` após um reinício), `MapScreen` chama
`widget.receivedQuoteStore.byRequest(_solicitacaoAtivaId!)` e inicializa
`_orcamentosRecebidos.value` com o resultado, antes de exibir `ReceivedQuotesScreen`.

**Contexto da decisão**: `ReceivedQuoteStore.byRequest` já existe desde a feature 008
(`lib/services/received_quote_store.dart`) mas nunca foi chamado por `MapScreen` — só `save` era
usado. A Clarification confirmou (opção A) que reusar essa consulta pronta é preferível a começar
sempre vazio.

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| Chamar `byRequest` ao entrar/restaurar a fase (escolhida) | Método já existe, sem custo de implementação novo; resolvida pela Clarification. |
| Lista sempre vazia numa reabertura | Rejeitada pela Clarification (opção B recusada). |

### Riscos assumidos e mitigação

- Nenhum risco novo — mesma consulta, sem novo estado a manter consistente.

## D5 — Remoção de `RideQuotesModal` e seu teste dedicado (atende FR-007)

**Decision**: `lib/screens/ride_quotes_modal.dart` e `test/screens/ride_quotes_modal_test.dart` são
removidos; a lógica de exibir um item de orçamento (mesmos campos, `Aceitar`) é recriada, condensada,
dentro de `received_quotes_screen.dart`.

**Contexto da decisão**: FR-007 exige explicitamente eliminar a notificação em modal — mantê-la ao
lado da nova tela duplicaria a mesma informação por dois caminhos diferentes (Princípio V).

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| Remover e recriar condensado no novo arquivo (escolhida) | Único caminho compatível com FR-007; a versão condensada é mais simples que a original (menos preenchimento/città de card), não mais complexa. |
| Manter `RideQuotesModal` como componente reaproveitado dentro da nova tela | Rejeitada: o item da lista precisa ser mais compacto (FR-005 — "porém de forma mais condensada"), o card atual da modal é dimensionado para exibição avulsa, não para uma lista densa. |

### Riscos assumidos e mitigação

- Nenhum risco novo — `test/screens/ride_quotes_modal_test.dart` é substituído por um teste
  equivalente do novo widget, sem perda de cobertura.

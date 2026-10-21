# Pesquisa: 027-recibos-de-reputacao

O contrato (seção 1 de `especificacao-passageiro.md`) já decide formato, cadeia, kinds e verificação; aqui só as
decisões de implementação que o contrato deixa abertas. Nenhuma `NEEDS CLARIFICATION` restou.

## D1 — Dependências (Princípio III)

**Decisão**: **nenhuma dependência nova.** `crypto ^3.0.7` (SHA-256) já é dependência direta (promovida na
022, D1 de `specs/022-mensagens-cifradas/research.md`); `sqflite` e `path` já são diretas; assinatura e
verificação Schnorr usam `dart_nostr` (`keys.sign/verify`), como `RideRatingSignature`.
**Alternativas descartadas**: implementar SHA-256 à mão (risco sem ganho); outro pacote de hash (dependência
duplicada).
**Acoplamento**: `dart_nostr` só em `receipt_signature.dart`; `sqflite` só em `receipt_store.dart`; domínio e telas
usam tipos próprios.

## D2 — Assinatura do recibo

**Decisão**: `keys.sign(privateKey, message: id_recibo)` e `keys.verify(publicKey, message: id_recibo, signature)`,
com `message` = hex do `id_recibo`. A API já aplica SHA-256 à mensagem antes de assinar, igual a
`RideRatingSignature` (D1 da 012). O vetor de contrato compartilhado fixa o resultado esperado de verificação
(a assinatura Schnorr é randomizada, então o vetor traz uma assinatura **gerada uma vez** e testa só `verify`).
**Alternativa descartada**: assinar o hash bruto (divergiria do motorista se a API dele hasheasse de novo).

## D3 — Onde guardar a reputação declarada do orçamento

**Decisão (revista na implementação)**: **os dois**. (1) `received_quotes.reputation_json` (coluna nova, banco v2 com
`ALTER TABLE`) guarda a reputação junto do orçamento; (2) `ReceiptStore.saveDeclared(quoteId, avaliado, reputation)`
é chamado no toque em "Aceitar" (`_aceitarOrcamento`) para a reputação do orçamento **aceito**.
**Por quê**: a decisão original era só (2), mas `map_screen.dart` recarrega os orçamentos de
`ReceivedQuoteStore.byRequest` depois de um reinício; sem (1) o passageiro veria "sem histórico" para um motorista que
declarou reputação e, pior, aceitaria um orçamento sem reputação e emitiria depois um recibo com `seq = 0`, ramificando
a cadeia do motorista. (2) continua porque o recibo usa a declarada da corrida aceita, não do orçamento.
**Alternativa descartada**: só (2) (a original). Sem reputação declarada, nada é gravado em (2): equivale a motorista sem
histórico.

## D4 — Quem recebe `20014`/`20015`

**Decisão**: `ReceiptService` assina `EventFeed.events` (já verificados, deduplicados e com marcador) e processa os
eventos novos de kind `20014`/`20015` (guarda os ids processados), decifrando com `EventFeed.decrypted`. Não passa
por `map_screen`, que só trata kinds de corrida. `acceptedKinds` do `EventFeed` (main) já é
`passengerConsumedKinds`; basta acrescentar os dois kinds ali.
**Alternativa descartada**: tratar no `map_screen` como os demais kinds (acopla a tela a persistência de
reputação que não tem UI).

## D5 — Gatilhos do reenvio (`retryPending`)

**Decisão**: (a) ao construir o `ReceiptService` no `main.dart` (abrir o app); (b) transição de qualquer relay
para conectado, observando `RelayHub.relays`; (c) `Timer.periodic` de 60 s dono do `ReceiptService`
(`start()`/`dispose()`), ativo enquanto a interface existe. O reenvio com **só o serviço em segundo plano** vivo
(sem interface) fica fora: o serviço não tem a chave nem decifra (exceção da constituição 2.15.0), e o
`20014` precisa ser cifrado pela interface. O recibo pendente é reenviado na próxima abertura. Isso é um limite
declarado, não escondido.
**Pendente já cifrado?** Não: guarda-se o recibo assinado e recifra-se a cada reenvio (cifra NIP-44 usa nonce
novo; o `id` do evento muda, o `id_recibo` não — o avaliado trata por `guid_corrida`/`id_recibo`).

## D6 — Emissão e ciclo de vida da corrida

**Decisão**: `issueFor(AcceptedRide, stars?)` é chamado em `_avaliarCorrida`/`_pularAvaliacao`
(`map_screen.dart`) **antes** de `_finalizarAvaliacao` zerar `_corridaAceita`, depois de `RideRatingStore.save`.
Usa a reputação declarada gravada em `saveDeclared(quoteId)`; se não existir (orçamento sem `reputacao`), é
sem histórico (`seq = 0`, sem `hash_anterior`). Falha nunca bloqueia a UI (`unawaited` + `catchError`).
Se já existe recibo emitido para o `guid_corrida`, não emite outro (idempotência).

## D7 — Persistência

**Decisão**: `receipts.db` (SQLite, v1) com as três tabelas do app do motorista (`recibos_recebidos`,
`recibos_emitidos`, `reputacao_declarada`), mesmas colunas e métodos, mais `issuedFor(guid)` (idempotência da emissão e
validação do `20015`). Nenhum teste toca SQLite real: o contrato da store é exercitado no dublê em memória, que usa as
mesmas funções puras (`isIntactReceipt`, `reputationFromReceipts`) que `SqfliteReceiptStore`. Recibos recebidos são imutáveis
(`INSERT` sem `REPLACE`; `guid_corrida` único) e a assinatura é revalidada a cada leitura; linha cuja assinatura
não confere é omitida (e contada), como `ride_ratings`.

## D8 — Privacidade do `20001`

**Decisão**: registrar na constituição (emenda 2.17.0, MINOR) que a exceção do `20001` em claro passa a poder
incluir `reputacao` (recibos assinados que expõem chaves públicas de contrapartes), com a justificativa de
`spec.md` e 1.9 do contrato. A seção "Restrições de Segurança e Privacidade" exige registrar toda exceção nova
**antes** do código. Alternativa (enviar só o resumo no `20001`, recibos após o orçamento) fica como evolução
futura documentada em 1.9.

## D9 — Recibo mal formado dentro de uma `reputacao`

**Decisão**: `Receipt.fromJson` é estrito só na **estrutura** (campos, tipos, hex); `v ≠ 1`, `nota` fora de 1..5 e `seq`
negativo são lidos e julgados por `Receipt.hasValidFields`, e um recibo ilegível dentro de `Reputation.fromJson` é
descartado e contado em `ilegiveis`, sem invalidar a reputação inteira. O excedente à janela de 5 também é contado.
**Por quê**: o contrato (1.6) manda "recibo inválido é descartado e contado" e "reputação malformada não invalida o
orçamento"; um único recibo ruim não pode apagar o resto, nem dar a um atacante um jeito de esconder recibos válidos.

## D10 — Vetor de contrato compartilhado

**Decisão**: o arquivo `test/fixtures/receipt_vectors.json` é gerado pelo **app do motorista** e copiado byte a byte para
cá (`diff` sem saída); não há gerador neste repositório. Os vetores são por recibo (`valido` + `motivo`); os cenários de
cadeia (`head`, lacunas, encadeamento, guid repetido) são montados em tempo de teste com chaves descartáveis
(`test/support/receipt_builders.dart`). A assinatura Schnorr é randomizada: o teste a **verifica**, só forma canônica e
`id_recibo` comparam por igualdade.

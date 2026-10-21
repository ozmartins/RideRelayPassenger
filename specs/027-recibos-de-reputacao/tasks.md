# Tarefas: 027-recibos-de-reputacao

**Entrada**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/reputacao-por-recibos.md](contracts/reputacao-por-recibos.md), [quickstart.md](quickstart.md)
**Testes**: obrigatórios (Princípios II e III da constituição: código que assina/verifica nasce com teste; dublês, sem rede).
**Formato**: `- [ ] TID [P?] [US?] descrição com caminho`. `[P]` = arquivos distintos e sem dependência pendente.
**Commits**: um por mudança lógica, em português, direto na `master`; emendas da constituição e do contrato em commits separados, antes do código.

## Fase 1 — Contrato e constituição (bloqueia todo o código; Princípio IV)

- [X] T001 (feito, já commitado nas duas apps: `0e4beef` aqui, `ef2c39a` no motorista) Emendar a constituição para 2.17.0 em `.specify/memory/constitution.md` (Sync Impact Report + exceção do `kind: 20001` admitindo `reputacao` em claro, texto do plan.md), em commit próprio; replicar com texto idêntico em `../RideRelayDriver/.specify/memory/constitution.md` na mesma alteração
- [X] T002 (feito, já commitado nas duas apps: `c441839` aqui, `36e6a24` no motorista) Aplicar a emenda 25 em `specs/002-nostr-relay-connection/contracts/nostr-events.md`: linha 25 do histórico, kinds `20014`/`20015` na tabela, campo `reputacao` em *Conteúdo do kind 20001/20002*, cifragem "`20002` a `20015`", regra de recepção 7 "`20002`–`20015`", *Forma da inscrição* com `20014`/`20015`, seção "Reputação por recibos" colada literalmente de `contracts/reputacao-por-recibos.md`; replicar idêntico em `../RideRelayDriver/specs/002-nostr-relay-connection/contracts/nostr-events.md`
- [X] T003 Vetor de contrato compartilhado `test/fixtures/receipt_vectors.json`: **gerado pelo app do motorista** e copiado byte a byte para cá (`diff` sem saída com `../RideRelayDriver/test/fixtures/receipt_vectors.json`); aqui só se consome. Os cenários de cadeia (head, lacunas, encadeamento) são montados em teste com chaves descartáveis (`test/support/receipt_builders.dart`)

## Fase 2 — Fundação (bloqueia as histórias)

- [X] T004 [P] Teste de `Receipt` em `test/domain/receipt_test.dart` (forma canônica `tcc-recibo-v1|…`, `computeId` contra o vetor, `fromJson` estrito, chaves opcionais omitidas, `nota` fora de 1..5)
- [X] T005 [P] Teste de `Reputation` em `test/domain/reputation_test.dart` (`toJson`/`fromJson` estritos, `media` e `head` omitidos, janela `kReputacaoJanela = 5`)
- [X] T006 [P] Implementar `Receipt` em `lib/domain/receipt.dart`
- [X] T007 [P] Implementar `Reputation` e `kReputacaoJanela` em `lib/domain/reputation.dart`
- [X] T008 [P] Implementar `ReputationView` em `lib/domain/reputation_view.dart`
- [X] T009 [P] Teste de `ReceiptSignature` em `test/services/receipt_signature_test.dart` (assina e verifica com a cripto real; falha com id adulterado, chave de outro autor, assinatura malformada; confere o vetor T003)
- [X] T010 Implementar `ReceiptSignature` (`sign`/`verify` sobre `id_recibo`, via `keys.sign/verify`) em `lib/services/receipt_signature.dart`
- [X] T011 [P] Teste de `ReputationVerifier` em `test/services/reputation_verifier_test.dart` (regras 1.6 a–i; recibo inválido descartado e contado; `inconsistente`; lacunas; verificado separado do declarado; vetor T003)
- [X] T012 Implementar `ReputationVerifier` (função pura) em `lib/services/reputation_verifier.dart`
- [X] T013 [P] Definir `ReceiptStore` (interface) e dublê em memória em `test/support/in_memory_receipt_store.dart`
- [X] T014 [P] Teste do contrato de `ReceiptStore` em `test/services/receipt_store_test.dart`, sobre o dublê em memória e as funções puras que `SqfliteReceiptStore` também usa (nenhum teste toca SQLite real, Princípio III): imutabilidade de recebidos, pendente/ack, leitura omite recibo adulterado, `myReputation` recalcula e é vazia sem recibos
- [X] T015 Implementar `ReceiptStore` + `SqfliteReceiptStore` (`receipts.db` v1, três tabelas, métodos do data-model) em `lib/services/receipt_store.dart`
- [X] T016 [P] Teste de `EventFeed` em `test/event_feed_test.dart`: `publishReceipt`/`publishReceiptAck` saem cifrados com tags `e`/`p` e marcador (content em claro é erro); `publishRideRequest` com e sem `reputation` (chave omitida, nunca `null`)
- [X] T017 Acrescentar a `lib/services/event_feed.dart` as constantes `receiptKind = 20014` e `receiptAckKind = 20015`, `publishReceipt`, `publishReceiptAck` e o parâmetro `{Reputation? reputation}` de `publishRideRequest`
- [X] T018 [P] Atualizar `test/services/subscription_request_test.dart` (contém `20014` e `20015`; igualdade com as constantes de `event_feed.dart`) e `test/domain/background_notification_rule_test.dart` (`20014/20015` não notificam)
- [X] T019 Acrescentar `20014` e `20015` (comentário "emenda 25") a `passengerConsumedKinds` em `lib/services/subscription_request.dart`, sem tocar `notifiableKinds` em `lib/domain/background_notification_rule.dart`

## Fase 3 — US1: ver a reputação verificada do motorista (P1) 🎯 MVP

**Teste independente**: `20002` com `reputacao` válida, adulterada e ausente; tela mostra verificado × declarado, "inconsistente", lacunas.

- [X] T020 [P] [US1] Estender `test/domain/received_quote_test.dart`: `reputacao` presente, ausente e malformada (esta vira `null` sem invalidar o orçamento)
- [X] T021 [US1] Adicionar `Reputation? reputation` e a leitura tolerante de `reputacao` em `lib/domain/received_quote.dart`
- [X] T022 [P] [US1] Estender `test/screens/received_quotes_screen_test.dart`: reputação verificada e declarada, "inconsistente", "N recibos não apresentados", orçamento sem reputação
- [X] T023 [US1] Exibir a reputação por orçamento (verificada em destaque, declarada em texto menor, avisos) em `lib/screens/received_quotes_screen.dart`, usando `ReputationVerifier` e `lib/screens/identidade_visual.dart`
- [X] T024 [US1] Ao tocar em "Aceitar", chamar `ReceiptStore.saveDeclared(quote.quoteId, quote.driverPubkey, quote.reputation)` (só se houver reputação) e persistir a reputação em `received_quotes.reputation_json` (banco v2, research D3) em `_aceitarOrcamento` de `lib/screens/map_screen.dart` (ao lado de `acceptedRideStore.save`), com teste em `test/screens/map_screen_test.dart`

## Fase 4 — US2: emitir o recibo ao fim da corrida (P1)

**Teste independente**: concluir, fechar a modal, ver recibo `pendente`, `20014` cifrado, baixa no `20015`.

- [X] T025 [P] [US2] Testes de `ReceiptService.issueFor` e `retryPending` em `test/services/receipt_service_issue_test.dart` (nota e "pular"; reputação declarada inconsistente não emite e avisa; sem declarada ⇒ `seq 0`; pendente gravado antes de publicar; idempotente por `guid_corrida`; reenvio até o `20015`; falha de publicação não lança)
- [X] T026 [US2] Implementar `ReceiptService` (`issueFor(AcceptedRide, int?)`, `onAckEvent`, `retryPending`, `start`/`dispose` com `Timer.periodic` de 60 s e gatilho de reconexão por `RelayHub.relays`) em `lib/services/receipt_service.dart`
- [X] T027 [US2] Em `lib/screens/map_screen.dart`, chamar `receiptService.issueFor(corridaAceita, stars)` em `_avaliarCorrida` (depois de `RideRatingStore.save`) e `issueFor(corridaAceita, null)` em `_pularAvaliacao`, ambos antes de `_finalizarAvaliacao`, com `unawaited`/`catchError` e aviso de uma linha para reputação inconsistente; teste em `test/screens/map_screen_test.dart`
- [X] T028 [US2] Instanciar `SqfliteReceiptStore` e `ReceiptService` junto de `_rideRatingStore` em `lib/main.dart`, injetar no `_Shell`/`map_screen` e chamar `retryPending` na abertura

## Fase 5 — US3: receber recibos e declarar a própria reputação (P2)

**Teste independente**: `20014` válido, inválido e repetido; gravação, `20015` e conteúdo do próximo `20001`.

- [X] T029 [P] [US3] Testes de `onReceiptEvent` em `test/services/receipt_service_receive_test.dart` (válido grava e responde `20015`; repetido idêntico só reenvia `20015`; diferente ignora; assinatura/hash/destinatário/autor inválidos descartados; `guid_corrida` ≠ tag `e` descartado; `myReputation` recalculada)
- [X] T030 [US3] Implementar `onReceiptEvent` e a assinatura de `EventFeed.events` (kinds `20014`/`20015`, ids já processados, `EventFeed.decrypted`) em `lib/services/receipt_service.dart`
- [X] T031 [US3] Em `lib/screens/map_screen.dart`, passar `await receiptStore.myReputation()` a `publishRideRequest(reputation: …)` (testar `20001` sem a chave quando não há recibos e com a chave quando há)

## Fase 6 — Polimento e gates

- [X] T032 [P] Teste de não vazamento (Princípio I) em `test/services/receipt_service_privacy_test.dart`: nenhuma chave privada em log ou no conteúdo publicado; `20014/20015` nunca em claro
- [X] T033 Executar `flutter analyze` ("No issues found!") e `flutter test` integral sem testes ignorados; corrigir
- [ ] T034 Executar os cenários 1–9 de `quickstart.md` nos dois apps e registrar o resultado (inclusive falhas) em `quickstart.md`; rodar o vetor compartilhado também no motorista
  - **Pendente**: os cenários 1–9 pedem dois aparelhos/emuladores com o app do motorista (feature 026 dele) e relays reais; não foram executados nesta sessão. O que o código cobre de forma automatizada está no quickstart ("Resultado da execução").
- [X] T035 Atualizar `CLAUDE.md` (invariantes: contrato de recibos e vetor compartilhado; arquitetura: `ReceiptService`/`ReceiptStore`) em commit separado

## Dependências

- Fase 1 → todo o código. Fase 2 → Fases 3–5. US1 (3) é o MVP; US2 (4) depende de T024 (`saveDeclared`) e da Fase 2; US3 (5) depende de T026 (serviço) e é independente de US1.
- Dentro da fase: testes antes da implementação; T010 antes de T012 e T026; T015 antes de T026; T017 antes de T026/T030.

## Paralelismo

- Fase 2: T004–T005, T009, T011, T013–T014, T016, T018 em paralelo (arquivos distintos); T006–T008 em paralelo.
- US1: T020 ∥ T022. Após a Fase 2, US1 e US3 podem andar em paralelo (US2 depende de T024).

## Estratégia

MVP = Fases 1–3 (ver a reputação verificada). Depois US2 (emissão, o coração da reputação) e US3 (receber). Cada fase termina com `flutter analyze` e testes verdes.

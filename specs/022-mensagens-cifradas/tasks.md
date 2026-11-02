# Tasks: Mensagens cifradas entre as apps (passageiro)

**Input**: Design documents from `/specs/022-mensagens-cifradas/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/README.md, quickstart.md; **e as tarefas de gate T001–T005 de `Prototipo/driver/specs/019-mensagens-cifradas/tasks.md` já feitas** (constituição 2.11.0, contrato emenda 17 nas duas apps, dependências do motorista).

**Tests**: **obrigatórios** (Princípio II; nenhum teste toca rede). Vetores oficiais do NIP-44, política de decifração, conteúdo cifrado dos quatro publicadores e os tratadores do mapa com os dublês de `test/support/`.

**Organization**: gates verificados primeiro; Foundational (cifra + política) bloqueia US1 (publicar) e US2 (receber); US3 fecha a consistência. Cada tarefa que quebra testes antigos já os ajusta.

## Format: `[ID] [P?] [Story] Description`

- Caminhos relativos a `Prototipo/passenger/`, salvo indicação (`../driver/` = `Prototipo/driver/`)

---

## Phase 1: Gates

- [X] T001 [US3] Verificar a cópia do contrato `specs/002-nostr-relay-connection/contracts/nostr-events.md` conforme `specs/022-mensagens-cifradas/contracts/README.md`: emenda 17, cabeçalho de procedência atualizado, `diff` com `../driver/specs/002-nostr-relay-connection/contracts/nostr-events.md` (menos o cabeçalho) vazio. Se faltar algo, voltar às tarefas T003/T004 do motorista — não editar só aqui.
- [X] T002 [US3] Verificar `.specify/memory/constitution.md` em 2.11.0 com Sync Impact Report e `diff` dos corpos com `../driver/.specify/memory/constitution.md`: vazio (SC-005). Mesma regra: divergência volta às T001/T002 do motorista.
- [X] T003 Em `pubspec.yaml`, promover `pointycastle: ^3.9.1` e `crypto: ^3.0.7` a dependências diretas (comentário citando a decisão D1 do motorista e `research.md` D1), `flutter pub get`; confirmar que o `pubspec.lock` só muda o campo `dependency` desses dois. Não adicionar `nostr`.

**Checkpoint**: contrato e constituição idênticos e commitados; `flutter pub get` limpo.

---

## Phase 2: Foundational — cifra NIP-44 e política (bloqueia US1 e US2)

- [X] T004 [P] Copiar `../driver/test/fixtures/nip44.vectors.json` para `test/fixtures/nip44.vectors.json` (mesmo arquivo; registrar a origem no teste).
- [X] T005 [P] Escrever `test/services/nip44_test.dart` contra os vetores (falha antes de T007): `get_conversation_key`, `get_message_keys`, `calc_padded_len`, `encrypt_decrypt` (nonce fixo, payload exato), `encrypt_decrypt_long_msg`, `invalid.*` lançando `Nip44Exception`; a mensagem da exceção não contém hex de chave nem o texto de entrada (FR-010). Mesmo conteúdo do teste do motorista, com imports `package:passenger/...`.
- [X] T006 [P] Escrever `test/services/message_cipher_test.dart` (falha antes de T008): ida e volta entre duas identidades; terceiro não decifra (`null`); em claro `null`; payload adulterado `null`; `{}` exigido com `emptyMarker` (outro texto, inclusive `''`, `null`); chave de conversa calculada uma vez por par e simétrica; `decryptFrom` não lança nem ecoa chave/texto.
- [X] T007 Criar `lib/services/nip44.dart`: cópia de `../driver/lib/services/nip44.dart` com imports `package:passenger/...` (D2). Se o motorista ainda não a tiver, implementar conforme `../driver/specs/019-mensagens-cifradas/tasks.md` T009. T005 passa.
- [X] T008 Criar `lib/services/message_cipher.dart`: cópia adaptada de `../driver/lib/services/message_cipher.dart` (`encryptFor`, `decryptFrom(..., emptyMarker)`, cache em memória, `{}` para vazio). T006 passa.

**Checkpoint**: `flutter test test/services/nip44_test.dart test/services/message_cipher_test.dart` verde.

---

## Phase 3: User Story 1 — O que o passageiro envia só o motorista certo lê (Priority: P1) 🎯 MVP

**Goal**: `20003`, `20004`, `20008`, `20010` saem cifrados e assinados; `20001` segue em claro.

**Independent Test**: publicar com o dublê e verificar `content` opaco, assinatura válida, tags em claro, decifrável só pelo motorista; `20001` legível.

- [X] T009 [P] [US1] Acrescentar a `test/event_feed_test.dart` o grupo `conteúdo cifrado (feature 022)`: `publishQuoteAcceptance`, `publishQuoteRejection`, `publishMeetingConfirmation`, `publishDestinationConfirmation` produzem evento com `content` ≠ `''`, decifrável pelo motorista de teste para exatamente `{}`, terceiro não decifra, assinatura válida sobre o `content` cifrado, tags `t`/`e`/`p` em claro; `publishRideRequest` continua com `content` JSON em claro; falha de cifragem (chave de destinatário malformada) não transmite nada e devolve `PublishReport` com `anyAccepted == false`. Falha antes de T010.
- [X] T010 [US1] Em `lib/services/event_feed.dart`, injetar `MessageCipher` (construtor, padrão `MessageCipher()`); `_publish` ganha `recipientPubkey` opcional: quando presente, cifra o `content` (vazio → `{}`) antes de `fromPartialData`; falha de cifragem devolve `PublishReport(eventId: '', byRelay: const {})` sem `broadcast` (D4). Os quatro publicadores com `p` passam o `recipientPubkey` derivado do mesmo valor da tag; `publishRideRequest` e `publish` (kind 1) não passam. T009 passa. **Na mesma tarefa**, ajustar os testes existentes de `test/event_feed_test.dart` e `test/screens/map_screen_test.dart` que liam o `content` publicado desses quatro kinds (agora cifrado) para decifrar com a identidade do motorista de teste; `flutter test` verde ao fim.
- [X] T011 [US1] Conferir em `lib/screens/map_screen.dart` que `_aceitarOrcamento`, `_confirmarEncontro`, `_confirmarDestino` e `_cancelarSolicitacao` tratam o `PublishReport` sem relay aceito como já tratam (mensagem existente, sem estado novo — FR-004); acrescentar a `test/screens/map_screen_test.dart` um teste de falha de cifragem simulada: nada transmitido, estado da corrida inalterado, mensagem de falha existente exibida.

**Checkpoint**: nenhum `20003`/`20004`/`20008`/`20010` sai em claro (SC-001); `20001` inalterado.

---

## Phase 4: User Story 2 — O que o passageiro recebe é decifrado e o fluxo segue igual (Priority: P1)

**Goal**: `20002`, `20005`, `20006`, `20007`, `20009`, `20011`, `20012` cifrados produzem o efeito de hoje; o resto é descartado em silêncio.

**Independent Test**: entregar os sete kinds cifrados ao passageiro e verificar os efeitos; entregar variantes inválidas e verificar descarte sem efeito.

- [X] T012 [P] [US2] Acrescentar a `test/event_feed_test.dart` o grupo `EventFeed.decrypted (feature 022)`: cifrado ao passageiro → texto; `p` alheia → `null` sem tentar decifrar; cifrado a outra chave → `null`; em claro → `null`; MAC adulterado → `null`; com `emptyMarker`, texto ≠ `{}` → `null`. Falha antes de T013.
- [X] T013 [US2] Acrescentar `NostrEvent.recipientPublicKey`/`withContent` (`lib/domain/nostr_event.dart`) e `EventFeed.decrypted(evento, identity, {emptyMarker = false})` → `NostrEvent?` (`lib/services/event_feed.dart`; confere `p` == `identity.publicKey`, decifra com a pública do autor via `MessageCipher`; nunca lança nem loga). T012 passa.
- [X] T014 [P] [US2] Em `test/support/event_fixtures.dart`, acrescentar construtores de evento **do motorista cifrado ao passageiro** (`20002` com `["p", passageiro]`, `20005`, `20006`, `20007`, `20009`, `20011`, `20012`), mais variantes inválidas (em claro, cifrado a outra chave, `p` alheia, MAC adulterado, texto ≠ `{}`), assinados com chaves de teste.
- [X] T015 [P] [US2] Acrescentar a `test/screens/map_screen_test.dart` os casos de recepção: (a) `20002` cifrado válido → orçamento na lista e persistido como campos decodificados; (b) `20005` → marcador e "motorista a caminho"; (c) `20007`/`20009` → modais de chegada; (d) `20011` → rota em "Em corrida"; (e) `20012` e `20006` → encerramento e modais; (f) cada variante inválida → nenhum efeito, nenhuma modal, nenhum erro; (g) **FR-007**: `20005` não decifrável não rearma o relógio de silêncio (com `driverSilenceTimeout` curto o aviso de silêncio dispara) e não dispara "a caminho"; `20005` decifrável com `content` inválido continua rearmando. Falham antes de T016.
- [X] T016 [US2] Em `lib/screens/map_screen.dart`, os tratadores de `rideQuoteKind`, `driverLocationKind`, `driverArrivalKind`, `destinationArrivalKind`, `rideRouteKind`, `rideCancelledKind` e `rideUnavailableKind` chamam `widget.eventFeed.decrypted` na entrada (com identidade não nula; `emptyMarker: true` nos de `{}`), retornam em silêncio se `null` e passam o texto decifrado às entidades (`ReceivedQuote`, `DriverLocation`, `RideRoute`), por parâmetro ou por evento com `content` substituído, sem mudar `fromNostrEvent` além do necessário; no `20005`, decifrar **antes** de rearmar o relógio e de disparar "a caminho" (FR-007). `EventFeed` **não** muda para receber (D3). T015 passa. **Na mesma tarefa**, ajustar os testes existentes que injetam esses kinds em claro (`test/screens/map_screen_test.dart`, `test/domain/*` se usarem `fromNostrEvent` com `content` cru) para usar os construtores cifrados de T014; `flutter test` verde ao fim.
- [X] T017 [US2] Garantir o FR-009: teste de que o orçamento persistido (`SqfliteReceivedQuoteStore`/dublê) guarda os campos decodificados e que um orçamento gravado antes da feature continua sendo carregado e exibido ao reabrir o app (`ReceivedQuoteStore.byRequest`).

**Checkpoint**: fluxo completo do passageiro com eventos cifrados (SC-002, SC-003).

---

## Phase 5: Polish & Cross-Cutting

- [X] T018 [US3] Rever o contrato e a constituição contra o código final (formato do texto de entrada, `p` no `20002`, `{}`, exceção do `20001`); corrigir o texto **nas duas apps** se divergirem e repetir os `diff` de T001/T002 (SC-005).
- [ ] T019 Medir (SC-004) no emulador `Pixel_6_API34_1` (e num aparelho físico, se houver) o primeiro ECDH e a decifração de uma `20005` e de uma `20011` de 1000 pontos; registrar em `research.md` D6; se o primeiro ECDH passar de ~100 ms, mover a cifra a um `Isolate` antes de seguir.
- [X] T020 [P] Atualizar `../CLAUDE.md` (raiz): entrada da feature `022-mensagens-cifradas` do passageiro (cifra copiada do motorista, `EventFeed._publish` cifra, decifração no `MapScreen`, FR-007 do relógio de silêncio, emenda 17, constituição 2.11.0) e a nota "defeito de cifra numa cópia → conferir na outra". Commit à parte.
- [X] T021 `flutter analyze` ("No issues found!") e `flutter test` (suíte completa verde); cenários 1–6 de `quickstart.md` marcados **validação em aparelho pendente** até haver dois aparelhos com as duas apps atualizadas.

---

## Dependencies & Execution Order

- Phase 1 verifica gates feitos pela feature do motorista; **não** reescreve contrato nem constituição.
- Phase 2 (T004–T008) bloqueia US1 e US2. T004/T005/T006 em paralelo → T007 → T008.
- US1 (T009–T011) e US2 (T012–T017) dependem só da Phase 2; compartilham `event_feed_test.dart`/`map_screen_test.dart`, então na prática em sequência. US1 antes de US2 (MVP de privacidade de saída).
- Ordem entre apps: gates do motorista (T001–T005 dele) → esta Phase 1 → cifra nas duas → publicação/recepção nas duas; teste ponta a ponta só depois das duas.

### Parallel opportunities

T004/T005/T006; T009 com T012, T014 e T015.

## Implementation Strategy

1. **MVP = Phase 1 + 2 + US1**: o passageiro publica cifrado ao motorista.
2. US2 fecha a via de volta; Polish mede e documenta.
3. Commits (Padrão de Commits, direto na `master`): dependências (T003) → cifra (T004–T008) → publicação cifrada (US1) → recepção cifrada (US2) → docs. A constituição e o contrato são commitados antes, pela feature do motorista.

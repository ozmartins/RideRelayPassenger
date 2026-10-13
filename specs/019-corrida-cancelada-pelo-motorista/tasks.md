# Tasks: Corrida cancelada pelo motorista (passageiro)

**Input**: Design documents from `/specs/019-corrida-cancelada-pelo-motorista/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/README.md, quickstart.md

**Tests**: **obrigatórios** (Princípio II; nenhum teste toca rede). Regra de estado e modal têm teste direto; o comportamento no mapa usa os dublês de `test/support/` e os helpers de `test/screens/map_screen_test.dart` (que pré-carregam estado e entregam eventos, como nos grupos das features 016 e 018).

**Organization**: precondição de contrato → fundação (regra, kind, inscrição, modal) → US1 (receber e encerrar) → US2 (limpeza e persistência) → US3 (só aviso legítimo). Setup vazio (nenhuma dependência nova).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo
- Caminhos relativos a `Prototipo/passenger/`, salvo indicação (`../driver/` = `Prototipo/driver/`)

---

## Phase 1: Precondição — contrato (Princípio IV)

- [X] T001 Verificar que a emenda 14 (`kind: 20012`, seção *Conteúdo do kind 20012*) já consta, idêntica, em `specs/002-nostr-relay-connection/contracts/nostr-events.md` e em `../driver/specs/002-nostr-relay-connection/contracts/nostr-events.md` (`grep -c 20012` em ambos > 0; `diff` ignorando o cabeçalho de procedência do passageiro vazio). Se não constar, **parar**: implementar antes as tarefas T001/T002 da feature `018-cancelar-corrida-motorista` do motorista (`../driver/specs/018-cancelar-corrida-motorista/tasks.md`). Nenhuma tarefa abaixo começa sem isto.

---

## Phase 2: Foundational — regra, kind, inscrição, modal (bloqueia as histórias)

- [X] T002 [P] Acrescentar a `test/domain/passenger_ride_status_test.dart` o grupo `canBeCancelledByDriver (feature 019)`: `true` em `orcamentoAceito`, `motoristaACaminho` e `emCorrida`; `false` em `inicial`, `aguardandoOrcamentos` e `destinoConfirmadoAguardandoAvaliacao`. Deve falhar antes de T004.
- [X] T003 [P] Escrever `test/screens/ride_cancelled_modal_test.dart` e criar `lib/screens/ride_cancelled_modal.dart` (`RideCancelledModal`, apresentacional, no padrão de `DriverMovingModal`: `ModalTematizado`, título "Corrida cancelada", texto "O motorista cancelou a corrida. Você pode solicitar outra.", botão primário "OK" de 48 px chamando `onClose`). Testes: mostra título, mensagem e "OK"; tocar "OK" chama `onClose`.
- [X] T004 Acrescentar `PassengerRideRules.canBeCancelledByDriver(PassengerRideStatus)` em `lib/domain/passenger_ride_status.dart` (só os três estados de corrida aceita e não concluída; doc comment no padrão dos vizinhos). T002 passa.
- [X] T005 Acrescentar `const rideCancelledKind = 20012;` em `lib/services/event_feed.dart` (doc comment no padrão dos vizinhos, citando emenda 14 e feature 018 do motorista) e incluí-lo em `acceptedKinds` de `lib/main.dart` (com comentário citando a emenda 14). Acrescentar em `test/event_feed_test.dart`, no padrão dos testes do `20011` (grupo de `acceptedKinds`), dois casos: `kind 20012` chega ao feed quando está em `acceptedKinds` e é ignorado quando está fora (regra 4); `subscriptionRequest` lista `20012` quando configurado. Conferir com `grep -rn acceptedKinds test` se algum outro teste enumera os kinds de `main.dart` e ajustar.

**Checkpoint**: `flutter test test/domain/passenger_ride_status_test.dart test/screens/ride_cancelled_modal_test.dart` verde.

---

## Phase 3: User Story 1 — Ser avisado e voltar ao início quando o motorista cancela (Priority: P1) 🎯 MVP

**Goal**: ao receber o aviso legítimo em `orcamentoAceito`, `motoristaACaminho` ou `emCorrida`, a modal aparece e o app já está no estado inicial.

**Independent Test**: no `map_screen_test.dart`, com a corrida pré-carregada em cada fase, entregar um `kind: 20012` assinado pelo motorista da corrida e verificar modal e estado.

- [X] T006 [US1] Escrever em `test/screens/map_screen_test.dart` o grupo `corrida cancelada pelo motorista (feature 019)`, falhando antes de T007/T008: para cada fase (`orcamentoAceito`, `motoristaACaminho`, `emCorrida`), entregar o aviso (autor = `driverPubkey` da corrida aceita, `["e", quoteId]`) e verificar: a modal "Corrida cancelada" aparece (FR-003); `rideStateStore.load()` já devolve `inicial` **antes** de tocar "OK" (FR-005, SC-001); tocar "OK" fecha a modal e o painel "Solicitar corrida" volta a aparecer (FR-009); a modal de avaliação **não** aparece (FR-007, SC-005); nenhum evento é publicado pelo passageiro (FR-010).
- [X] T007 [US1] Em `lib/screens/map_screen.dart`, implementar `_processarCancelamentoDoMotorista(NostrEvent)` conforme `research.md` D2/D3: dedupe por `_idsCancelamentoProcessados`; `corridaAceita != null`; `referencedEventId == quoteId`; `authorPublicKey == driverPubkey`; `PassengerRideRules.canBeCancelledByDriver(_rideStatus)`; aceito, `unawaited(widget.rideStateStore.save(PassengerRideStatus.inicial, null))` e, num só `setState`, `_rideStatus = inicial`, `_corridaAceita = null`, `_limparPosicaoMotorista()`, `_modalMotoristaVisivel = false`, `_modalChegadaMotoristaVisivel = false`, `_modalChegadaDestinoVisivel = false`, `_modalCorridaCanceladaVisivel = true`. Despachar `rideCancelledKind` em `_aoAtualizarOrcamentos`.
- [X] T008 [US1] Em `lib/screens/map_screen.dart`, declarar `_idsCancelamentoProcessados` e `_modalCorridaCanceladaVisivel` (com doc comments no padrão dos vizinhos) e, no `build()`, renderizar `RideCancelledModal` em `Stack` com o mesmo fundo `Colors.black54` das demais, **antes** da verificação de `_modalAvaliacaoVisivel` (precedência, D4); `onClose` apenas desliga a flag. T006 passa.

**Checkpoint**: US1 funcional e testável sozinha.

---

## Phase 4: User Story 2 — Nada da corrida cancelada sobra no app (Priority: P1)

**Goal**: limpeza completa e persistida.

- [X] T009 [US2] Acrescentar ao grupo de T006, em `test/screens/map_screen_test.dart`: (a) com posição e rota do motorista exibidas, depois do aviso o marcador do motorista e o traçado do motorista não existem (FR-006); (b) com a modal de chegada do motorista, a de "motorista a caminho" ou a de chegada ao destino abertas, o aviso as substitui — só a modal de cancelamento fica (Edge Cases); (c) reabrir a tela com o mesmo `rideStateStore` e `acceptedRideStore` depois do aviso, sem tocar "OK": estado `inicial`, sem modal, sem corrida aceita (FR-004, SC-003); (d) localização (`20005`), chegada (`20007`/`20009`) e rota (`20011`) da corrida cancelada, entregues depois, não alteram nada (FR-006); (e) depois do cancelamento, solicitar nova corrida e aceitar outro orçamento funciona normalmente (FR-009, SC-004). Se algum caso falhar, corrigir `_processarCancelamentoDoMotorista`.

**Checkpoint**: US1 e US2 verdes.

---

## Phase 5: User Story 3 — Ignorar avisos que não valem (Priority: P2)

**Goal**: só o aviso do motorista da corrida aceita, na fase certa, tem efeito, uma vez.

- [X] T010 [US3] Acrescentar ao grupo de T006, em `test/screens/map_screen_test.dart`: aviso (a) assinado por outra chave que não a do motorista da corrida; (b) com `["e", ...]` de outro orçamento; (c) sem corrida aceita (`inicial`); (d) em `aguardandoOrcamentos`; (e) em `destinoConfirmadoAguardandoAvaliacao` — a avaliação segue normal (Edge Cases, FR-002); (f) o mesmo evento reentregue depois de tratado — a modal não reabre (FR-008). Em todos: nenhuma modal de cancelamento e nenhuma mudança de estado (SC-002). Assinatura inválida é descartada pelo `EventFeed` antes de chegar ao mapa — regra geral já coberta em `test/event_feed_test.dart`, sem teste novo por kind.

---

## Phase 6: Polish & cross-cutting

- [X] T011 Rodar `flutter analyze` ("No issues found!") e `flutter test` (suíte completa; anotar o total) em `Prototipo/passenger/`.
- [X] T012 Conferir a modal nova contra a seção **Identidade Visual e Design** de `.specify/memory/constitution.md` (modal: `folha`, raio 24, título 20/800, ação primária `roxo` 48 px, raio 16); corrigir divergências.
- [X] T013 Registrar o estado da validação em aparelho em `specs/019-corrida-cancelada-pelo-motorista/quickstart.md` (cenários 1–5; o ponta a ponta depende da feature 018 do motorista; marcar pendente se não houver aparelho/emulador).
- [X] T014 Atualizar `../CLAUDE.md` (raiz do repositório): entrada da feature `019-corrida-cancelada-pelo-motorista` do passageiro e da `018-cancelar-corrida-motorista` do motorista (se ainda não registrada), referência cruzada e validação em aparelho pendente, em commit separado, no padrão das entradas anteriores.

---

## Dependencies & Execution Order

- Phase 1 (T001) → bloqueia tudo; exige a feature 018 do motorista com o contrato já commitado.
- Phase 2: T002 ∥ T003; T004 depois de T002; T005 independente das demais.
- Phase 3: T006 → T007 → T008 (dependem de T003, T004, T005).
- Phases 4 e 5 dependem de T008; T009 e T010 estão no mesmo arquivo: sequenciar.
- Polish depois de tudo.

### Parallel opportunities
- T002 ∥ T003 ∥ T005 (arquivos diferentes).

## Implementation Strategy

1. Conferir que o contrato (emenda 14) já está nas duas cópias (T001).
2. MVP = Phase 2 + Phase 3 (T002–T008): o passageiro é avisado e volta ao início.
3. Phases 4–5 travam limpeza, reinício e avisos ilegítimos; Phase 6 fecha qualidade e documentação.
4. Ponta a ponta real exige a feature `018` do motorista implementada; sem ela o aviso só existe simulado em teste.

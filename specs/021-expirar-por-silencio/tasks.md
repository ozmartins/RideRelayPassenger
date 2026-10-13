# Tasks: Expirar a corrida por silêncio do motorista (passageiro)

**Input**: Design documents from `/specs/021-expirar-por-silencio/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/README.md, quickstart.md

**Tests**: **obrigatórios** (Princípio II; nenhum teste toca rede). O tempo é avançado com `tester.pump(Duration)` sobre o relógio falso, reduzindo o prazo pelo parâmetro `driverSilenceTimeout` do `MapScreen` nos testes. Os helpers `montarComCorridaAceita`, `avisarMotoristaACaminho`, `montarComEncontroConfirmado` e `esperarEntregaDoEvento` de `test/screens/map_screen_test.dart` já existem; `montar` e eles precisam repassar o novo parâmetro (T003).

**Organization**: fundação (regra, modal, parâmetro) → US1 (expirar em "orçamento aceito") → US2 (expirar em "motorista a caminho", rearmar a cada sinal) → US3 (não expirar em "em corrida", cancelar a contagem, sinais inválidos). Sem contrato (nada a replicar) e sem setup.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo
- Caminhos relativos a `Prototipo/passenger/`

---

## Phase 1: Foundational — regra, modal, parâmetro (bloqueia as histórias)

- [X] T001 [P] Acrescentar a `test/domain/passenger_ride_status_test.dart` o grupo `canExpireBySilence (feature 021)`: `true` em `orcamentoAceito` e `motoristaACaminho`; `false` nos demais quatro estados. Deve falhar antes de T003.
- [X] T002 [P] Escrever `test/screens/driver_silent_modal_test.dart` e criar `lib/screens/driver_silent_modal.dart` (`DriverSilentModal`, apresentacional, no padrão de `DriverUnavailableModal`: `ModalTematizado`, título "Motorista sem sinal", texto "O motorista ficou sem sinal e a corrida foi encerrada. Você pode solicitar outra.", botão primário "OK" de 48 px chamando `onClose`). Testes: mostra título, mensagem e "OK"; tocar "OK" chama `onClose`.
- [X] T003 Acrescentar `PassengerRideRules.canExpireBySilence(PassengerRideStatus)` em `lib/domain/passenger_ride_status.dart` (só `orcamentoAceito` e `motoristaACaminho`; doc comment no padrão dos vizinhos) — T001 passa — e o parâmetro opcional `driverSilenceTimeout` (`Duration`, padrão 3 minutos, com doc comment citando a feature 021) em `MapScreen` (`lib/screens/map_screen.dart`). Em `test/screens/map_screen_test.dart`, fazer `montar` e os helpers `montarComSolicitacaoAtiva`/`montarComCorridaAceita`/`montarComEncontroConfirmado` aceitarem e repassarem `driverSilenceTimeout` (padrão: o do `MapScreen`).

**Checkpoint**: `flutter test test/domain/passenger_ride_status_test.dart test/screens/driver_silent_modal_test.dart` verde e o app compila.

---

## Phase 2: User Story 1 — Sair de "orçamento aceito" quando o motorista nunca aparece (Priority: P1) 🎯 MVP

**Goal**: 3 minutos sem sinal em "orçamento aceito" encerram a corrida e abrem a modal.

**Independent Test**: no `map_screen_test.dart`, com a corrida aceita e `driverSilenceTimeout` curto, avançar o relógio além do prazo e verificar modal e estado.

- [X] T004 [US1] Escrever em `test/screens/map_screen_test.dart` o grupo `expirar por silêncio (feature 021)`, falhando antes de T005/T006: em "orçamento aceito", depois do prazo, a modal "Motorista sem sinal" aparece e `rideStateStore.status` já é `inicial` **antes** de tocar "OK" (FR-003, FR-004, SC-001); nada é publicado (FR-007, SC-005); a avaliação não abre; "OK" fecha a modal e o painel "Solicitar corrida" volta (FR-004, FR-008); antes do prazo nada acontece; uma localização do motorista antes do prazo leva a "motorista a caminho" e a modal não aparece no prazo original (FR-005).
- [X] T005 [US1] Em `lib/screens/map_screen.dart`, declarar `_silencioMotorista` (`Timer?`) e `_modalMotoristaSemSinalVisivel`; implementar `_armarSilencio()` (cancela o timer atual; se `PassengerRideRules.canExpireBySilence(_rideStatus)` e `_corridaAceita != null`, cria um `Timer(widget.driverSilenceTimeout, _expirarPorSilencio)`), `_expirarPorSilencio()` (reconfere corrida aceita e fase; chama `_encerrarCorridaAceita(() => _modalMotoristaSemSinalVisivel = true)`) e `_fecharModalMotoristaSemSinal`; cancelar o timer em `dispose`.
- [X] T006 [US1] Em `lib/screens/map_screen.dart`, chamar `_armarSilencio()` no fim de `_aceitarOrcamento` (depois do `setState` que entra em `orcamentoAceito`) e no fim de `_carregarEstadoCorrida` (depois de restaurar `orcamentoAceito`/`motoristaACaminho`); chamar também em `_encerrarCorridaAceita` (para cancelar, pois o estado já é `inicial`); e renderizar `DriverSilentModal` em `Stack` no `build()`, com o mesmo fundo `Colors.black54` das demais, **antes** de `_modalMotoristaIndisponivelVisivel` (precedência). T004 passa.

**Checkpoint**: US1 funcional e testável sozinha.

---

## Phase 3: User Story 2 — Sair de "motorista a caminho" quando o motorista some (Priority: P1)

**Goal**: cada sinal recomeça a contagem; 3 minutos sem sinal em "motorista a caminho" expiram.

- [X] T007 [US2] Em `lib/screens/map_screen.dart`, chamar `_armarSilencio()` em `_processarLocalizacaoMotorista`, depois das conferências de autor/`quoteId`/fase e depois do `setState` que trata a primeira localização — a cada sinal novo, inclusive com `content` inválido (FR-001, FR-002, FR-005).
- [X] T008 [US2] Acrescentar ao grupo de T004, em `test/screens/map_screen_test.dart`: (a) em "motorista a caminho", o prazo sem nova localização expira, a modal aparece e o marcador do motorista some (US2, cenário 1); (b) localizações chegando a menos do prazo uma da outra nunca expiram (SC-002, FR-005): entregar uma localização a cada meio prazo por vários prazos; (c) uma localização com `content` inválido também rearma a contagem (FR-002); (d) o mesmo evento reentregue (mesmo `id`) não rearma (borda). Se algum caso falhar, corrigir T007.

**Checkpoint**: US1 e US2 verdes.

---

## Phase 4: User Story 3 — A expiração não atinge a viagem nem avisos já tratados (Priority: P2)

**Goal**: sem expiração em "em corrida", contagem cancelada ao sair das duas fases, só sinais legítimos contam.

- [X] T009 [US3] Em `lib/screens/map_screen.dart`, chamar `_armarSilencio()` em `_confirmarEncontro` (depois do `setState` que entra em `emCorrida`, o que cancela a contagem) e em `_finalizarAvaliacao` (defensivo; o estado já é `inicial`) (FR-006).
- [X] T010 [US3] Acrescentar ao grupo de T004, em `test/screens/map_screen_test.dart`: (a) em "em corrida" (via `montarComEncontroConfirmado`), avançar o relógio muito além do prazo: nada acontece (US3 cenário 1, SC-003); (b) depois de confirmar o encontro com a contagem em andamento, avançar o relógio além do prazo: nada acontece (cenário 2); (c) depois de encerrar por `20012` (feature 019) ou `20006` (feature 020), avançar o relógio: nenhuma modal de expiração (cenário 3); (d) localização assinada por outra chave, ou referenciando outro orçamento, não rearma a contagem e a expiração segue no prazo original (cenário 4, FR-002); (e) reabrir o app (nova `MapScreen` sobre os mesmos stores) em "orçamento aceito": a contagem recomeça do zero e, depois do prazo, expira (edge case; FR-001); (f) reabrir depois de expirar, com a modal aberta: estado inicial, sem modal (SC-004); (g) depois de expirar, localização tardia da corrida expirada não traz o marcador de volta (FR-008).

---

## Phase 5: Polish & cross-cutting

- [X] T011 Rodar `flutter analyze` ("No issues found!") e `flutter test` (suíte completa; anotar o total) em `Prototipo/passenger/`.
- [X] T012 Conferir a modal nova contra a seção **Identidade Visual e Design** de `.specify/memory/constitution.md` (modal: `folha`, raio 24, título 20/800, ação primária `roxo` 48 px, raio 16); corrigir divergências.
- [X] T013 Registrar o estado da validação em aparelho em `specs/021-expirar-por-silencio/quickstart.md` (cenários 1–5; marcar pendente se não houver aparelho/emulador).
- [X] T014 Atualizar `../CLAUDE.md` (raiz do repositório): entrada da feature `021-expirar-por-silencio` do passageiro, em commit separado, no padrão das entradas anteriores; e atualizar `ESTADOS.md` e `FLUXOS_BPM.txt` (fluxo e lacuna L2, que passa a apontar esta feature como implementada).

---

## Dependencies & Execution Order

- Phase 1: T001 ∥ T002; T003 depende de T001.
- Phase 2: T004 → T005 → T006 (dependem de T002, T003).
- Phase 3 e 4 dependem de T006; T007 → T008; T009 → T010; T008 e T010 estão no mesmo arquivo: sequenciar.
- Polish depois de tudo.

### Parallel opportunities
- T001 ∥ T002 (arquivos diferentes).

## Implementation Strategy

1. Fundação (T001–T003): regra, modal e parâmetro de prazo.
2. MVP = Phases 1 e 2 (T001–T006): "orçamento aceito" expira por silêncio.
3. Phases 3–4 estendem a "motorista a caminho" e travam as proteções; Phase 5 fecha qualidade e documentação.
4. Sem contrato e sem mudança no motorista: a feature é validável só no passageiro; o ponta a ponta usa o motorista real ou simulado.

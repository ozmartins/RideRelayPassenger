---

description: "Task list for feature 002-nostr-relay-connection (passenger)"
---

# Tasks: Conexão do Passageiro com Relays Nostr

**Input**: Design documents from `specs/002-nostr-relay-connection/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md, contracts/nostr-events.md

**Tests**: obrigatórios. O Princípio II da constituição (NÃO NEGOCIÁVEL) exige teste automatizado, com
caso válido **e** inválido, para todo código que assina, verifica, deriva chaves ou descarta mensagem —
rodando sem rede e sem relay real.

**Organization**: tarefas agrupadas por user story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependências pendentes)
- Caminhos relativos à raiz do repositório do TCC

---

## Phase 1: Setup

- [X] T001 Adicionar as dependências executando em `Prototipo/passenger/`: `flutter pub add flutter_secure_storage shared_preferences` (decisões D2 e D3 de `research.md`)
- [X] T002 Declarar `<uses-permission android:name="android.permission.INTERNET"/>` em `Prototipo/passenger/android/app/src/main/AndroidManifest.xml` (FR-016, D6)
- [X] T003 Verificar que a permissão vale em produção: `flutter build apk --release` e `aapt2 dump permissions build/app/outputs/flutter-apk/app-release.apk` deve listar `android.permission.INTERNET` (FR-016)
- [X] T004 Criar os diretórios `Prototipo/passenger/lib/domain/` e `Prototipo/passenger/lib/services/` (D8)

**Checkpoint**: dependências instaladas, rede permitida em release, estrutura pronta.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: entidades de domínio com tipos próprios — pré-requisito de todos os serviços. Nenhuma
importa `dart_nostr` (Princípio III).

- [X] T005 [P] Criar `Prototipo/passenger/lib/domain/identity.dart` com `Identity` (`publicKey`, `privateKey`), validando 64 caracteres hexadecimais em ambas e sem `toString()` que exponha a chave privada (data-model.md, FR-005, Princípio I)
- [X] T006 [P] Criar `Prototipo/passenger/lib/domain/relay.dart` com `Relay` (`url`, `status`, `lastError`, `isDefault`) e o enum `RelayStatus` (`connecting`/`connected`/`unavailable`) (data-model.md)
- [X] T007 [P] Criar `Prototipo/passenger/lib/domain/nostr_event.dart` com `NostrEvent` (`id`, `authorPublicKey`, `createdAt`, `kind`, `content`, `isSignatureValid`) (data-model.md)
- [X] T008 Criar `Prototipo/passenger/lib/shared/default_relays.dart` com a constante `defaultRelays` contendo exatamente os três endereços fixados na decisão D7 de `research.md` — `wss://nos.lol`, `wss://relay.primal.net`, `wss://offchain.pub` — e conferir que `tool/check_relays.dart` espelha a mesma lista (D7; a lista em comum com o motorista é o que torna a US4 possível)
- [X] T008a Confirmar com quem mantém a app do motorista que ela adota a **mesma** lista padrão de D7; enquanto os dois lados não a compartilharem, registrar a User Story 4 como bloqueada (D7, obrigação de simetria)
- [X] T009 Definir as interfaces de dublê para injeção: contrato de armazenamento seguro e contrato de transporte de relay, em `Prototipo/passenger/lib/services/`, para que os testes não precisem de rede (D5, Princípio II)

**Checkpoint**: domínio pronto, sem nenhum tipo de terceiro vazando.

---

## Phase 3: User Story 2 — Identidade Nostr própria e estável (Priority: P1) 🎯 base

**Goal**: identidade criada uma vez, persistida no Keystore e recuperada nas execuções seguintes.

**Independent Test**: abrir, anotar a chave pública, fechar, reabrir e verificar que é a mesma.

> Implementada antes da US1 porque publicar e receber dependem dela, e porque é o código sujeito ao
> Princípio I — convém estabilizá-lo primeiro.

- [X] T010 [US2] Escrever `Prototipo/passenger/test/identity_service_test.dart` cobrindo: identidade criada na primeira execução; mesma identidade recuperada na segunda; chave fora do formato hexadecimal de 64 caracteres tratada como armazenamento corrompido; falha do armazenamento seguro reportada em vez de gerar identidade nova silenciosamente (cenários A1 e A2 do quickstart, FR-004, edge case de armazenamento)
- [X] T011 [US2] Implementar `Prototipo/passenger/lib/services/identity_service.dart` usando `dart_nostr` para gerar o par de chaves e `flutter_secure_storage` para persistir, até T010 passar (FR-004, D1, D2)
- [X] T012 [US2] Criar `Prototipo/passenger/lib/screens/identity_screen.dart` exibindo a chave pública em formato legível e copiável, **sem** exibir a chave privada por padrão (FR-006, US2 cenário 3)
- [X] T013 [US2] Escrever `Prototipo/passenger/test/screens/identity_screen_test.dart` verificando que a chave pública aparece e que a chave privada **não** aparece em nenhum widget da árvore (FR-005, SC-007)

**Checkpoint**: o passageiro tem identidade estável e verificadamente não vazada na UI.

---

## Phase 4: User Story 1 — Conectar a relays e ver o estado (Priority: P1)

**Goal**: conexão simultânea a múltiplos relays com estado observável e reconexão automática.

**Independent Test**: abrir com a lista padrão e ver os estados evoluírem sem travar a interface.

- [X] T014 [US1] Escrever `Prototipo/passenger/test/relay_service_test.dart` com dublês de transporte cobrindo: transição `connecting → connected`; transição `connecting → unavailable` com motivo; falha de um relay não afeta os demais; timeout de relay que aceita e não responde; retorno de rede dispara nova tentativa nos indisponíveis (cenários A9 e A10, FR-002, FR-003, FR-014, SC-003)
- [X] T015 [US1] Implementar `Prototipo/passenger/lib/services/relay_service.dart` (conexões, máquina de estados de `data-model.md`, reconexão) sobre `dart_nostr`, até T014 passar (FR-001, FR-002, FR-003, FR-014)
- [X] T016 [US1] Atualizar `Prototipo/passenger/lib/screens/home_screen.dart` para exibir o estado de cada relay em tempo real, substituindo o placeholder da feature 001 (FR-002, US1 cenário 1)
- [X] T017 [US1] Tratar ausência de rede e falhas de relay com mensagens compreensíveis, sem erro técnico cru nem travamento, em `Prototipo/passenger/lib/screens/home_screen.dart` (FR-015, US1 cenário 3)
- [X] T018 [US1] Compor as dependências em `Prototipo/passenger/lib/main.dart`, injetando armazenamento e transporte reais nos serviços (D5)

**Checkpoint**: o app conecta, mostra o estado e se recupera de queda de rede.

---

## Phase 5: User Story 3 — Publicar e receber eventos assinados (Priority: P1)

**Goal**: publicar evento de teste assinado e exibir eventos recebidos, verificados e deduplicados.

**Independent Test**: publicar um evento e vê-lo retornar pela assinatura de recepção.

- [X] T019 [US3] Escrever `Prototipo/passenger/test/event_feed_test.dart` cobrindo o **caso válido e o inválido** exigidos pelo Princípio II: evento com assinatura válida é aceito; com assinatura adulterada é descartado; com autor divergente da assinatura é descartado; com campo obrigatório ausente é descartado (cenários A3 e A4, FR-009)
- [X] T020 [US3] Acrescentar a `Prototipo/passenger/test/event_feed_test.dart` os casos de exibição: mesmo `id` vindo de dois relays aparece uma vez; kind desconhecido é ignorado sem erro; conteúdo com marcação é exibido como texto simples; evento de autor diferente do local traz o autor correto (cenários A5 a A8, FR-010, FR-018, FR-020)
- [X] T021 [US3] Implementar `Prototipo/passenger/lib/services/event_feed.dart` — assinatura de eventos nos relays, verificação de assinatura **antes** de qualquer processamento e deduplicação por `id` — até T019 e T020 passarem (FR-009, FR-010, D4, contrato regra 1 e 2)
- [X] T022 [US3] Implementar a publicação de evento de teste (`kind: 1`, conforme `contracts/nostr-events.md`) em `Prototipo/passenger/lib/services/relay_service.dart`, reportando aceitação ou recusa **por relay** (FR-007, US3 cenário 1)
- [X] T023 [US3] Atualizar `Prototipo/passenger/lib/screens/home_screen.dart` com a lista de eventos recebidos (autor, horário, conteúdo) e a ação de publicar, impedindo a publicação com explicação quando não houver relay conectado (FR-008, FR-020, US3 cenário 5)
- [X] T024 [US3] Limitar a janela de eventos mantidos em memória e verificar a responsividade sob rajada de ≥ 100 eventos em `Prototipo/passenger/test/event_feed_test.dart` (SC-006, edge case de volume)

**Checkpoint**: ida e volta comprovada com a própria app; toda a lógica criptográfica coberta por teste.

---

## Phase 6: User Story 5 — Gerenciar a lista de relays (Priority: P2)

**Goal**: adicionar, remover e persistir relays, com restauração da lista padrão.

**Independent Test**: adicionar, remover, reabrir e confirmar que a lista persistiu.

- [X] T025 [US5] Escrever `Prototipo/passenger/test/relay_repository_test.dart` cobrindo: endereço inválido recusado; duplicado recusado; lista persistida e restaurada; lista vazia sinalizada (cenários A11 e A12, FR-011, FR-012, FR-013)
- [X] T026 [US5] Implementar a persistência da lista de relays com `shared_preferences` (JSON com `url` + `isDefault`) em `Prototipo/passenger/lib/services/`, até T025 passar (FR-012, D3)
- [X] T027 [US5] Criar `Prototipo/passenger/lib/screens/relays_screen.dart` para listar, adicionar e remover relays, com validação de endereço e oferta de restaurar a lista padrão quando vazia (FR-011, FR-013, US5 cenários 1, 2 e 5)
- [X] T028 [US5] Garantir que remover um relay encerra a conexão e interrompe publicação e recepção por ele, em `Prototipo/passenger/lib/services/relay_service.dart` (US5 cenário 3)

**Checkpoint**: lista de relays sob controle do usuário e persistida.

---

## Phase 7: User Story 4 — Validação cross-app (Priority: P1) 🎯 experimento central

**Goal**: comprovar que o evento publicado pelo app do motorista chega verificado ao passageiro.

**Independent Test**: com as duas apps no mesmo aparelho e um relay em comum, publicar pelo motorista e
ver o evento aparecer no passageiro com o autor correto.

> **Dependência externa**: exige a feature 002 do motorista **implementada**. As tarefas automatizadas
> abaixo não dependem dela; as manuais sim.

- [X] T029 [US4] Confirmar que os testes de autoria e verificação já cobrem o caso cross-app com dublês — evento de `authorPublicKey` diferente da identidade local, assinado por outra chave, é aceito e atribuído ao autor correto — em `Prototipo/passenger/test/event_feed_test.dart` (US4 cenário 3, FR-020, D9)
- [X] T030 [US4] Executar o cenário X1 do `quickstart.md`: as duas apps no mesmo aparelho exibem chaves públicas **diferentes** (US2 cenário 5, SC-010)
- [X] T031 [US4] Executar os cenários X2, X3 e X4 do `quickstart.md`: evento publicado pelo motorista aparece no passageiro, com autor igual à chave pública do motorista e assinatura verificada (US4 cenários 1 a 3)
- [X] T032 [US4] Executar o cenário X5 do `quickstart.md`: sem relay em comum, o evento do motorista **não** chega — comprovando que o transporte é o relay e não um canal direto (US4 cenário 4)
- [X] T033 [US4] Medir SC-009 conforme o protocolo do `quickstart.md`: 10 repetições de X2, registrando cada intervalo, o relay, o tipo de rede e o aparelho. Relatar o resultado **mesmo se ficar abaixo do critério** (SC-009, Princípio V)

**Checkpoint**: hipótese central do TCC comprovada — ou refutada com medição registrada.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T033a Verificar que o contrato não derivou: `diff` entre `specs/002-nostr-relay-connection/contracts/nostr-events.md` (a partir da linha 11, abaixo do cabeçalho de procedência) e o arquivo correspondente em `Prototipo/driver`; qualquer diferença MUST ser resolvida com quem mantém a outra app antes de fechar a feature (FR-019, Princípio IV)
- [X] T033b Confirmar que a decisão D1 de `research.md` mantém as quatro alternativas com versão e data de publicação e os critérios aplicados, satisfazendo FR-017 e SC-008 de forma verificável
- [X] T033c Re-executar `dart run tool/check_relays.dart` imediatamente antes da validação da US4 e registrar o resultado; se algum relay padrão estiver fora, trocar pela reserva `wss://nostr.mom` **nos dois apps** antes de medir (D7)
- [X] T034 Executar a verificação de não vazamento do Princípio I conforme o `quickstart.md` (log, código-fonte e tráfego publicado) e **registrar o resultado** dos três itens (FR-005, SC-007, gate 4 da constituição)
- [X] T035 Executar os cenários manuais M1 a M10 do `quickstart.md` e relatar os que falharem, sem omitir (gate 3 da constituição)
- [X] T036 Rodar `flutter analyze` e `flutter test` e confirmar zero apontamentos e nenhum teste ignorado ou pendente (gates 1 e 2 da constituição)
- [X] T037 Atualizar `Prototipo/passenger/README.md` com as três telas, a nota de que o app agora exige rede, e o aviso de que desinstalar o app destrói a identidade (US2 cenário 4)
- [X] T038 Atualizar `CLAUDE.md` na raiz registrando que a app do passageiro passou a ter domínio, serviços e dependência de rede — edição cirúrgica, sem tocar no que descreve o `driver/`
- [X] T039 Commitar em português, descrevendo a mudança de comportamento e não os arquivos (gate 5 da constituição), com pathspec restrito a `Prototipo/passenger`

---

## Dependencies

**Ordem de fases**: 1 → 2 → 3 (US2) → 4 (US1) → 5 (US3) → 6 (US5) → 7 (US4) → 8.

- **Phase 2** bloqueia tudo: sem entidades de domínio, nenhum serviço compila.
- **US2 (identidade)** antes de **US1 (relays)**: publicar exige identidade, e é o código sob o
  Princípio I.
- **US3** depende de US1 e US2.
- **US5** depende de US1 (a lista alimenta as conexões); é P2 e pode ser adiada sem bloquear US4.
- **US4** depende de US1, US2 e US3 **e** da feature 002 do motorista implementada.
- **Phase 8** depende de todas.

**Ordem TDD dentro de cada story** (Princípio II): a tarefa de teste vem **antes** da implementação
correspondente — T010 antes de T011, T014 antes de T015, T019/T020 antes de T021, T025 antes de T026.

## Parallel Opportunities

- **Phase 2**: T005, T006 e T007 são arquivos independentes, marcados `[P]`.
- **Phase 3 a 6**: cada story toca serviços e telas próprios; o gargalo real é a ordem TDD dentro de
  cada uma, não o paralelismo entre arquivos.
- **Phase 7**: T029 (automatizado) é independente das tarefas manuais e da app do motorista.
- **Phase 8**: T037 e T038 tocam arquivos diferentes, mas T038 mexe em arquivo compartilhado com a
  outra sessão — fazer por último e conferir `git status` antes de commitar.

## Implementation Strategy

**MVP = Phases 1 a 5** (T001–T024): o app tem identidade, conecta a relays e comprova ida e volta
sozinho. Já é resultado apresentável.

**O experimento que sustenta o TCC é a Phase 7**, e ela depende de código mantido em outro projeto. Se a
feature 002 do motorista atrasar, as Phases 1 a 6 e 8 podem ser concluídas e a Phase 7 fica pendente,
explicitamente relatada como tal — nunca silenciada (gate final da constituição).

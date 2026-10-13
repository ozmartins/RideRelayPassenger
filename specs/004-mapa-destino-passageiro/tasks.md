---

description: "Task list for feature 004-mapa-destino-passageiro"
---

# Tasks: Mapa e Destino do Passageiro

**Input**: Design documents from `specs/004-mapa-destino-passageiro/`

**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, quickstart.md ✓ (sem
`contracts/` — feature sem interface externa, ver Constitution Check do `plan.md`)

**Tests**: por analogia ao Princípio II da constituição (NÃO NEGOCIÁVEL para código de assinatura e
verificação), o código que garante que o campo de destino nunca dispara publicação em relay (FR-008)
MUST ter teste cobrindo essa garantia, com dublê de relay, sem rede real. Por isso as tarefas de teste
abaixo são obrigatórias, não opcionais.

**Organization**: agrupadas por user story. Caminhos relativos a `Prototipo/passenger/`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependências pendentes)
- **[Story]**: US1 (ver a própria posição no mapa), US2 (informar o endereço de destino)

---

## Phase 1: Setup

**Purpose**: preparar as dependências de mapa e localização, e a permissão do sistema, antes de
qualquer código de domínio ou de tela

- [X] T001 Adicionar a dependência `geolocator ^14.0.3` ao `pubspec.yaml` com `flutter pub add`,
  conforme a decisão D1 já registrada em `specs/004-mapa-destino-passageiro/research.md`
- [X] T002 Adicionar as dependências `flutter_map ^8.3.2` e `latlong2 ^0.10.1` ao `pubspec.yaml` com
  `flutter pub add`, conforme a decisão D2 já registrada em `research.md`
- [X] T003 Declarar a permissão de localização em primeiro plano
  (`android.permission.ACCESS_FINE_LOCATION` e `android.permission.ACCESS_COARSE_LOCATION`) em
  `android/app/src/main/AndroidManifest.xml`, com comentário justificando o uso — constituição,
  *Restrições de Segurança e Privacidade*: nada de permissão "para o futuro", e esta é a feature que
  justifica por escrito o acesso a este dado sensível no app do passageiro

**Checkpoint**: dependências justificadas e instaladas, permissão declarada com justificativa

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: entidades de domínio e o serviço de localização — bloqueiam todas as user stories

**⚠️ CRITICAL**: nenhuma user story pode começar antes desta fase

- [X] T004 [P] Criar a entidade `PassengerPosition` em `lib/domain/passenger_position.dart`, com
  `latitude`, `longitude` e `capturedAt` (`data-model.md`)
- [X] T005 [P] Criar a entidade `DestinationAddress` em `lib/domain/destination_address.dart`, com o
  campo `text` (texto livre, aceitando vazio, sem validação — FR-007, `data-model.md`)
- [X] T006 [P] Escrever os testes de `DestinationAddress` em
  `test/domain/destination_address_test.dart`: aceita texto vazio, aceita texto qualquer sem validação
  de formato (FR-007)
- [X] T007 Definir a interface `LocationService` em `lib/services/location_service.dart` — fluxo de
  `PassengerPosition?` (nulo enquanto indisponível) e verificação/pedido de permissão —, mais as
  exceções `LocationPermissionDenied` e `LocationUnavailable`, seguindo o mesmo padrão de `SecureStore`
  e `RelayTransport` (Princípio III)
- [X] T008 Implementar `GeolocatorLocationService` em `lib/services/geolocator_location_service.dart`
  sobre `geolocator` — único arquivo que importa `package:geolocator` (Princípio III)

**Checkpoint**: domínio e serviço de localização prontos; `flutter analyze`/`flutter test` seguem
limpos com o código já existente das features anteriores

---

## Phase 3: User Story 1 - Ver a própria posição no mapa ao abrir o aplicativo (Priority: P1)

**Goal**: a tela inicial do aplicativo é um mapa centrado na posição real do aparelho, com um ícone de
carro que acompanha o deslocamento, e trata com clareza a ausência de permissão ou de localização.

**Independent Test**: abrir o aplicativo com localização disponível e verificar que a tela inicial é um
mapa centrado na posição real, com o ícone de carro; sem localização, verificar a mensagem
compreensível.

- [X] T009 [US1] Escrever os testes de `LocationService` em `test/services/location_service_test.dart`
  com um dublê em memória, cobrindo: o fluxo emite as posições publicadas, a ausência de permissão
  surge como `LocationPermissionDenied`, e a indisponibilidade (sinal perdido) surge como
  `LocationUnavailable`, distinta da ausência de permissão (FR-004, FR-005)
- [X] T010 [US1] Implementar `MapScreen` em `lib/screens/map_screen.dart`: mapa via `flutter_map` com
  mosaicos do OpenStreetMap (atribuição visível, `userAgentPackageName` configurado — D2 de
  `research.md`), centrado na última `PassengerPosition` recebida, com um ícone de carro (`Icons.
  directions_car` ou equivalente, consistente com o visual do app do motorista) naquele ponto,
  atualizado a cada nova posição do fluxo (FR-001, FR-002, FR-003)
- [X] T011 [US1] Em `MapScreen`, solicitar a permissão de localização ao entrar na tela quando ainda
  não concedida, explicando o motivo, e exibir mensagem compreensível — sem travar nem erro técnico
  cru — quando a permissão for negada ou a localização estiver indisponível (FR-004, FR-005, edge case
  de permissão negada permanentemente)
- [X] T012 [US1] No `main.dart`, no bootstrap, instanciar `LocationService` e tornar `MapScreen` a
  primeira aba de uma barra de navegação inferior nova, com a `HomeScreen` atual (lista de eventos)
  deslocada para a aba seguinte, e as telas de Identidade e Relays continuando acessíveis (Structure
  Decision do `plan.md`)
- [X] T013 [US1] Escrever o teste de widget em `test/screens/map_screen_test.dart` verificando: o
  ícone de carro aparece quando o dublê de `LocationService` emite uma posição, e a mensagem de
  indisponibilidade aparece no lugar dele quando o dublê emite ausência ou lança as exceções de T009

**Checkpoint**: abrir o app mostra o mapa na posição real com o ícone de carro (ou a mensagem
adequada), e o indicador acompanha novas posições emitidas

---

## Phase 4: User Story 2 - Informar o endereço de destino (Priority: P2)

**Goal**: um campo de texto na mesma tela de mapa permite ao passageiro informar para onde deseja ir,
sem depender da posição estar disponível e sem disparar nenhuma comunicação de rede.

**Independent Test**: com o mapa exibido, tocar no campo de destino, digitar um endereço e verificar
que o texto fica visível, sem nenhuma chamada de publicação disparada.

**Depende de**: US1 (a tela que esta história reaproveita).

- [X] T014 [US2] Acrescentar a `MapScreen` (T010) um `TextField` de destino com
  `TextEditingController`, texto de apoio "Para onde você quer ir?" quando vazio, refletindo sempre o
  valor mais recente digitado (FR-006, FR-009, cenário de campo vazio). O widget MUST não receber
  nem depender de `RelayService`/`EventFeed` — apenas de `LocationService`, para que a ausência
  estrutural de qualquer referência a relay evidencie FR-008
- [X] T015 [US2] Garantir em `MapScreen` que o campo de destino funciona (aceita e reflete texto)
  independentemente do estado de `LocationService` — disponível, indisponível ou com permissão negada
  (FR-010)
- [X] T016 [US2] Escrever os testes de widget em `test/screens/map_screen_test.dart` cobrindo: digitar
  um endereço reflete o texto no campo; alterar ou apagar o texto atualiza o campo para o valor mais
  recente; digitar um endereço com o dublê de `LocationService` emitindo `LocationUnavailable` ou
  `LocationPermissionDenied` funciona normalmente (FR-010); e — usando um dublê de `RelayService` que
  falha o teste caso qualquer método de publicação seja chamado — nenhuma publicação ocorre como
  consequência de digitar, alterar ou apagar o texto do campo de destino (FR-008, SC-004)

**Checkpoint**: o campo de destino reflete o texto digitado, funciona com ou sem localização
disponível, e nenhuma ação nele publica em relay

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: fechar os gates da constituição (seção *Fluxo de Desenvolvimento e Gates*)

- [X] T017 Executar `flutter analyze` em `Prototipo/passenger/` até obter `No issues found!` (gate 1)
- [X] T018 [P] Executar `dart format lib test` em `Prototipo/passenger/` e confirmar que nada ficou
  fora do padrão
- [X] T019 Executar `flutter test` em `Prototipo/passenger/` e confirmar aprovação integral, **sem
  nenhum teste ignorado ou marcado como pendente** (gate 2)
- [X] T020 Executar os 7 cenários de `specs/004-mapa-destino-passageiro/quickstart.md` em
  emulador/aparelho com localização simulável, registrando o resultado de cada um — cenários que
  falharem devem ser **relatados, não omitidos** (gate 3), com o tempo de SC-001/SC-002/SC-003
  efetivamente medido, não estimado (Princípio V)
- [X] T021 [P] Atualizar `Prototipo/passenger/README.md` com o escopo desta feature e as novas
  dependências
- [X] T022 [P] Atualizar a seção "Protótipo" de `/home/oseias/Documentos/ufsc/TCC/CLAUDE.md` com o
  novo estado do `passenger/`
- [ ] T023 Commitar em português descrevendo a mudança de comportamento, não os arquivos tocados
  (gate 5, Padrão de Commits) — sem contrapartida em `Prototipo/driver`, pois esta feature não toca o
  contrato de eventos (Constitution Check do `plan.md`)

---

## Dependencies & Execution Order

```text
Phase 1 (Setup: T001–T003)
        ↓
Phase 2 (Foundational: T004–T008)
        ↓
Phase 3 (US1 · mapa e posição: T009–T013)
        ↓
Phase 4 (US2 · destino: T014–T016)   ← reaproveita MapScreen e LocationService de US1
        ↓
Phase 5 (Polish: T017–T023)
```

- **T001–T003 não dependem de nenhum registro pendente**: D1 e D2 já estão em `research.md` desde a
  fase de planejamento, resolvidos antes da geração de tarefas.
- **US2 depende de US1** na prática (reaproveita a tela), embora seja independentemente **testável**
  uma vez que US1 exista — mesma relação já usada entre US1 e US2 da feature 004 do motorista.

## Parallel Opportunities

- Phase 2: `T004`, `T005` e `T006` em paralelo (entidades de domínio e seus testes, sem dependência
  mútua).
- Phase 5: `T018`, `T021` e `T022` em paralelo.
- Dentro de cada história, teste → implementação é sequencial por construção (Princípio II por
  analogia).

## Implementation Strategy

**MVP**: Phases 1–3 (T001–T013). Ao final, o passageiro abre o aplicativo e vê sua posição real no
mapa, com o ícone de carro — a demonstração central da US1.

**Incremento 2**: Phase 4 (T014–T016) — o campo de destino, que dá ao passageiro um lugar para
registrar a intenção de ir a algum lugar, preparando o terreno para uma feature futura que decida como
essa intenção é comunicada.

**Fechamento**: Phase 5 (T017–T023) — os gates da constituição.

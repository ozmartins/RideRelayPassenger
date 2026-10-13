# Tarefas: 026-conexao-em-segundo-plano

**Entrada**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/service-channel.md](contracts/service-channel.md). **App**: `passenger/` (caminhos relativos a `Prototipo/passenger/`
salvo indicação). Testes são exigidos pela constituição (Princípio II) e pelo SC-002/003/005/007.
**Formato**: `- [ ] Tnnn [P] [USn] descrição com caminho` · `[P]` = paralelizável (arquivos distintos).

## Fase 1 — Pré-requisitos e setup

- [X] T001 Emendar as constituições para **2.15.0** (estender a exceção de segundo plano da 2.14.0 ao passageiro, condição de decidir só por dados públicos; ver plan.md): `.specify/memory/constitution.md`, `../driver/.specify/memory/constitution.md` e conferir `../.specify/memory/constitution.md`; conferir por `diff` dos corpos; **commit separado do código** (gate do plan.md)
- [X] T002 Spike curto no passageiro (cenário 1 do quickstart): serviço de teste com `specialUse` no manifesto do passageiro, WebSocket real, deslizar dos recentes; registrar o resultado em `research.md` (D3); se falhar, parar e voltar ao usuário
- [X] T003 Adicionar `flutter_foreground_task: ^11.0.3` e `flutter_local_notifications: ^22.3.1` em `pubspec.yaml` com comentário da decisão (Princípio III, D2) e rodar `flutter pub get`
- [X] T004 [P] Ajustar `android/app/src/main/AndroidManifest.xml`: `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `POST_NOTIFICATIONS`, `<service>` do plugin com `<property PROPERTY_SPECIAL_USE_FGS_SUBTYPE>`, remover `WAKE_LOCK` e o receptor de boot (`tools:node="remove"`); sem `stopWithTask`
- [X] T005 [P] Habilitar *core library desugaring* em `android/app/build.gradle.kts` (`isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs:2.1.5`)

## Fase 2 — Fundação (bloqueia as histórias)

- [X] T006 Criar a interface `RelayHub` em `lib/services/relay_hub.dart` (relays, current, messages, connectedUrls, hasAnyConnected, start, add, remove, retryUnavailable, subscribe, broadcast, enableAutoRetry, dispose) e fazer `RelayService` a implementar em `lib/services/relay_service.dart`, sem mudar comportamento
- [X] T007 Trocar o tipo `RelayService` por `RelayHub` em `lib/services/event_feed.dart`, `lib/screens/map_screen.dart`, `lib/screens/home_screen.dart`, `lib/screens/relays_screen.dart` e `lib/main.dart`; `flutter analyze` limpo e suíte existente verde
- [X] T008 [P] Criar `ServiceState` (data-model) em `lib/domain/service_state.dart` com (de)serialização e testes em `test/domain/service_state_test.dart`
- [X] T009 [P] Criar `BackgroundNotificationRule` em `lib/domain/background_notification_rule.dart` (data-model; conferir em `MapScreen` qual guarda de `PassengerRideRules` cada kind usa) e testes em `test/domain/background_notification_rule_test.dart`: aceita cada um dos 5 kinds no estado certo; recusa `20005`/`20011`, `p` alheio, autor ou `e` errados, estado errado
- [X] T010 [P] Criar o contrato de mensagens em `lib/services/background/service_messages.dart` (conforme `contracts/service-channel.md`; versão `v`, desconhecida ignorada) e testes em `test/services/background/service_messages_test.dart`
- [X] T011 [P] Criar `ServiceStateStore` sobre `KeyValueStore` (prefixo `background.`) em `lib/services/background/service_state_store.dart` e testes de ida e volta em `test/services/background/service_state_store_test.dart`
- [X] T012 Criar `RelayHostCore` (núcleo sem plugin) em `lib/services/background/relay_host_core.dart`: verifica assinatura (id recalculado) com `NostrEventVerifier`, marcador e deduplicação antes de tudo; com a UI à vista repassa mensagens cruas; sem ela decide por `BackgroundNotificationRule`, retém por 5 min e chama o notificador; testes em `test/services/background/relay_host_core_test.dart` (inválido, duplicado, sem marcador, retenção, expiração, `20005` nunca retido) — dependência: T008–T011

## Fase 3 — US1: avisado de mensagem do motorista com o app fechado (P1)

**Objetivo**: notificação + tratamento normal ao tocar. **Teste independente**: quickstart cenários 2–5.

- [X] T013 [P] [US1] Criar `RideMessageNotifier` (flutter_local_notifications, canal `ride_messages` de alta importância, textos fixos do FR-006, toque abre o app) em `lib/services/ride_message_notifier.dart`, com interface para dublê e teste de que nenhum texto contém dado de terceiros em `test/services/ride_message_notifier_test.dart`
- [X] T014 [US1] Criar `RelayTaskHandler` em `lib/services/background/relay_task_handler.dart`: hospeda `RelayService` + `WsRelayTransport` + `RelayHostCore`, lê relays do `RelayRepository` no `onStart`, trata `subscribe`/`broadcast`/relays/`hello` do canal
- [X] T015 [US1] Criar `RemoteRelayHub` (implementa `RelayHub`) em `lib/services/remote_relay_hub.dart`: espelha `relaysChanged`, devolve `connectedUrls` do espelho de forma síncrona em `broadcast`, enfileira comandos até `ready`; testes com canal dublê em `test/services/remote_relay_hub_test.dart`
- [X] T016 [US1] Criar `BackgroundService` (única fronteira com `flutter_foreground_task`: iniciar/parar/estado/canal) em `lib/services/background/background_service.dart`
- [X] T017 [US1] Compor em `lib/main.dart`: `RemoteRelayHub` em produção, `RelayService` quando `relayService`/dublê injetado (todos os testes); inicializar o serviço ao abrir o app
- [X] T018 [US1] Em `lib/screens/map_screen.dart`, emitir `ServiceState` a cada mudança de estado de corrida/solicitação/corrida aceita e observar o ciclo de vida do app (`appInForeground`); sem reescrever a tela
- [X] T019 [US1] Reentrega: tratar `helloAck.pending` como mensagens normais por `EventFeed`, sem duplicar (dedupe por `id`); teste em `test/services/background/remote_relay_hub_test.dart` (EventFeed sobre `RemoteRelayHub` + núcleo) e um de widget em `test/screens/map_screen_test.dart` (mensagem retida abre a lista de orçamentos / modal)
- [X] T020 [P] [US1] Teste de não vazamento em `test/services/background/no_secret_leak_test.dart`: imports de `lib/services/background/` sem `identity_service`/`flutter_secure_store`; tráfego do canal em cenário simulado sem chave nem texto decifrado (SC-007)

## Fase 4 — US2: saber que o app ouve e parar quando não há corrida (P1)

**Teste independente**: quickstart cenários 6 e 8.

- [X] T021 [US2] Criar `ServiceController` em `lib/services/background/service_controller.dart`: decide iniciar/manter/encerrar por `appInForeground` e estado de corrida, textos da fixa ("Acompanhando sua corrida" / discreta); testes em `test/services/background/service_controller_test.dart` (tabela do ciclo de vida do plan.md)
- [X] T022 [US2] Pedir `POST_NOTIFICATIONS` só ao solicitar a primeira corrida e avisar se negada (serviço não sobrevive à saída do app) em `lib/screens/map_screen.dart` e `lib/services/background/background_service.dart`; teste de widget em `test/screens/map_screen_test.dart`
- [X] T023 [US2] Encerrar o serviço ao fim da corrida com o app fora de primeiro plano (corrida concluída, cancelada, expirada, solicitação cancelada) ligando `MapScreen` ao `ServiceController`; teste em `test/services/background/service_controller_test.dart`

## Fase 5 — US3: conexão sobrevive a quedas em segundo plano (P2)

**Teste independente**: quickstart cenário 7.

- [X] T024 [US3] Conferir no `RelayTaskHandler` (T014) o reenvio da inscrição a cada conexão, a retentativa e a sonda de vivacidade já existentes em `RelayService` rodando no isolate (`enableAutoRetry`); teste em `test/services/background/service_reconnection_test.dart` com `RelayTransport` dublê que cai e volta
- [X] T025 [US3] Ligar "Reconectar" da tela de Relays ao comando `retryUnavailable` do canal em `lib/services/remote_relay_hub.dart`; teste em `test/services/remote_relay_hub_test.dart`

## Fase 6 — Acabamento e validação

- [X] T026 Rodar `flutter analyze` (limpo) e a suíte completa em dois lotes (`test/screens/map_screen_test.dart` e o restante); nenhum teste anterior regride (SC-005)
- [X] T027 Compilar o apk de debug e instalar no emulador `Pixel_6_API34_1` (reinstalar antes de medir: o snapshot desfaz instalações)
- [ ] T028 Executar os cenários 2–10 do `quickstart.md` e registrar resultados (inclusive falhas) em `quickstart.md`, marcando o que foi só emulador — **parcial**: 2, 4 (parte) e 6 feitos no emulador; 3, 7, 8, 9, 10 pendentes
- [ ] T029 Medir SC-001 (10 amostras — **feito no emulador**), SC-004 e SC-006 (**pendentes**); registrar método e números reais em `quickstart.md` (Princípio V); se não medir bateria, dizer que não foi medida
- [ ] T030 Atualizar `../../CLAUDE.md` (entrada `026-conexao-em-segundo-plano` do passageiro e constituição 2.15.0) e `../CLAUDE.md` se tocar o texto técnico; commit separado, padrão de commits em português, direto na `master`

## Dependências

Fase 1 → Fase 2 → US1 → US2 → US3 → Fase 6. T001 antes de qualquer código (gate). T006→T007; T012 depende de T008–T011; T014–T018 dependem de T006, T010, T012, T013; T021 depende de T016; T022/T023 de T018 e T021.

## Paralelismo

T004‖T005; T008‖T009‖T010‖T011; T013‖T020 (após T012).

## Estratégia

MVP = Fase 1 a US1 (notificação funcionando com app fechado). US2 evita gasto sem corrida e é parte do P1, então entra antes de validar. US3 só valida o que a arquitetura já traz.

# Plano de implementação: 026-conexao-em-segundo-plano

**Spec**: [spec.md](spec.md) · **App**: `passenger/` · **Data**: 2026-10-12 · **Referência**: `driver/specs/025-conexao-em-segundo-plano/`
(mesma arquitetura, adaptada; o código das apps não é espelho)

## Resumo

Mover a conexão com os relays (`RelayService` + `WsRelayTransport`) para o isolate de um **serviço em primeiro
plano do Android**, vivo enquanto o app está visível **ou** há solicitação/corrida ativa. A interface passa a usar
a conexão por uma interface (`RelayHub`), implementada por `RelayService` (testes e serviço) e por
`RemoteRelayHub` (produção, por mensagens). O serviço verifica assinatura, marcador e duplicidade e, com o app
fora de primeiro plano, decide a notificação **só por dados públicos** do evento (kind, autor, tags `p`/`e`) com
uma regra pura compartilhada (`BackgroundNotificationRule`), sem decifrar. Sem FCM, sem servidor, sem contrato
novo.

## Contexto técnico

- **Linguagem/SDK**: Dart ^3.13.3, Flutter 3.47.7, Android apenas.
- **Dependências novas** (Princípio III; [research.md](research.md)): `flutter_foreground_task` 11.0.3,
  `flutter_local_notifications` 22.3.1 — as mesmas da 025 (`pub add --dry-run` resolve no passageiro em
  2026-10-12; traz `timezone`).
- **Armazenamento**: `KeyValueStore` (SharedPreferences) para o estado que o serviço relê ([data-model.md](data-model.md)).
  Sem tabela SQLite nova.
- **Testes**: `flutter_test` com dublês; nenhum teste toca rede, serviço Android ou notificação reais.
- **Alvo**: Android 13+ (`POST_NOTIFICATIONS`); tipo de serviço exigido no 14+.
- **Restrições**: chave privada/semente nunca no serviço e sem decifração lá (Princípio I); assinatura verificada
  antes de tudo (II/IV); tipos de plugin confinados a `services/` (III).
- **Escala**: três relays padrão; tráfego esparso; `20005` a cada 5 s não é notificado nem retido.

## Verificação da constituição (2.14.0)

| Princípio / restrição | Situação |
|---|---|
| I — segredo não vaza | OK por construção: serviço sem chave, sem decifração; só repassa mensagens cruas do relay e publica o que a interface já assinou/cifrou. Teste de não vazamento (imports + tráfego do canal), como na 025. |
| II — assinatura nasce com teste | OK: reutiliza `NostrEventVerifier`; testes novos na fronteira do serviço (inválido, duplicado, sem marcador) e da regra de notificação (autor, tag, estado, kind). |
| III — dependência registrada | Em `research.md` (D2). Tipos de plugin só em `services/background/` e no notificador. |
| IV — contrato antes do código | Nenhum evento novo. Contrato interno UI↔serviço em [contracts/service-channel.md](contracts/service-channel.md). |
| V — simplicidade | `RelayHub` nasce com duas implementações reais; medições SC-001/004/006 serão feitas de fato. |
| Execução em segundo plano / notificação | **Exceção 2.14.0 vale só para o motorista** ("O app do motorista pode manter…"). **Gate**: emenda **2.15.0** nas duas apps (e conferir a de `Prototipo/`), commit à parte, **antes** do código. Texto abaixo. |
| Permissões | `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `POST_NOTIFICATIONS` usadas; `WAKE_LOCK` removida da mescla (`tools:node="remove"`), como na 025. Sem localização em segundo plano. |
| Dados fora de relay | Nada novo sai do aparelho; notificação é local. |
| Identidade visual | Notificação do sistema; ícone/cor `roxo`. Sem tela nova. |

**Emenda 2.15.0 (texto proposto):** na exceção de segundo plano, trocar "O app do motorista" por "Os apps do
motorista e do passageiro" e acrescentar: no passageiro o serviço fica ativo enquanto o app está visível ou há
solicitação ou corrida ativa; MUST NOT ler a chave privada nem decifrar; a decisão de notificar usa apenas kind,
autor e tags do evento; a notificação MUST NOT conter nome, placa, endereço, coordenada nem chave de terceiros.
Mantêm-se as demais condições (iniciado pela interface com o app visível, nunca no boot, sem push de terceiros).

## Estrutura do código

```text
passenger/lib/
├── domain/
│   ├── background_notification_rule.dart  # novo: regra pura (kind/autor/tag p,e/estado) -> tipo de aviso ou null
│   └── service_state.dart                 # novo: estado que o serviço relê (pubkey, status, solicitação, corrida)
├── services/
│   ├── relay_hub.dart                     # novo: interface (relays, current, messages, connectedUrls, hasAnyConnected,
│   │                                      #   start, add, remove, retryUnavailable, subscribe, broadcast, enableAutoRetry, dispose)
│   ├── relay_service.dart                 # implements RelayHub (sem mudar comportamento)
│   ├── remote_relay_hub.dart              # novo: lado da interface; espelha relays e fala com o serviço
│   ├── ride_message_notifier.dart         # novo: flutter_local_notifications (canal de alta importância)
│   └── background/
│       ├── service_messages.dart          # novo: (de)serialização do canal
│       ├── relay_host_core.dart           # novo: núcleo sem plugin — verifica, deduplica, decide, retém 5 min
│       ├── relay_task_handler.dart        # novo: TaskHandler — hospeda RelayService + WsRelayTransport
│       ├── service_controller.dart        # novo: ciclo de vida e texto da notificação fixa
│       └── background_service.dart        # novo: única fronteira com flutter_foreground_task
├── screens/map_screen.dart                # tipo do parâmetro -> RelayHub; informa estado ao serviço; ciclo de vida
├── screens/{home,relays}_screen.dart      # idem (tipo)
├── services/event_feed.dart               # tipo -> RelayHub
└── main.dart                              # compõe RemoteRelayHub em produção; RelayService nos testes
passenger/android/app/src/main/AndroidManifest.xml  # permissões, <service>, remoções
passenger/android/app/build.gradle.kts              # core library desugaring
passenger/test/{domain,services,services/background}/…
```

**Decisão de estrutura**: tudo que roda no isolate do serviço fica em `services/background/` (revisão de vazamento).
**Diferença para o motorista**: o passageiro monta o protocolo `REQ`/`EVENT`/`OK` à mão (`EventFeed` + `RelayService.messages`
cru). Logo o canal repassa **mensagens cruas** do relay e a inscrição (`subscribe`) e o `broadcast` atravessam como
texto; o `OK` volta pelo mesmo fluxo de mensagens, sem `publishResult` próprio.

## Ciclo de vida do serviço

`app abre → serviço inicia (discreto)` · `solicitação/corrida ativa → "Acompanhando sua corrida"` · `app sai &
sem corrida → encerra` · `app sai & com corrida → continua` · `corrida termina com app fechado → encerra`.
Android 14+ só permite iniciar o serviço com o app visível: sempre iniciado pela UI (abertura do app), nunca por
receptor nem no boot. Ao reabrir com o serviço vivo: handshake de estado e reentrega das mensagens retidas (≤ 5 min).

## Riscos

1. Notificação sem decifrar pode disparar por conteúdo forjado ou ilegível — aceito (spec, bordas); a interface
   descarta ao abrir.
2. `MapScreen` (1799 linhas): trocar só o tipo do parâmetro e acrescentar a emissão de estado; sem reescrita.
3. O relógio de silêncio (021) não corre com o app fechado: fora de escopo, documentado.
4. Fabricantes com economia de bateria agressiva e "Forçar parada": limitação.
5. Spike da 025 já provou sobrevivência ao deslizar dos recentes, Doze forçado e queda de rede com o mesmo
   plugin; **repetir um spike curto no passageiro** (T001) antes da refatoração, por ser outro app/manifesto.

## Complexity Tracking

Sem violação injustificada. A emenda 2.15.0 é pré-requisito (gate), não exceção.

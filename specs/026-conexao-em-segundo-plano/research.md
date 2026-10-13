# Pesquisa: 026-conexao-em-segundo-plano

Decisões D1–D3 reaproveitam a [pesquisa da 025 do motorista](../../../driver/specs/025-conexao-em-segundo-plano/research.md)
(spike do mesmo plugin no emulador API 34, 2026-10-11); aqui só o que muda ou precisa ser repetido.

## D1 — Mecanismo

**Decisão**: serviço em primeiro plano do Android com notificação local; sem FCM/UnifiedPush. Alternativas
(FCM, servidor observando o relay, WorkManager, engine em cache) descartadas pelos mesmos motivos da 025: quebram
"sem intermediário" ou não mantêm conexão contínua. Eventos são efêmeros, então não há como "buscar depois".

## D2 — Pacotes (Princípio III)

`flutter_foreground_task` 11.0.3 (2026-09-07) e `flutter_local_notifications` 22.3.1 (2026-09-13), as mesmas versões
da 025. `flutter pub add --dry-run` no passageiro (2026-10-12) resolve sem conflito (adiciona `timezone` 0.11.2 e
atualiza 7 dependências transitivas). Alternativas (`flutter_background_service`, Kotlin próprio) como na 025.
**Acoplamento**: só em `services/background/` e `ride_message_notifier.dart`. Cita a exceção da constituição 2.15.0.

## D3 — Tipo do serviço

`specialUse` (D3 da 025, confirmado no spike). Manifest: `FOREGROUND_SERVICE_SPECIAL_USE`, `<property
PROPERTY_SPECIAL_USE_FGS_SUBTYPE>`, `WAKE_LOCK` removida (`tools:node="remove"`), core library desugaring.
Sem `stopWithTask`.

### Verificação no passageiro (T002) — 2026-10-12, emulador API 34

Feita com o próprio app implementado em vez de um app descartável: `specialUse` inicia o serviço no manifesto do
passageiro (`types=0x40000000`), o WebSocket do `RelayService` roda no isolate do serviço (3 sockets), o serviço e o
processo sobrevivem à remoção dos recentes e geram a notificação de alta importância. Detalhes e números em
`quickstart.md`. Doze forçado e queda de rede não foram repetidos aqui (valem os resultados da 025).

## D4 — Onde a conexão vive

Toda no isolate do serviço; a UI usa `RemoteRelayHub`. Consequência: serviço também com app visível e sem corrida.
`RelayService` já é Dart puro sobre `RelayTransport`, então roda no isolate com `WsRelayTransport` sem mudança
(ao contrário do motorista, que precisou de `NostrRelayGateway`). Nada de `dart_nostr` além do verificador de
assinatura, que o serviço usa e que não toca em chave privada.

## D5 — O que cruza o canal

Primitivos apenas. Do serviço à UI: **mensagens cruas do relay** (`RelayMessage{url,payload}`), já que o `EventFeed`
as interpreta (EVENT/OK) e mantém a verificação própria (defesa em profundidade). Da UI ao serviço: `subscribe`
(id + texto do REQ, para o serviço reenviar a cada conexão — "inscrição é estado de conexão"), `broadcast` (texto
do EVENT já assinado e cifrado), comandos de relay. `broadcast` precisa devolver de forma síncrona as URLs
destino: a `RemoteRelayHub` espelha a lista de relays (`relaysChanged`) e devolve `connectedUrls` do espelho; o
`OK` volta como mensagem crua e o `EventFeed` o correlaciona como hoje. Chave privada nunca cruza o canal.

## D6 — Regra de notificação sem decifrar (diferença central para a 025)

Os kinds `20002`, `20006`, `20007`, `20009`, `20012` chegam cifrados (NIP-44, emenda 17). O serviço não tem a chave
(Princípio I), então decide por dados públicos: kind ∈ notificáveis, tag `p` = chave pública do passageiro, autor e
tag `e` conforme o estado, e `PassengerRideRules` (mesmas guardas que a UI usa). `20005` e `20011` nunca notificam.
**Alternativa descartada**: levar a chave ao serviço para decifrar e validar o conteúdo — viola o Princípio I e a
2.14.0; ganho (evitar notificação por conteúdo forjado) não compensa. **Consequência aceita**: quem tem a chave de
assinatura do motorista da corrida pode causar uma notificação; sem efeito no estado.

## D7 — Estado que o serviço precisa

`pubkey` do passageiro (pública), `rideStatus`, `requestId` (solicitação ativa, já persistido por
`PassengerRideStateStore`), `quoteId` e `driverPubkey` (de `AcceptedRide`), `appInForeground` (só memória).
Origem: UI, mensagem `state`, **persistido** em `KeyValueStore` (prefixo `background.`) e relido pelo serviço
(`SharedPreferences.reload()` ao iniciar; isolates não compartilham cache).

## D8 — Retenção e reentrega

O serviço guarda em memória, por 5 min, as mensagens **aprovadas pela regra** recebidas sem UI à vista (e só
elas); reentrega no handshake. O `id` evita duplicata. Sem persistência em disco.

## D9 — Notificação

Canal `ride_messages` (importância alta); id por evento; textos fixos por tipo (spec FR-006); canal `service`
(baixa) para a fixa. `POST_NOTIFICATIONS` pedida ao solicitar a primeira corrida (FR-009). Toque abre a
`MainActivity`. A tela existente trata a mensagem retida ao abrir.

## D10 — Medições (Princípio V)

SC-001 (10 amostras), SC-004, SC-006, método no quickstart; nenhum número no TCC sem ser medido.

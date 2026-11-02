# Modelo de dados: 026-conexao-em-segundo-plano

Sem tabela SQLite nova. Entidades são mensagens do canal e valores em `KeyValueStore`.

## ServiceState (UI → serviço; persistido, exceto `appInForeground`)
| Campo | Tipo | Regra |
|---|---|---|
| `passengerPubkey` | string (hex) | chave **pública**; nunca a privada |
| `rideStatus` | nome de `PassengerRideStatus` | só `aguardandoOrcamentos`…`emCorrida` mantêm o serviço vivo |
| `requestId` | string? | `id` do `kind: 20001` ativo (de `PassengerRideStateStore`) |
| `quoteId`, `driverPubkey` | string? | de `AcceptedRide`, quando há corrida aceita |
| `appInForeground` | bool | só memória; ao reiniciar o serviço assume `false` |

## BackgroundNotificationRule (domain, puro)
Entrada: payload do evento (já verificado), `ServiceState`. Saída: `NotificationKind?` —
`novoOrcamento` (20002), `motoristaChegou` (20007), `chegouAoDestino` (20009), `canceladaPeloMotorista` (20012),
`motoristaIndisponivel` (20006) — ou `null`. Condições: `p` = `passengerPubkey`; para 20002: status
`aguardandoOrcamentos` e `e` = `requestId`; para os demais: autor = `driverPubkey`, `e` = `quoteId` e a guarda de
`PassengerRideRules` do estado (`canNotifyMovement`/`canConfirmDestinationArrival`/`canBeCancelledByDriver`/
`canBeDeclinedByDriver`, conferindo no código qual guarda cada kind usa hoje em `MapScreen`). Mesma função na UI
(teste de paridade) e no serviço.

## PendingMessage (serviço, memória)
`{ relayUrl, payload (texto cru), receivedAt }`; descartada com 5 min; reentregue no handshake.

## ServiceMessage
Ver [contracts/service-channel.md](contracts/service-channel.md).

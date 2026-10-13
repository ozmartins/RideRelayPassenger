# Data Model: Confirmar encontro com o motorista e chegada ao destino

## AcceptedRide (domínio, `lib/domain/accepted_ride.dart`) — alterado

Dois campos novos, junto de `movementNotified` (feature 009):

| Campo | Tipo | Observação |
|---|---|---|
| `meetingConfirmed` | `bool` | Falso por padrão; `true` desde o instante em que a modal de confirmação de encontro abre (D1 de `research.md`) — controla FR-004. |
| `destinationConfirmed` | `bool` | Falso por padrão; `true` desde o instante em que a modal de confirmação de destino abre — controla FR-008. |

## EventFeed (serviço, `lib/services/event_feed.dart`) — alterado

Novas constantes de kind (todos já definidos pela feature 012 do motorista, emenda 11):

```dart
const driverArrivalKind = 20007;       // consumido, primeira vez nesta feature
const meetingConfirmedKind = 20008;    // publicado
const destinationArrivalKind = 20009;  // consumido
const destinationConfirmedKind = 20010; // publicado
```

Dois métodos de publicação novos, por analogia a `publishQuoteAcceptance`:

```dart
Future<PublishReport> publishMeetingConfirmation(String quoteId, String driverPubkey, Identity identity);
Future<PublishReport> publishDestinationConfirmation(String quoteId, String driverPubkey, Identity identity);
```

## Fluxo (visão geral)

```text
[corrida aceita, AcceptedRide.meetingConfirmed == false]
                    |
        kind 20007 recebido, referencedEventId == quoteId
                    |
                    v
        DriverArrivedModal exibida; meetingConfirmed = true (persistido)
                    |
        toque em "Confirmo que encontrei o motorista"
                    |
                    v
        publica kind 20008; modal fecha
                    |
        (feature 012 do motorista: Em corrida → chegada ao destino → kind 20009)
                    |
        kind 20009 recebido, referencedEventId == quoteId, destinationConfirmed == false
                    |
                    v
        DestinationArrivedModal exibida; destinationConfirmed = true (persistido)
                    |
        toque em "Confirmo que chegamos ao destino"
                    |
                    v
        publica kind 20010; modal fecha
```

## Contrato (já definido pela feature 012 do motorista — ver `contracts/README.md`)

Nenhum campo novo introduzido por esta feature.

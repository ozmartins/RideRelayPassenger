# Data Model — Posição do motorista no mapa do passageiro

Nada é persistido. Tudo vive em memória, na sessão.

## DriverLocation (novo, `lib/domain/driver_location.dart`)

| Campo | Tipo | Regra |
|---|---|---|
| `latitude` | `double` | finita, −90..90 |
| `longitude` | `double` | finita, −180..180 |
| `reportedAt` | `DateTime` | `createdAt` declarado pelo autor do evento |

- `DriverLocation.fromNostrEvent(NostrEvent)`: `content` deve ser JSON objeto com `lat` e `lon`
  numéricos; senão `FormatException`.
- `isNewerThan(DriverLocation? other)`: `true` se `other == null` ou `reportedAt` for estritamente
  posterior.

## Estado novo em `_MapScreenState` (não persistido)

| Campo | Padrão | Papel |
|---|---|---|
| `DriverLocation? _posicaoMotorista` | `null` | última posição válida e mais nova do motorista aceito |
| `bool _motoristaEnquadrado` | `false` | já enquadrou a primeira exibição desta corrida (D6) |
| `bool _seguindoPassageiro` | `true` | o mapa recentraliza no passageiro a cada GPS |

Limpeza (D5): `_posicaoMotorista = null`, `_motoristaEnquadrado = false`, `_seguindoPassageiro = true`
quando `_corridaAceita` muda (aceitar, finalizar avaliação, restaurar) e ao sair de
`motoristaACaminho`.

## Visibilidade do marcador

`_rideStatus == PassengerRideStatus.motoristaACaminho && _posicaoMotorista != null`.

## Entidades existentes, inalteradas

`AcceptedRide` (`quoteId`, `driverPubkey` — fonte da conferência de autor), `PassengerRideStatus`,
`NostrEvent`, `PassengerPosition`.

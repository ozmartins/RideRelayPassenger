# Data Model — Corrida cancelada pelo motorista (passageiro)

Nenhuma entidade persistida nova; nenhum campo novo em `AcceptedRide`; nenhuma migração.

## `PassengerRideRules.canBeCancelledByDriver` (`lib/domain/passenger_ride_status.dart`)

| Estado atual | `canBeCancelledByDriver` |
|---|---|
| `inicial` | `false` |
| `aguardandoOrcamentos` | `false` |
| `orcamentoAceito` | `true` |
| `motoristaACaminho` | `true` |
| `emCorrida` | `true` |
| `destinoConfirmadoAguardandoAvaliacao` | `false` |

Função pura, no padrão de `canConfirmMeeting`. A transição resultante é sempre `→ inicial`.

## Transições de `PassengerRideStatus` depois desta feature

```text
inicial → aguardandoOrcamentos → orcamentoAceito → motoristaACaminho → emCorrida → destinoConfirmadoAguardandoAvaliacao → inicial
              │ cancelar (015)       │                    │                │
              ▼                      └────────────────────┴────────────────┘
           inicial                       cancelamento pelo motorista (019) → inicial
```

## Estado em memória novo em `_MapScreenState`

| Campo | Papel |
|---|---|
| `_idsCancelamentoProcessados` (`Set<String>`) | `id`s de avisos `20012` já tratados — evita reprocessar a cada emissão do `EventFeed` (padrão de `_idsRotaProcessados`) |
| `_modalCorridaCanceladaVisivel` (`bool`) | liga a `RideCancelledModal`; só em memória, nunca persistido |

## Evento consumido: `kind: 20012` (emenda 14, definida em `driver/018`)

| Campo | Valor |
|-------|-------|
| `kind` | `20012` (`rideCancelledKind`) |
| `tags` | `["t","tcc-ufsc-caronas"]`, `["e", quoteId]`, `["p", passengerPubkey]` |
| `content` | `""` (ignorado) |

## Entidades reaproveitadas

- `AcceptedRide`: fornece `quoteId` e `driverPubkey` para conferir referência e autor; não muda.
- `PassengerRideStateStore`: `save(inicial, null)`; não muda.

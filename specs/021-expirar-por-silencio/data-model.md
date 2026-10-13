# Data Model — Expirar a corrida por silêncio do motorista (passageiro)

Nenhuma entidade persistida nova; nenhum campo novo em `AcceptedRide`; nenhuma migração.

## `PassengerRideRules.canExpireBySilence` (`lib/domain/passenger_ride_status.dart`)

| Estado atual | `canExpireBySilence` |
|---|---|
| `inicial` | `false` |
| `aguardandoOrcamentos` | `false` |
| `orcamentoAceito` | `true` |
| `motoristaACaminho` | `true` |
| `emCorrida` | `false` |
| `destinoConfirmadoAguardandoAvaliacao` | `false` |

Função pura. A transição resultante é sempre `→ inicial`.

## Transições de `PassengerRideStatus` depois desta feature

```text
orcamentoAceito ──┬── 20005 (sinal) ──▶ motoristaACaminho ── confirma encontro ──▶ emCorrida
        │         │                          │
        │         └─ 3 min sem sinal ─┐      └─ 3 min sem sinal ─┐
        ▼                              ▼                          ▼
      inicial ◀───────────── expira por silêncio (021) ───────────┘
```

(Também saem para `inicial`: cancelamento `20012` — 019 — e `20006` — 020, só de `orcamentoAceito`.)

## Estado em memória novo em `_MapScreenState`

| Campo | Papel |
|---|---|
| `_silencioMotorista` (`Timer?`) | contagem dos 3 minutos desde o último sinal; só em memória |
| `_modalMotoristaSemSinalVisivel` (`bool`) | liga a `DriverSilentModal`; só em memória |

## Parâmetro novo de `MapScreen`

| Parâmetro | Padrão | Papel |
|---|---|---|
| `driverSilenceTimeout` | `Duration(minutes: 3)` | prazo do silêncio; reduzido nos testes |

## Evento consumido (sem alteração): `kind: 20005`

Conferido como na feature 016: assinatura verificada pelo `EventFeed`, autor = `AcceptedRide.driverPubkey`,
`["e", quoteId]` = `AcceptedRide.quoteId`. Cada ocorrência nova rearma o temporizador; o `content` é
irrelevante para o sinal.

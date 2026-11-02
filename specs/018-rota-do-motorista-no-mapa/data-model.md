# Data Model — Rota do motorista no mapa do passageiro

Nada persistido; nenhum campo novo em `AcceptedRide`, `PassengerRideStateStore` ou SQLite.

## `RideRoute` (`lib/domain/ride_route.dart`, novo)

Valor puro, sem Flutter/`dart_nostr` (só `latlong2` e `NostrEvent` do próprio projeto).

| Campo | Tipo | Regra |
|-------|------|-------|
| `points` | `List<LatLng>` | 2 a 1000 itens; cada um com `lat ∈ [−90, 90]`, `lon ∈ [−180, 180]`, finitos; imutável (lista não modificável) |
| `reportedAt` | `DateTime` | `created_at` do evento — declarado pelo autor, só para ordenar rotas |

| Membro | Descrição |
|--------|-----------|
| `RideRoute.fromNostrEvent(NostrEvent)` | Decodifica `{"points":[[lat,lon],...]}`. Lança `FormatException` em qualquer falha (JSON inválido, `points` ausente/não lista, item que não seja par numérico, fora de faixa, contagem fora de 2–1000) |
| `isNewerThan(RideRoute?)` | `true` se não há outra ou `reportedAt` estritamente posterior (igual não troca — Edge Case) |

## Estado em `_MapScreenState`

| Campo | Tipo | Vida |
|-------|------|------|
| `_rotaDoMotorista` | `RideRoute?` | Memória da sessão; zerado ao mudar/encerrar a corrida aceita e ao sair de `emCorrida` |
| `_idsRotaProcessados` | `Set<String>` | Deduplicação por `id`, como `_idsLocalizacaoProcessados` |

## Regra de domínio

`PassengerRideRules.canShowDriverRoute(PassengerRideStatus s) => s == PassengerRideStatus.emCorrida`.

## Transições de estado

Nenhuma nova. A rota é efeito de um evento recebido enquanto o estado vale `emCorrida`.

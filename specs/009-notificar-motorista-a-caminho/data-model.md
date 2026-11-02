# Data Model: Notificar que o motorista está a caminho

## AcceptedRide (domínio, `lib/domain/accepted_ride.dart`)

Representa a decisão já tomada pelo passageiro — existe a partir do toque em "Aceitar" (feature
008); antes disso não há nenhuma instância.

| Campo | Tipo | Observação |
|---|---|---|
| `quoteId` | `String` | `id` do evento `kind: 20002` aceito — mesma referência usada nas tags `["e", ...]` dos eventos do motorista relativos a esta corrida (`kind: 20005`/`20006`/`20007`). |
| `driverPubkey` | `String` | Chave pública do motorista escolhido (`ReceivedQuote.driverPubkey` no momento da aceitação). |
| `movementNotified` | `bool` | Falso ao aceitar; `true` depois que a modal desta feature é exibida — controla FR-004 (nunca mais de uma exibição), inclusive através de um reinício (D2 de `research.md`). |

`AcceptedRide` ganha um `copyWith` para permitir `movementNotified: true` sem reconstruir os
demais campos manualmente em `MapScreen`.

## AcceptedRideStore (serviço, `lib/services/accepted_ride_store.dart`)

```dart
abstract class AcceptedRideStore {
  /// `null` se nenhuma corrida foi aceita ainda (ou desde a última vez que
  /// [clear] foi chamado).
  Future<AcceptedRide?> load();

  Future<void> save(AcceptedRide ride);

  /// Sem uso nesta feature (nenhum gatilho de "corrida terminou" existe
  /// ainda) — mantido fora da interface por proporcionalidade (Princípio V);
  /// se uma feature futura precisar, entra então.
}
```

Implementação real sobre `KeyValueStore` (JSON serializado num único valor, mesmo padrão de
`RideStateStore` do motorista); dublê em memória para os testes.

## Fluxo (visão geral)

```text
[toca "Aceitar" em RideQuotesModal] --grava--> AcceptedRideStore
                                                (quoteId, driverPubkey, movementNotified: false)
                                                        |
                          [kind 20005 chega, referenciando algum quoteId]
                                                        |
                          quoteId == AcceptedRide.quoteId?         --não--> ignorado
                                                        |
                                                       sim
                                                        |
                          AcceptedRide.movementNotified == false?  --não--> ignorado
                                                        |
                                                       sim
                                                        |
                          exibe DriverMovingModal (mensagem + "OK")
                          grava movementNotified: true (persistido)
```

## Emenda ao contrato único (ver `contracts/README.md`)

Nenhum campo novo — `kind: 20005` mantém o formato já definido na emenda 08
(`{"lat":, "lon":}`, tags `["e", quoteId]` + `["p", passengerPubkey]`). A emenda 10 só acrescenta o
consumo pelo passageiro à seção existente.

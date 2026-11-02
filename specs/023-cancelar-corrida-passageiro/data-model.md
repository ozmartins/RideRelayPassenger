# Data Model — Cancelar corrida (passageiro)

Nenhuma entidade nova e nenhuma persistência nova.

| Entidade | Mudança |
|---|---|
| `PassengerRideStatus` | nenhuma — a transição nova é `orcamentoAceito`/`motoristaACaminho`/`emCorrida` → `inicial` |
| `AcceptedRide` | nenhuma — `quoteId` e `driverPubkey` (já existentes) vão nas tags do aviso; deixa de ser lida porque o estado `inicial` persistido a faz ignorar no boot |
| `PassengerRideRules` | + `canCancelRide(status)` = `orcamentoAceito`, `motoristaACaminho` ou `emCorrida` |
| `EventFeed` | + `rideCancelledByPassengerKind = 20013` e `publishRideCancellation(quoteId, driverPubkey, identity)` |
| Estado de `MapScreen` | + `_modalConfirmarCancelamentoVisivel` (só memória) |

## Transição

```text
orcamentoAceito    ──(confirmar cancelamento)──► inicial   (corrida aceita zerada; 20013 publicado)
motoristaACaminho  ──(confirmar cancelamento)──► inicial
emCorrida          ──(confirmar cancelamento)──► inicial
aguardandoOrcamentos / inicial / destinoConfirmadoAguardandoAvaliacao ──► sem botão
```

# Contrato — nenhuma alteração nesta feature

Esta feature só **consome** o `kind: 20011` ("Rota da corrida") definido pela emenda 13, escrita pela
feature `017-publicar-rota-ao-passageiro` do motorista
(`Prototipo/driver/specs/017-publicar-rota-ao-passageiro/contracts/README.md`).

**Dependência bloqueante (Princípio IV)**: a emenda 13 precisa estar nas **duas** cópias do contrato
antes de qualquer código desta feature (tarefas T001/T002 da 017). Em 2026-10-03 ela ainda não
estava em nenhuma cópia.

## Regras de consumo implementadas aqui (do contrato)

| Regra | Onde |
|-------|------|
| Assinatura e `id` verificados antes de tudo | `EventFeed` (já existente) |
| Só vale rota **assinada pelo motorista do orçamento aceito** (autor do evento = `AcceptedRide.driverPubkey`) | `MapScreen._processarRotaDoMotorista` |
| Referencia o `quoteId` aceito (`["e", ...]`) | idem |
| Só com o passageiro em `emCorrida` | `PassengerRideRules.canShowDriverRoute` |
| Vale a de maior `created_at` | `RideRoute.isNewerThan` |
| `content` malformado, < 2 ou > 1000 pontos, fora de faixa → descartado sem alterar o traçado | `RideRoute.fromNostrEvent` |
| Só em memória | `_rotaDoMotorista` |
| Inscrição inclui `20011` | `main.dart` (`acceptedKinds`) |

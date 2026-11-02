# Research — Rota do motorista no mapa do passageiro

## D1 — Recepção e conferência

**Decision**: acrescentar `rideRouteKind = 20011` (`lib/services/event_feed.dart`) e incluí-lo em
`acceptedKinds` em `main.dart`, o que também o põe na inscrição (`kinds`). `MapScreen` ganha
`_processarRotaDoMotorista(NostrEvent)`, chamado por `_aoAtualizarOrcamentos`, que (na ordem):
deduplica por `id` (`_idsRotaProcessados`, mesmo padrão de `_idsLocalizacaoProcessados`); exige
`_corridaAceita != null`; exige `evento.referencedEventId == quoteId`; exige `evento.authorPublicKey ==
driverPubkey`; exige `PassengerRideRules.canShowDriverRoute(_rideStatus)` (só `emCorrida`);
decodifica por `RideRoute.fromNostrEvent` (descarta em `FormatException`); só substitui se
`isNewerThan(atual)`.

**Rationale**: é exatamente a cadeia da feature 016 para o `kind: 20005`; a assinatura e a
recomputação do `id` já ocorrem antes, em `EventFeed`. A tag `["e", ...]` é pública no relay, por
isso o autor é conferido (emenda 12).

**Alternatives**: confiar só na tag `e` — rejeitado (forjável). Guardar a rota em `AcceptedRide` —
rejeitado: seria persistência (FR-007).

## D2 — Validação do `content`

**Decision**: `RideRoute.fromNostrEvent`: `jsonDecode` → objeto com `points` lista; 2 ≤ `length` ≤ 1000;
cada elemento lista de 2 `num` finitos, `lat ∈ [−90, 90]`, `lon ∈ [−180, 180]`; qualquer falha →
`FormatException` (tratada como dado inválido, sem alterar o traçado). Guarda `reportedAt =
event.createdAt` e a lista de `LatLng`.

**Rationale**: o `content` é dado de terceiro (regra 3 de recepção); o limite superior impede um
evento gigante de forçar desenho/alocação arbitrários.

## D3 — Exibição e substituição

**Decision**: `MapScreen` mantém `RideRoute? _rotaDoMotorista`. Desenha-se numa `PolylineLayer`
própria (mesma cor `IdentidadeVisual.roxo`, 5 px) **somente** se `_rideStatus ==
PassengerRideStatus.emCorrida && _rotaDoMotorista != null`. Substituir é trocar a referência dentro de
`setState`. É zerada em `_limparPosicaoMotorista` (já chamado quando a corrida aceita muda ou
termina) e ao sair de `emCorrida` (`_confirmarDestino`).

**Rationale**: o desenho derivado do estado (como a feature 017 fez com "seguir motorista") evita
flag extra; o zeramento explícito garante FR-006 mesmo que o estado volte a `emCorrida` numa corrida
diferente.

## D4 — O passageiro não calcula a rota em `emCorrida`

**Decision**: (a) `_talvezRecalcularRota` retorna sem fazer nada quando `_rideStatus ==
emCorrida`; (b) ao entrar em `emCorrida` (`_confirmarEncontro`, e na restauração do estado no boot),
zera `_rota`, `_falhaRota` e incrementa `_rotaToken` (invalida cálculo em voo); (c) a `PolylineLayer`
da rota local só é desenhada fora de `emCorrida`. Nos demais estados a feature 007 não muda.

**Rationale**: hoje `_destino` não é limpo ao solicitar, então a rota local continua sendo recalculada
a cada 50 m em qualquer estado, inclusive durante a corrida — duplicaria a linha e gastaria cota do
serviço de rotas. (c) é cinto e suspensório para o caso de um cálculo em voo que chegue depois.

**Alternatives**: limpar `_destino` ao solicitar — mudaria a feature 006/007 em todos os estados
(fora de escopo, ver Assumptions da spec).

## D5 — Estilo

**Decision**: reaproveitar a rota `roxo` de 5 px da constituição (já usada pela rota local). Sem
marcador novo.

## D6 — Enquadramento da câmera

**Decision**: não alterar. Em `emCorrida` o mapa segue o passageiro (a regra de seguir o motorista
vale só para `motoristaACaminho`, feature 017).

## D7 — Contrato

**Decision**: nenhuma alteração de formato nesta feature. A seção *Conteúdo do kind 20011* (feature
017 do motorista) já define o consumo. A conferência desta feature (autor, `quoteId`, só em `emCorrida`,
mais nova por `created_at`, 2–1000 pontos, em memória) é a descrita lá; se a leitura da seção em campo
revelar divergência, a emenda é corrigida **nas duas cópias** pela 017, não aqui.

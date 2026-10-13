# Data Model — Seguir o motorista no mapa do passageiro

Nada é persistido; nenhuma entidade nova.

## Estado em `_MapScreenState`

| Campo | Situação |
|---|---|
| `DriverLocation? _posicaoMotorista` | mantido (feature 016); passa a ser também o foco do mapa |
| `bool _seguindoPassageiro` | **removido** |
| `bool _motoristaEnquadrado` | **removido** |

## Derivado

`seguindoMotorista = _rideStatus == PassengerRideStatus.motoristaACaminho && _posicaoMotorista != null`

| `seguindoMotorista` | Câmera responde a |
|---|---|
| `true` | posição nova do motorista |
| `false` | posição do GPS do passageiro (comportamento anterior à 016) |

A limpeza de `_posicaoMotorista` ao trocar de corrida ou sair do estado (D5 da 016) já faz o
`seguindoMotorista` voltar a `false`; `_limparPosicaoMotorista` perde só as duas linhas das flags
removidas.

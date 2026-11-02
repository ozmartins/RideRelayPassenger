# Phase 1 — Data Model: Rota real até o destino

## RouteResult

Representa o resultado de um cálculo de rota bem-sucedido entre a posição atual do passageiro e o
destino escolhido (Key Entities do `spec.md`, "Rota calculada"). Tipo próprio do projeto, em
`lib/domain/route_result.dart` — não expõe nenhum tipo de `open_route_service` (Princípio III).

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `points` | `List<LatLng>` (`latlong2`, já usado por `flutter_map`) | sim, não vazio | Sequência de coordenadas do trajeto, na ordem de origem a destino — usada diretamente para desenhar o `Polyline` (FR-004). |
| `distanceMeters` | `double` | sim, `>= 0` | Distância total do trajeto, em metros (FR-001, FR-002). |
| `originUsed` | `LatLng` | sim | Posição do passageiro no momento em que este cálculo foi feito — referência para decidir quando recalcular por deslocamento (D2 de `research.md`, FR-003). |
| `destination` | `LatLng` | sim | Destino usado neste cálculo — igual a `DestinationAddress.latitude/longitude` no momento do cálculo; permite validar que uma resposta tardia não é aplicada a um destino já trocado (FR-008). |

**Ciclo de vida**: criado quando um cálculo de rota termina com sucesso; substituído inteiramente
por um novo `RouteResult` a cada recálculo (FR-003); descartado (não mais referenciado) quando o
destino é limpo (FR-005) ou quando um novo destino é escolhido antes do cálculo anterior terminar
(FR-008 — o resultado antigo, se chegar depois, é ignorado por não corresponder mais ao `destination`
atual da tela). Existe só em memória, nunca persistido nem publicado em relay.

**Validação**: `distanceMeters` negativo ou `points` vazio são estados que a camada de serviço nunca
deve produzir (falha de cálculo é modelada como exceção, não como `RouteResult` inválido — ver
`RouteService` abaixo); não há necessidade de validação defensiva adicional na entidade.

## RouteService (abstração de serviço, não entidade de domínio)

Documentada aqui por completar o modelo de dados que `MapScreen` consome:

```dart
abstract class RouteService {
  /// Lança em qualquer falha (rede, timeout, erro do serviço, chave ausente/inválida) —
  /// quem chama trata qualquer exceção como "rota indisponível" (FR-007), sem
  /// distinguir motivos.
  Future<RouteResult> route({required LatLng origin, required LatLng destination});
}
```

A implementação real (`OrsRouteService`) encapsula `open_route_service.OpenRouteService` e faz a
conversão `ORSCoordinate` ↔ `LatLng`/`RouteResult` (D1 de `research.md`). Testes usam
`FakeRouteService`, seguindo o padrão de dublê já usado para `GeocodingService`/`LocationService`.

## Relação com entidades existentes

- **`PassengerPosition`** (feature 004) e **`DestinationAddress`** (feature 005) são as entradas do
  cálculo; esta feature não os altera.
- **`RideRequest`** (feature 006) não é alterado nem lido por esta feature — FR-009 garante que o
  cálculo de rota é inteiramente desacoplado da solicitação de corrida.

import 'package:latlong2/latlong.dart';

/// Resultado de um cálculo de rota bem-sucedido entre a posição atual do
/// passageiro e o destino escolhido (Key Entities do
/// `specs/007-rota-ate-destino/spec.md`).
///
/// Tipo próprio do projeto — não expõe nenhum tipo de `open_route_service`
/// (Princípio III; `data-model.md` da feature 007). Existe só em memória,
/// nunca persistido nem publicado em relay.
class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.originUsed,
    required this.destination,
  });

  /// Sequência de coordenadas do trajeto, na ordem de origem a destino —
  /// usada diretamente para desenhar o `Polyline` (FR-004).
  final List<LatLng> points;

  /// Distância total do trajeto, em metros (FR-001, FR-002).
  final double distanceMeters;

  /// Posição do passageiro no momento em que este cálculo foi feito —
  /// referência para decidir quando recalcular por deslocamento (D2 de
  /// `research.md`, FR-003).
  final LatLng originUsed;

  /// Destino usado neste cálculo — permite descartar uma resposta tardia que
  /// não corresponde mais ao destino atual da tela (FR-008).
  final LatLng destination;

  @override
  String toString() =>
      'RouteResult(${points.length} pontos, ${distanceMeters}m, '
      'origem=$originUsed, destino=$destination)';
}

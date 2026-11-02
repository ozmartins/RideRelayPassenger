import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:passenger/domain/route_result.dart';
import 'package:passenger/services/route_service.dart';

/// Dublê em memória: nenhum teste de tela toca rede real (Princípio II
/// aplicado por analogia a `RouteService`).
///
/// Por padrão devolve um `RouteResult` com uma rota reta de dois pontos e
/// `distanceMeters` igual à distância informada em [resultado] (ou um valor
/// fixo se não sobrescrito). [erro], quando definido, é lançado em vez de
/// devolver um resultado — simula falha do serviço (FR-007). [atraso], quando
/// definido, atrasa a resposta — usado para testar o descarte de resposta
/// tardia quando o destino já mudou (FR-008).
class FakeRouteService implements RouteService {
  FakeRouteService({this.resultado, this.erro, this.atraso});

  RouteResult? resultado;
  Object? erro;
  Duration? atraso;

  /// Quando definido, `route()` só responde depois que ele for completado —
  /// simula uma resposta em voo sem depender do relógio (feature 018).
  Completer<void>? bloqueio;

  /// Chamadas recebidas, na ordem — permite ao teste verificar o throttle de
  /// 50 m (D2 de `research.md`).
  final chamadas = <({LatLng origin, LatLng destination})>[];

  @override
  Future<RouteResult> route({
    required LatLng origin,
    required LatLng destination,
  }) async {
    chamadas.add((origin: origin, destination: destination));
    final esperar = bloqueio;
    if (esperar != null) await esperar.future;
    if (atraso != null) await Future<void>.delayed(atraso!);
    final erroAtual = erro;
    if (erroAtual != null) throw erroAtual;
    return resultado ??
        RouteResult(
          points: [origin, destination],
          distanceMeters: const Distance().as(
            LengthUnit.Meter,
            origin,
            destination,
          ),
          originUsed: origin,
          destination: destination,
        );
  }
}

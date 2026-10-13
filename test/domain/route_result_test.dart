import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:passenger/domain/route_result.dart';

void main() {
  test('guarda points, distanceMeters, originUsed e destination', () {
    const origem = LatLng(-28.9298, -49.4753);
    const destino = LatLng(-28.9350, -49.4800);
    final rota = RouteResult(
      points: const [origem, destino],
      distanceMeters: 812.5,
      originUsed: origem,
      destination: destino,
    );

    expect(rota.points, [origem, destino]);
    expect(rota.distanceMeters, 812.5);
    expect(rota.originUsed, origem);
    expect(rota.destination, destino);
  });
}

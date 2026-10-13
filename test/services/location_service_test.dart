import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/services/location_service.dart';

import '../support/fake_location_service.dart';

void main() {
  group('LocationService — fluxo de posições (FR-003)', () {
    test('o fluxo emite as posições publicadas', () async {
      final service = FakeLocationService();
      final recebidas = <dynamic>[];
      final sub = service.positions.listen(recebidas.add);

      final posicao = posicaoDeTeste();
      service.emitir(posicao);
      await pumpEventQueue();

      expect(recebidas, [posicao]);
      await sub.cancel();
      await service.fechar();
    });
  });

  group('LocationService — permissão e indisponibilidade (FR-004, FR-005)', () {
    test(
      'ensurePermission() não lança quando a permissão já foi concedida',
      () async {
        final service = FakeLocationService();
        await expectLater(service.ensurePermission(), completes);
      },
    );

    test(
      'ensurePermission() lança LocationPermissionDenied quando negada',
      () async {
        final service = FakeLocationService(
          permissionError: const LocationPermissionDenied(),
        );
        await expectLater(
          service.ensurePermission(),
          throwsA(isA<LocationPermissionDenied>()),
        );
      },
    );

    test('o fluxo lança LocationUnavailable quando o sinal se perde, distinto '
        'de permissão negada', () async {
      final service = FakeLocationService();
      final erros = <Object>[];
      final sub = service.positions.listen((_) {}, onError: erros.add);

      service.emitirErro(const LocationUnavailable('sinal perdido'));
      await pumpEventQueue();

      expect(erros, [isA<LocationUnavailable>()]);
      await sub.cancel();
      await service.fechar();
    });
  });
}

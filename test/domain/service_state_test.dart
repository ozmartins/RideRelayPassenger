import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/passenger_ride_status.dart';
import 'package:passenger/domain/service_state.dart';

void main() {
  const estado = ServiceState(
    passengerPubkey: 'p',
    rideStatus: PassengerRideStatus.orcamentoAceito,
    requestId: 'r',
    quoteId: 'q',
    driverPubkey: 'd',
    appInForeground: true,
  );

  group('ServiceState', () {
    test('ida e volta pelo canal preserva todos os campos', () {
      expect(ServiceState.fromJson(estado.toJson()), estado);
    });

    test('o formato guardado em disco não inclui appInForeground', () {
      expect(estado.toStorageJson().containsKey('appInForeground'), isFalse);
      expect(
        ServiceState.fromJson(estado.toStorageJson()).appInForeground,
        isFalse,
      );
    });

    test('estado desconhecido volta a inicial, sem lançar', () {
      final lido = ServiceState.fromJson({'rideStatus': 'inventado'});
      expect(lido.rideStatus, PassengerRideStatus.inicial);
      expect(lido.passengerPubkey, isNull);
    });

    test('nenhum campo é uma chave privada: só chaves públicas e ids', () {
      expect(estado.toJson().keys, isNot(contains('privateKey')));
    });

    test('hasActiveRide só nas fases que mantêm o serviço vivo', () {
      bool ativo(PassengerRideStatus s) =>
          ServiceState(rideStatus: s).hasActiveRide;
      expect(ativo(PassengerRideStatus.inicial), isFalse);
      expect(
        ativo(PassengerRideStatus.destinoConfirmadoAguardandoAvaliacao),
        isFalse,
      );
      for (final s in [
        PassengerRideStatus.aguardandoOrcamentos,
        PassengerRideStatus.orcamentoAceito,
        PassengerRideStatus.motoristaACaminho,
        PassengerRideStatus.emCorrida,
      ]) {
        expect(ativo(s), isTrue, reason: '$s');
      }
    });

    test('copyWith com clearRide zera solicitação e corrida', () {
      final limpo = estado.copyWith(
        rideStatus: PassengerRideStatus.inicial,
        clearRide: true,
      );
      expect(limpo.requestId, isNull);
      expect(limpo.quoteId, isNull);
      expect(limpo.driverPubkey, isNull);
      expect(limpo.passengerPubkey, 'p');
    });
  });
}

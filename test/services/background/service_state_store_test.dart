import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/passenger_ride_status.dart';
import 'package:passenger/domain/service_state.dart';
import 'package:passenger/services/background/service_state_store.dart';

import '../../support/in_memory_store.dart';

void main() {
  late InMemoryKeyValueStore base;
  late ServiceStateStore store;

  setUp(() {
    base = InMemoryKeyValueStore();
    store = ServiceStateStore(base);
  });

  test('sem nada guardado devolve o padrão (sem corrida)', () async {
    expect((await store.load()).rideStatus, PassengerRideStatus.inicial);
  });

  test('guarda e relê o estado, sem appInForeground', () async {
    await store.save(
      const ServiceState(
        passengerPubkey: 'p',
        rideStatus: PassengerRideStatus.emCorrida,
        requestId: 'r',
        quoteId: 'q',
        driverPubkey: 'd',
        appInForeground: true,
      ),
    );
    final lido = await ServiceStateStore(base).load();
    expect(lido.rideStatus, PassengerRideStatus.emCorrida);
    expect(lido.quoteId, 'q');
    expect(lido.appInForeground, isFalse);
  });

  test('dado corrompido volta ao padrão sem travar', () async {
    base.values[ServiceStateStore.storageKey] = 'não é json';
    expect((await store.load()).rideStatus, PassengerRideStatus.inicial);
  });

  test('o disco não guarda nada que pareça chave privada', () async {
    await store.save(const ServiceState(passengerPubkey: 'p'));
    expect(
      base.values[ServiceStateStore.storageKey]!.toLowerCase(),
      isNot(contains('private')),
    );
  });
}

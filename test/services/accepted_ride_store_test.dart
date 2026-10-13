import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/accepted_ride.dart';
import 'package:passenger/services/accepted_ride_store.dart';
import 'package:passenger/services/key_value_store.dart';

class InMemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

const _ride = AcceptedRide(quoteId: 'quote-1', driverPubkey: 'driver-1');

void main() {
  late InMemoryStore store;
  late AcceptedRideStore repo;

  setUp(() {
    store = InMemoryStore();
    repo = PreferencesAcceptedRideStore(store);
  });

  test('na primeira execução devolve null (nenhuma corrida aceita)', () async {
    expect(await repo.load(), isNull);
  });

  test('persiste e restaura a corrida aceita', () async {
    await repo.save(_ride);

    final restaurada = await PreferencesAcceptedRideStore(store).load();

    expect(restaurada, _ride);
  });

  test('estado corrompido volta a null sem travar', () async {
    store.values[PreferencesAcceptedRideStore.storageKey] = 'não é json';

    expect(await repo.load(), isNull);
  });
}

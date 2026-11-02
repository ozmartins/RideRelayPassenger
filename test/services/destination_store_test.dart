import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/destination_address.dart';
import 'package:passenger/services/destination_store.dart';
import 'package:passenger/services/key_value_store.dart';

class InMemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  late InMemoryStore store;
  late DestinationStore repo;

  const destino = DestinationAddress(
    'Rua das Flores, 123, Araranguá',
    latitude: -28.9348,
    longitude: -49.4859,
  );

  setUp(() {
    store = InMemoryStore();
    repo = PreferencesDestinationStore(store);
  });

  test('sem nada salvo, load devolve null', () async {
    expect(await repo.load(), isNull);
  });

  test('salvar e carregar devolve o mesmo destino', () async {
    await repo.save(destino);

    expect(await repo.load(), destino);
  });

  test('save(null) apaga o destino salvo', () async {
    await repo.save(destino);

    await repo.save(null);

    expect(await repo.load(), isNull);
  });

  test('registro corrompido devolve null, sem lançar', () async {
    store.values[PreferencesDestinationStore.storageKey] = '{nao e json';

    expect(await repo.load(), isNull);
  });

  test('registro com campo ausente devolve null', () async {
    store.values[PreferencesDestinationStore.storageKey] = '{"text":"x"}';

    expect(await repo.load(), isNull);
  });

  test('coordenada fora da faixa devolve null', () async {
    store.values[PreferencesDestinationStore.storageKey] =
        '{"text":"x","lat":95.0,"lon":10.0}';

    expect(await repo.load(), isNull);
  });
}

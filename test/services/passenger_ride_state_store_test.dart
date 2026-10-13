import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/passenger_ride_status.dart';
import 'package:passenger/services/key_value_store.dart';
import 'package:passenger/services/passenger_ride_state_store.dart';

class InMemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  late InMemoryStore store;
  late PassengerRideStateStore repo;

  setUp(() {
    store = InMemoryStore();
    repo = PreferencesPassengerRideStateStore(store);
  });

  test(
    'na primeira execução devolve (inicial, null) — default do enum',
    () async {
      expect(await repo.load(), (PassengerRideStatus.inicial, null));
    },
  );

  test('persiste e restaura aguardandoOrcamentos com solicitacaoId', () async {
    await repo.save(PassengerRideStatus.aguardandoOrcamentos, 'solicitacao-1');

    final restaurado = await PreferencesPassengerRideStateStore(store).load();

    expect(
      restaurado,
      (PassengerRideStatus.aguardandoOrcamentos, 'solicitacao-1'),
    );
  });

  test(
    'persiste e restaura cada estado intermediário do ciclo, sem '
    'solicitacaoId',
    () async {
      for (final status in [
        PassengerRideStatus.orcamentoAceito,
        PassengerRideStatus.motoristaACaminho,
        PassengerRideStatus.emCorrida,
        PassengerRideStatus.destinoConfirmadoAguardandoAvaliacao,
      ]) {
        await repo.save(status, null);

        final restaurado = await PreferencesPassengerRideStateStore(
          store,
        ).load();

        expect(restaurado, (status, null));
      }
    },
  );

  test('persiste e restaura o retorno a inicial', () async {
    await repo.save(PassengerRideStatus.aguardandoOrcamentos, 'solicitacao-1');
    await repo.save(PassengerRideStatus.inicial, null);

    final restaurado = await PreferencesPassengerRideStateStore(store).load();

    expect(restaurado, (PassengerRideStatus.inicial, null));
  });

  test('estado corrompido volta ao default sem travar', () async {
    store.values[PreferencesPassengerRideStateStore.storageKey] =
        'não é json';

    expect(await repo.load(), (PassengerRideStatus.inicial, null));
  });
}

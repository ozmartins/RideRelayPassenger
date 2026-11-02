import 'dart:convert';

import '../domain/accepted_ride.dart';
import 'key_value_store.dart';

/// Persiste a corrida aceita pelo passageiro — mesmo mecanismo já usado
/// para a lista de relays (D2 de `research.md`), por analogia direta a
/// `RideStateStore` do motorista (features 010/011 dele).
///
/// Sem isto, o app não teria como saber, ao receber uma localização do
/// motorista, se ela é da corrida que o próprio passageiro aceitou — o
/// único registro hoje é um sinalizador em memória, sem o `quoteId`, que se
/// perde ao fechar o app.
///
/// Desde a feature 014, a fase da corrida não é mais responsabilidade
/// desta entidade — ver `PassengerRideStateStore`.
abstract class AcceptedRideStore {
  /// `null` se nenhuma corrida foi aceita ainda.
  Future<AcceptedRide?> load();

  Future<void> save(AcceptedRide ride);
}

/// Implementação real sobre `KeyValueStore`, como um único valor JSON —
/// mesma decisão de atomicidade já usada por `RelayRepository`.
class PreferencesAcceptedRideStore implements AcceptedRideStore {
  PreferencesAcceptedRideStore(this._store);

  final KeyValueStore _store;

  static const String storageKey = 'passenger_accepted_ride';

  @override
  Future<AcceptedRide?> load() async {
    final raw = await _store.read(storageKey);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return AcceptedRide(
        quoteId: decoded['quoteId'] as String,
        driverPubkey: decoded['driverPubkey'] as String,
      );
    } catch (_) {
      // Estado corrompido não trava o app: trata como se nenhuma corrida
      // tivesse sido aceita ainda, mesma postura de `RelayRepository`.
      return null;
    }
  }

  @override
  Future<void> save(AcceptedRide ride) async {
    await _store.write(
      storageKey,
      jsonEncode({'quoteId': ride.quoteId, 'driverPubkey': ride.driverPubkey}),
    );
  }
}

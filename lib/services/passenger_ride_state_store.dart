import 'dart:convert';

import '../domain/passenger_ride_status.dart';
import 'key_value_store.dart';

/// Persiste o estado de corrida do passageiro introduzido pela feature 014
/// — mesmo mecanismo já usado por `AcceptedRideStore`/`RelayRepository` (D1
/// de `research.md`), por analogia direta a `RideStateStore` do motorista.
///
/// Este estado MUST sobreviver ao fechamento do app (FR-009).
abstract class PassengerRideStateStore {
  /// `(inicial, null)` se nenhum estado foi salvo ainda — mesmo default do
  /// enum quando não há nada persistido.
  Future<(PassengerRideStatus, String?)> load(); // (status, solicitacaoId)

  /// Grava o par status + id da solicitação ativa. `solicitacaoId` só é
  /// relevante (e não-nulo) quando `status == aguardandoOrcamentos` — nos
  /// demais estados além de `inicial`, a identificação da corrida já é
  /// responsabilidade de `AcceptedRide`/`AcceptedRideStore`.
  Future<void> save(PassengerRideStatus status, String? solicitacaoId);
}

/// Implementação real sobre `KeyValueStore`, como um único valor JSON —
/// mesma decisão de atomicidade já usada por `RelayRepository`/
/// `PreferencesAcceptedRideStore`.
class PreferencesPassengerRideStateStore implements PassengerRideStateStore {
  PreferencesPassengerRideStateStore(this._store);

  final KeyValueStore _store;

  static const String storageKey = 'passenger_ride_state';

  @override
  Future<(PassengerRideStatus, String?)> load() async {
    final raw = await _store.read(storageKey);
    if (raw == null) {
      return (PassengerRideStatus.inicial, null);
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final status = PassengerRideStatus.values.byName(
        decoded['status'] as String,
      );
      if (status == PassengerRideStatus.inicial) {
        return (status, null);
      }
      return (status, decoded['solicitacaoId'] as String?);
    } catch (_) {
      // Estado corrompido não trava o app: volta ao default, mesma postura
      // de robustez já usada por `RelayRepository.load`/`AcceptedRideStore`.
      return (PassengerRideStatus.inicial, null);
    }
  }

  @override
  Future<void> save(PassengerRideStatus status, String? solicitacaoId) async {
    await _store.write(
      storageKey,
      jsonEncode({'status': status.name, 'solicitacaoId': ?solicitacaoId}),
    );
  }
}

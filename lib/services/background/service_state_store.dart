import 'dart:convert';

import 'package:passenger/domain/service_state.dart';
import 'package:passenger/services/key_value_store.dart';

/// Guarda o [ServiceState] para o serviço relê-lo quando o sistema o reiniciar
/// (FR-011). Dado não sensível (chaves públicas e ids), mesmo mecanismo da
/// lista de relays.
class ServiceStateStore {
  ServiceStateStore(this._store);

  final KeyValueStore _store;

  static const String storageKey = 'background.service_state';

  /// O estado salvo, ou o padrão (sem corrida) se não há nada ou está
  /// corrompido.
  Future<ServiceState> load() async {
    final raw = await _store.read(storageKey);
    if (raw == null) return const ServiceState();
    try {
      return ServiceState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ServiceState();
    }
  }

  Future<void> save(ServiceState state) =>
      _store.write(storageKey, jsonEncode(state.toStorageJson()));
}

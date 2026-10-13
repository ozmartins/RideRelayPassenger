import 'dart:convert';

import '../domain/destination_address.dart';
import 'key_value_store.dart';

/// Persiste o destino que o passageiro selecionou, para que sobreviva a um
/// reinício do app (constituição 2.16.0: só o texto exibido e as coordenadas do
/// destino selecionado, só no aparelho, apagado quando o usuário limpa o campo).
abstract class DestinationStore {
  /// O destino salvo, ou `null` se não há nenhum (ou o registro está ilegível).
  Future<DestinationAddress?> load();

  /// Grava [destino]; `null` apaga o registro.
  Future<void> save(DestinationAddress? destino);
}

/// Implementação real sobre `KeyValueStore`, como um único valor JSON — mesma
/// decisão de atomicidade de `PreferencesAcceptedRideStore`.
class PreferencesDestinationStore implements DestinationStore {
  PreferencesDestinationStore(this._store);

  final KeyValueStore _store;

  static const String storageKey = 'passenger_destination';

  @override
  Future<DestinationAddress?> load() async {
    final raw = await _store.read(storageKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final lat = (decoded['lat'] as num).toDouble();
      final lon = (decoded['lon'] as num).toDouble();
      final texto = decoded['text'] as String;
      if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) {
        return null;
      }
      return DestinationAddress(texto, latitude: lat, longitude: lon);
    } catch (_) {
      // Registro corrompido não trava o app: sem destino salvo.
      return null;
    }
  }

  @override
  Future<void> save(DestinationAddress? destino) async {
    // `KeyValueStore` só tem `write`: apagar é gravar um valor que `load`
    // não aceita como destino.
    await _store.write(
      storageKey,
      destino == null
          ? ''
          : jsonEncode({
              'text': destino.text,
              'lat': destino.latitude,
              'lon': destino.longitude,
            }),
    );
  }
}

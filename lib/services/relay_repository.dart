import 'dart:convert';

import 'package:passenger/domain/relay.dart';
import 'package:passenger/services/key_value_store.dart';
import 'package:passenger/shared/default_relays.dart';

/// Desfecho de uma tentativa de acrescentar relay.
enum AddRelayResult {
  /// Acrescentado com sucesso.
  added,

  /// Endereço malformado ou com esquema diferente de `ws`/`wss`.
  invalid,

  /// Já existe na lista, comparando de forma normalizada.
  duplicate,
}

/// Guarda a lista de relays do passageiro entre execuções (FR-012).
///
/// Persiste apenas `url` e `isDefault`: estado de conexão é de runtime e não
/// faz sentido restaurar "conectado" de uma sessão anterior.
class RelayRepository {
  RelayRepository(this._store);

  static const storageKey = 'relay_list';

  final KeyValueStore _store;
  final _relays = <Relay>[];

  /// Lista corrente, na ordem em que foi montada.
  List<Relay> get relays => List.unmodifiable(_relays);

  /// Verdadeiro quando o passageiro removeu todos os relays — a tela principal
  /// usa isso para oferecer restaurar a lista padrão (FR-013).
  bool get isEmpty => _relays.isEmpty;

  /// Carrega a lista guardada, ou a lista padrão na primeira execução.
  ///
  /// Armazenamento ilegível cai na lista padrão em vez de derrubar o
  /// aplicativo: a lista de relays é preferência, não material crítico — ao
  /// contrário da identidade, cuja corrupção é reportada e nunca contornada.
  Future<List<Relay>> load() async {
    final cru = await _store.read(storageKey);

    if (cru == null) {
      _relays
        ..clear()
        ..addAll(_padrao());
      return relays;
    }

    try {
      final lista = (jsonDecode(cru) as List).cast<Map<String, dynamic>>();
      _relays
        ..clear()
        ..addAll(
          lista.map(
            (item) => Relay(
              url: item['url'] as String,
              isDefault: item['isDefault'] as bool? ?? false,
            ),
          ),
        );
    } on Object {
      _relays
        ..clear()
        ..addAll(_padrao());
    }
    return relays;
  }

  /// Acrescenta um relay, validando o endereço e rejeitando duplicados
  /// (FR-011).
  Future<AddRelayResult> add(String url) async {
    if (!Relay.isValidUrl(url)) return AddRelayResult.invalid;

    final normalizada = Relay.normalizeUrl(url);
    final jaExiste = _relays.any(
      (r) => Relay.normalizeUrl(r.url) == normalizada,
    );
    if (jaExiste) return AddRelayResult.duplicate;

    _relays.add(Relay(url: normalizada));
    await _persist();
    return AddRelayResult.added;
  }

  /// Retira o relay da lista (FR-011).
  Future<void> remove(String url) async {
    final normalizada = Relay.normalizeUrl(url);
    _relays.removeWhere((r) => Relay.normalizeUrl(r.url) == normalizada);
    await _persist();
  }

  /// Repõe a lista padrão, a pedido do passageiro (FR-013).
  Future<void> restoreDefaults() async {
    _relays
      ..clear()
      ..addAll(_padrao());
    await _persist();
  }

  Future<void> _persist() async {
    final json = jsonEncode([
      for (final r in _relays) {'url': r.url, 'isDefault': r.isDefault},
    ]);
    await _store.write(storageKey, json);
  }

  static List<Relay> _padrao() => [
    for (final url in defaultRelays) Relay(url: url, isDefault: true),
  ];
}

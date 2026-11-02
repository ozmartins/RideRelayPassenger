import 'package:passenger/domain/user_profile.dart';
import 'package:passenger/services/key_value_store.dart';

/// Guarda o nome/apelido do usuário entre execuções (FR-009).
///
/// Não é material criptográfico — o Princípio I não se aplica a ele — então
/// reaproveita o mesmo `KeyValueStore` já usado pela lista de relays (decisão
/// D1 de specs/003-nome-usuario/research.md), em vez do armazenamento
/// protegido usado pela identidade Nostr.
class NameService {
  NameService(this._store);

  static const storageKey = 'user_display_name';

  final KeyValueStore _store;

  /// Nome salvo, ou `null` se nenhum foi salvo ainda (FR-001).
  Future<String?> loadName() => _store.read(storageKey);

  /// Valida (FR-003, FR-006) e persiste o nome, substituindo o anterior
  /// (FR-004, FR-007). Lança [ArgumentError] se o valor for inválido.
  Future<void> saveName(String rawName) async {
    final perfil = UserProfile.fromInput(rawName);
    await _store.write(storageKey, perfil.displayName);
  }
}

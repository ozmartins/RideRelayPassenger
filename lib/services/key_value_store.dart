/// Contrato de armazenamento local simples, para dados **não sensíveis**.
///
/// Segredo criptográfico não passa por aqui: vai para [SecureStore], como
/// exige o Princípio I da constituição. Este contrato serve à lista de relays,
/// que é dado público e de baixo volume (decisão D3).
abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

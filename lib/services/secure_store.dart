/// Contrato de armazenamento protegido de segredos.
///
/// Existe para que [IdentityService] possa ser testado sem Keystore e sem
/// plugin de plataforma, como exige o Princípio II da constituição: o código de
/// derivação e guarda de chaves precisa de teste rodando sem rede e sem
/// dependência de aparelho.
///
/// A implementação de produção usa `flutter_secure_storage` (decisão D2); os
/// testes usam um dublê em memória.
abstract interface class SecureStore {
  /// Valor guardado sob [key], ou nulo se não houver.
  ///
  /// Lança [SecureStoreUnavailable] se o armazenamento protegido não estiver
  /// disponível no aparelho — situação que MUST ser reportada ao usuário, nunca
  /// tratada gerando uma identidade nova em silêncio.
  Future<String?> read(String key);

  /// Grava [value] sob [key] no armazenamento protegido.
  Future<void> write(String key, String value);
}

/// O armazenamento protegido do aparelho não está acessível.
class SecureStoreUnavailable implements Exception {
  const SecureStoreUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'Armazenamento protegido indisponível: $reason';
}

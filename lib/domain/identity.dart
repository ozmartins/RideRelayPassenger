/// Identidade Nostr do passageiro: par de chaves que o identifica na rede.
///
/// A chave pública identifica o passageiro; a privada assina os eventos. Pelo
/// Princípio I da constituição, a chave privada nunca é exibida, registrada em
/// log ou enviada a um relay — por isso [toString] a omite deliberadamente.
class Identity {
  Identity({required this.publicKey, required this.privateKey}) {
    if (!isValidKey(publicKey)) {
      throw ArgumentError.value(publicKey, 'publicKey', _formatoEsperado);
    }
    if (!isValidKey(privateKey)) {
      // Não inclui o valor na exceção: a mensagem pode ir para log.
      throw ArgumentError('privateKey inválida: $_formatoEsperado');
    }
  }

  static const _formatoEsperado = 'deve ter 64 caracteres hexadecimais';
  static final _hex64 = RegExp(r'^[0-9a-f]{64}$');

  /// Chave pública em hexadecimal, exibível ao usuário.
  final String publicKey;

  /// Chave privada em hexadecimal. Vive apenas em memória e no armazenamento
  /// protegido do sistema. Nunca exibir, logar ou transmitir.
  final String privateKey;

  /// Verdadeiro para chaves com exatamente 64 caracteres hexadecimais
  /// minúsculos. Chave recuperada fora desse formato indica armazenamento
  /// corrompido, não identidade válida.
  static bool isValidKey(String value) => _hex64.hasMatch(value);

  /// Forma abreviada da chave pública, para exibição em espaço reduzido.
  String get shortPublicKey =>
      '${publicKey.substring(0, 8)}…${publicKey.substring(56)}';

  @override
  String toString() => 'Identity(publicKey: $publicKey, privateKey: <oculta>)';

  @override
  bool operator ==(Object other) =>
      other is Identity &&
      other.publicKey == publicKey &&
      other.privateKey == privateKey;

  @override
  int get hashCode => Object.hash(publicKey, privateKey);
}

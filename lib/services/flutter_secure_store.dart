import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:passenger/services/secure_store.dart';

/// Armazenamento protegido real: Keystore do Android, via
/// `flutter_secure_storage` (decisão D2).
///
/// Traduz falhas do plugin em [SecureStoreUnavailable], para que a ausência de
/// armazenamento protegido seja reportada ao usuário em vez de resultar em uma
/// identidade nova a cada abertura.
class FlutterSecureStore implements SecureStore {
  const FlutterSecureStore([
    this._storage = const FlutterSecureStorage(aOptions: androidOptions),
  ]);

  /// Opções do armazenamento no Android.
  ///
  /// A cifra fica no padrão do pacote: na versão 11 o construtor de
  /// `AndroidOptions` já aplica AES-GCM para os dados e envelopamento de chave
  /// com RSA-OAEP/SHA-256 sobre o Keystore, sem exigir biometria — a opção
  /// `encryptedSharedPreferences`, comum em exemplos de versões anteriores, não
  /// existe mais nesta.
  ///
  /// `resetOnError: false` é obrigatório. O padrão do plugin é `true`: quando a
  /// decifração falha — backup restaurado em outro aparelho, chave do Keystore
  /// invalidada —, ele **apaga todos os dados**, a leitura devolve nulo e o
  /// `IdentityService` gera uma identidade nova sem ninguém saber. Com `false`,
  /// a falha chega aqui como exceção e vira [SecureStoreUnavailable], visível ao
  /// passageiro (Princípio I).
  static const AndroidOptions androidOptions = AndroidOptions(
    resetOnError: false,
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on Object catch (erro) {
      throw SecureStoreUnavailable(erro.toString());
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } on Object catch (erro) {
      throw SecureStoreUnavailable(erro.toString());
    }
  }
}

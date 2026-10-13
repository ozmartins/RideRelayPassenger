import 'package:dart_nostr/dart_nostr.dart';

import 'package:passenger/domain/identity.dart';
import 'package:passenger/services/secure_store.dart';

/// A identidade guardada no aparelho não está em formato válido.
///
/// Sinalizada em vez de contornada: gerar uma identidade nova em silêncio
/// destruiria a identidade do usuário na rede sem que ele soubesse.
class CorruptedIdentity implements Exception {
  const CorruptedIdentity();

  @override
  String toString() =>
      'A identidade guardada está corrompida: a chave não está no formato '
      'hexadecimal de 64 caracteres.';
}

/// Cria a identidade Nostr do passageiro na primeira execução e a recupera nas
/// seguintes.
///
/// Único lugar, junto do [EventFeed] e do [NostrEventVerifier], que conhece
/// `dart_nostr` — a camada de domínio e as telas usam apenas [Identity]
/// (Princípio III da constituição). O [RelayService] não conhece: fala só
/// texto do protocolo, sem tipo da biblioteca.
class IdentityService {
  IdentityService(this._store);

  /// Chave de armazenamento da chave privada. Apenas a privada é guardada: a
  /// pública é derivada dela, evitando o risco de as duas divergirem.
  static const privateKeyKey = 'nostr_private_key';

  final SecureStore _store;

  /// Recupera a identidade do armazenamento protegido ou cria uma nova se for a
  /// primeira execução.
  ///
  /// Lança [CorruptedIdentity] se o que estiver guardado não for uma chave
  /// válida, e propaga [SecureStoreUnavailable] se o armazenamento protegido
  /// não estiver acessível (FR-004, edge case de armazenamento).
  Future<Identity> loadOrCreate() async {
    final guardada = await _store.read(privateKeyKey);

    if (guardada != null) {
      if (!Identity.isValidKey(guardada)) {
        throw const CorruptedIdentity();
      }
      return Identity(
        publicKey: _derivePublicKey(guardada),
        privateKey: guardada,
      );
    }

    final par = Nostr.instance.services.keys.generateKeyPair();
    await _store.write(privateKeyKey, par.private);
    return Identity(publicKey: par.public, privateKey: par.private);
  }

  String _derivePublicKey(String privateKey) =>
      Nostr.instance.services.keys.derivePublicKey(privateKey: privateKey);
}

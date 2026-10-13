import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/identity.dart';
import 'package:passenger/services/identity_service.dart';
import 'package:passenger/services/secure_store.dart';

/// Dublê em memória do armazenamento protegido. Nenhum teste toca Keystore,
/// plugin de plataforma ou rede (Princípio II, decisão D5).
class FakeSecureStore implements SecureStore {
  FakeSecureStore([Map<String, String>? inicial]) : _dados = {...?inicial};

  final Map<String, String> _dados;
  int escritas = 0;

  @override
  Future<String?> read(String key) async => _dados[key];

  @override
  Future<void> write(String key, String value) async {
    escritas++;
    _dados[key] = value;
  }
}

/// Armazenamento que falha, para o edge case de aparelho sem Keystore.
class BrokenSecureStore implements SecureStore {
  @override
  Future<String?> read(String key) async =>
      throw const SecureStoreUnavailable('Keystore indisponível no teste');

  @override
  Future<void> write(String key, String value) async =>
      throw const SecureStoreUnavailable('Keystore indisponível no teste');
}

void main() {
  group('IdentityService', () {
    test('cria identidade na primeira execução e a persiste', () async {
      final store = FakeSecureStore();
      final service = IdentityService(store);

      final identidade = await service.loadOrCreate();

      expect(Identity.isValidKey(identidade.publicKey), isTrue);
      expect(Identity.isValidKey(identidade.privateKey), isTrue);
      expect(store.escritas, 1, reason: 'a identidade deve ser gravada');
    });

    test(
      'recupera a mesma identidade na execução seguinte, sem gerar outra',
      () async {
        final store = FakeSecureStore();
        final service = IdentityService(store);

        final primeira = await service.loadOrCreate();
        final escritasApos = store.escritas;
        final segunda = await IdentityService(store).loadOrCreate();

        expect(segunda.publicKey, primeira.publicKey);
        expect(segunda.privateKey, primeira.privateKey);
        expect(
          store.escritas,
          escritasApos,
          reason: 'recuperar não deve regravar nem gerar nova identidade',
        );
      },
    );

    test('chave fora do formato hexadecimal de 64 caracteres é tratada como '
        'armazenamento corrompido', () async {
      final store = FakeSecureStore({
        IdentityService.privateKeyKey: 'nao-e-hex',
      });

      expect(
        () => IdentityService(store).loadOrCreate(),
        throwsA(isA<CorruptedIdentity>()),
        reason: 'não deve silenciosamente sobrescrever com uma identidade nova',
      );
    });

    test('armazenamento protegido indisponível é reportado, e não contornado '
        'gerando identidade nova', () async {
      final service = IdentityService(BrokenSecureStore());

      expect(service.loadOrCreate(), throwsA(isA<SecureStoreUnavailable>()));
    });

    test(
      'a chave pública derivada corresponde à chave privada guardada',
      () async {
        final store = FakeSecureStore();
        final identidade = await IdentityService(store).loadOrCreate();

        // Recuperar deriva a pública da privada: se divergir, a identidade
        // exibida não corresponderia às assinaturas produzidas.
        final recuperada = await IdentityService(store).loadOrCreate();
        expect(recuperada.publicKey, identidade.publicKey);
      },
    );
  });

  group('Identity', () {
    test('rejeita chaves fora do formato', () {
      expect(
        () => Identity(publicKey: 'curta', privateKey: 'a' * 64),
        throwsArgumentError,
      );
      expect(
        () => Identity(publicKey: 'a' * 64, privateKey: 'XYZ'),
        throwsArgumentError,
      );
    });

    test('toString não expõe a chave privada', () {
      final identidade = Identity(publicKey: 'a' * 64, privateKey: 'b' * 64);

      expect(identidade.toString(), contains('a' * 64));
      expect(identidade.toString(), isNot(contains('b' * 64)));
      expect(identidade.toString(), contains('oculta'));
    });

    test('a exceção de chave privada inválida não vaza o valor', () {
      try {
        Identity(publicKey: 'a' * 64, privateKey: 'segredo-invalido-visivel');
        fail('deveria ter lançado');
      } on ArgumentError catch (e) {
        expect(e.toString(), isNot(contains('segredo-invalido-visivel')));
      }
    });
  });
}

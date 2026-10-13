import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/services/flutter_secure_store.dart';

void main() {
  group('FlutterSecureStore — opções do Android', () {
    test(
      'não apaga os dados quando a decifração falha (resetOnError desligado)',
      () {
        // Com o padrão do plugin (true), uma falha de decifração apaga a chave
        // privada, a leitura devolve nulo e o IdentityService cria outra
        // identidade sem avisar. Desligado, a falha vira
        // SecureStoreUnavailable.
        expect(
          FlutterSecureStore.androidOptions.toMap()['resetOnError'],
          'false',
        );
      },
    );
  });
}

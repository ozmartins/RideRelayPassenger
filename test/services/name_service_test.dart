import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/services/key_value_store.dart';
import 'package:passenger/services/name_service.dart';

/// Dublê em memória das preferências locais. Nenhum teste toca plugin de
/// plataforma (decisão D5, Princípio II).
class FakeKeyValueStore implements KeyValueStore {
  String? _valor;

  @override
  Future<String?> read(String key) async => _valor;

  @override
  Future<void> write(String key, String value) async => _valor = value;
}

void main() {
  group('NameService — carregar', () {
    test('nenhum nome salvo devolve null', () async {
      final service = NameService(FakeKeyValueStore());

      expect(await service.loadName(), isNull);
    });

    test('nome salvo é devolvido em uma nova instância do serviço, sobre o '
        'mesmo armazenamento', () async {
      final store = FakeKeyValueStore();
      await NameService(store).saveName('Maria');

      final depoisDoReinicio = await NameService(store).loadName();

      expect(depoisDoReinicio, 'Maria');
    });
  });

  group('NameService — salvar', () {
    test('salva o nome com espaços das extremidades removidos', () async {
      final store = FakeKeyValueStore();
      final service = NameService(store);

      await service.saveName('  Maria  ');

      expect(await service.loadName(), 'Maria');
    });

    test('recusa nome vazio', () async {
      final service = NameService(FakeKeyValueStore());

      expect(() => service.saveName(''), throwsArgumentError);
      expect(await service.loadName(), isNull);
    });

    test('recusa nome só com espaços em branco', () async {
      final service = NameService(FakeKeyValueStore());

      expect(() => service.saveName('   '), throwsArgumentError);
      expect(await service.loadName(), isNull);
    });

    test('recusa nome acima de 60 caracteres', () async {
      final service = NameService(FakeKeyValueStore());

      expect(() => service.saveName('a' * 61), throwsArgumentError);
      expect(await service.loadName(), isNull);
    });

    test('aceita nome com exatamente 60 caracteres', () async {
      final service = NameService(FakeKeyValueStore());
      final nome = 'a' * 60;

      await service.saveName(nome);

      expect(await service.loadName(), nome);
    });

    test('salvar um novo nome substitui o anterior', () async {
      final store = FakeKeyValueStore();
      final service = NameService(store);
      await service.saveName('Maria');

      await service.saveName('João');

      expect(await NameService(store).loadName(), 'João');
    });
  });
}

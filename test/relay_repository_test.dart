import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/services/key_value_store.dart';
import 'package:passenger/services/relay_repository.dart';
import 'package:passenger/shared/default_relays.dart';

/// Dublê em memória das preferências locais. Nenhum teste toca plugin de
/// plataforma (decisão D5, Princípio II).
class FakeKeyValueStore implements KeyValueStore {
  FakeKeyValueStore([this._valor]);

  String? _valor;

  @override
  Future<String?> read(String key) async => _valor;

  @override
  Future<void> write(String key, String value) async => _valor = value;
}

void main() {
  group('RelayRepository — carga inicial', () {
    test('primeira execução devolve a lista padrão', () async {
      final repo = RelayRepository(FakeKeyValueStore());

      final relays = await repo.load();

      expect(relays.map((r) => r.url), defaultRelays);
      expect(relays.every((r) => r.isDefault), isTrue);
    });

    test('lista alterada sobrevive ao reinício do aplicativo', () async {
      final store = FakeKeyValueStore();
      final repo = RelayRepository(store);
      await repo.load();

      await repo.add('wss://meu-relay.example');
      await repo.remove(defaultRelays.first);

      // Reinício: um repositório novo sobre o mesmo armazenamento.
      final depoisDoReinicio = await RelayRepository(store).load();

      expect(
        depoisDoReinicio.map((r) => r.url),
        contains('wss://meu-relay.example'),
      );
      expect(
        depoisDoReinicio.map((r) => r.url),
        isNot(contains(defaultRelays.first)),
      );
    });

    test('a marca de relay padrão é preservada entre reinícios', () async {
      final store = FakeKeyValueStore();
      final repo = RelayRepository(store);
      await repo.load();
      await repo.add('wss://meu-relay.example');

      final depois = await RelayRepository(store).load();
      final porUrl = {for (final r in depois) r.url: r};

      expect(porUrl[defaultRelays.first]!.isDefault, isTrue);
      expect(porUrl['wss://meu-relay.example']!.isDefault, isFalse);
    });

    test('armazenamento corrompido não derruba o aplicativo: cai na lista '
        'padrão', () async {
      final repo = RelayRepository(FakeKeyValueStore('isto não é json'));

      final relays = await repo.load();

      expect(relays.map((r) => r.url), defaultRelays);
    });
  });

  group('RelayRepository — adicionar', () {
    test('aceita endereço wss válido', () async {
      final repo = RelayRepository(FakeKeyValueStore());
      await repo.load();

      final resultado = await repo.add('wss://novo.example');

      expect(resultado, AddRelayResult.added);
      expect(repo.relays.map((r) => r.url), contains('wss://novo.example'));
    });

    test('recusa endereço inválido e mantém a lista inalterada', () async {
      final repo = RelayRepository(FakeKeyValueStore());
      final antes = (await repo.load()).length;

      for (final invalido in [
        'http://nao-e-websocket.example',
        'nos.lol',
        'wss://',
        '',
        '   ',
      ]) {
        expect(
          await repo.add(invalido),
          AddRelayResult.invalid,
          reason: 'deveria recusar "$invalido"',
        );
      }

      expect(repo.relays.length, antes);
    });

    test(
      'recusa duplicado, inclusive com espaços, caixa alta e barra final',
      () async {
        final repo = RelayRepository(FakeKeyValueStore());
        await repo.load();
        final antes = repo.relays.length;

        expect(await repo.add(defaultRelays.first), AddRelayResult.duplicate);
        expect(
          await repo.add('  ${defaultRelays.first.toUpperCase()}/  '),
          AddRelayResult.duplicate,
        );

        expect(repo.relays.length, antes);
      },
    );
  });

  group('RelayRepository — remover e restaurar', () {
    test('remover retira o relay da lista', () async {
      final repo = RelayRepository(FakeKeyValueStore());
      await repo.load();

      await repo.remove(defaultRelays.first);

      expect(
        repo.relays.map((r) => r.url),
        isNot(contains(defaultRelays.first)),
      );
    });

    test('lista pode ficar vazia, e o estado é sinalizado', () async {
      final repo = RelayRepository(FakeKeyValueStore());
      final relays = await repo.load();
      for (final r in relays) {
        await repo.remove(r.url);
      }

      expect(repo.relays, isEmpty);
      expect(repo.isEmpty, isTrue);
    });

    test(
      'lista vazia persiste vazia — não ressuscita a padrão sozinha',
      () async {
        final store = FakeKeyValueStore();
        final repo = RelayRepository(store);
        for (final r in await repo.load()) {
          await repo.remove(r.url);
        }

        final depois = await RelayRepository(store).load();

        expect(
          depois,
          isEmpty,
          reason:
              'restaurar a lista padrão é escolha do usuário (FR-013), '
              'não algo que o aplicativo faça por conta própria',
        );
      },
    );

    test('restaurar a lista padrão devolve os três relays', () async {
      final repo = RelayRepository(FakeKeyValueStore());
      for (final r in await repo.load()) {
        await repo.remove(r.url);
      }

      await repo.restoreDefaults();

      expect(repo.relays.map((r) => r.url), defaultRelays);
      expect(repo.isEmpty, isFalse);
    });
  });
}

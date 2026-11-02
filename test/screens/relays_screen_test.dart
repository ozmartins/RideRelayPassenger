import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/relay.dart';
import 'package:passenger/screens/relays_screen.dart';
import 'package:passenger/services/key_value_store.dart';
import 'package:passenger/services/relay_repository.dart';
import 'package:passenger/services/relay_service.dart';
import 'package:passenger/shared/default_relays.dart';

import '../support/fake_relay_transport.dart';

class FakeKeyValueStore implements KeyValueStore {
  String? _valor;

  @override
  Future<String?> read(String key) async => _valor;

  @override
  Future<void> write(String key, String value) async => _valor = value;
}

void main() {
  late FakeTransport transport;
  late RelayService service;
  late RelayRepository repository;

  setUp(() {
    transport = FakeTransport({});
    service = RelayService(
      transport: transport,
      connectTimeout: const Duration(milliseconds: 50),
      livenessTimeout: const Duration(milliseconds: 50),
    );
    repository = RelayRepository(FakeKeyValueStore());
  });

  tearDown(() => service.dispose());

  Future<void> montar(WidgetTester tester) async {
    await repository.load();
    await service.start(repository.relays);
    await tester.pumpWidget(
      MaterialApp(
        home: RelaysScreen(repository: repository, relayService: service),
      ),
    );
    await tester.pump();
  }

  testWidgets('lista os relays padrão', (tester) async {
    await montar(tester);

    for (final url in defaultRelays) {
      expect(find.text(url), findsOneWidget);
    }
  });

  testWidgets('acrescenta um relay válido e passa a conectá-lo', (
    tester,
  ) async {
    await montar(tester);

    await tester.enterText(find.byType(TextField), 'wss://novo.test');
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('wss://novo.test'), findsOneWidget);
    expect(service.current.map((r) => r.url), contains('wss://novo.test'));
    expect(repository.relays.map((r) => r.url), contains('wss://novo.test'));
  });

  testWidgets('recusa endereço inválido com explicação, sem alterar a lista', (
    tester,
  ) async {
    await montar(tester);
    final antes = service.current.length;

    await tester.enterText(find.byType(TextField), 'nao-e-um-endereco');
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pump();

    expect(find.textContaining('inválido'), findsOneWidget);
    expect(service.current.length, antes);
  });

  testWidgets('recusa relay duplicado com explicação', (tester) async {
    await montar(tester);
    final antes = service.current.length;

    await tester.enterText(find.byType(TextField), defaultRelays.first);
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pump();

    expect(find.textContaining('já está na lista'), findsOneWidget);
    expect(service.current.length, antes);
  });

  testWidgets('remover encerra a conexão e retira o relay da lista', (
    tester,
  ) async {
    await montar(tester);
    final alvo = defaultRelays.first;
    expect(transport.conexoes[alvo]!.fechada, isFalse);

    await tester.tap(find.byTooltip('Remover').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // US5 cenário 3: não basta sumir da tela, a conexão precisa ser encerrada,
    // senão o app continuaria recebendo eventos por um relay removido.
    expect(transport.conexoes[alvo]!.fechada, isTrue);
    expect(service.current.map((r) => r.url), isNot(contains(alvo)));
    expect(repository.relays.map((r) => r.url), isNot(contains(alvo)));
  });

  testWidgets('lista vazia explica a situação e oferece restaurar a padrão', (
    tester,
  ) async {
    await montar(tester);

    for (final url in List.of(defaultRelays)) {
      await repository.remove(url);
      await service.remove(url);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Nenhum relay configurado'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Restaurar lista padrão'),
      findsOneWidget,
      reason: 'FR-013: a saída precisa ser oferecida, não apenas explicada',
    );
  });
  testWidgets('relay indisponível exibe o motivo, em linguagem comum, e os '
      'demais seguem conectados', (tester) async {
    transport.comportamentos[defaultRelays.first] =
        FakeBehavior.refuseConnection;
    await montar(tester);

    // Esta cobertura veio da home, que deixou de listar relay a relay.
    expect(find.textContaining('Indisponível'), findsOneWidget);
    expect(find.text('Conectado'), findsNWidgets(defaultRelays.length - 1));

    // FR-015: motivo legível, nunca erro técnico cru.
    for (final w in tester.allWidgets) {
      if (w is! Text || w.data == null) continue;
      for (final termo in ['exception', 'errno', 'os error', 'socket']) {
        expect(w.data!.toLowerCase(), isNot(contains(termo)));
      }
    }
  });

  group('botão Reconectar', () {
    final botao = find.byKey(const Key('botao-reconectar'));

    testWidgets('aparece quando há relays', (tester) async {
      await montar(tester);

      expect(
        find.descendant(of: botao, matching: find.text('Reconectar')),
        findsOneWidget,
      );
    });

    testWidgets('retenta os relays indisponíveis ao tocar', (tester) async {
      transport.comportamentos[defaultRelays.first] =
          FakeBehavior.refuseConnection;
      await montar(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        service.current.firstWhere((r) => r.url == defaultRelays.first).status,
        RelayStatus.unavailable,
      );

      transport.comportamentos.remove(defaultRelays.first);
      await tester.tap(botao);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        service.current.firstWhere((r) => r.url == defaultRelays.first).status,
        RelayStatus.connected,
      );
    });

    testWidgets('não aparece sem relays', (tester) async {
      await repository.load();
      await service.start(const []);
      await tester.pumpWidget(
        MaterialApp(
          home: RelaysScreen(repository: repository, relayService: service),
        ),
      );
      await tester.pump();

      expect(botao, findsNothing);
    });
  });
}

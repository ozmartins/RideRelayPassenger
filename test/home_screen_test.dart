import 'package:dart_nostr/dart_nostr.dart' as nostr;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/identity.dart';
import 'package:passenger/domain/relay.dart';
import 'package:passenger/screens/home_screen.dart';
import 'package:passenger/screens/identity_screen.dart';
import 'package:passenger/screens/relays_screen.dart';
import 'package:passenger/services/key_value_store.dart';
import 'package:passenger/services/relay_repository.dart';
import 'package:passenger/screens/name_screen.dart';
import 'package:passenger/services/relay_service.dart';
import 'package:passenger/shared/app_info.dart';

import 'support/event_fixtures.dart';
import 'support/fake_relay_transport.dart';

class _MemoriaChaveValor implements KeyValueStore {
  String? _valor;

  @override
  Future<String?> read(String key) async => _valor;

  @override
  Future<void> write(String key, String value) async => _valor = value;
}

void main() {
  late FakeTransport transport;
  late RelayService service;
  late Identity identidade;
  late nostr.NostrKeyPairs par;

  setUp(() {
    transport = FakeTransport({});
    service = RelayService(
      transport: transport,
      connectTimeout: const Duration(milliseconds: 100),
      livenessTimeout: const Duration(milliseconds: 100),
    );
    par = novoPar();
    identidade = Identity(publicKey: par.public, privateKey: par.private);
  });

  tearDown(() {
    return service.dispose();
  });

  Future<void> montar(
    WidgetTester tester, {
    bool comIdentidade = true,
    String? displayName,
    Future<void> Function(String)? onSaveName,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          relayService: service,
          identity: comIdentidade ? identidade : null,
          displayName: displayName,
          onSaveName: onSaveName,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('exibe o título da tela inicial', (tester) async {
    await montar(tester);

    expect(find.text(appDisplayName), findsOneWidget);
  });

  testWidgets('não contém boilerplate do template do Flutter', (tester) async {
    await montar(tester);

    // Herdado da feature 001: protege contra a reintrodução do app de contador.
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.textContaining('You have pushed the button'), findsNothing);
  });

  testWidgets('o menu não tem mais "Tentar reconectar" (agora em Relays)', (
    tester,
  ) async {
    await montar(tester);

    expect(find.text('Tentar reconectar'), findsNothing);
  });

  testWidgets('resume quantos relays estão conectados', (tester) async {
    await service.start([
      const Relay(url: 'wss://a.test'),
      const Relay(url: 'wss://b.test'),
    ]);
    await montar(tester);

    expect(find.textContaining('2 de 2 relays conectados'), findsOneWidget);
  });

  testWidgets('com um relay fora, o resumo reflete apenas os conectados', (
    tester,
  ) async {
    transport.comportamentos['wss://b.test'] = FakeBehavior.refuseConnection;
    await service.start([
      const Relay(url: 'wss://a.test'),
      const Relay(url: 'wss://b.test'),
    ]);
    await montar(tester);

    expect(find.textContaining('1 de 2 relays conectados'), findsOneWidget);
  });

  testWidgets('sem nenhum relay conectado, explica em linguagem comum e sem '
      'erro técnico cru', (tester) async {
    transport.comportamentos
      ..['wss://a.test'] = FakeBehavior.refuseConnection
      ..['wss://b.test'] = FakeBehavior.refuseConnection;
    await service.start([
      const Relay(url: 'wss://a.test'),
      const Relay(url: 'wss://b.test'),
    ]);
    await montar(tester);

    expect(find.textContaining('Sem conexão com nenhum relay'), findsOneWidget);

    // FR-015: nenhum vocabulário de erro técnico na interface.
    const vocabularioTecnico = [
      'exception',
      'os error',
      'errno',
      'host lookup',
      'socket',
      'stacktrace',
    ];
    for (final w in tester.allWidgets) {
      if (w is! Text || w.data == null) continue;
      for (final termo in vocabularioTecnico) {
        expect(w.data!.toLowerCase(), isNot(contains(termo)));
      }
    }
  });

  testWidgets('lista de relays vazia é explicada, com saída indicada', (
    tester,
  ) async {
    await service.start([]);
    await montar(tester);

    expect(find.textContaining('Nenhum relay configurado'), findsOneWidget);
    expect(find.textContaining('tela de relays'), findsOneWidget);
  });

  testWidgets('sem nome, a ação de alterar nome não aparece', (tester) async {
    await service.start([const Relay(url: 'wss://a.test')]);
    await montar(tester);

    expect(find.byTooltip('Meu nome'), findsNothing);
  });

  testWidgets('ação de alterar nome abre a NameScreen com o nome atual', (
    tester,
  ) async {
    await service.start([const Relay(url: 'wss://a.test')]);
    await montar(tester, displayName: 'Maria', onSaveName: (_) async {});

    await tester.tap(find.byTooltip('Meu nome'));
    await tester.pumpAndSettle();

    expect(find.byType(NameScreen), findsOneWidget);
    expect(find.text('Maria'), findsOneWidget);
  });

  testWidgets('não exibe lista de eventos nem a ação de publicar teste', (
    tester,
  ) async {
    await service.start([const Relay(url: 'wss://a.test')]);
    await montar(tester);

    expect(find.textContaining('Nenhum evento'), findsNothing);
    expect(find.text('Publicar teste'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('o menu leva à identidade e aos relays', (tester) async {
    await service.start([const Relay(url: 'wss://a.test')]);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          relayService: service,
          identity: identidade,
          relayRepository: RelayRepository(_MemoriaChaveValor()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Minha identidade'));
    await tester.pumpAndSettle();
    expect(find.byType(IdentityScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Relays'));
    await tester.pumpAndSettle();
    expect(find.byType(RelaysScreen), findsOneWidget);
  });
}

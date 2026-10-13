import 'package:dart_nostr/dart_nostr.dart' as nostr;
import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/passenger_ride_status.dart';
import 'package:passenger/domain/relay.dart';
import 'package:passenger/domain/service_state.dart';
import 'package:passenger/services/background/relay_host_core.dart';
import 'package:passenger/services/background/service_messages.dart';
import 'package:passenger/services/background/service_state_store.dart';
import 'package:passenger/services/relay_repository.dart';
import 'package:passenger/services/relay_service.dart';
import 'package:passenger/services/subscription_request.dart';
import 'package:passenger/shared/default_relays.dart';
import 'package:passenger/shared/prototype_marker.dart';

import '../../support/event_fixtures.dart';
import '../../support/fake_relay_transport.dart';
import '../../support/fake_ride_message_notifier.dart';
import '../../support/in_memory_store.dart';
import '../../support/memory_channel.dart';

Future<void> pump() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late nostr.NostrKeyPairs passageiro;
  late nostr.NostrKeyPairs motorista;
  late FakeTransport transport;
  late RelayService relays;
  late MemoryChannelPair canal;
  late InMemoryKeyValueStore store;
  late FakeRideMessageNotifier notifier;
  late RelayHostCore core;
  late DateTime agora;
  late List<ServiceMessage> naUi;

  List<List<String>> tags({String? p, String? e}) => [
    prototypeMarkerTag,
    if (p != null) ['p', p],
    if (e != null) ['e', e],
  ];

  Map<String, dynamic> aviso(
    int kind, {
    nostr.NostrKeyPairs? autor,
    String? e = 'quote-1',
    String content = 'texto-cifrado-que-o-servico-nunca-le',
  }) => eventoAssinado(
    autor: autor ?? motorista,
    kind: kind,
    content: content,
    tags: tags(p: passageiro.public, e: e),
  );

  void emitir(Map<String, dynamic> payload, {String? url}) {
    final alvo = url ?? defaultRelays.first;
    transport.conexoes[alvo]!.emitir(mensagemEvent(payload));
  }

  /// Só os `EVENT` (o canal também leva OK/EOSE, como o relay os envia).
  List<ServiceRelayMessage> eventosNaUi() => naUi
      .whereType<ServiceRelayMessage>()
      .where((m) => m.payload.startsWith('["EVENT"'))
      .toList();

  void estado(ServiceState s) => canal.ui.send(ServiceStateUpdate(s));

  ServiceState corridaAceita(PassengerRideStatus status) => ServiceState(
    passengerPubkey: passageiro.public,
    rideStatus: status,
    requestId: 'req-1',
    quoteId: 'quote-1',
    driverPubkey: motorista.public,
  );

  setUp(() async {
    passageiro = novoPar();
    motorista = novoPar();
    transport = FakeTransport({});
    relays = RelayService(transport: transport);
    canal = MemoryChannelPair();
    store = InMemoryKeyValueStore();
    notifier = FakeRideMessageNotifier();
    agora = DateTime(2026, 10, 12, 12);
    naUi = [];
    canal.ui.incoming.listen(naUi.add);
    core = RelayHostCore(
      relays: relays,
      channel: canal.service,
      stateStore: ServiceStateStore(store),
      relayRepository: RelayRepository(store),
      notifier: notifier,
      now: () => agora,
    );
    await core.start(restoreState: false);
    await pump();
  });

  tearDown(() async => core.dispose());

  group('inscrição e conexão', () {
    test('avisa que está pronto e conecta sozinho aos relays persistidos', () {
      expect(naUi.whereType<ServiceReady>(), hasLength(1));
      expect(relays.connectedUrls, defaultRelays);
    });

    test('registra a inscrição sozinho, com o marcador e os kinds', () {
      final reqs = transport.conexoes[defaultRelays.first]!.enviadas
          .where((m) => m.contains('"$eventSubscriptionId"'));
      expect(reqs, isNotEmpty);
      expect(reqs.first, contains('#t'));
      expect(reqs.first, contains(prototypeMarker));
    });
  });

  group('recepção (regras 1, 2 e 6 do contrato)', () {
    test('repassa à interface o evento válido, como texto cru', () async {
      final e = aviso(20005);
      emitir(e);
      await pump();
      expect(eventosNaUi(), hasLength(1));
      expect(eventosNaUi().single.payload, mensagemEvent(e));
    });

    test('descarta assinatura inválida (conteúdo adulterado)', () async {
      final e = aviso(20005)..['content'] = 'adulterado';
      emitir(e);
      await pump();
      expect(eventosNaUi(), isEmpty);
      expect(core.discardedInvalidCount, 1);
    });

    test('descarta evento sem o marcador do protótipo', () async {
      emitir(
        eventoAssinado(autor: motorista, kind: 20005, comMarcador: false),
      );
      await pump();
      expect(eventosNaUi(), isEmpty);
      expect(core.discardedUnmarkedCount, 1);
    });

    test('o mesmo evento por três relays chega uma só vez', () async {
      final e = aviso(20005);
      for (final url in defaultRelays) {
        emitir(e, url: url);
      }
      await pump();
      expect(eventosNaUi(), hasLength(1));
      expect(core.discardedDuplicateCount, 2);
    });

    test('kind fora da lista é ignorado sem erro', () async {
      emitir(aviso(1));
      await pump();
      expect(eventosNaUi(), isEmpty);
    });

    test('OK e EOSE do relay seguem para a interface', () async {
      transport.conexoes[defaultRelays.first]!.emitir('["OK","x",true,""]');
      await pump();
      expect(
        naUi.whereType<ServiceRelayMessage>().last.payload,
        '["OK","x",true,""]',
      );
    });
  });

  group('notificação (FR-005) — decide sem ler o content', () {
    test('notifica o 20007 com o app fora de primeiro plano', () async {
      estado(corridaAceita(PassengerRideStatus.motoristaACaminho));
      final e = aviso(20007);
      emitir(e);
      await pump();
      expect(notifier.notified, hasLength(1));
      expect(notifier.notified.single.$2, e['id']);
    });

    test('com a interface em primeiro plano só a tela reage', () async {
      estado(
        corridaAceita(
          PassengerRideStatus.motoristaACaminho,
        ).copyWith(appInForeground: true),
      );
      emitir(aviso(20007));
      await pump();
      expect(notifier.notified, isEmpty);
      expect(eventosNaUi(), hasLength(1));
    });

    test('o 20007 repetido a cada 5 s gera uma única notificação', () async {
      estado(corridaAceita(PassengerRideStatus.motoristaACaminho));
      for (var i = 0; i < 4; i++) {
        emitir(aviso(20007, content: 'chegada $i'));
        await pump();
      }
      expect(notifier.notified, hasLength(1));
      expect(eventosNaUi(), hasLength(4)); // a tela recebe todos
    });

    test('cada orçamento notifica; o 20005 nunca', () async {
      estado(
        ServiceState(
          passengerPubkey: passageiro.public,
          rideStatus: PassengerRideStatus.aguardandoOrcamentos,
          requestId: 'req-1',
        ),
      );
      emitir(aviso(20002, e: 'req-1', content: 'orçamento A'));
      emitir(aviso(20002, e: 'req-1', content: 'orçamento B'));
      emitir(aviso(20005));
      await pump();
      expect(notifier.notified, hasLength(2));
    });

    test('autor que não é o motorista da corrida: sem notificação', () async {
      estado(corridaAceita(PassengerRideStatus.motoristaACaminho));
      emitir(aviso(20007, autor: novoPar()));
      await pump();
      expect(notifier.notified, isEmpty);
    });

    test('sem corrida ativa: sem notificação', () async {
      estado(corridaAceita(PassengerRideStatus.inicial));
      emitir(aviso(20012));
      await pump();
      expect(notifier.notified, isEmpty);
    });

    test('o texto do aviso nunca vem do evento (SC-003)', () async {
      estado(corridaAceita(PassengerRideStatus.emCorrida));
      emitir(aviso(20009));
      await pump();
      expect(notifier.notified.single.$1.title, 'Você chegou ao destino');
    });
  });

  group('hello e reentrega (FR-007, FR-012)', () {
    test('reentrega o que chegou sem a interface e esvazia a fila', () async {
      estado(corridaAceita(PassengerRideStatus.motoristaACaminho));
      final e = aviso(20007);
      emitir(e);
      await pump();

      canal.ui.send(const ServiceHello(foreground: true));
      await pump();
      final ack = naUi.whereType<ServiceHelloAck>().single;
      expect(ack.pending, hasLength(1));
      expect(ack.pending.single.payload, mensagemEvent(e));
      expect(ack.relays.map((r) => r.url), defaultRelays);

      canal.ui.send(const ServiceHello(foreground: true));
      await pump();
      expect(naUi.whereType<ServiceHelloAck>().last.pending, isEmpty);
    });

    test('descarta o que passou de 5 minutos', () async {
      estado(corridaAceita(PassengerRideStatus.motoristaACaminho));
      emitir(aviso(20007));
      await pump();
      agora = agora.add(const Duration(minutes: 5, seconds: 1));

      canal.ui.send(const ServiceHello(foreground: true));
      await pump();
      expect(naUi.whereType<ServiceHelloAck>().single.pending, isEmpty);
    });

    test('a interface voltando à tela apaga os avisos da bandeja', () async {
      canal.ui.send(const ServiceHello(foreground: true));
      await pump();
      expect(notifier.cancelAllCalls, 1);
    });
  });

  group('comandos da interface', () {
    test('broadcast leva o texto do EVENT aos relays conectados', () async {
      canal.ui.send(const ServiceBroadcast('["EVENT",{"id":"z"}]'));
      await pump();
      for (final url in defaultRelays) {
        expect(
          transport.conexoes[url]!.enviadas,
          contains('["EVENT",{"id":"z"}]'),
        );
      }
    });

    test('subscribe registra e reenvia a conexões novas', () async {
      canal.ui.send(
        const ServiceSubscribe(subscriptionId: 'outra', request: '["REQ","outra",{}]'),
      );
      await pump();
      expect(
        transport.conexoes[defaultRelays.first]!.enviadas,
        contains('["REQ","outra",{}]'),
      );
    });

    test('start concilia a lista sem reconectar quem já está bom', () async {
      final antes = transport.tentativas;
      canal.ui.send(
        ServiceStart([for (final u in defaultRelays) Relay(url: u)]),
      );
      await pump();
      expect(transport.tentativas, antes);

      canal.ui.send(
        const ServiceStart([Relay(url: 'wss://novo.example')]),
      );
      await pump();
      expect(relays.current.map((r) => r.url), ['wss://novo.example']);
    });

    test('o estado recebido é persistido (FR-011), sem appInForeground', () async {
      estado(corridaAceita(PassengerRideStatus.emCorrida));
      await pump();
      final lido = await ServiceStateStore(store).load();
      expect(lido.rideStatus, PassengerRideStatus.emCorrida);
      expect(lido.quoteId, 'quote-1');
      expect(lido.appInForeground, isFalse);
    });

    test('mudanças nos relays são espelhadas para a interface', () async {
      canal.ui.send(const ServiceRemoveRelay('wss://nos.lol'));
      await pump();
      expect(
        naUi.whereType<ServiceRelaysChanged>().last.relays.map((r) => r.url),
        isNot(contains('wss://nos.lol')),
      );
    });
  });

  test('reiniciado pelo sistema, relê o estado persistido', () async {
    await ServiceStateStore(store).save(
      corridaAceita(PassengerRideStatus.motoristaACaminho),
    );
    final outroCanal = MemoryChannelPair();
    final outro = RelayHostCore(
      relays: RelayService(transport: FakeTransport({})),
      channel: outroCanal.service,
      stateStore: ServiceStateStore(store),
      relayRepository: RelayRepository(store),
      notifier: notifier,
      now: () => agora,
    );
    await outro.start(restoreState: true);
    expect(outro.state.rideStatus, PassengerRideStatus.motoristaACaminho);
    await outro.dispose();
  });
}

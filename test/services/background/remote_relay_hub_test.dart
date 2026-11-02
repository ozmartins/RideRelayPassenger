import 'package:dart_nostr/dart_nostr.dart' as nostr;
import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/passenger_ride_status.dart';
import 'package:passenger/domain/relay.dart';
import 'package:passenger/domain/service_state.dart';
import 'package:passenger/services/background/relay_host_core.dart';
import 'package:passenger/services/background/service_messages.dart';
import 'package:passenger/services/background/service_state_store.dart';
import 'package:passenger/services/event_feed.dart';
import 'package:passenger/services/relay_repository.dart';
import 'package:passenger/services/relay_service.dart';
import 'package:passenger/services/remote_relay_hub.dart';
import 'package:passenger/services/subscription_request.dart';
import 'package:passenger/shared/prototype_marker.dart';

import '../../support/event_fixtures.dart';
import '../../support/fake_relay_transport.dart';
import '../../support/fake_ride_message_notifier.dart';
import '../../support/in_memory_store.dart';
import '../../support/memory_channel.dart';

Future<void> pump() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('RemoteRelayHub sozinho', () {
    late MemoryChannelPair canal;
    late RemoteRelayHub hub;
    late List<ServiceMessage> noServico;

    setUp(() {
      canal = MemoryChannelPair();
      hub = RemoteRelayHub(
        canal.ui,
        helloRetry: const Duration(hours: 1),
        retryTimeout: const Duration(milliseconds: 50),
      );
      noServico = [];
      canal.service.incoming.listen(noServico.add);
    });

    tearDown(() => hub.dispose());

    void responder({List<Relay> relays = const [], List<PendingRelayMessage> pending = const []}) =>
        canal.service.send(ServiceHelloAck(relays: relays, pending: pending));

    test('comandos esperam o serviço responder ao hello, na ordem', () async {
      hub.attach(foreground: true);
      hub.subscribe('corridas', '["REQ"]');
      await hub.add(const Relay(url: 'wss://a'));
      await pump();
      expect(noServico.whereType<ServiceSubscribe>(), isEmpty);
      expect(noServico.whereType<ServiceAddRelay>(), isEmpty);

      responder();
      await pump();
      final tipos = noServico.map((m) => m.type).toList();
      expect(tipos.indexOf('subscribe'), lessThan(tipos.indexOf('addRelay')));
    });

    test('o hello é repetido até a resposta', () async {
      final rapido = RemoteRelayHub(
        canal.ui,
        helloRetry: const Duration(milliseconds: 10),
      );
      rapido.attach(foreground: true);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(noServico.whereType<ServiceHello>().length, greaterThan(1));
      responder();
      await pump();
      final n = noServico.whereType<ServiceHello>().length;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(noServico.whereType<ServiceHello>().length, n);
      await rapido.dispose();
    });

    test('connectedUrls e broadcast usam o espelho dos relays', () async {
      hub.attach(foreground: true);
      responder(
        relays: const [
          Relay(url: 'wss://a', status: RelayStatus.connected),
          Relay(url: 'wss://b', status: RelayStatus.unavailable),
        ],
      );
      await pump();
      expect(hub.connectedUrls, ['wss://a']);
      expect(hub.hasAnyConnected, isTrue);
      expect(hub.broadcast('["EVENT",{}]'), ['wss://a']);
      await pump();
      expect(noServico.whereType<ServiceBroadcast>(), hasLength(1));
    });

    test('broadcast sem relay conectado não envia e devolve vazio', () async {
      hub.attach(foreground: true);
      responder();
      await pump();
      expect(hub.broadcast('["EVENT",{}]'), isEmpty);
      await pump();
      expect(noServico.whereType<ServiceBroadcast>(), isEmpty);
    });

    test('relaysChanged atualiza o espelho e o fluxo de relays', () async {
      hub.attach(foreground: true);
      responder();
      final emitidos = <List<Relay>>[];
      hub.relays.listen(emitidos.add);
      canal.service.send(
        const ServiceRelaysChanged([
          Relay(url: 'wss://a', status: RelayStatus.connected),
        ]),
      );
      await pump();
      expect(hub.current.single.status, RelayStatus.connected);
      expect(emitidos, isNotEmpty);
    });

    test('mensagens pendentes são reentregues como mensagens normais', () async {
      final recebidas = <RelayMessage>[];
      hub.messages.listen(recebidas.add);
      hub.attach(foreground: true);
      responder(
        pending: const [
          PendingRelayMessage(relayUrl: 'wss://a', payload: '["EVENT"]'),
        ],
      );
      await pump();
      expect(recebidas.single.url, 'wss://a');
      expect(recebidas.single.payload, '["EVENT"]');
    });

    test('um serviço reiniciado recebe de novo as inscrições', () async {
      hub.subscribe('corridas', '["REQ"]');
      hub.attach(foreground: true);
      responder();
      await pump();
      noServico.clear();
      hub.attach(foreground: true); // reapresentação
      responder();
      await pump();
      expect(noServico.whereType<ServiceSubscribe>(), hasLength(1));
    });

    test('start mostra a lista como "conectando" e pede ao serviço', () async {
      hub.attach(foreground: true);
      responder();
      await hub.start(const [Relay(url: 'wss://a', status: RelayStatus.connected)]);
      await pump();
      expect(hub.current.single.status, RelayStatus.connecting);
      expect(noServico.whereType<ServiceStart>(), hasLength(1));
    });

    test('add e remove atualizam o espelho na hora', () async {
      hub.attach(foreground: true);
      responder();
      await hub.add(const Relay(url: 'wss://a'));
      expect(hub.current.map((r) => r.url), ['wss://a']);
      await hub.remove('wss://a');
      expect(hub.current, isEmpty);
      await pump();
      expect(noServico.whereType<ServiceRemoveRelay>(), hasLength(1));
    });

    test('retryUnavailable espera a resposta, ou o prazo', () async {
      hub.attach(foreground: true);
      responder();
      await pump();
      final t = Stopwatch()..start();
      await hub.retryUnavailable(); // ninguém responde: volta pelo prazo
      expect(t.elapsedMilliseconds, greaterThanOrEqualTo(40));
      expect(noServico.whereType<ServiceRetryUnavailable>(), hasLength(1));
    });

    test('detach descarta a fila: serviço encerrado de propósito', () async {
      hub.attach(foreground: true);
      hub.subscribe('corridas', '["REQ"]');
      hub.detach();
      responder();
      await pump();
      // Só o replay das inscrições na reapresentação; o comando da fila,
      // descartado, não sai de novo.
      expect(noServico.whereType<ServiceSubscribe>(), hasLength(1));
    });
  });

  group('interface + serviço ligados (FR-012, T019)', () {
    late nostr.NostrKeyPairs passageiro;
    late nostr.NostrKeyPairs motorista;
    late FakeTransport transport;
    late MemoryChannelPair canal;
    late RemoteRelayHub hub;
    late RelayHostCore core;
    late FakeRideMessageNotifier notifier;
    late EventFeed feed;

    setUp(() async {
      passageiro = novoPar();
      motorista = novoPar();
      transport = FakeTransport({});
      canal = MemoryChannelPair();
      final store = InMemoryKeyValueStore();
      notifier = FakeRideMessageNotifier();
      core = RelayHostCore(
        relays: RelayService(transport: transport),
        channel: canal.service,
        stateStore: ServiceStateStore(store),
        relayRepository: RelayRepository(store),
        notifier: notifier,
      );
      hub = RemoteRelayHub(canal.ui, helloRetry: const Duration(hours: 1));
      feed = EventFeed(
        relayService: hub,
        acceptedKinds: passengerConsumedKinds,
      );
      await core.start(restoreState: false);
      await hub.start(const [Relay(url: 'wss://nos.lol')]);
      feed.start();
      hub.attach(foreground: true);
      await pump();
    });

    tearDown(() async {
      feed.dispose();
      await hub.dispose();
      await core.dispose();
    });

    Map<String, dynamic> orcamento(String texto) => eventoAssinado(
      autor: motorista,
      kind: 20002,
      content: texto,
      tags: [
        prototypeMarkerTag,
        ['p', passageiro.public],
        ['e', 'req-1'],
      ],
    );

    test('com a tela aberta o orçamento chega pelo EventFeed', () async {
      final e = orcamento('um');
      transport.conexoes['wss://nos.lol']!.emitir(mensagemEvent(e));
      await pump();
      expect(feed.current.map((x) => x.id), contains(e['id']));
      expect(notifier.notified, isEmpty);
    });

    test('app fechado: notifica, retém e entrega ao reabrir sem duplicar', () async {
      canal.ui.send(
        ServiceStateUpdate(
          ServiceState(
            passengerPubkey: passageiro.public,
            rideStatus: PassengerRideStatus.aguardandoOrcamentos,
            requestId: 'req-1',
          ),
        ),
      );
      // A interface sai de vista: o serviço passa a notificar e reter.
      hub.attach(foreground: false);
      await pump();
      canal.ui.send(
        ServiceStateUpdate(
          ServiceState(
            passengerPubkey: passageiro.public,
            rideStatus: PassengerRideStatus.aguardandoOrcamentos,
            requestId: 'req-1',
            appInForeground: false,
          ),
        ),
      );
      await pump();

      final e = orcamento('dois');
      transport.conexoes['wss://nos.lol']!.emitir(mensagemEvent(e));
      await pump();
      expect(notifier.notified, hasLength(1));
      final antes = feed.current.where((x) => x.id == e['id']).length;

      // Reabre: handshake em primeiro plano; a retida não duplica no feed.
      hub.attach(foreground: true);
      await pump();
      expect(feed.current.where((x) => x.id == e['id']).length, antes);
      expect(notifier.cancelAllCalls, greaterThanOrEqualTo(1));
    });
  });
}

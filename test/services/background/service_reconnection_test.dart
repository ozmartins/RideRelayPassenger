import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/relay.dart';
import 'package:passenger/services/background/relay_host_core.dart';
import 'package:passenger/services/background/service_messages.dart';
import 'package:passenger/services/background/service_state_store.dart';
import 'package:passenger/services/relay_repository.dart';
import 'package:passenger/services/relay_service.dart';
import 'package:passenger/services/subscription_request.dart';
import 'package:passenger/shared/prototype_marker.dart';

import '../../support/event_fixtures.dart';
import '../../support/fake_relay_transport.dart';
import '../../support/fake_ride_message_notifier.dart';
import '../../support/in_memory_store.dart';
import '../../support/memory_channel.dart';

Future<void> pump([int rodadas = 8]) async {
  for (var i = 0; i < rodadas; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// FR-002 / US3 (T024): a retentativa automática e o reenvio da inscrição do
/// `RelayService` continuam valendo rodando dentro do núcleo do serviço.
void main() {
  test('relay que cai volta sozinho e a inscrição é reenviada', () async {
    final motorista = novoPar();
    final transport = FakeTransport({});
    final store = InMemoryKeyValueStore();
    await RelayRepository(store).load();
    final canal = MemoryChannelPair();
    final naUi = <ServiceMessage>[];
    canal.ui.incoming.listen(naUi.add);
    final relays = RelayService(
      transport: transport,
      retryInterval: const Duration(milliseconds: 30),
    );
    final core = RelayHostCore(
      relays: relays,
      channel: canal.service,
      stateStore: ServiceStateStore(store),
      relayRepository: RelayRepository(store),
      notifier: FakeRideMessageNotifier(),
    );
    await core.start(restoreState: false);
    await pump();

    const url = 'wss://nos.lol';
    final primeira = transport.conexoes[url]!;
    primeira.derrubar();
    await pump();
    expect(
      relays.current.firstWhere((r) => r.url == url).status,
      RelayStatus.unavailable,
    );
    // A interface é avisada da queda.
    expect(
      naUi.whereType<ServiceRelaysChanged>().last.relays
          .firstWhere((r) => r.url == url)
          .status,
      RelayStatus.unavailable,
    );

    await Future<void>.delayed(const Duration(milliseconds: 120));
    await pump();
    final segunda = transport.conexoes[url]!;
    expect(identical(segunda, primeira), isFalse);
    expect(
      relays.current.firstWhere((r) => r.url == url).status,
      RelayStatus.connected,
    );
    // Inscrição é estado de conexão: reenviada à conexão nova.
    expect(
      segunda.enviadas.where((m) => m.contains('"$eventSubscriptionId"')),
      isNotEmpty,
    );

    // E voltou a entregar eventos.
    final e = eventoAssinado(
      autor: motorista,
      kind: 20005,
      tags: [prototypeMarkerTag, ['p', 'x'], ['e', 'q']],
    );
    segunda.emitir(mensagemEvent(e));
    await pump();
    expect(
      naUi.whereType<ServiceRelayMessage>().any(
        (m) => m.payload.contains(e['id'] as String),
      ),
      isTrue,
    );
    await core.dispose();
  });
}

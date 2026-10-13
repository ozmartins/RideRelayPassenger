import 'dart:io';

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
import 'package:passenger/services/remote_relay_hub.dart';
import 'package:passenger/shared/prototype_marker.dart';

import '../../support/event_fixtures.dart';
import '../../support/fake_relay_transport.dart';
import '../../support/fake_ride_message_notifier.dart';
import '../../support/in_memory_store.dart';
import '../../support/memory_channel.dart';

/// Arquivos que tocam a identidade, o armazenamento protegido ou a cifra: o
/// isolate do serviço não pode alcançá-los (Princípio I; constituição 2.15.0).
const _proibidos = {
  'lib/domain/identity.dart',
  'lib/services/identity_service.dart',
  'lib/services/flutter_secure_store.dart',
  'lib/services/secure_store.dart',
  'lib/services/message_cipher.dart',
  'lib/services/nip44.dart',
  'lib/services/event_feed.dart',
};

/// Raízes do que roda no isolate do serviço.
const _raizes = [
  'lib/services/background/relay_task_handler.dart',
  'lib/services/background/relay_host_core.dart',
];

final _importacao = RegExp(r"import\s+'package:passenger/([^']+)'");

Set<String> _fechamento(List<String> raizes) {
  final visto = <String>{};
  final fila = [...raizes];
  while (fila.isNotEmpty) {
    final arquivo = fila.removeLast();
    if (!visto.add(arquivo)) continue;
    final f = File(arquivo);
    if (!f.existsSync()) continue;
    for (final m in _importacao.allMatches(f.readAsStringSync())) {
      fila.add('lib/${m.group(1)}');
    }
  }
  return visto;
}

Future<void> pump() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('imports do isolate do serviço (SC-007)', () {
    test('nenhum arquivo alcançável toca identidade, cofre ou cifra', () {
      final alcancados = _fechamento(_raizes);
      expect(alcancados, isNotEmpty);
      expect(
        alcancados.intersection(_proibidos),
        isEmpty,
        reason: 'o serviço importaria (direta ou indiretamente) código de segredo',
      );
    });

    test('os arquivos de services/background não citam chave privada', () {
      final arquivos = Directory('lib/services/background')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final f in arquivos) {
        final texto = f.readAsStringSync().toLowerCase();
        expect(texto.contains('privatekey'), isFalse, reason: f.path);
        expect(texto.contains('nsec'), isFalse, reason: f.path);
      }
    });
  });

  test('o tráfego do canal nunca carrega a chave privada nem texto decifrado',
      () async {
    final passageiro = novoPar();
    final motorista = novoPar();
    final transport = FakeTransport({});
    final canal = MemoryChannelPair();
    final store = InMemoryKeyValueStore();
    final core = RelayHostCore(
      relays: RelayService(transport: transport),
      channel: canal.service,
      stateStore: ServiceStateStore(store),
      relayRepository: RelayRepository(store),
      notifier: FakeRideMessageNotifier(),
    );
    final hub = RemoteRelayHub(
      canal.ui,
      helloRetry: const Duration(hours: 1),
    );
    await core.start(restoreState: false);
    await hub.start(const [Relay(url: 'wss://nos.lol')]);
    hub.attach(foreground: false);
    await pump();
    canal.ui.send(
      ServiceStateUpdate(
        ServiceState(
          passengerPubkey: passageiro.public,
          rideStatus: PassengerRideStatus.emCorrida,
          quoteId: 'q1',
          driverPubkey: motorista.public,
        ),
      ),
    );
    await pump();
    transport.conexoes['wss://nos.lol']!.emitir(
      mensagemEvent(
        eventoAssinado(
          autor: motorista,
          kind: 20009,
          content: 'cifrado-pelo-nip44',
          tags: [
            prototypeMarkerTag,
            ['p', passageiro.public],
            ['e', 'q1'],
          ],
        ),
      ),
    );
    await pump();

    expect(canal.traffic, isNotEmpty);
    final tudo = canal.traffic.toString();
    expect(tudo.contains(passageiro.private), isFalse);
    expect(tudo.contains(motorista.private), isFalse);
    // O que foi gravado em disco tampouco.
    expect(store.values.values.join().contains(passageiro.private), isFalse);

    await hub.dispose();
    await core.dispose();
  });

  test('a chave de teste existe (o teste acima não é vácuo)', () {
    final par = novoPar();
    expect(par.private, hasLength(64));
    expect(nostr.Nostr.instance.services.keys.isValidPrivateKey(par.private), isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/passenger_ride_status.dart';
import 'package:passenger/domain/service_state.dart';
import 'package:passenger/services/background/background_service.dart';
import 'package:passenger/services/background/message_channel.dart';
import 'package:passenger/services/background/service_controller.dart';
import 'package:passenger/services/background/service_messages.dart';
import 'package:passenger/services/remote_relay_hub.dart';

import '../../support/memory_channel.dart';

class _FakeService implements BackgroundService {
  _FakeService(this.channel);

  @override
  final MessageChannel channel;
  bool permitted = true;
  bool running = false;
  final textos = <String>[];
  int stops = 0;
  int permissionRequests = 0;

  @override
  Future<bool> get isRunning async => running;

  @override
  Future<void> start({required String text}) async {
    running = true;
    textos.add(text);
  }

  @override
  Future<void> updateText(String text) async => textos.add(text);

  @override
  Future<void> stop() async {
    running = false;
    stops++;
  }

  @override
  Future<bool> hasNotificationPermission() async => permitted;

  @override
  Future<bool> requestNotificationPermission() async {
    permissionRequests++;
    return permitted;
  }
}

Future<void> pump() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const _semCorrida = ServiceState(passengerPubkey: 'p');
const _comCorrida = ServiceState(
  passengerPubkey: 'p',
  rideStatus: PassengerRideStatus.motoristaACaminho,
  quoteId: 'q',
  driverPubkey: 'd',
);

void main() {
  group('ServiceController.shouldRun (FR-001)', () {
    test('tabela do ciclo de vida', () {
      bool f(bool fg, bool ride, bool notify) => ServiceController.shouldRun(
        foreground: fg,
        hasActiveRide: ride,
        canNotify: notify,
      );
      expect(f(true, false, false), isTrue); // aberto, sem corrida
      expect(f(true, true, true), isTrue);
      expect(f(false, true, true), isTrue); // fechado com corrida
      expect(f(false, false, true), isFalse); // fechado sem corrida
      expect(f(false, true, false), isFalse); // sem permissão
    });
  });

  group('ServiceController', () {
    late MemoryChannelPair canal;
    late RemoteRelayHub hub;
    late _FakeService service;
    late ServiceController controller;
    late List<ServiceMessage> noServico;

    setUp(() async {
      canal = MemoryChannelPair();
      hub = RemoteRelayHub(
        canal.ui,
        helloRetry: const Duration(hours: 1),
      );
      service = _FakeService(canal.ui);
      controller = ServiceController(service: service, hub: hub);
      noServico = [];
      canal.service.incoming.listen((m) {
        noServico.add(m);
        // O "serviço" responde ao hello, como o núcleo real.
        if (m is ServiceHello) {
          canal.service.send(
            const ServiceHelloAck(relays: [], pending: []),
          );
        }
      });
      await controller.start();
      await pump();
    });

    tearDown(() async {
      await controller.dispose();
      await hub.dispose();
    });

    test('inicia o serviço com a notificação discreta e se apresenta', () {
      expect(service.running, isTrue);
      expect(service.textos.first, ServiceController.textConnected);
      expect(noServico.whereType<ServiceHello>(), isNotEmpty);
    });

    test('só manda estado depois da primeira informação da tela', () async {
      expect(noServico.whereType<ServiceStateUpdate>(), isEmpty);
      controller.update(_semCorrida);
      await pump();
      expect(noServico.whereType<ServiceStateUpdate>(), hasLength(1));
    });

    test('estado repetido não é reenviado', () async {
      controller.update(_semCorrida);
      controller.update(_semCorrida);
      await pump();
      expect(noServico.whereType<ServiceStateUpdate>(), hasLength(1));
    });

    test('com corrida ativa o texto vira "Acompanhando sua corrida"', () async {
      controller.update(_comCorrida);
      await pump();
      expect(service.textos.last, ServiceController.textRide);
    });

    test('sai de vista sem corrida: encerra o serviço', () async {
      controller.update(_semCorrida);
      await controller.onForeground(false);
      await pump();
      expect(service.stops, 1);
      expect(service.running, isFalse);
    });

    test('sai de vista com corrida: o serviço continua', () async {
      controller.update(_comCorrida);
      await controller.onForeground(false);
      await pump();
      expect(service.stops, 0);
      expect(service.running, isTrue);
      final estados = noServico.whereType<ServiceStateUpdate>().toList();
      expect(estados.last.state.appInForeground, isFalse);
    });

    test('a corrida termina com o app fechado: encerra o serviço', () async {
      controller.update(_comCorrida);
      await controller.onForeground(false);
      controller.update(_semCorrida);
      await pump();
      expect(service.stops, 1);
    });

    test('voltar à tela religa o serviço se ele tinha parado', () async {
      controller.update(_semCorrida);
      await controller.onForeground(false);
      await controller.onForeground(true);
      await pump();
      expect(service.running, isTrue);
    });

    test('sem permissão de notificação o serviço não sobrevive à saída', () async {
      service.permitted = false;
      expect(await controller.ensureNotificationPermission(), isFalse);
      controller.update(_comCorrida);
      await controller.onForeground(false);
      await pump();
      expect(service.stops, 1);
      expect(service.permissionRequests, 1);
    });

    test('a permissão só é pedida se ainda não foi dada', () async {
      expect(await controller.ensureNotificationPermission(), isTrue);
      expect(service.permissionRequests, 0);
    });
  });
}

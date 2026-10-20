import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/passenger_ride_status.dart';
import 'package:passenger/domain/relay.dart';
import 'package:passenger/domain/service_state.dart';
import 'package:passenger/services/background/service_messages.dart';

ServiceMessage? _volta(ServiceMessage m) => ServiceMessage.fromMap(m.toMap());

void main() {
  const relay = Relay(
    url: 'wss://nos.lol',
    status: RelayStatus.unavailable,
    lastError: 'sem resposta do relay',
    isDefault: true,
  );

  group('ida e volta de cada mensagem', () {
    test('ready, stop, retryUnavailable', () {
      expect(_volta(const ServiceReady()), isA<ServiceReady>());
      expect(_volta(const ServiceStop()), isA<ServiceStop>());
      expect(
        _volta(const ServiceRetryUnavailable()),
        isA<ServiceRetryUnavailable>(),
      );
    });

    test('hello', () {
      final m = _volta(const ServiceHello(foreground: false));
      expect((m! as ServiceHello).foreground, isFalse);
    });

    test('helloAck com relays e pendentes', () {
      final m =
          _volta(
                const ServiceHelloAck(
                  relays: [relay],
                  pending: [
                    PendingRelayMessage(relayUrl: 'wss://nos.lol', payload: '["EVENT"]'),
                  ],
                ),
              )!
              as ServiceHelloAck;
      expect(m.relays.single.url, 'wss://nos.lol');
      expect(m.relays.single.status, RelayStatus.unavailable);
      expect(m.relays.single.lastError, 'sem resposta do relay');
      expect(m.relays.single.isDefault, isTrue);
      expect(m.pending.single.payload, '["EVENT"]');
    });

    test('state', () {
      const s = ServiceState(
        passengerPubkey: 'p',
        rideStatus: PassengerRideStatus.emCorrida,
        quoteId: 'q',
        driverPubkey: 'd',
        appInForeground: true,
      );
      expect((_volta(const ServiceStateUpdate(s))! as ServiceStateUpdate).state, s);
    });

    test('start, addRelay, removeRelay, relaysChanged', () {
      expect((_volta(const ServiceStart([relay]))! as ServiceStart).relays, [relay]);
      expect((_volta(const ServiceAddRelay(relay))! as ServiceAddRelay).relay, relay);
      expect(
        (_volta(const ServiceRemoveRelay('wss://a'))! as ServiceRemoveRelay).url,
        'wss://a',
      );
      expect(
        (_volta(const ServiceRelaysChanged([relay]))! as ServiceRelaysChanged)
            .relays,
        [relay],
      );
    });

    test('subscribe, broadcast e message', () {
      final sub = _volta(
        const ServiceSubscribe(subscriptionId: 'corridas', request: '["REQ"]'),
      )! as ServiceSubscribe;
      expect(sub.subscriptionId, 'corridas');
      expect(sub.request, '["REQ"]');
      expect(
        (_volta(const ServiceBroadcast('["EVENT"]'))! as ServiceBroadcast).message,
        '["EVENT"]',
      );
      final msg = _volta(
        const ServiceRelayMessage(relayUrl: 'wss://a', payload: '["OK"]'),
      )! as ServiceRelayMessage;
      expect(msg.relayUrl, 'wss://a');
      expect(msg.payload, '["OK"]');
    });
  });

  group('entrada hostil é ignorada, nunca lança (regra 3)', () {
    test('não mapa, versão diferente, tipo desconhecido, campo faltando', () {
      expect(ServiceMessage.fromMap('texto'), isNull);
      expect(ServiceMessage.fromMap(null), isNull);
      expect(ServiceMessage.fromMap({'t': 'ready', 'v': 2}), isNull);
      expect(ServiceMessage.fromMap({'t': 'inventado', 'v': 1}), isNull);
      expect(ServiceMessage.fromMap({'t': 'hello', 'v': 1}), isNull);
      expect(
        ServiceMessage.fromMap({'t': 'state', 'v': 1, 'state': 'não é mapa'}),
        isNull,
      );
    });
  });
}

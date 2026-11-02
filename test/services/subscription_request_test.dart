import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/services/event_feed.dart';
import 'package:passenger/services/relay_service.dart';
import 'package:passenger/services/relay_transport.dart';
import 'package:passenger/services/subscription_request.dart';
import 'package:passenger/shared/prototype_marker.dart';

void main() {
  test('passengerConsumedKinds são exatamente os kinds consumidos pelo app', () {
    expect(passengerConsumedKinds, {
      rideQuoteKind,
      driverLocationKind,
      driverArrivalKind,
      meetingConfirmedKind,
      destinationArrivalKind,
      destinationConfirmedKind,
      rideRouteKind,
      rideCancelledKind,
      rideUnavailableKind,
      receiptKind,
      receiptAckKind,
    });
    expect(passengerConsumedKinds, containsAll([20014, 20015]));
  });

  test('a inscrição do serviço é a mesma do EventFeed (emendas 01 e 02)', () {
    final feed = EventFeed(
      relayService: RelayService(transport: _SemRede()),
      acceptedKinds: passengerConsumedKinds,
    );
    expect(buildSubscriptionRequest(passengerConsumedKinds), feed.subscriptionRequest());
  });

  test('traz o marcador, limit 50 e nunca since', () {
    final req = jsonDecode(buildSubscriptionRequest(passengerConsumedKinds))
        as List<dynamic>;
    expect(req[0], 'REQ');
    expect(req[1], eventSubscriptionId);
    final filtro = req[2] as Map<String, dynamic>;
    expect(filtro['#t'], [prototypeMarker]);
    expect(filtro['limit'], 50);
    expect(filtro.containsKey('since'), isFalse);
  });
}

class _SemRede implements RelayTransport {
  @override
  Future<RelayConnection> connect(String url, {Duration? timeout}) =>
      throw UnimplementedError();
}

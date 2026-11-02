import 'package:passenger/domain/accepted_ride.dart';
import 'package:flutter_test/flutter_test.dart';

const _base = AcceptedRide(quoteId: 'quote-1', driverPubkey: 'driver-1');

void main() {
  group('AcceptedRide', () {
    test('duas instâncias com os mesmos campos são iguais', () {
      const a = _base;
      const b = AcceptedRide(quoteId: 'quote-1', driverPubkey: 'driver-1');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('instâncias com quoteId diferente não são iguais', () {
      final b = AcceptedRide(
        quoteId: 'quote-2',
        driverPubkey: _base.driverPubkey,
      );

      expect(_base, isNot(b));
    });

    test('instâncias com driverPubkey diferente não são iguais', () {
      final b = AcceptedRide(
        quoteId: _base.quoteId,
        driverPubkey: 'driver-2',
      );

      expect(_base, isNot(b));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/destination_address.dart';
import 'package:passenger/domain/passenger_position.dart';
import 'package:passenger/domain/payment_method.dart';
import 'package:passenger/domain/ride_request.dart';

void main() {
  final origem = PassengerPosition(
    latitude: -28.9298,
    longitude: -49.4753,
    capturedAt: DateTime(2026, 9, 20),
  );
  const destino = DestinationAddress(
    'Rua Exemplo, 123',
    latitude: -28.6721,
    longitude: -49.3671,
  );

  test('agrupa origem, destino e pagamento', () {
    final pedido = RideRequest(
      origin: origem,
      destination: destino,
      payment: PaymentMethod.pix,
    );

    expect(pedido.origin, origem);
    expect(pedido.destination, destino);
    expect(pedido.payment, PaymentMethod.pix);
  });

  test('igualdade considera os três campos', () {
    final a = RideRequest(
      origin: origem,
      destination: destino,
      payment: PaymentMethod.cash,
    );
    final b = RideRequest(
      origin: origem,
      destination: destino,
      payment: PaymentMethod.cash,
    );
    final c = RideRequest(
      origin: origem,
      destination: destino,
      payment: PaymentMethod.card,
    );

    expect(a, b);
    expect(a, isNot(c));
  });
}

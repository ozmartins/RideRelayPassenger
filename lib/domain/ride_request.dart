import 'package:passenger/domain/destination_address.dart';
import 'package:passenger/domain/passenger_position.dart';
import 'package:passenger/domain/payment_method.dart';

/// Intenção do passageiro no instante em que toca em "Solicitar corrida"
/// (Key Entities do `spec.md` da feature 006).
///
/// Existe só o tempo suficiente para ser transformada no evento Nostr
/// publicado por `EventFeed.publishRideRequest` — não é persistida. A
/// validação de que `origin` e `destination` estão disponíveis acontece
/// antes de construir esta classe (`MapScreen`, FR-002 a FR-004); ela mesma
/// não valida nada, só agrupa três valores já validados.
class RideRequest {
  const RideRequest({
    required this.origin,
    required this.destination,
    required this.payment,
  });

  /// Posição atual do passageiro no instante da solicitação.
  final PassengerPosition origin;

  /// Destino escolhido pelo passageiro (feature 005).
  final DestinationAddress destination;

  /// Forma de pagamento escolhida.
  final PaymentMethod payment;

  @override
  bool operator ==(Object other) =>
      other is RideRequest &&
      other.origin == origin &&
      other.destination == destination &&
      other.payment == payment;

  @override
  int get hashCode => Object.hash(origin, destination, payment);

  @override
  String toString() =>
      'RideRequest(origin: $origin, destination: $destination, payment: '
      '$payment)';
}

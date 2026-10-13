import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/payment_method.dart';

void main() {
  test('dinheiro tem rótulo e valor de contrato corretos', () {
    expect(PaymentMethod.cash.label, 'Dinheiro');
    expect(PaymentMethod.cash.contractValue, 'dinheiro');
  });

  test('pix tem rótulo e valor de contrato corretos', () {
    expect(PaymentMethod.pix.label, 'PIX');
    expect(PaymentMethod.pix.contractValue, 'pix');
  });

  test('cartão tem rótulo e valor de contrato corretos', () {
    expect(PaymentMethod.card.label, 'Cartão');
    expect(PaymentMethod.card.contractValue, 'cartao');
  });
}

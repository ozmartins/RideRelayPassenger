import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/address_suggestion.dart';

void main() {
  group('AddressSuggestion — igualdade por id', () {
    test('duas sugestões com o mesmo id são iguais, mesmo com displayText '
        'e coordenadas diferentes', () {
      const a = AddressSuggestion(
        id: 'R123456',
        displayText: 'Endereço A',
        latitude: -28.9298,
        longitude: -49.4753,
      );
      const b = AddressSuggestion(
        id: 'R123456',
        displayText: 'Endereço B',
        latitude: -28.6721,
        longitude: -49.3671,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('duas sugestões com o mesmo displayText mas id diferente não são '
        'iguais (Edge Case — endereços homônimos)', () {
      const a = AddressSuggestion(
        id: 'R1',
        displayText: 'Rua das Flores',
        latitude: -28.9298,
        longitude: -49.4753,
      );
      const b = AddressSuggestion(
        id: 'R2',
        displayText: 'Rua das Flores',
        latitude: -28.9298,
        longitude: -49.4753,
      );
      expect(a, isNot(b));
    });

    test('expõe id, displayText e coordenadas', () {
      const sugestao = AddressSuggestion(
        id: 'R123456',
        displayText: 'Lisboa, Portugal',
        latitude: -28.9298,
        longitude: -49.4753,
      );
      expect(sugestao.id, 'R123456');
      expect(sugestao.displayText, 'Lisboa, Portugal');
      expect(sugestao.latitude, -28.9298);
      expect(sugestao.longitude, -49.4753);
    });
  });
}

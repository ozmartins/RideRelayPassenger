import 'package:passenger/domain/address_suggestion.dart';
import 'package:passenger/services/geocoding_service.dart';

/// Dublê em memória: nenhum teste de tela toca rede real (Princípio II).
///
/// Programável por texto buscado: cada entrada de [respostas] mapeia o texto
/// exato recebido em [search] para uma lista de sugestões (pode ser vazia —
/// "sem resultado"), e [erros] mapeia texto para uma exceção a lançar.
/// Texto sem entrada em nenhum dos dois mapas retorna lista vazia.
class FakeGeocodingService implements GeocodingService {
  FakeGeocodingService({
    Map<String, List<AddressSuggestion>>? respostas,
    Map<String, Object>? erros,
  }) : respostas = respostas ?? {},
       erros = erros ?? {};

  final Map<String, List<AddressSuggestion>> respostas;
  final Map<String, Object> erros;

  /// Textos efetivamente buscados, na ordem das chamadas — permite ao teste
  /// verificar o debounce (T007).
  final buscas = <String>[];

  @override
  Future<List<AddressSuggestion>> search(String text) async {
    buscas.add(text);
    final erro = erros[text];
    if (erro != null) throw erro;
    return respostas[text] ?? const [];
  }
}

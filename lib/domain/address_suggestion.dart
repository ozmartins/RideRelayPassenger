/// Endereço candidato retornado pelo serviço de geocodificação a partir do
/// texto digitado pelo passageiro (Key Entities do `spec.md`).
///
/// Nunca vem de entrada direta do usuário — só de uma resposta bem-sucedida
/// do [GeocodingService] (FR-004: o destino nunca é construído a partir de
/// texto bruto).
class AddressSuggestion {
  const AddressSuggestion({
    required this.id,
    required this.displayText,
    required this.latitude,
    required this.longitude,
  });

  /// Identificador estável, composto de `osm_type` + `osm_id` da resposta da
  /// Photon (ex.: `"R123456"`). Existe só para distinguir sugestões com o
  /// mesmo texto exibido (Edge Case do `spec.md` — endereços homônimos em
  /// bairros diferentes) — nunca exibido ao usuário.
  final String id;

  /// Texto completo do endereço, já formatado para exibição.
  final String displayText;

  /// Latitude em graus decimais, lida de `geometry.coordinates[1]` da
  /// resposta da Photon — a feature 006 precisa dela para montar a
  /// solicitação de corrida (D4 de `specs/006-solicitar-corrida/research.md`).
  final double latitude;

  /// Longitude em graus decimais, lida de `geometry.coordinates[0]` — a
  /// ordem do GeoJSON é `[longitude, latitude]`, invertida em relação ao par
  /// usual "lat, lon" (D4 de `specs/006-solicitar-corrida/research.md`).
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is AddressSuggestion && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AddressSuggestion($id, $displayText)';
}

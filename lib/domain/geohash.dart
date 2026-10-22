/// Precisões (em caracteres) em que o passageiro publica a tag `g` do `20001`
/// (emenda 27 do contrato). O relay compara o valor da tag por igualdade
/// exata, então o motorista só consegue pedir, via `#g`, uma precisão que o
/// evento carrega.
///
/// MUST ser idêntica à de `RideRelayDriver/lib/domain/geohash.dart`.
const List<int> kPrecisoesDaTag = [5, 4, 3];

/// Geohash padrão (Niemeyer), em Dart puro: sem dependência de terceiros
/// (R1 de `specs/028-tag-geohash-solicitacao/research.md`). Só a codificação;
/// vizinhança e raio existem apenas no motorista.
abstract final class Geohash {
  static const String _alfabeto = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Geohash de [precisao] caracteres para o ponto. Os bits alternam entre
  /// longitude e latitude, começando pela longitude.
  ///
  /// Lança [ArgumentError] para latitude fora de −90..90, longitude fora de
  /// −180..180 (ou não numéricas) e precisão fora de 1–12.
  static String encode(double lat, double lon, int precisao) {
    if (!(lat >= -90 && lat <= 90)) {
      throw ArgumentError.value(lat, 'lat', 'fora de −90..90');
    }
    if (!(lon >= -180 && lon <= 180)) {
      throw ArgumentError.value(lon, 'lon', 'fora de −180..180');
    }
    if (precisao < 1 || precisao > 12) {
      throw ArgumentError.value(precisao, 'precisao', 'fora de 1–12');
    }

    var minLat = -90.0, maxLat = 90.0, minLon = -180.0, maxLon = 180.0;
    final buffer = StringBuffer();
    var bits = 0, valor = 0;
    var par = true;
    while (buffer.length < precisao) {
      if (par) {
        final meio = (minLon + maxLon) / 2;
        if (lon >= meio) {
          valor = (valor << 1) | 1;
          minLon = meio;
        } else {
          valor <<= 1;
          maxLon = meio;
        }
      } else {
        final meio = (minLat + maxLat) / 2;
        if (lat >= meio) {
          valor = (valor << 1) | 1;
          minLat = meio;
        } else {
          valor <<= 1;
          maxLat = meio;
        }
      }
      par = !par;
      if (++bits == 5) {
        buffer.write(_alfabeto[valor]);
        bits = 0;
        valor = 0;
      }
    }
    return buffer.toString();
  }
}

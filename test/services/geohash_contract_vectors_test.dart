import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/geohash.dart';

/// Teste de contrato (emenda 27): `test/fixtures/geohash_vectors.json` é
/// idêntico, byte a byte, nas duas apps (gerado no motorista, nunca editado
/// aqui). O geohash que o passageiro calcula MUST bater com o do arquivo, para
/// que o `#g` do motorista case com a tag `g` publicada. O passageiro confere
/// só `encode`; as células do bloco 3×3 (`celulas`) são do motorista.
void main() {
  final dados = jsonDecode(
    File('test/fixtures/geohash_vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final ancoras = (dados['ancoras'] as List).cast<Map<String, dynamic>>();
  final pontos = (dados['pontos'] as List).cast<Map<String, dynamic>>();

  test('o arquivo traz âncoras e os pontos mínimos do contrato', () {
    expect(ancoras, isNotEmpty);
    expect(
      pontos.map((p) => p['nome']),
      containsAll([
        'ararangua',
        'sao_paulo',
        'chui',
        'boa_vista',
        'antimeridiano_leste',
        'antimeridiano_oeste',
        'perto_do_polo_norte',
        'perto_do_polo_sul',
      ]),
    );
  });

  test('as âncoras independentes batem', () {
    for (final a in ancoras) {
      expect(
        Geohash.encode(
          (a['lat'] as num).toDouble(),
          (a['lon'] as num).toDouble(),
          a['precisao'] as int,
        ),
        a['geohash'],
      );
    }
  });

  for (final p in pontos) {
    test('${p['nome']}: as três tags g', () {
      final lat = (p['lat'] as num).toDouble();
      final lon = (p['lon'] as num).toDouble();
      expect([
        for (final prec in kPrecisoesDaTag) Geohash.encode(lat, lon, prec),
      ], (p['tags_g'] as List).cast<String>());
    });
  }
}

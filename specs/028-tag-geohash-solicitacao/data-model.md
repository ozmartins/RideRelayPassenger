# Modelo de dados: 028-tag-geohash-solicitacao

Nada é persistido.

## `kPrecisoesDaTag` e `Geohash.encode` (`lib/domain/geohash.dart`)

| Item | Definição |
|---|---|
| `kPrecisoesDaTag = [5, 4, 3]` | precisões publicadas, nesta ordem |
| `Geohash.encode(lat, lon, precisao)` | `String` de `precisao` caracteres do alfabeto `0123456789bcdefghjkmnpqrstuvwxyz`; bits alternam a partir da longitude; `ArgumentError` para lat fora de −90..90, lon fora de −180..180 ou precisão fora de 1–12 |

## Tags do `20001`

`[["t","tcc-ufsc-caronas"], ["g",g5], ["g",g4], ["g",g3]]`, com `g4 = g5[0..4]` e `g3 = g5[0..3]`. `content`
inalterado.

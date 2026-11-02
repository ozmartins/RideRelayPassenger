# Pesquisa: 028-tag-geohash-solicitacao

## R1 — Geohash em casa, sem dependência

**Decisão**: `lib/domain/geohash.dart` com `kPrecisoesDaTag = [5, 4, 3]` e `Geohash.encode(lat, lon, precisao)`,
algoritmo idêntico ao `encode` do motorista (Dart puro). Sem pacote de geohash.
**Racional**: a única operação necessária é a codificação (≈30 linhas); a decisão do motorista (R1 da feature 027
dele) já descartou o pacote `dart_geohash`. Sem dependência nova não há entrada obrigatória do Princípio III.
**Alternativas**: pacote de geohash — descartado (acoplamento e versão a vigiar por uma função trivial);
copiar também `neighbors`/`bounds` — descartado (Princípio V: o passageiro não filtra).
**Garantia contra divergência**: vetor compartilhado byte a byte (R3) com âncoras públicas independentes
(`42.605, -5.603 → ezs42`; `57.64911, 10.40744 → u4pruydqqvj`).

## R2 — Três tags `g`, não uma

**Decisão**: publicar `g` em 5, 4 e 3 caracteres, nesta ordem, após o marcador `t`.
**Racional**: o relay compara por igualdade exata; o motorista escolhe a precisão que cobre o raio dele
(contrato, seção *Tag `g` do `20001`*). Confirmado pelo autor em 2026-10-21; substitui "exatamente uma" do pedido.

## R3 — Vetor de contrato

**Decisão**: `test/fixtures/geohash_vectors.json` é gerado no motorista (`tool/gen_geohash_vectors.dart`) e copiado
byte a byte; `diff` sem saída é parte do quickstart. O teste do passageiro confere só `encode` (as 9 células são
do motorista).
**Dependência de ordem**: o gerador e o arquivo ainda não existem no motorista; esta feature os consome. Se o
formato do vetor mudar lá, muda aqui no mesmo passo.

## R4 — Coordenada inválida

**Decisão**: `publishRideRequest` captura o `ArgumentError` de `encode` e devolve `PublishReport` vazio, o mesmo
caminho de falha de cifra: nada é assinado nem transmitido. **Racional**: nunca emitir `20001` sem `g` (o motorista
o descartaria sem aviso) nem com `g` errada. A origem vem do GPS, então o caso é defensivo.

## R5 — Onde calcular

**Decisão**: dentro de `publishRideRequest`, a partir de `request.origin`; a tela não muda. Todo caminho de
publicação do `20001` passa por esse método (única chamada: `MapScreen`).

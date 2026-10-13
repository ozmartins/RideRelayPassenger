# Contrato: GeocodingService

Este não é um contrato de evento Nostr (Princípio IV não se aplica — nenhum evento novo é introduzido
nem precisa ser replicado no motorista). É o contrato da interface interna que a tela (`MapScreen`)
usa, e o subconjunto do contrato HTTP da Photon do qual essa interface depende. Documentado aqui para
que a implementação e os testes (dublê vs. real) concordem sobre o comportamento antes do código.

## Interface `GeocodingService` (`lib/services/geocoding_service.dart`)

```text
abstract class GeocodingService {
  Future<List<AddressSuggestion>> search(String text);
}
```

- **Entrada**: `text` — o texto atualmente digitado no campo de destino. Nunca vazio quando chamado
  (a tela só chama depois do mínimo de caracteres de D3 do `research.md`).
- **Saída em caso de sucesso**: lista de `AddressSuggestion` (pode ser vazia — "sem resultado" não é
  erro).
- **Saída em caso de falha**: MUST lançar uma exceção (não retornar lista vazia) para que a tela
  distinga "sem resultado" (FR-008) de "falha de busca" (FR-009). Toda falha de rede, timeout ou
  resposta malformada é reportada dessa forma.
- **Sem estado entre chamadas**: cada chamada é independente; a implementação não mantém a última
  busca nem faz cancelamento — isso é responsabilidade de quem chama (a tela ignora a resposta de uma
  busca que não é mais a mais recente, caso duas cheguem fora de ordem).

## Implementação real: `PhotonGeocodingService`

Chama `GET https://photon.komoot.io/api/` com query string:

| Parâmetro | Valor |
|---|---|
| `q` | o texto recebido em `search(text)`, sem alteração |
| `lang` | `default` (fixo — D4 de `research.md`; `pt` não é suportado pela Photon pública, só `default`/`de`/`en`/`fr`) |
| `limit` | `5` (fixo — D2 de `research.md`) |

Nenhum outro parâmetro é enviado — em particular, nenhum `lat`/`lon`/posição do usuário (exceção da
constituição 2.2.0 exige ausência de identificador do usuário na chamada).

**Cabeçalho obrigatório**: `User-Agent: CaronasPassageiro/1.0 (br.ufsc.tcc.caronas.passenger;
academic prototype, UFSC)`, em ASCII puro — um valor com acentos (ex.: "protótipo acadêmico") é
rejeitado pelo próprio `package:http` com `FormatException` antes de qualquer requisição sair (D4 de
`research.md`). A Photon pública responde HTTP 403 ao `User-Agent` padrão do `package:http` — sem
esse cabeçalho, toda busca falha.

**Timeout**: 5 segundos (D1 de `research.md`); estourar o timeout é tratado como falha de busca.

### Contrato de resposta esperado (subconjunto usado da Photon)

Corpo JSON no formato GeoJSON `FeatureCollection`:

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "geometry": { "type": "Point", "coordinates": [-9.1365919, 38.7077507] },
      "properties": {
        "osm_type": "R",
        "osm_id": 123456,
        "name": "Lisboa",
        "street": null,
        "housenumber": null,
        "city": null,
        "county": "Lisboa",
        "state": "Lisboa",
        "country": "Portugal",
        "countrycode": "PT"
      }
    }
  ]
}
```

Campos usados para montar `AddressSuggestion`:

- `id` = `"${properties.osm_type}${properties.osm_id}"`.
- `displayText` = junção, na ordem `name`, `street` + `housenumber` (se ambos presentes), `city` ou
  `county` (o primeiro presente), `state`, `country`, separados por `", "`, pulando os campos ausentes
  ou nulos.

Qualquer campo de `properties` não listado acima é ignorado. `geometry`/`coordinates` não é usado
nesta feature (Assumptions do `spec.md` — sem exibição no mapa nem biblioteca de posição associada ao
destino).

**Resposta malformada** (corpo que não é JSON, `features` ausente, ou item sem `properties.name`):
tratada como falha de busca (FR-009), nunca como "sem resultado" nem como sugestão parcial.

## Dublê para testes

`test/support/` (ou local equivalente) MUST fornecer uma implementação de `GeocodingService` que
retorna respostas programadas (lista de sugestões, lista vazia, ou lança exceção) sem tocar rede,
para os testes de `MapScreen`. Os testes do próprio `PhotonGeocodingService` usam um `http.Client`
dublê (não uma rede real), respondendo com corpos JSON fixos para cada cenário da tabela de Riscos de
D1: sucesso com resultados, sucesso vazio, erro HTTP, corpo malformado, timeout.

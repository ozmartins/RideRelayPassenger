# Plano de implementação: 028-tag-geohash-solicitacao

**Spec**: [spec.md](spec.md) · **App**: `passenger/` · **Data**: 2026-10-21 · **Contrapartida**: feature 027 do motorista
(`027-filtro-geografico-solicitacoes`, que define a emenda 27)

## Resumo

O `20001` passa a levar, além do marcador `t`, três tags `["g", <geohash>]` (5, 4 e 3 caracteres) calculadas da
`origin` do `content`. O `content` não muda. O passageiro ganha só um `encode` de geohash em Dart puro (sem
dependência) e acrescenta as tags em `EventFeed.publishRideRequest`. O texto da emenda 27 entra no contrato e o
vetor `geohash_vectors.json` é copiado byte a byte do motorista.

## Contexto técnico

- **Linguagem/SDK**: Dart ^3.13.3, Flutter, Android apenas.
- **Dependências novas**: nenhuma ([research.md](research.md) R1).
- **Armazenamento**: nenhum; a tag é recalculada a cada publicação.
- **Testes**: `flutter_test` com o transporte dublê de `test/support/`; assinatura real; nenhum relay real.
- **Restrições**: `content` byte a byte igual ao de antes; tag em claro; sem raio nem filtro no passageiro;
  coordenadas inválidas nunca produzem evento sem `g` ou com `g` errada.
- **Escala**: 3 tags de ≤ 5 caracteres por solicitação.

## Verificação da constituição (2.18.0)

| Princípio / restrição | Situação |
|---|---|
| I — segredo não vaza | OK: nenhuma chave nova; a tag deriva da origem pública. |
| II — assinatura nasce com teste | OK: a tag entra antes da assinatura; teste confere o evento assinado e verificado com a cripto real. |
| III — dependência registrada | Nenhuma nova ([research.md](research.md) R1). |
| IV — contrato antes do código | [contracts/emenda-27-tag-g.md](contracts/emenda-27-tag-g.md) (cópia do texto do motorista); emenda 27 no `nostr-events.md` das duas apps na mesma alteração; vetor compartilhado. |
| V — simplicidade | Só `encode` e `kPrecisoesDaTag`; sem vizinhança, bounds nem raio (consumidor só no motorista). |
| Dado pessoal sem cifra | OK: a tag não expõe além do `content` do `20001`, que já leva a origem em claro (exceção da constituição). |
| Segundo plano / notificação | Sem mudança; o serviço não lê tags `g`. |
| Identidade visual | Sem tela nova nem mudança de tela. |

Pós-design: sem violações; nenhuma exceção a justificar.

## Estrutura

```text
specs/028-tag-geohash-solicitacao/
├── plan.md  research.md  data-model.md  quickstart.md  tasks.md
└── contracts/emenda-27-tag-g.md

lib/domain/geohash.dart                       # novo: kPrecisoesDaTag, Geohash.encode
lib/services/event_feed.dart                  # publishRideRequest passa extraTags g
specs/002-nostr-relay-connection/contracts/nostr-events.md   # emenda 27 (idêntico ao do motorista)
test/domain/geohash_test.dart                 # novo: âncoras públicas, limites, erros
test/services/geohash_contract_vectors_test.dart  # novo: confere test/fixtures/geohash_vectors.json
test/event_feed_test.dart                     # ampliado: 20001 tem t + 3 g, content intacto, sem relay real
test/fixtures/geohash_vectors.json            # cópia byte a byte do motorista
CLAUDE.md                                     # invariante nova (commit à parte)
```

## Ordem de entrega

1. Contrato (emenda 27) nos dois repositórios, mesma alteração; `diff` só no cabeçalho.
2. Vetor `geohash_vectors.json` gerado no motorista e copiado.
3. `encode` + testes, depois a publicação da tag + testes.
4. `CLAUDE.md` em commit separado.

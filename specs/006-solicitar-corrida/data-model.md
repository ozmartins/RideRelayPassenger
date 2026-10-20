# Phase 1 — Data Model: Solicitar corrida

## `PaymentMethod` (novo, `lib/domain/payment_method.dart`)

Enum com os três valores aceitos (D3 de `research.md`):

```text
enum PaymentMethod { cash, pix, card }
```

Nomes dos valores em inglês (convenção Dart de enum), mas cada um carrega o texto de exibição em
português e o valor de contrato (D3) que vai para o `content` do evento:

| Valor | Exibição na UI | Valor no contrato (`content.payment`) |
|-------|-----------------|----------------------------------------|
| `PaymentMethod.cash` | "Dinheiro" | `"dinheiro"` |
| `PaymentMethod.pix` | "PIX" | `"pix"` |
| `PaymentMethod.card` | "Cartão" | `"cartao"` |

`PaymentMethod.cash` é o valor pré-selecionado por padrão ao abrir a tela do mapa (FR-005,
clarificação da sessão 2026-09-20).

## `RideRequest` (novo, `lib/domain/ride_request.dart`)

Representa a intenção do passageiro no instante em que toca em "Solicitar corrida" — existe só o
tempo suficiente para ser transformada no evento Nostr publicado; não é persistida (Key Entities do
`spec.md`).

| Campo | Tipo | Origem |
|-------|------|--------|
| `origin` | `PassengerPosition` (já existe) | Última posição lida do `LocationService` |
| `destination` | `DestinationAddress` (já existe, ganha lat/lon — ver abaixo) | Última sugestão selecionada pelo passageiro |
| `payment` | `PaymentMethod` | Selecionado na `SegmentedButton` da tela do mapa |

Validação (FR-002 a FR-004) acontece **antes** de construir um `RideRequest`: a tela só o monta
quando `origin` e `destination` estão disponíveis. `RideRequest` em si não valida nada — é um
agrupamento de três valores já validados, não uma máquina de estados.

## `AddressSuggestion` (existente, `lib/domain/address_suggestion.dart`) — ganha lat/lon

Novos campos, sourced de `geometry.coordinates` da resposta da Photon (D4 de `research.md`):

| Campo novo | Tipo | Observação |
|------------|------|------------|
| `latitude` | `double` | `geometry.coordinates[1]` da feature GeoJSON |
| `longitude` | `double` | `geometry.coordinates[0]` da feature GeoJSON |

`==`/`hashCode` continuam baseados só em `id` (nenhuma mudança de identidade — duas sugestões com o
mesmo `id` continuam a mesma sugestão, ainda que hipoteticamente viessem com coordenadas
arredondadas de forma diferente entre respostas).

## `DestinationAddress` (existente, `lib/domain/destination_address.dart`) — ganha lat/lon

Novos campos, copiados da `AddressSuggestion` selecionada no momento da construção (mesma regra de
FR-004/FR-005 da feature 005 — `DestinationAddress` só nasce de uma seleção explícita):

| Campo novo | Tipo |
|------------|------|
| `latitude` | `double` |
| `longitude` | `double` |

`==`/`hashCode` passam a considerar `latitude`/`longitude` além de `text` — duas instâncias com o
mesmo texto de exibição mas coordenadas diferentes (endereços homônimos, já um Edge Case coberto pelo
`id` de `AddressSuggestion` na feature 005) deixam de comparar como iguais, o que é mais correto: elas
representam destinos diferentes.

## Evento Nostr "Solicitação de corrida" (contrato — ver `contracts/`)

Não é um tipo Dart novo além dos acima; é a serialização de `RideRequest` + `Identity` no envelope
NIP-01 padrão, montada em `EventFeed.publishRideRequest` (D6 de `research.md`) via
`nostr.NostrEvent.fromPartialData`, com `content` no formato definido em
`contracts/ride-request-event.md`.

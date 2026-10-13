# Phase 1 — Data Model: Mapa e Destino do Passageiro

## PassengerPosition

Coordenadas geográficas atuais do aparelho do passageiro (FR-001 a FR-003).

| Campo | Tipo | Regras |
|-------|------|--------|
| `latitude` | `double` | obrigatório |
| `longitude` | `double` | obrigatório |
| `capturedAt` | `DateTime` | momento da leitura; usado apenas para depuração/testes, sem exigência de exibição na UI |

- Existe apenas em memória, durante a sessão do aplicativo (Key Entities do `spec.md`).
- Não é persistida entre execuções, nem enviada a nenhum relay ou servidor nesta feature.
- Tipo próprio do domínio — nunca o `Position` de `package:geolocator` diretamente (Princípio III;
  D1 de `research.md`).
- Sem transições de estado: é substituída inteiramente a cada leitura nova de posição.

## DestinationAddress

Texto livre informado pelo passageiro indicando para onde deseja ir (FR-006 a FR-010).

| Campo | Tipo | Regras |
|-------|------|--------|
| `text` | `String` | livre; pode ser vazio; sem validação de formato ou de correspondência a endereço real (FR-007) |

- Existe apenas em memória, local ao aparelho, durante a sessão do aplicativo (Key Entities do
  `spec.md`).
- Não é persistida entre execuções, nem publicada nem enviada a nenhum relay ou servidor nesta
  feature (FR-008).
- Não depende de `PassengerPosition` estar disponível (FR-010) — as duas entidades são independentes
  entre si nesta feature.
- Sem transições de estado formais: o valor mais recente digitado é o único estado relevante
  (FR-009).

## Relação entre as entidades

Nenhuma relação direta nesta feature: `PassengerPosition` alimenta o mapa e o indicador de posição;
`DestinationAddress` alimenta apenas o campo de texto. Uma feature futura pode vir a relacioná-las
(por exemplo, para calcular rota ou publicar uma solicitação de corrida), mas isso está fora do escopo
aqui — nenhum evento Nostr nem comunicação entre as duas apps é criado por esta feature.

# Phase 0 — Research: Solicitar corrida

## D1 — Kind do evento de solicitação de carona (atende FR-006, FR-007)

**Decision**: usar `kind: 20001` ("Solicitação de carona"), na faixa de eventos efêmeros do NIP-01
(20000–29999) — relays não retêm nem reenviam esse kind ao estabelecer uma inscrição futura.

**Contexto da decisão**: a tabela de kinds do contrato (`specs/002-nostr-relay-connection/contracts/nostr-events.md`)
já reserva "Solicitação de carona" como *futura*, sem número. Um número precisa existir para
implementar e testar. `kind: 1` (usado pelo evento de teste) é proibido para eventos de domínio pelo
próprio contrato — poluiria e seria poluído pelo tráfego social geral da rede.

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| `20001`, efêmero (escolhida) | Uma solicitação de carona é, por natureza, um pedido momentâneo: se nenhum motorista estiver ouvindo no instante da publicação, reter o evento no relay para entrega tardia não corresponde ao domínio (o passageiro precisa de uma corrida agora, não daqui a horas). A faixa efêmera do NIP-01 (20000–29999) expressa isso sem exigir nenhuma lógica própria do app — o relay descarta após repassar aos ouvintes conectados. |
| Evento regular (kind na faixa 1000–9999) | Persistiria no relay e seria devolvido a inscrições futuras (sujeito ao `limit`/`since` de quem se inscreve), fazendo motoristas verem solicitações antigas e já resolvidas como se fossem novas — exigiria um mecanismo de expiração/cancelamento que esta feature não implementa (fora de escopo: a app do motorista consumir o evento é trabalho futuro). |
| Evento substituível parametrizado (kind 30000–39999, com tag `d`) | Faria sentido se o passageiro tivesse no máximo uma solicitação "vigente" que atualiza a anterior — mas nada nesta feature define o que é "a mesma" solicitação nem uma tela para o passageiro acompanhar/cancelar; introduzir isso sem consumidor descumpriria o Princípio V. |

### Riscos assumidos e mitigação

- **Risco de relay não implementar a semântica efêmera do NIP-01 corretamente**: aceito como risco de
  protótipo — o pior caso é o relay reter o evento como se fosse regular, o que não quebra nada para
  esta feature (que só publica, nunca se inscreve neste kind).

## D2 — Forma do `content`: JSON estruturado (atende FR-006, FR-007)

**Decision**: `content` é uma string JSON com três campos: `origin` (`{lat, lon}`), `destination`
(`{lat, lon}`) e `payment` (`"dinheiro" | "pix" | "cartao"`), latitude/longitude em graus decimais
(`double`), sem truncamento de precisão.

**Contexto da decisão**: o NIP-01 trata `content` como texto livre, com a semântica definida pelo
`kind`. Sem convenção comunitária estabelecida para "solicitação de carona" (ao contrário de, por
exemplo, `kind: 0` para metadados de perfil), a estrutura é definida por este contrato.

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| JSON estruturado no `content` (escolhida) | Um único campo para decodificar; biblioteca padrão (`dart:convert`) dos dois lados, sem depender de convenção externa. Mantém tags reservadas só para o que já existe no contrato (o marcador do protótipo). |
| Coordenadas como tags (`["origin", "<lat>", "<lon>"]`, `["destination", ...]`, `["payment", ...]`) | Seguiria o padrão de indexação de outras NIPs (ex.: tag `g` de geohash), permitindo relays filtrarem por tag — recurso que esta feature não usa (a app do motorista não se inscreve neste kind ainda). Acrescentaria uma convenção de tags própria do protótipo sem consumidor, contra o Princípio V. |
| Geohash em vez de lat/lon exatos | Reduziria a precisão exposta publicamente (mitigação de privacidade), mas a justificativa de privacidade do `spec.md` já assume coordenadas exatas como necessárias para o motorista avaliar a corrida; truncar precisão é mitigação registrada como trabalho futuro, não desta feature. |

### Riscos assumidos e mitigação

- **Risco de o `content` crescer e virar um formato difícil de versionar**: aceito — o escopo desta
  feature é apenas os três campos citados; qualquer campo novo (ex.: número de passageiros) é decisão
  de uma feature futura, com sua própria emenda ao contrato.

## D3 — Valores do campo `payment` (atende FR-005, FR-006)

**Decision**: os três valores aceitos são as strings ASCII `"dinheiro"`, `"pix"` e `"cartao"` (sem
cedilha/til, para evitar qualquer ambiguidade de *encoding* entre implementações).

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| `"dinheiro"` / `"pix"` / `"cartao"` (escolhida) | Mantém os nomes em português, como o resto do domínio do protótipo (`displayText`, mensagens de UI), evitando uma segunda tradução só para o contrato; ASCII puro evita o mesmo tipo de armadilha de *encoding* já visto no `User-Agent` da Photon (D4 de `specs/005-busca-endereco-photon/research.md`). |
| `"cash"` / `"pix"` / `"card"` (inglês) | Mistura idiomas sem necessidade — o restante do vocabulário do protótipo (contrato, commits, UI) é português. |
| Código numérico (`0`/`1`/`2`) | Exigiria uma tabela de tradução para qualquer cliente ler o evento sem consultar este contrato; string legível é mais direta para um protocolo cujo objetivo é interoperar sem backend. |

## D4 — Coordenadas de destino: `AddressSuggestion`/`DestinationAddress` passam a carregar lat/lon
(atende FR-006)

**Decision**: `AddressSuggestion` e `DestinationAddress` ganham os campos `latitude`/`longitude`
(`double`), lidos de `geometry.coordinates` da resposta da Photon — que vem no formato GeoJSON
`[longitude, latitude]` (ordem invertida em relação ao par usual "lat, lon").

**Contexto da decisão**: a feature 005 já recebe essas coordenadas na resposta da Photon
(`feature['geometry']['coordinates']`, ver `specs/005-busca-endereco-photon/contracts/geocoding-service.md`)
mas as descarta ao montar `AddressSuggestion` — só usava o texto. Sem essa mudança, não há como montar
o evento desta feature: a coordenada de destino não estaria disponível em nenhum lugar do app. Não é
uma dependência de terceiros nova (Princípio III não se aplica) — é dado que a Photon já devolve,
apenas não capturado até agora.

### Riscos assumidos e mitigação

- **Risco de trocar a ordem lat/lon ao ler o GeoJSON**: mitigado com teste automatizado que verifica
  explicitamente que `coordinates[0]` vira `longitude` e `coordinates[1]` vira `latitude` (a inversão é
  uma fonte de erro conhecida e silenciosa — o par errado ainda é um par de números válido).

## D5 — Seleção da forma de pagamento na interface (atende FR-005, clarificação da sessão
2026-09-20)

**Decision**: `SegmentedButton<PaymentMethod>` do Material 3 (`package:flutter`, já uma dependência do
projeto — nenhuma dependência nova), com "Dinheiro" pré-selecionado, na mesma barra inferior do campo
de destino.

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| `SegmentedButton` (escolhida) | Três opções mutuamente exclusivas, sempre visíveis, sem exigir abrir um menu — coerente com a decisão de clarificação de manter tudo em uma única interação (SC-001 do `spec.md`). Widget padrão do Material 3, já disponível via `package:flutter`. |
| `DropdownButton`/`DropdownMenu` | Esconde as opções não selecionadas atrás de um toque extra, sem ganho real para apenas três valores fixos. |
| Três `RadioListTile` empilhados | Ocupa mais espaço vertical que o cartão inferior comporta junto do campo de destino e da lista de sugestões. |

## D6 — Publicação: novo método em `EventFeed`, não um serviço novo (atende FR-006, FR-007, FR-011)

**Decision**: acrescentar `Future<PublishReport> publishRideRequest(RideRequest request, Identity
identity)` a `EventFeed` (`lib/services/event_feed.dart`), ao lado do `publish` já existente para o
evento de teste. `MapScreen` passa a receber `EventFeed`, `Identity` e `RelayService` (para a checagem
`hasAnyConnected`, mesmo padrão de `HomeScreen`), preservando o comentário estrutural do arquivo — que
será atualizado para não afirmar mais que a tela nunca recebe esses tipos.

**Contexto da decisão**: `EventFeed` já é o único lugar (fora do teste) que assina e publica eventos, e
já implementa a espera por confirmação `OK` por relay reaproveitada aqui — reaproveitar em vez de
duplicar essa lógica em uma classe nova evita a estrutura sem consumidor que o Princípio V proíbe.

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| Novo método em `EventFeed` (escolhida) | Reaproveita a espera por `OK` por relay já implementada em `publish`, sem duplicar. |
| Serviço novo (`RideRequestService`) só para este evento | Duplicaria a lógica de aguardar confirmação por relay já escrita em `EventFeed.publish`, ou exigiria extrair essa lógica para um lugar comum — trabalho não pedido por nenhum outro consumidor hoje (Princípio V). |

## D7 — Alcance da publicidade do conteúdo (Restrições de Segurança e Privacidade)

Ver a seção "Justificativa de privacidade" do `spec.md`: coordenadas e forma de pagamento trafegam sem
criptografia porque a solicitação é, por definição, um anúncio a qualquer motorista interessado, não
uma mensagem a um destinatário já escolhido. Registrado aqui apenas para referência cruzada — a
justificativa por extenso vive no `spec.md`, como a constituição exige.

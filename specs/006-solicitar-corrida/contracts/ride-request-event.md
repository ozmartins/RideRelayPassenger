# Contrato: evento "Solicitação de carona" (kind 20001)

O contrato de interoperabilidade é o único canônico e vive em
`specs/002-nostr-relay-connection/contracts/nostr-events.md` (emenda 04, seção *Conteúdo do kind
20001*) — replicado de forma idêntica na app do motorista, conforme o Princípio IV da constituição.
Este arquivo **não duplica** aquele contrato; documenta a interface interna do passageiro que o
implementa, para que a implementação e os testes concordem sobre o comportamento antes do código
(mesmo padrão de `specs/005-busca-endereco-photon/contracts/geocoding-service.md`).

## `EventFeed.publishRideRequest` (`lib/services/event_feed.dart`)

```text
Future<PublishReport> publishRideRequest(RideRequest request, Identity identity)
```

- **Entrada**: `request` — um `RideRequest` já montado (origem, destino e forma de pagamento todos
  presentes; a validação de que estão disponíveis acontece na tela, antes de construir o
  `RideRequest` — ver FR-002 a FR-004 do `spec.md`). `identity` — a identidade local do passageiro,
  usada para assinar.
- **Saída**: `PublishReport` (tipo já existente, reaproveitado de `publish`) — o `eventId` do evento
  montado e o desfecho (`accepted`/`rejected`/`noAnswer`) por relay conectado no momento da chamada.
- **Efeito**: monta o evento com `kind: 20001`, a tag de marcador `["t", "tcc-ufsc-caronas"]` e
  `content` no formato JSON definido no contrato canônico (`origin`, `destination`, `payment`),
  assina com `identity` e transmite (`RelayService.broadcast`) a todos os relays atualmente
  conectados (`RelayService.connectedUrls`).
- **Sem relay conectado**: retorna `PublishReport` com `byRelay` vazio, sem lançar exceção — mesmo
  comportamento de `publish` para o evento de teste. Quem chama (a tela) MUST checar
  `RelayService.hasAnyConnected` **antes** de chamar, para mostrar uma mensagem específica de "nenhum
  relay conectado" em vez de um relato vazio silencioso (mesmo padrão de `HomeScreen._publicar`).
- **Não se inscreve em nada**: ao contrário de `EventFeed.start()`, este método só publica; a
  inscrição em `kind: 1` continua sendo a única mantida por esta app (consumir `kind: 20001` é da app
  do motorista, fora de escopo).

## `RideRequest` → `content` (mapeamento)

| Campo de `RideRequest` | Campo em `content` |
|--------------------------|---------------------|
| `origin.latitude`, `origin.longitude` | `origin.lat`, `origin.lon` |
| `destination.latitude`, `destination.longitude` | `destination.lat`, `destination.lon` |
| `payment` (`PaymentMethod`) | `payment` — traduzido pela tabela de D3/`data-model.md` (`cash` → `"dinheiro"`, `pix` → `"pix"`, `card` → `"cartao"`) |

## Validação da tela (`MapScreen`) antes de chamar `publishRideRequest`

Ordem de checagem ao tocar em "Solicitar corrida" (FR-002 a FR-004):

1. Destino ausente (nenhum `DestinationAddress` selecionado) → mensagem de destino ausente; não
   chama `publishRideRequest`.
2. Posição atual ausente (`PassengerPosition` ainda não recebida) → mensagem de posição
   indisponível; não chama `publishRideRequest`.
3. Nenhum relay conectado (`RelayService.hasAnyConnected == false`) → mensagem de nenhum relay
   conectado; não chama `publishRideRequest` (mesmo padrão de `HomeScreen`, FR-010).
4. Todas as checagens acima passaram → monta `RideRequest`, chama `publishRideRequest`, mostra
   confirmação (FR-009) ou erro (FR-010) conforme o `PublishReport`.

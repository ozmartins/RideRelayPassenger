# Phase 1 — Data Model: Tela de orçamentos recebidos e cancelamento da solicitação

## `PassengerRideRules` (alterada)

Acrescenta uma guarda à classe já existente (`lib/domain/passenger_ride_status.dart`, feature 014):

```dart
/// A transição de volta a [PassengerRideStatus.inicial] por cancelamento só
/// é válida a partir de [PassengerRideStatus.aguardandoOrcamentos] (FR-009,
/// FR-011).
static bool canCancelRequest(PassengerRideStatus current) =>
    current == PassengerRideStatus.aguardandoOrcamentos;
```

Nenhum valor novo em `PassengerRideStatus` — o cancelamento é só mais uma transição de volta a
`inicial`, ao lado da já existente por avaliação concluída.

## `ReceivedQuotesScreen` (novo widget, apresentacional)

Substitui `RideQuotesModal`. Mesma filosofia (widget "burro": publicar e decidir o que "fechar"
significa é responsabilidade de quem chama):

```dart
class ReceivedQuotesScreen extends StatelessWidget {
  const ReceivedQuotesScreen({
    required this.quotes,       // ValueListenable<List<ReceivedQuote>>
    required this.onAccept,     // Future<String?> Function(ReceivedQuote)
    required this.onCancel,     // VoidCallback
  });
}
```

| Elemento | Origem | Observação |
|---|---|---|
| Lista de itens | `quotes` (`ValueListenableBuilder`) | Mesmo mecanismo de atualização ao vivo de `RideQuotesModal` (D3 de `specs/008-receber-orcamentos/research.md`) — sem novo `showDialog`/`Navigator`. |
| Item da lista | `driverName`, `carBrand`/`carModel`/`carYear`, `total`, `etaMinutes` (ou "não disponível"), botão "Aceitar" | Mesmos campos de `_LinhaDeOrcamento` (`ride_quotes_modal.dart`), em layout mais compacto (FR-005) — menos preenchimento vertical, texto em uma ou duas linhas por item em vez de um card avulso por orçamento. |
| Botão "Cancelar" | fixo na parte inferior da tela, fora da lista rolável | Sempre visível, inclusive com a lista vazia (FR-008). |

Nenhuma entidade de domínio nova: `ReceivedQuote` (feature 008) é reaproveitada sem alteração.

## Fluxo em `MapScreen`

- **Entrada em `aguardandoOrcamentos`** (`_solicitarCorrida`, sucesso) e **restauração**
  (`_carregarEstadoCorrida`, status já persistido como `aguardandoOrcamentos`): ambos os pontos
  passam a chamar `widget.receivedQuoteStore.byRequest(_solicitacaoAtivaId!)` e inicializar
  `_orcamentosRecebidos.value` com o resultado (D4 de `research.md`, FR-012).
- **Renderização**: `build()` retorna `ReceivedQuotesScreen(...)` diretamente (sem `Stack`/dim,
  D1 de `research.md`) quando `_rideStatus == PassengerRideStatus.aguardandoOrcamentos`, antes de
  montar o `scaffold` do mapa. O bloco antigo de `_modalOrcamentosVisivel` (`Stack` +
  `Positioned.fill` com `RideQuotesModal`) é removido.
- **Painel de solicitação**: o `Positioned` com o campo de destino, forma de pagamento e
  "Solicitar corrida" passa a ser condicional a `_rideStatus == PassengerRideStatus.inicial`
  (FR-001, FR-002) — como o próprio `build()` já retorna antes disso quando não está em `inicial`,
  na prática essa condição só precisa valer dentro do ramo em que o mapa é de fato mostrado.
- **`_cancelarSolicitacao`** (novo método): valida
  `PassengerRideRules.canCancelRequest(_rideStatus)`; para cada `ReceivedQuote` em
  `_orcamentosRecebidos.value`, chama `widget.eventFeed.publishQuoteRejection(quote,
  widget.identity)` (`unawaited`, D2 de `research.md`); atualiza `_rideStatus = inicial`, persiste
  via `PassengerRideStateStore.save(inicial, null)`, e limpa `_solicitacaoAtivaId`,
  `_orcamentosRecebidos.value` e `_idsOrcamentosProcessados`.
- **`_processarOrcamentoRecebido`**: sem alteração na persistência (`receivedQuoteStore.save`
  continua incondicional); a condição que hoje decide reabrir a modal
  (`PassengerRideRules.canAcceptQuote(_rideStatus)`) passa a decidir simplesmente se o orçamento é
  adicionado a `_orcamentosRecebidos.value` — sem `_modalOrcamentosVisivel`, já que a visibilidade
  da tela inteira é derivada de `_rideStatus`.

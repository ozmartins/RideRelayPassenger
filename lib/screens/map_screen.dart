import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../domain/accepted_ride.dart';
import '../domain/address_suggestion.dart';
import '../domain/destination_address.dart';
import '../domain/driver_location.dart';
import '../domain/identity.dart';
import '../domain/nostr_event.dart';
import '../domain/passenger_position.dart';
import '../domain/passenger_ride_status.dart';
import '../domain/payment_method.dart';
import '../domain/received_quote.dart';
import '../domain/reputation.dart';
import '../domain/ride_rating.dart';
import '../domain/ride_request.dart';
import '../domain/ride_route.dart';
import '../domain/route_result.dart';
import '../domain/service_state.dart';
import '../services/accepted_ride_store.dart';
import '../services/background/service_controller.dart';
import '../services/destination_store.dart';
import '../services/event_feed.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/passenger_ride_state_store.dart';
import '../services/received_quote_store.dart';
import '../services/receipt_service.dart';
import '../services/receipt_store.dart';
import '../services/relay_hub.dart';
import '../services/ride_rating_store.dart';
import '../services/route_service.dart';
import 'camada_mapa_base.dart';
import 'cancel_ride_modal.dart';
import 'driver_arrived_modal.dart';
import 'driver_moving_modal.dart';
import 'identidade_visual.dart';
import 'received_quotes_screen.dart';
import 'ride_rating_modal.dart';
import 'driver_unavailable_modal.dart';
import 'ride_cancelled_modal.dart';

/// Duração do agrupamento de digitações antes de disparar uma busca de
/// endereço (D3 de `specs/005-busca-endereco-photon/research.md`).
const _debounceBusca = Duration(milliseconds: 400);

/// Tamanho mínimo de texto para disparar uma busca de endereço (D3 de
/// `specs/005-busca-endereco-photon/research.md`).
const _tamanhoMinimoBusca = 3;

/// Distância mínima de deslocamento, a partir da origem usada no último
/// cálculo de rota, para disparar um recálculo (D2 de
/// `specs/007-rota-ate-destino/research.md`, FR-003) — nunca a cada
/// atualização de posição, para não exceder o limite de requisições do
/// nível gratuito do serviço de roteamento.
const _limiarRecalculoRotaMetros = 50;

const _calculadoraDistancia = Distance();

/// Raio, em metros, do destino pedido dentro do qual o botão de confirmar a
/// chegada aparece — 1 km, o mesmo do aviso do motorista (emenda 23 do
/// contrato): a busca de endereço nem sempre localiza o destino com precisão.
const _raioConfirmacaoDestinoMetros = 1000;

/// Tela inicial do aplicativo: mapa centrado na posição real do passageiro,
/// com um indicador dessa posição, um campo de busca de endereço de destino
/// com sugestões da Photon (feature 005), um seletor de forma de pagamento e
/// o botão "Solicitar corrida" (feature 006).
///
/// Único arquivo do aplicativo, além de `main.dart`, que conhece tipos de
/// `package:flutter_map` (Princípio III). Até a feature 005, esta tela nunca
/// recebia `RelayService` nem `EventFeed`, o que evidenciava estruturalmente
/// que nada aqui publicava em relay. A feature 006 muda isso deliberadamente
/// (clarificação da sessão 2026-09-20, FR-011): a tela passa a publicar a
/// solicitação de corrida, e por isso recebe os três.
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.locationService,
    required this.geocodingService,
    required this.eventFeed,
    required this.identity,
    required this.relayService,
    required this.routeService,
    required this.receivedQuoteStore,
    required this.acceptedRideStore,
    required this.destinationStore,
    required this.rideStateStore,
    required this.rideRatingStore,
    required this.receiptStore,
    required this.receiptService,
    this.serviceController,
  });

  final LocationService locationService;
  final GeocodingService geocodingService;
  final EventFeed eventFeed;
  final Identity identity;
  final RelayHub relayService;
  final RouteService routeService;
  final ReceivedQuoteStore receivedQuoteStore;

  /// Persistência da corrida aceita (feature 009, FR-006/FR-007).
  final AcceptedRideStore acceptedRideStore;
  final DestinationStore destinationStore;

  /// Persistência do estado único de corrida (feature 014, FR-009).
  final PassengerRideStateStore rideStateStore;

  /// Persistência da avaliação da corrida (feature 011, FR-004/FR-005).
  final RideRatingStore rideRatingStore;

  /// Recibos de reputação (feature 027): guarda a reputação declarada pelo
  /// motorista ao aceitar o orçamento e fornece a do próprio passageiro à
  /// solicitação.
  final ReceiptStore receiptStore;

  /// Emite o recibo do motorista ao fim da corrida (feature 027).
  final ReceiptService receiptService;

  /// Controla o serviço em segundo plano (feature 026): recebe o estado da
  /// corrida e a visibilidade do app. Nulo nos testes e onde não há serviço.
  final ServiceController? serviceController;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  /// Nome do pacote exigido pela política de uso dos mosaicos do
  /// OpenStreetMap (D2 de `specs/004-mapa-destino-passageiro/research.md`).

  final _mapController = MapController();
  final _destinoController = TextEditingController();
  StreamSubscription<PassengerPosition>? _assinatura;
  PassengerPosition? _posicao;
  String? _mensagemIndisponibilidade;
  bool _carregando = true;

  Timer? _debounce;
  final List<AddressSuggestion> _sugestoes = [];
  String? _mensagemBusca;

  /// Destino efetivamente registrado (feature 006 — a feature 005 construía
  /// esse valor em `_selecionarSugestao` mas nunca o guardava, porque nada
  /// ainda precisava lê-lo de volta). Definido só por seleção explícita de
  /// uma sugestão; zerado quando o campo de destino é totalmente apagado,
  /// preservado em edição parcial (mesma regra da feature 005).
  DestinationAddress? _destino;

  /// Forma de pagamento selecionada; "Dinheiro" pré-selecionado por padrão
  /// (FR-005, clarificação da sessão 2026-09-20).
  PaymentMethod _pagamento = PaymentMethod.cash;

  var _solicitando = false;

  /// Último cálculo de rota bem-sucedido (feature 007), usado tanto para
  /// exibir a distância quanto para desenhar o traçado no mapa. `null`
  /// quando não há destino, quando o destino foi limpo (FR-005) ou enquanto
  /// o primeiro cálculo para um novo destino ainda não terminou.
  RouteResult? _rota;

  /// Verdadeiro quando o último cálculo de rota tentado falhou — exibido
  /// como indicação não bloqueante, sem impedir nenhuma outra ação da tela
  /// (FR-007, US3 de `specs/007-rota-ate-destino/spec.md`).
  var _falhaRota = false;

  /// Identifica a chamada de rota mais recente, para descartar uma resposta
  /// tardia que já não corresponde ao destino atual quando ele muda antes
  /// dela terminar (FR-008).
  var _rotaToken = 0;

  /// Estado único de corrida do passageiro (feature 014) — substitui a
  /// combinação antes implícita de `_solicitacaoAtivaId`/`_corridaDecidida`
  /// e das três flags removidas de `AcceptedRide`.
  var _rideStatus = PassengerRideStatus.inicial;

  /// `id` da última solicitação de corrida publicada com sucesso nesta
  /// sessão (feature 008) — só orçamentos que a referenciam são
  /// persistidos/exibidos (FR-002, FR-003).
  String? _solicitacaoAtivaId;

  /// Orçamentos recebidos para [_solicitacaoAtivaId], observados pela
  /// `ReceivedQuotesScreen` (D3 de `specs/008-receber-orcamentos/research.md`,
  /// feature 015 substitui a antiga `RideQuotesModal`).
  final _orcamentosRecebidos = ValueNotifier<List<ReceivedQuote>>(const []);

  /// `id`s de orçamentos já processados (persistidos ou descartados por
  /// `content` malformado) — evita reprocessar a cada emissão de
  /// `eventFeed.events` (que reemite a lista inteira a cada evento novo, de
  /// qualquer kind).
  final _idsOrcamentosProcessados = <String>{};

  StreamSubscription<List<NostrEvent>>? _assinaturaOrcamentos;

  /// Corrida aceita (feature 009) — `null` até a primeira aceitação
  /// confirmada, ou até `AcceptedRideStore.load()` terminar, se já havia
  /// uma persistida de antes de um reinício.
  AcceptedRide? _corridaAceita;

  /// Última posição válida e mais nova do motorista aceito (feature 016),
  /// só em memória (FR-009). Exibida só em `motoristaACaminho` (FR-006) e,
  /// enquanto existe, é o foco do mapa (feature 017); zerada quando a
  /// corrida aceita muda (D5 de `specs/016-posicao-do-motorista/research.md`).
  DriverLocation? _posicaoMotorista;

  /// `id`s de localizações do motorista (`kind: 20005`) já processadas —
  /// mesmo padrão de `_idsOrcamentosProcessados`, evita reprocessar a cada
  /// emissão de `eventFeed.events`.
  final _idsLocalizacaoProcessados = <String>{};

  /// Rota até o destino enviada pelo motorista (`kind: 20011`, emenda 13,
  /// feature 018): só a mais nova (`created_at`), só em memória, só enquanto
  /// `emCorrida`. Zerada junto da posição do motorista e ao sair de
  /// `emCorrida`.
  RideRoute? _rotaDoMotorista;

  /// `id`s de rotas do motorista (`kind: 20011`) já processadas — mesmo
  /// padrão de `_idsLocalizacaoProcessados`.
  final _idsRotaProcessados = <String>{};

  /// Verdadeiro enquanto a modal "motorista a caminho" deve aparecer
  /// (feature 009). Mesmo motivo de `_modalOrcamentosVisivel` para não usar
  /// `showDialog` (T019 de `specs/008-receber-orcamentos/tasks.md`).
  var _modalMotoristaVisivel = false;

  /// `id`s de chegadas do motorista ao ponto de encontro (`kind: 20007`) já
  /// processadas — mesmo padrão de `_idsLocalizacaoProcessados` (feature
  /// 010).
  final _idsChegadaMotoristaProcessados = <String>{};

  /// Verdadeiro enquanto a modal de chegada do motorista deve aparecer
  /// (feature 010, US1). Mesmo motivo de `_modalMotoristaVisivel` para não
  /// usar `showDialog`.
  var _modalChegadaMotoristaVisivel = false;

  /// Verdadeiro enquanto a confirmação de chegada ao destino está sendo
  /// publicada (o botão fica desabilitado) e a mensagem de falha da última
  /// tentativa, se houve.
  var _confirmandoDestino = false;
  String? _erroConfirmarDestino;

  /// Verdadeiro enquanto a modal de avaliação da corrida deve aparecer
  /// (feature 011, US1) — aberta uma única vez, ao encerrar a corrida
  /// (`_confirmarDestino`); nunca reexibida (D3 de
  /// `specs/011-avaliar-corrida/research.md`).
  var _modalAvaliacaoVisivel = false;

  /// `rideId` da corrida cuja avaliação está pendente, enquanto
  /// `_modalAvaliacaoVisivel` é verdadeiro.
  String? _corridaParaAvaliar;

  /// `id`s de avisos de cancelamento do motorista (`kind: 20012`) já
  /// processados — mesmo padrão de `_idsRotaProcessados` (feature 019).
  final _idsCancelamentoProcessados = <String>{};

  /// `id`s de avisos de motorista indisponível (`kind: 20006`) já processados
  /// — mesmo padrão de `_idsCancelamentoProcessados` (feature 020).
  final _idsIndisponibilidadeProcessados = <String>{};

  /// Verdadeiro enquanto a modal "motorista indisponível" deve aparecer
  /// (feature 020, US1). Só em memória, como `_modalCorridaCanceladaVisivel`.
  var _modalMotoristaIndisponivelVisivel = false;

  /// Verdadeiro enquanto a modal "corrida cancelada" deve aparecer (feature
  /// 019, US1). Só em memória: a corrida já foi encerrada no instante em que
  /// ela abre, então fechar o app antes do "OK" não a reabre.
  var _modalCorridaCanceladaVisivel = false;

  /// Verdadeiro enquanto a confirmação "Cancelar corrida?" (feature 023,
  /// FR-002) está aberta. Só em memória; fechada por qualquer encerramento
  /// da corrida aceita (`_encerrarCorridaAceita`), para nunca publicar um
  /// cancelamento sobre uma corrida que já não existe (FR-006).
  var _modalConfirmarCancelamentoVisivel = false;

  /// Verdadeiro depois de o estado de corrida persistido ser restaurado
  /// (feature 026): antes disso o serviço não recebe estado, para o padrão
  /// "sem corrida" não sobrescrever o que ele guardou.
  var _estadoCarregado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciar();
    _carregarEstadoCorrida();
    _assinaturaOrcamentos = widget.eventFeed.events.listen(
      _aoAtualizarOrcamentos,
    );
  }

  /// Restaura o estado de corrida persistido (FR-009), se houver — sem
  /// isto, o passageiro perderia a fase da corrida em andamento a cada
  /// reinício do app, e nunca reconheceria a localização do motorista
  /// depois disso.
  ///
  /// Carrega `PassengerRideStateStore` e, se o status for `orcamentoAceito`
  /// ou posterior, também `AcceptedRideStore`. Se as duas leituras
  /// divergirem (status avançado sem `AcceptedRide` correspondente, ou o
  /// inverso), trata como estado corrompido e volta ao default seguro (D5
  /// de `research.md` da feature 014, achado C1 do `/speckit-analyze`).
  /// Restaurando `aguardandoOrcamentos`, também recarrega os orçamentos já
  /// recebidos via `ReceivedQuoteStore.byRequest` (D4 de
  /// `specs/015-lista-orcamentos-recebidos/research.md`).
  Future<void> _carregarEstadoCorrida() async {
    try {
      await _restaurarDestino();
      await _restaurarEstadoCorrida();
    } finally {
      if (mounted) setState(() => _estadoCarregado = true);
    }
  }

  /// Devolve ao campo e ao estado o destino salvo (constituição 2.16.0). Um
  /// destino já escolhido nesta sessão, antes de a leitura terminar, prevalece.
  Future<void> _restaurarDestino() async {
    final salvo = await widget.destinationStore.load();
    if (!mounted || salvo == null || _destino != null) return;
    _destinoController.value = TextEditingValue(
      text: salvo.text,
      selection: TextSelection.collapsed(offset: salvo.text.length),
    );
    setState(() => _destino = salvo);
  }

  Future<void> _restaurarEstadoCorrida() async {
    final (status, solicitacaoId) = await widget.rideStateStore.load();
    if (!mounted) return;

    if (status == PassengerRideStatus.inicial) {
      setState(() => _rideStatus = status);
      return;
    }
    if (status == PassengerRideStatus.aguardandoOrcamentos) {
      // FR-012 da feature 015 (Clarification): recarrega os orçamentos já
      // persistidos para a solicitação, em vez de reabrir a lista vazia.
      final orcamentos = solicitacaoId == null
          ? const <ReceivedQuote>[]
          : await widget.receivedQuoteStore.byRequest(solicitacaoId);
      if (!mounted) return;
      setState(() {
        _rideStatus = status;
        _solicitacaoAtivaId = solicitacaoId;
        _orcamentosRecebidos.value = orcamentos;
      });
      return;
    }

    final aceita = await widget.acceptedRideStore.load();
    if (!mounted) return;
    if (aceita == null) {
      // Divergência: status avançado sem AcceptedRide correspondente — D5.
      unawaited(widget.rideStateStore.save(PassengerRideStatus.inicial, null));
      setState(() => _rideStatus = PassengerRideStatus.inicial);
      return;
    }
    setState(() {
      _rideStatus = status;
      _corridaAceita = aceita;
      _limparPosicaoMotorista();
    });
  }

  /// O app saiu de vista ou voltou (feature 026): o serviço em segundo plano
  /// só notifica com a interface fora de primeiro plano. `inactive` (painel
  /// de notificações, diálogo de permissão) ainda é app visível.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final aVista =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    unawaited(widget.serviceController?.onForeground(aVista));
  }

  /// Informa ao serviço o estado de que ele depende (feature 026, FR-011):
  /// só dados públicos — chave pública do passageiro, fase da corrida e os
  /// ids que a identificam. Idempotente: o controlador só age se algo mudou.
  void _sincronizarServico() {
    final controlador = widget.serviceController;
    if (controlador == null || !_estadoCarregado) return;
    controlador.update(
      ServiceState(
        passengerPubkey: widget.identity.publicKey,
        rideStatus: _rideStatus,
        requestId: _solicitacaoAtivaId,
        quoteId: _corridaAceita?.quoteId,
        driverPubkey: _corridaAceita?.driverPubkey,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_assinatura?.cancel());
    unawaited(_assinaturaOrcamentos?.cancel());
    _debounce?.cancel();
    _destinoController.dispose();
    _orcamentosRecebidos.dispose();
    super.dispose();
  }

  /// Reage a qualquer mudança do `EventFeed`, tratando os orçamentos
  /// (`kind: 20002`, FR-001 a FR-003 da feature 008) e as localizações do
  /// motorista (`kind: 20005`, FR-001 a FR-005 da feature 009).
  void _aoAtualizarOrcamentos(List<NostrEvent> eventos) {
    for (final evento in eventos) {
      if (evento.kind == rideQuoteKind) {
        _processarOrcamentoRecebido(evento);
      } else if (evento.kind == driverLocationKind) {
        _processarLocalizacaoMotorista(evento);
      } else if (evento.kind == driverArrivalKind) {
        _processarChegadaMotorista(evento);
      } else if (evento.kind == rideRouteKind) {
        _processarRotaDoMotorista(evento);
      } else if (evento.kind == rideCancelledKind) {
        _processarCancelamentoDoMotorista(evento);
      } else if (evento.kind == rideUnavailableKind) {
        _processarMotoristaIndisponivel(evento);
      }
    }
  }

  void _processarOrcamentoRecebido(NostrEvent evento) {
    if (!_idsOrcamentosProcessados.add(evento.id)) return;

    final solicitacaoAtiva = _solicitacaoAtivaId;
    if (solicitacaoAtiva == null ||
        evento.referencedEventId != solicitacaoAtiva) {
      return; // FR-003: fora da solicitação ativa, ignorado.
    }

    // Emenda 17: só o autor da solicitação lê o orçamento; o que não decifra
    // é descartado em silêncio (regra de recepção 7).
    final claro = widget.eventFeed.decrypted(evento, widget.identity);
    if (claro == null) return;

    ReceivedQuote orcamento;
    try {
      orcamento = ReceivedQuote.fromNostrEvent(claro);
    } on FormatException {
      // content malformado é dado, nunca instrução — descartado sem
      // persistir nem exibir.
      return;
    }

    unawaited(widget.receivedQuoteStore.save(orcamento));
    // FR-010: um orçamento chegando depois que a solicitação já foi
    // decidida continua sendo persistido (linha acima), mas não aparece na
    // tela de orçamentos nem altera o estado corrente — a tela só é
    // exibida enquanto `_rideStatus == aguardandoOrcamentos` (feature 015).
    if (!PassengerRideRules.canAcceptQuote(_rideStatus)) return;
    setState(() {
      _orcamentosRecebidos.value = [..._orcamentosRecebidos.value, orcamento];
    });
  }

  /// Trata uma localização do motorista (`kind: 20005`).
  ///
  /// Só vale a do motorista **cujo orçamento foi aceito** (autor conferido,
  /// FR-005 da feature 016 — a tag `["e", quoteId]` é pública no relay e
  /// qualquer um poderia forjá-la) e referente à corrida aceita. A primeira
  /// é o sinal de que ele começou a se deslocar (FR-005 da feature 014,
  /// ex-FR-001/FR-002 da feature 009) — sinal que não depende de o conteúdo
  /// ser válido; a posição em si só é guardada se o conteúdo for válido e
  /// mais novo que a exibida (FR-002, FR-008 da feature 016). Fora de
  /// `orcamentoAceito`/`motoristaACaminho` é ignorada.
  void _processarLocalizacaoMotorista(NostrEvent evento) {
    if (!_idsLocalizacaoProcessados.add(evento.id)) return;

    final corridaAceita = _corridaAceita;
    if (corridaAceita == null) return;
    if (evento.referencedEventId != corridaAceita.quoteId) return;
    if (evento.authorPublicKey != corridaAceita.driverPubkey) return;

    final primeiraLocalizacao = PassengerRideRules.canNotifyMovement(
      _rideStatus,
    );
    if (!primeiraLocalizacao &&
        _rideStatus != PassengerRideStatus.motoristaACaminho) {
      return;
    }

    // Emenda 17 / FR-007 da feature 022: só um `20005` que decifra conta como
    // sinal do motorista — não dispara "a caminho" nem rearma o silêncio.
    final claro = widget.eventFeed.decrypted(evento, widget.identity);
    if (claro == null) return;

    DriverLocation? nova;
    try {
      nova = DriverLocation.fromNostrEvent(claro);
    } on FormatException {
      nova = null; // dado, nunca instrução: não toca o marcador.
    }
    if (nova != null && !nova.isNewerThan(_posicaoMotorista)) nova = null;

    if (primeiraLocalizacao) {
      unawaited(
        widget.rideStateStore.save(PassengerRideStatus.motoristaACaminho, null),
      );
    }
    setState(() {
      if (primeiraLocalizacao) {
        _rideStatus = PassengerRideStatus.motoristaACaminho;
        _modalMotoristaVisivel = true;
      }
      if (nova != null) _posicaoMotorista = nova;
    });
    if (nova != null) _seguirMotorista(nova);
  }

  /// Guarda a rota até o destino enviada pelo motorista (`kind: 20011`,
  /// feature 018). Só vale a rota do motorista da corrida aceita (autor e
  /// `["e", quoteId]`, como a localização — a tag é pública no relay),
  /// recebida com o passageiro em `emCorrida`, com `content` válido e mais
  /// nova que a exibida (FR-002 a FR-005). Qualquer outra é ignorada sem
  /// alterar o traçado.
  void _processarRotaDoMotorista(NostrEvent evento) {
    if (!_idsRotaProcessados.add(evento.id)) return;

    final corridaAceita = _corridaAceita;
    if (corridaAceita == null) return;
    if (evento.referencedEventId != corridaAceita.quoteId) return;
    if (evento.authorPublicKey != corridaAceita.driverPubkey) return;
    if (!PassengerRideRules.canShowDriverRoute(_rideStatus)) return;

    final claro = widget.eventFeed.decrypted(evento, widget.identity);
    if (claro == null) return;

    final RideRoute nova;
    try {
      nova = RideRoute.fromNostrEvent(claro);
    } on FormatException {
      return; // dado, nunca instrução: não toca o traçado.
    }
    if (!nova.isNewerThan(_rotaDoMotorista)) return;

    setState(() => _rotaDoMotorista = nova);
  }

  /// Reconhece o cancelamento da corrida pelo motorista (`kind: 20012`,
  /// feature 019). Só vale o aviso do motorista da corrida aceita (autor e
  /// `["e", quoteId]`, como a localização — a tag é pública no relay),
  /// recebido em `orcamentoAceito`, `motoristaACaminho` ou `emCorrida`
  /// (`PassengerRideRules.canBeCancelledByDriver`); qualquer outro é
  /// ignorado sem erro.
  ///
  /// A corrida é encerrada no instante do recebimento, não ao tocar "OK"
  /// (FR-005, D3 de `specs/019-corrida-cancelada-pelo-motorista/
  /// research.md`): estado `inicial` persistido, corrida aceita e posição e
  /// rota do motorista zeradas, modais da corrida apagadas. Não abre a
  /// avaliação (FR-007) nem publica nada (FR-010).
  void _processarCancelamentoDoMotorista(NostrEvent evento) {
    if (!_idsCancelamentoProcessados.add(evento.id)) return;

    final corridaAceita = _corridaAceita;
    if (corridaAceita == null) return;
    if (evento.referencedEventId != corridaAceita.quoteId) return;
    if (evento.authorPublicKey != corridaAceita.driverPubkey) return;
    if (!PassengerRideRules.canBeCancelledByDriver(_rideStatus)) return;
    if (widget.eventFeed.decrypted(
          evento,
          widget.identity,
          emptyMarker: true,
        ) ==
        null) {
      return; // emenda 17: não decifra para {} → descartado em silêncio.
    }

    _encerrarCorridaAceita(() => _modalCorridaCanceladaVisivel = true);
  }

  /// Reconhece o aviso de que o motorista não pode atender a corrida
  /// (`kind: 20006`, feature 020). Mesmas conferências de autor e de
  /// `["e", quoteId]` do cancelamento, mas só vale em `orcamentoAceito`
  /// (`PassengerRideRules.canBeDeclinedByDriver`): é a fase em que o motorista
  /// ainda não assumiu a corrida. Aceito, encerra a corrida no instante do
  /// recebimento e abre a modal informativa.
  void _processarMotoristaIndisponivel(NostrEvent evento) {
    if (!_idsIndisponibilidadeProcessados.add(evento.id)) return;

    final corridaAceita = _corridaAceita;
    if (corridaAceita == null) return;
    if (evento.referencedEventId != corridaAceita.quoteId) return;
    if (evento.authorPublicKey != corridaAceita.driverPubkey) return;
    if (!PassengerRideRules.canBeDeclinedByDriver(_rideStatus)) return;
    if (widget.eventFeed.decrypted(
          evento,
          widget.identity,
          emptyMarker: true,
        ) ==
        null) {
      return; // emenda 17: não decifra para {} → descartado em silêncio.
    }

    _encerrarCorridaAceita(() => _modalMotoristaIndisponivelVisivel = true);
  }

  /// Encerra a corrida aceita no instante em que o motorista a cancela ou
  /// avisa que não pode atendê-la: estado `inicial` persistido, corrida aceita,
  /// posição e rota do motorista zeradas, modais da corrida apagadas.
  /// [abrirModal] liga, no mesmo `setState`, a modal informativa de cada caso.
  void _encerrarCorridaAceita(void Function() abrirModal) {
    unawaited(widget.rideStateStore.save(PassengerRideStatus.inicial, null));
    setState(() {
      _rideStatus = PassengerRideStatus.inicial;
      _corridaAceita = null;
      _limparPosicaoMotorista();
      _modalMotoristaVisivel = false;
      _modalChegadaMotoristaVisivel = false;
      _confirmandoDestino = false;
      _erroConfirmarDestino = null;
      _modalConfirmarCancelamentoVisivel = false;
      abrirModal();
    });
  }

  /// Cancela a corrida aceita por iniciativa do passageiro (feature 023,
  /// FR-003 a FR-007): encerra no instante — estado `inicial` persistido,
  /// corrida aceita, posição e rota do motorista zeradas, relógio de silêncio
  /// cancelado, tudo por `_encerrarCorridaAceita` — e publica o aviso
  /// (`kind: 20013`) ao motorista.
  ///
  /// Todo o efeito local acontece antes de qualquer `await`, de modo que um
  /// segundo acionamento já vê `inicial` e sai: no máximo um aviso por corrida
  /// (D3 de `specs/023-cancelar-corrida-passageiro/research.md`). Diferente
  /// da conclusão, não abre a avaliação (FR-005).
  void _cancelarCorrida() {
    final corrida = _corridaAceita;
    if (corrida == null || !PassengerRideRules.canCancelRide(_rideStatus)) {
      return;
    }
    _encerrarCorridaAceita(() {});
    unawaited(_publicarCancelamento(corrida));
  }

  /// Publica o cancelamento ao motorista da corrida encerrada. Melhor
  /// esforço: sem relay conectado, ou se a publicação falhar ou for recusada,
  /// o cancelamento local prevalece e nada é reenviado (FR-007, D4).
  Future<void> _publicarCancelamento(AcceptedRide corrida) async {
    if (!widget.relayService.hasAnyConnected) return;
    try {
      await widget.eventFeed.publishRideCancellation(
        corrida.quoteId,
        corrida.driverPubkey,
        widget.identity,
      );
    } on Object {
      // Absorvida: sem fila nem reenvio (D4).
    }
  }

  void _abrirConfirmacaoCancelamento() {
    if (!PassengerRideRules.canCancelRide(_rideStatus)) return;
    setState(() => _modalConfirmarCancelamentoVisivel = true);
  }

  void _fecharConfirmacaoCancelamento() {
    setState(() => _modalConfirmarCancelamentoVisivel = false);
  }

  void _fecharModalMotoristaIndisponivel() {
    setState(() => _modalMotoristaIndisponivelVisivel = false);
  }

  void _fecharModalCorridaCancelada() {
    setState(() => _modalCorridaCanceladaVisivel = false);
  }

  /// Zera a posição do motorista e a rota que ele enviou — chamado dentro de
  /// `setState` quando a corrida aceita muda (D5 da feature 016; feature
  /// 018). Sem posição, o mapa volta a seguir o passageiro (D1 da feature
  /// 017).
  void _limparPosicaoMotorista() {
    _posicaoMotorista = null;
    _rotaDoMotorista = null;
  }

  /// Se o mapa segue o motorista em vez do passageiro (feature 017, D1):
  /// só em "motorista a caminho" e com uma posição dele já exibida.
  bool get _seguindoMotorista =>
      _rideStatus == PassengerRideStatus.motoristaACaminho &&
      _posicaoMotorista != null;

  /// Centraliza o mapa no motorista, mantendo o zoom vigente (FR-001,
  /// FR-003). Sem o mapa montado ainda, não faz nada: o `initialCenter` do
  /// mapa já usa a posição do motorista quando ela existe (D2).
  void _seguirMotorista(DriverLocation motorista) {
    final zoom = _zoomAtual;
    if (_carregando || zoom == null) return;
    _mapController.move(LatLng(motorista.latitude, motorista.longitude), zoom);
  }

  /// Zoom do mapa, ou `null` se o `FlutterMap` não está renderizado (tela de
  /// carregamento, lista de orçamentos no lugar do mapa): o `MapController`
  /// lança em `camera` nesse caso, e um GPS chegando então derrubava o
  /// ouvinte da posição com exceção não tratada.
  double? get _zoomAtual {
    try {
      final zoom = _mapController.camera.zoom;
      return zoom.isNaN ? null : zoom;
    } on Exception {
      return null;
    }
  }

  void _fecharModalMotorista() {
    setState(() => _modalMotoristaVisivel = false);
  }

  /// Reconhece a chegada do motorista ao ponto de encontro (`kind: 20007`,
  /// feature 010); ignora eventos de fora da corrida aceita e, via
  /// `PassengerRideRules.canConfirmMeeting`, não reabre a modal já exibida
  /// nem depois que o encontro já foi confirmado (FR-010) — a transição
  /// para `emCorrida` só ocorre em `_confirmarEncontro`, quando a
  /// confirmação é de fato publicada (FR-006).
  void _processarChegadaMotorista(NostrEvent evento) {
    if (!_idsChegadaMotoristaProcessados.add(evento.id)) return;

    final corridaAceita = _corridaAceita;
    if (corridaAceita == null) return;
    if (evento.referencedEventId != corridaAceita.quoteId) return;
    if (!PassengerRideRules.canConfirmMeeting(_rideStatus)) return;
    if (widget.eventFeed.decrypted(
          evento,
          widget.identity,
          emptyMarker: true,
        ) ==
        null) {
      return; // emenda 17: não decifra para {} → descartado em silêncio.
    }

    setState(() => _modalChegadaMotoristaVisivel = true);
  }

  /// Verdadeiro quando o botão "Confirmar chegada ao destino" deve aparecer:
  /// a corrida está em `emCorrida` e a posição do próprio passageiro está a
  /// até [_raioConfirmacaoDestinoMetros] do destino pedido. Decisão local —
  /// não depende do aviso de chegada do motorista (`kind: 20009`).
  bool get _noRaioDoDestino {
    if (!PassengerRideRules.canConfirmDestinationArrival(_rideStatus)) {
      return false;
    }
    final posicao = _posicao;
    final destino = _destino;
    if (posicao == null || destino == null) return false;
    return _calculadoraDistancia.as(
          LengthUnit.Meter,
          LatLng(posicao.latitude, posicao.longitude),
          LatLng(destino.latitude, destino.longitude),
        ) <=
        _raioConfirmacaoDestinoMetros;
  }

  /// Toque no botão de chegada ao destino: publica a confirmação e, em
  /// falha, mostra a mensagem junto ao botão.
  Future<void> _aoTocarConfirmarDestino() async {
    if (_confirmandoDestino) return;
    setState(() {
      _confirmandoDestino = true;
      _erroConfirmarDestino = null;
    });
    final erro = await _confirmarDestino();
    if (!mounted) return;
    setState(() {
      _confirmandoDestino = false;
      _erroConfirmarDestino = erro;
    });
  }

  /// Publica a confirmação de encontro (`kind: 20008`) para a corrida
  /// aceita; devolve a mensagem de falha (nenhum relay aceitou), ou
  /// transiciona para `emCorrida` e fecha a modal em caso de
  /// sucesso (FR-006) — mesmo padrão de `_aceitarOrcamento`.
  Future<String?> _confirmarEncontro() async {
    final corridaAceita = _corridaAceita;
    if (!widget.relayService.hasAnyConnected ||
        corridaAceita == null ||
        !PassengerRideRules.canConfirmMeeting(_rideStatus)) {
      return 'Nenhum relay conectado. A confirmação não foi enviada — '
          'conecte-se a um relay e tente novamente.';
    }

    final relato = await widget.eventFeed.publishMeetingConfirmation(
      corridaAceita.quoteId,
      corridaAceita.driverPubkey,
      widget.identity,
    );
    final aceitos = relato.byRelay.values
        .where((s) => s == PublishStatus.accepted)
        .length;
    if (aceitos == 0) {
      return 'Nenhum relay aceitou a confirmação.';
    }

    if (!mounted) return null;
    unawaited(widget.rideStateStore.save(PassengerRideStatus.emCorrida, null));
    setState(() {
      _rideStatus = PassengerRideStatus.emCorrida;
      _modalChegadaMotoristaVisivel = false;
      // FR-008: a rota local (feature 007) sai de cena e qualquer cálculo
      // em voo é invalidado; a linha passa a ser a enviada pelo motorista.
      _rota = null;
      _falhaRota = false;
      _rotaToken++;
    });
    return null;
  }

  /// Publica a confirmação de destino (`kind: 20010`) para a corrida
  /// aceita e transiciona para `destinoConfirmadoAguardandoAvaliacao`
  /// (FR-007) — mesmo padrão de `_confirmarEncontro`.
  Future<String?> _confirmarDestino() async {
    final corridaAceita = _corridaAceita;
    if (!widget.relayService.hasAnyConnected ||
        corridaAceita == null ||
        !PassengerRideRules.canConfirmDestinationArrival(_rideStatus)) {
      return 'Nenhum relay conectado. A confirmação não foi enviada — '
          'conecte-se a um relay e tente novamente.';
    }

    final relato = await widget.eventFeed.publishDestinationConfirmation(
      corridaAceita.quoteId,
      corridaAceita.driverPubkey,
      widget.identity,
    );
    final aceitos = relato.byRelay.values
        .where((s) => s == PublishStatus.accepted)
        .length;
    if (aceitos == 0) {
      return 'Nenhum relay aceitou a confirmação.';
    }

    if (!mounted) return null;
    unawaited(
      widget.rideStateStore.save(
        PassengerRideStatus.destinoConfirmadoAguardandoAvaliacao,
        null,
      ),
    );
    setState(() {
      _rideStatus = PassengerRideStatus.destinoConfirmadoAguardandoAvaliacao;
      _rotaDoMotorista = null; // FR-006: o traçado some ao sair de emCorrida.
      _corridaParaAvaliar = corridaAceita.quoteId;
      _modalAvaliacaoVisivel = true;
    });
    return null;
  }

  /// Persiste a nota escolhida para a corrida encerrada, fecha a modal de
  /// avaliação e volta o estado a `inicial` (FR-004, FR-005 da feature
  /// 011; FR-008 da feature 014).
  Future<void> _avaliarCorrida(int stars) async {
    final rideId = _corridaParaAvaliar;
    if (rideId == null || !PassengerRideRules.canFinishRating(_rideStatus)) {
      return;
    }
    final corrida = _corridaAceita;
    await widget.rideRatingStore.save(
      RideRating(rideId: rideId, stars: stars, ratedAt: DateTime.now()),
      widget.identity,
    );
    // Feature 027: o recibo é derivado da nota local, depois que ela está
    // gravada e antes de a corrida ser zerada.
    unawaited(_emitirRecibo(corrida, stars));
    if (!mounted) return;
    _finalizarAvaliacao();
  }

  /// Fecha a modal de avaliação sem persistir nenhuma nota e volta o
  /// estado a `inicial` (FR-008 da feature 011; FR-008 da feature 014).
  void _pularAvaliacao() {
    if (!PassengerRideRules.canFinishRating(_rideStatus)) return;
    // Pular conta como corrida, não como avaliação: recibo sem nota.
    unawaited(_emitirRecibo(_corridaAceita, null));
    _finalizarAvaliacao();
  }

  /// Emite o recibo do motorista da [corrida] (feature 027, contrato 1.7).
  /// Nunca bloqueia nem derruba a interface: a falha de emissão ou de
  /// publicação deixa o recibo pendente, e só a reputação inconsistente do
  /// motorista vira aviso de uma linha.
  Future<void> _emitirRecibo(AcceptedRide? corrida, int? stars) async {
    if (corrida == null) return;
    try {
      final desfecho = await widget.receiptService.issueFor(corrida, stars);
      if (desfecho == ReceiptIssueOutcome.skippedInconsistent && mounted) {
        // Os avisos entram numa fila: o desta corrida não pode esperar o
        // anterior (de seis segundos) terminar.
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _avisar(
          'A reputação do motorista é inconsistente: o recibo desta corrida '
          'não foi emitido. Sua nota foi guardada.',
        );
      }
    } on Object {
      // Sem recibo desta vez; a nota local continua gravada.
    }
  }

  /// Zera a corrida e volta o estado a `inicial`, liberando uma nova
  /// solicitação (FR-008, SC-003) — comum a `_avaliarCorrida` e
  /// `_pularAvaliacao`.
  void _finalizarAvaliacao() {
    unawaited(widget.rideStateStore.save(PassengerRideStatus.inicial, null));
    setState(() {
      _rideStatus = PassengerRideStatus.inicial;
      _corridaAceita = null;
      _limparPosicaoMotorista();
      _modalAvaliacaoVisivel = false;
      _corridaParaAvaliar = null;
    });
  }

  /// Aceita [quote]: publica a aceitação para o motorista escolhido e uma
  /// recusa para cada outro orçamento já recebido da mesma solicitação
  /// (FR-008, FR-009 da feature 008). Fecha a modal e transiciona para
  /// `orcamentoAceito` só se a aceitação for aceita por ao menos um relay
  /// (FR-004 da feature 014); devolve mensagem sem fechar se não houver
  /// relay conectado ou fora do estado esperado (FR-010).
  Future<String?> _aceitarOrcamento(ReceivedQuote quote) async {
    if (!widget.relayService.hasAnyConnected ||
        !PassengerRideRules.canAcceptQuote(_rideStatus)) {
      return 'Nenhum relay conectado. A aceitação não foi enviada — '
          'conecte-se a um relay e tente novamente.';
    }

    final relato = await widget.eventFeed.publishQuoteAcceptance(
      quote,
      widget.identity,
    );
    final aceitos = relato.byRelay.values
        .where((s) => s == PublishStatus.accepted)
        .length;
    if (aceitos == 0) {
      return 'Nenhum relay aceitou a confirmação.';
    }

    for (final outro in _orcamentosRecebidos.value) {
      if (outro.quoteId == quote.quoteId) continue;
      unawaited(widget.eventFeed.publishQuoteRejection(outro, widget.identity));
    }

    // FR-006 da feature 009: registra qual corrida foi aceita — dado hoje
    // inexistente em qualquer armazenamento do passageiro, necessário para
    // reconhecer depois a localização deste motorista (D2 de
    // `specs/009-notificar-motorista-a-caminho/research.md`).
    final aceita = AcceptedRide(
      quoteId: quote.quoteId,
      driverPubkey: quote.driverPubkey,
    );
    unawaited(widget.acceptedRideStore.save(aceita));
    // Feature 027: a reputação que o motorista declarou neste orçamento é a
    // base do recibo que o passageiro emitirá ao fim da corrida (seq e head).
    // Sem reputação declarada não há o que guardar (motorista sem histórico).
    final declarada = quote.reputation;
    if (declarada != null) {
      try {
        await widget.receiptStore.saveDeclared(
          quote.quoteId,
          quote.driverPubkey,
          declarada,
        );
      } on Object {
        // Sem a declarada o recibo não é emitido; a aceitação não falha por isso.
      }
    }
    unawaited(
      widget.rideStateStore.save(PassengerRideStatus.orcamentoAceito, null),
    );

    if (!mounted) return null;
    setState(() {
      _rideStatus = PassengerRideStatus.orcamentoAceito;
      _corridaAceita = aceita;
      _limparPosicaoMotorista();
    });
    return null;
  }

  /// Cancela a solicitação ativa (feature 015, US3): recusa cada orçamento
  /// já recebido (D2 de `research.md` — mesma `publishQuoteRejection` já
  /// usada para os orçamentos não escolhidos ao aceitar outro) e volta o
  /// estado a `inicial` (FR-009 a FR-011). Só válido a partir de
  /// `aguardandoOrcamentos` (`PassengerRideRules.canCancelRequest`); lista
  /// vazia não publica nenhuma recusa (FR-009, cenário 3 do spec.md).
  void _cancelarSolicitacao() {
    if (!PassengerRideRules.canCancelRequest(_rideStatus)) return;

    for (final orcamento in _orcamentosRecebidos.value) {
      unawaited(
        widget.eventFeed.publishQuoteRejection(orcamento, widget.identity),
      );
    }

    unawaited(widget.rideStateStore.save(PassengerRideStatus.inicial, null));
    setState(() {
      _rideStatus = PassengerRideStatus.inicial;
      _solicitacaoAtivaId = null;
      _orcamentosRecebidos.value = const [];
      _idsOrcamentosProcessados.clear();
    });
  }

  Future<void> _iniciar() async {
    try {
      await widget.locationService.ensurePermission();
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _mensagemIndisponibilidade = _descrever(erro);
      });
      return;
    }

    if (mounted) setState(() => _carregando = false);

    _assinatura = widget.locationService.positions.listen(
      _aoReceberPosicao,
      onError: (Object erro) {
        if (!mounted) return;
        setState(() => _mensagemIndisponibilidade = _descrever(erro));
      },
    );
  }

  void _aoReceberPosicao(PassengerPosition posicao) {
    if (!mounted) return;
    setState(() {
      _posicao = posicao;
      _mensagemIndisponibilidade = null;
    });
    final ponto = LatLng(posicao.latitude, posicao.longitude);
    _talvezRecalcularRota(ponto);
    // FR-002/FR-005: com o motorista em foco, o GPS do passageiro não move a
    // câmera; em qualquer outro caso, segue como sempre.
    final zoom = _zoomAtual;
    if (_seguindoMotorista || zoom == null) return;
    _mapController.move(ponto, zoom);
  }

  /// Decide se um novo cálculo de rota é necessário para a posição atual
  /// [origem] e o destino já registrado, e o dispara quando for o caso
  /// (feature 007).
  ///
  /// Sem destino, não há nada a calcular. Com um cálculo já feito para o
  /// mesmo destino, só recalcula se [origem] se afastou mais de
  /// `_limiarRecalculoRotaMetros` da origem usada nesse cálculo (D2 de
  /// `specs/007-rota-ate-destino/research.md`, FR-003) — nunca a cada
  /// atualização de posição.
  void _talvezRecalcularRota(LatLng origem) {
    // Feature 018 (FR-008): em `emCorrida` a rota vem do motorista; o
    // passageiro não consulta o serviço de rotas.
    if (PassengerRideRules.canShowDriverRoute(_rideStatus)) return;
    final destino = _destino;
    if (destino == null) return;
    final destinoPonto = LatLng(destino.latitude, destino.longitude);

    final rotaAtual = _rota;
    if (rotaAtual != null && rotaAtual.destination == destinoPonto) {
      final deslocamento = _calculadoraDistancia.as(
        LengthUnit.Meter,
        rotaAtual.originUsed,
        origem,
      );
      if (deslocamento <= _limiarRecalculoRotaMetros) return;
    }

    _calcularRota(origem, destinoPonto);
  }

  Future<void> _calcularRota(LatLng origem, LatLng destino) async {
    final token = ++_rotaToken;
    try {
      final resultado = await widget.routeService.route(
        origin: origem,
        destination: destino,
      );
      // Resposta tardia de um destino já trocado — descartada (FR-008).
      if (!mounted || token != _rotaToken) return;
      setState(() {
        _rota = resultado;
        _falhaRota = false;
      });
    } catch (_) {
      if (!mounted || token != _rotaToken) return;
      setState(() {
        _rota = null;
        _falhaRota = true;
      });
    }
  }

  static String _descrever(Object erro) {
    if (erro is LocationPermissionDenied) {
      return erro.permanently
          ? 'Permissão de localização negada permanentemente. Conceda-a '
                'pelas configurações do aparelho para usar o mapa.'
          : 'É preciso permitir o acesso à localização para mostrar o mapa.';
    }
    if (erro is LocationUnavailable) {
      return 'Não foi possível obter sua localização agora. Verifique se a '
          'localização está ligada no aparelho.';
    }
    return 'Não foi possível obter sua localização.';
  }

  /// Reage a cada mudança do texto do campo de destino feita pelo usuário
  /// (FR-001, FR-003).
  ///
  /// Não é chamado quando o texto é trocado programaticamente ao selecionar
  /// uma sugestão (`TextField.onChanged` só reage a edição do usuário, não a
  /// `TextEditingController.value` atribuído em código — T015). Limpa
  /// sugestões e mensagem a cada nova digitação; texto vazio ou curto demais
  /// (D3) não dispara busca — texto vazio também é o Edge Case do
  /// `spec.md`: apagar tudo volta ao estado "sem destino definido" (FR-012),
  /// que aqui já corresponde a não haver nenhuma sugestão nem mensagem
  /// visível.
  void _aoMudarTexto(String texto) {
    _debounce?.cancel();
    setState(() {
      _sugestoes.clear();
      _mensagemBusca = null;
      // FR-012 da feature 005: apagar todo o texto volta ao estado "sem
      // destino definido". Edição parcial preserva o destino anterior até
      // uma nova seleção (T011 de specs/006-solicitar-corrida/tasks.md).
      if (texto.isEmpty) {
        _destino = null;
        unawaited(widget.destinationStore.save(null));
        // FR-005 da feature 007: limpar o destino remove a distância
        // exibida e o traçado; invalida qualquer cálculo em andamento.
        _rota = null;
        _falhaRota = false;
        _rotaToken++;
      }
    });

    if (texto.length < _tamanhoMinimoBusca) return;

    _debounce = Timer(_debounceBusca, () => _buscar(texto));
  }

  Future<void> _buscar(String texto) async {
    List<AddressSuggestion> resultados;
    try {
      resultados = await widget.geocodingService.search(texto);
    } catch (_) {
      // Ignora resposta de uma busca que não é mais a mais recente (o texto
      // do campo já mudou de novo) — contrato de `GeocodingService`.
      if (!mounted || texto != _destinoController.text) return;
      setState(() {
        _sugestoes.clear();
        _mensagemBusca =
            'Não foi possível buscar endereços no momento. Verifique sua '
            'conexão e tente digitar novamente.';
      });
      return;
    }

    if (!mounted || texto != _destinoController.text) return;
    setState(() {
      _sugestoes
        ..clear()
        ..addAll(resultados);
      _mensagemBusca = resultados.isEmpty
          ? 'Nenhum endereço encontrado para esse texto.'
          : null;
    });
  }

  /// Registra o endereço da sugestão tocada como destino (FR-004, FR-005 da
  /// feature 005): único ponto do app que constrói um [DestinationAddress]
  /// — sempre a partir do `displayText` e das coordenadas de uma
  /// [AddressSuggestion] selecionada, nunca do texto bruto digitado.
  void _selecionarSugestao(AddressSuggestion sugestao) {
    _debounce?.cancel();
    final destino = DestinationAddress(
      sugestao.displayText,
      latitude: sugestao.latitude,
      longitude: sugestao.longitude,
    );

    _destinoController.value = TextEditingValue(
      text: destino.text,
      selection: TextSelection.collapsed(offset: destino.text.length),
    );

    setState(() {
      _sugestoes.clear();
      _mensagemBusca = null;
      _destino = destino;
      // FR-003/FR-008 da feature 007: um novo destino invalida qualquer
      // rota exibida ou em cálculo para o destino anterior.
      _rota = null;
      _falhaRota = false;
      _rotaToken++;
    });
    unawaited(widget.destinationStore.save(destino));

    final posicao = _posicao;
    if (posicao != null) {
      _talvezRecalcularRota(LatLng(posicao.latitude, posicao.longitude));
    }
  }

  /// Manipulador do botão "Solicitar corrida" (feature 006). Ordem das
  /// checagens conforme `contracts/ride-request-event.md`: destino, depois
  /// posição, depois relay conectado — cada uma impede a publicação e
  /// explica o motivo (FR-002 a FR-004, FR-010), sem montar nem publicar
  /// nenhum evento quando falha. Em sucesso, transiciona para
  /// `aguardandoOrcamentos` (FR-003 da feature 014) — só chamado a partir
  /// de `inicial` (o botão só existe fora do fluxo de uma corrida ativa).
  Future<void> _solicitarCorrida() async {
    if (_destino == null) {
      _avisar('Escolha um destino antes de solicitar a corrida.');
      return;
    }
    final posicao = _posicao;
    if (posicao == null) {
      _avisar('Sua posição atual ainda não está disponível.');
      return;
    }
    if (!widget.relayService.hasAnyConnected) {
      // FR-010: impedir com explicação, sem perder a solicitação em
      // silêncio — mesmo padrão de HomeScreen._publicar.
      _avisar(
        'Nenhum relay conectado. A solicitação não foi enviada — '
        'conecte-se a um relay e tente novamente.',
      );
      return;
    }
    if (!PassengerRideRules.canRequestRide(_rideStatus)) {
      // FR-001/FR-010 da feature 014: já existe uma corrida em andamento
      // — o estado só permite uma por vez.
      _avisar('Já existe uma corrida em andamento.');
      return;
    }

    // Feature 026, FR-009: a permissão de notificação é pedida aqui, ao
    // solicitar, e nunca ao abrir o app. Recusar não impede a solicitação.
    final controlador = widget.serviceController;
    if (controlador != null &&
        !await controlador.ensureNotificationPermission()) {
      if (!mounted) return;
      _avisar(
        'Notificações desativadas: você só será avisado das mensagens do '
        'motorista com o app aberto.',
      );
    }
    if (!mounted) return;

    setState(() => _solicitando = true);
    // Feature 027: a reputação do próprio passageiro vai em claro no 20001; sem
    // recibos a chave é omitida. Falha ao ler não impede a solicitação.
    Reputation? reputacao;
    try {
      reputacao = await widget.receiptStore.myReputation();
    } on Object {
      reputacao = null;
    }
    final relato = await widget.eventFeed.publishRideRequest(
      RideRequest(origin: posicao, destination: _destino!, payment: _pagamento),
      widget.identity,
      reputation: reputacao,
    );
    if (!mounted) return;
    setState(() => _solicitando = false);

    final aceitos = relato.byRelay.values
        .where((s) => s == PublishStatus.accepted)
        .length;
    if (aceitos > 0) {
      // FR-002/FR-003 da feature 008: só orçamentos desta solicitação são
      // aceitos a partir de agora; reinicia o estado da anterior, se havia.
      _solicitacaoAtivaId = relato.eventId;
      _idsOrcamentosProcessados.clear();
      _orcamentosRecebidos.value = const [];
      _rideStatus = PassengerRideStatus.aguardandoOrcamentos;
      unawaited(
        widget.rideStateStore.save(
          PassengerRideStatus.aguardandoOrcamentos,
          relato.eventId,
        ),
      );
      _sincronizarServico();
    }
    _avisar(
      aceitos == 0
          ? 'Nenhum relay aceitou a solicitação.'
          : 'Solicitação de corrida enviada — aceita por $aceitos de '
                '${relato.byRelay.length} relays.',
    );
  }

  void _avisar(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), duration: const Duration(seconds: 6)),
    );
  }

  @override
  Widget build(BuildContext context) {
    _sincronizarServico();
    // FR-003, FR-007 da feature 015 (D1 de research.md): a tela de
    // orçamentos substitui o mapa por completo enquanto aguarda decisão —
    // não é uma modal sobreposta, por isso um retorno antecipado, sem
    // Stack/dim, diferente das demais modais abaixo.
    if (_rideStatus == PassengerRideStatus.aguardandoOrcamentos) {
      return ReceivedQuotesScreen(
        quotes: _orcamentosRecebidos,
        onAccept: _aceitarOrcamento,
        onCancel: _cancelarSolicitacao,
      );
    }

    final posicao = _posicao;
    final ponto = posicao == null
        ? const LatLng(0, 0)
        : LatLng(posicao.latitude, posicao.longitude);
    // Com o motorista em foco, o mapa já nasce nele (D2 da feature 017).
    final motorista = _posicaoMotorista;
    final centroInicial = _seguindoMotorista && motorista != null
        ? LatLng(motorista.latitude, motorista.longitude)
        : ponto;

    final scaffold = Scaffold(
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: centroInicial,
                    initialZoom: 16,
                    // `mapa-base`: o que se vê enquanto os tiles não chegam.
                    backgroundColor: const Color(0xFFE5DFEF),
                  ),
                  children: [
                    const CamadaMapaBase(),
                    if (posicao != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: ponto,
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: BoxDecoration(
                                color: IdentidadeVisual.fundo,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_pin_circle,
                                color: IdentidadeVisual.destaque,
                                size: 26,
                                semanticLabel: 'Sua posição',
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_rota != null &&
                        !PassengerRideRules.canShowDriverRoute(_rideStatus))
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _rota!.points,
                            strokeWidth: 5,
                            color: IdentidadeVisual.roxo,
                          ),
                        ],
                      ),
                    // Rota até o destino enviada pelo motorista (feature 018):
                    // só em `emCorrida` (FR-002), mesma cor e espessura da
                    // rota local (FR-009).
                    if (_rotaDoMotorista != null &&
                        PassengerRideRules.canShowDriverRoute(_rideStatus))
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _rotaDoMotorista!.points,
                            strokeWidth: 5,
                            color: IdentidadeVisual.roxo,
                          ),
                        ],
                      ),
                    // Motorista a caminho (feature 016): só neste estado e
                    // só com uma posição válida recebida (FR-006), por cima
                    // do marcador do passageiro.
                    if (_rideStatus == PassengerRideStatus.motoristaACaminho &&
                        _posicaoMotorista != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              _posicaoMotorista!.latitude,
                              _posicaoMotorista!.longitude,
                            ),
                            width: 44,
                            height: 44,
                            child: const _MarcadorCircular(
                              icon: Icons.directions_car,
                              semanticLabel: 'Motorista',
                            ),
                          ),
                        ],
                      ),
                    // No topo: o painel de ação, de altura variável (sugestões
                    // de busca), cobriria a atribuição embaixo. O widget já
                    // antepõe o "©" ao texto.
                    Padding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.paddingOf(context).top,
                      ),
                      child: const SimpleAttributionWidget(
                        source: Text(
                          'OpenFreeMap, OpenMapTiles\nOpenStreetMap contributors',
                        ),
                        alignment: Alignment.topRight,
                      ),
                    ),
                  ],
                ),
                if (_mensagemIndisponibilidade != null)
                  _AvisoIndisponibilidade(
                    mensagem: _mensagemIndisponibilidade!,
                    onTentarDeNovo: _iniciar,
                  ),
                // Acima do aviso de indisponibilidade, de propósito: a busca
                // de endereço funciona independentemente da posição estar
                // disponível ou da permissão ter sido negada (FR-010 da
                // feature 004). Visível só na fase inicial — nas demais, o
                // passageiro já está numa corrida em andamento (FR-001,
                // FR-002 da feature 015).
                if (_rideStatus == PassengerRideStatus.inicial)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: SafeArea(
                      child: Material(
                        color: IdentidadeVisual.folha,
                        elevation: 8,
                        shadowColor: const Color(0x66000000),
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _destinoController,
                                style: IdentidadeVisual.estiloValor,
                                decoration:
                                    decoracaoCampo(
                                      rotulo: 'Destino',
                                      dica: 'Para onde você quer ir?',
                                    ).copyWith(
                                      prefixIcon: const Icon(
                                        Icons.flag_outlined,
                                        color: IdentidadeVisual.roxo,
                                      ),
                                    ),
                                onChanged: _aoMudarTexto,
                              ),
                              if (_sugestoes.isNotEmpty)
                                _ListaDeSugestoes(
                                  sugestoes: _sugestoes,
                                  onSelecionar: _selecionarSugestao,
                                ),
                              if (_mensagemBusca != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    _mensagemBusca!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: IdentidadeVisual.textoSuave,
                                    ),
                                  ),
                                ),
                              if (_destino != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: _InfoDeRota(
                                    rota: _rota,
                                    falhou: _falhaRota,
                                  ),
                                ),
                              const SizedBox(height: 12),
                              SegmentedButton<PaymentMethod>(
                                showSelectedIcon: false,
                                style: SegmentedButton.styleFrom(
                                  backgroundColor: IdentidadeVisual.campo,
                                  foregroundColor: IdentidadeVisual.texto,
                                  selectedBackgroundColor:
                                      IdentidadeVisual.roxo,
                                  selectedForegroundColor: Colors.white,
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                segments: [
                                  for (final forma in PaymentMethod.values)
                                    ButtonSegment(
                                      value: forma,
                                      label: Text(forma.label),
                                    ),
                                ],
                                selected: {_pagamento},
                                onSelectionChanged: (selecionado) => setState(
                                  () => _pagamento = selecionado.first,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                style: IdentidadeVisual.estiloAcaoPrimaria(),
                                onPressed: _solicitando
                                    ? null
                                    : _solicitarCorrida,
                                child: _solicitando
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Solicitar corrida'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // Cancelar a corrida aceita (feature 023, FR-001): só nas três
                // fases de corrida aceita e não concluída. Ocupa a área do
                // painel de solicitação, que some nessas fases.
                if (PassengerRideRules.canCancelRide(_rideStatus))
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Chegada ao destino: botão no lugar da antiga modal,
                          // só com o passageiro no raio do destino.
                          if (_noRaioDoDestino) ...[
                            _BotaoConfirmarDestino(
                              confirmando: _confirmandoDestino,
                              erro: _erroConfirmarDestino,
                              onPressed: _aoTocarConfirmarDestino,
                            ),
                            const SizedBox(height: 8),
                          ],
                          _BotaoCancelarCorrida(
                            onPressed: _abrirConfirmacaoCancelamento,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );

    if (_modalMotoristaIndisponivelVisivel) {
      return Stack(
        children: [
          scaffold,
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: DriverUnavailableModal(
                  onClose: _fecharModalMotoristaIndisponivel,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_modalCorridaCanceladaVisivel) {
      return Stack(
        children: [
          scaffold,
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: RideCancelledModal(
                  onClose: _fecharModalCorridaCancelada,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_modalConfirmarCancelamentoVisivel &&
        PassengerRideRules.canCancelRide(_rideStatus)) {
      return Stack(
        children: [
          scaffold,
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: CancelRideModal(
                  onBack: _fecharConfirmacaoCancelamento,
                  onConfirm: _cancelarCorrida,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_modalAvaliacaoVisivel) {
      return Stack(
        children: [
          scaffold,
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: RideRatingModal(
                  onConfirm: _avaliarCorrida,
                  onSkip: _pularAvaliacao,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_modalChegadaMotoristaVisivel) {
      return Stack(
        children: [
          scaffold,
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: DriverArrivedModal(onConfirm: _confirmarEncontro),
              ),
            ),
          ),
        ],
      );
    }

    if (_modalMotoristaVisivel) {
      return Stack(
        children: [
          scaffold,
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: DriverMovingModal(onClose: _fecharModalMotorista),
              ),
            ),
          ),
        ],
      );
    }

    return scaffold;
  }
}

/// Exibe a distância do trajeto real até o destino (US1), ou uma indicação
/// não bloqueante quando o cálculo falhou (US3) ou ainda está em andamento
/// (feature 007). Nada é exibido enquanto não há um resultado nem falha —
/// evita mostrar "calculando" permanentemente antes da posição atual chegar.
/// Marcador circular de 44 px da identidade visual (`fundo`, borda branca de
/// 2 px, ícone em `destaque`) — o mesmo desenho que o app do motorista usa
/// para a própria posição, agora para representar o motorista no mapa do
/// passageiro (FR-004 da feature 016).
class _MarcadorCircular extends StatelessWidget {
  const _MarcadorCircular({required this.icon, required this.semanticLabel});

  final IconData icon;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: IdentidadeVisual.fundo,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: IdentidadeVisual.destaque,
        size: 24,
        semanticLabel: semanticLabel,
      ),
    );
  }
}

class _InfoDeRota extends StatelessWidget {
  const _InfoDeRota({required this.rota, required this.falhou});

  final RouteResult? rota;
  final bool falhou;

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(fontSize: 13, color: IdentidadeVisual.texto);
    if (falhou) {
      return Text(
        'Não foi possível calcular a distância até o destino agora.',
        style: estilo,
      );
    }
    final rotaAtual = rota;
    if (rotaAtual == null) {
      return Text('Calculando distância…', style: estilo);
    }
    return Text(
      'Distância: ${_formatarDistancia(rotaAtual.distanceMeters)}',
      style: estilo,
    );
  }

  static String _formatarDistancia(double metros) {
    if (metros < 1000) return '${metros.round()} m';
    return '${(metros / 1000).toStringAsFixed(1)} km';
  }
}

class _ListaDeSugestoes extends StatelessWidget {
  const _ListaDeSugestoes({
    required this.sugestoes,
    required this.onSelecionar,
  });

  final List<AddressSuggestion> sugestoes;
  final ValueChanged<AddressSuggestion> onSelecionar;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: sugestoes.length,
        itemBuilder: (context, indice) {
          final sugestao = sugestoes[indice];
          return ListTile(
            dense: true,
            leading: const Icon(
              Icons.place_outlined,
              color: IdentidadeVisual.roxo,
            ),
            title: Text(
              sugestao.displayText,
              style: const TextStyle(
                fontSize: 14,
                color: IdentidadeVisual.texto,
              ),
            ),
            onTap: () => onSelecionar(sugestao),
          );
        },
      ),
    );
  }
}

class _AvisoIndisponibilidade extends StatelessWidget {
  const _AvisoIndisponibilidade({
    required this.mensagem,
    required this.onTentarDeNovo,
  });

  final String mensagem;
  final VoidCallback onTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: IdentidadeVisual.folha.withValues(alpha: 0.96),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_off,
                  size: 48,
                  color: IdentidadeVisual.roxo,
                ),
                const SizedBox(height: 16),
                Text(
                  mensagem,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: IdentidadeVisual.texto,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: IdentidadeVisual.estiloAcaoPrimaria(),
                  onPressed: onTentarDeNovo,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão "Confirmar chegada ao destino": cartão `folha` com a ação primária,
/// exibido sobre o botão de cancelar quando o passageiro está no raio do
/// destino. Mostra a falha da última tentativa abaixo do botão.
class _BotaoConfirmarDestino extends StatelessWidget {
  const _BotaoConfirmarDestino({
    required this.confirmando,
    required this.erro,
    required this.onPressed,
  });

  final bool confirmando;
  final String? erro;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IdentidadeVisual.folha,
      elevation: 8,
      shadowColor: const Color(0x66000000),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              key: const Key('botao-confirmar-destino'),
              style: IdentidadeVisual.estiloAcaoPrimaria(altura: 48),
              onPressed: confirmando ? null : onPressed,
              icon: confirmando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.flag_outlined),
              label: const Text('Confirmar chegada ao destino'),
            ),
            if (erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  erro!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Botão "Cancelar corrida" do mapa (feature 023, FR-001): cartão `folha` com
/// o botão de cancelamento de corrida da constituição (2.12.0) — a aparência
/// da ação primária, fundo `roxo` e texto e ícone brancos (feature 024).
class _BotaoCancelarCorrida extends StatelessWidget {
  const _BotaoCancelarCorrida({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IdentidadeVisual.folha,
      elevation: 8,
      shadowColor: const Color(0x66000000),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: FilledButton.icon(
          key: const Key('botao-cancelar-corrida'),
          style: IdentidadeVisual.estiloAcaoPrimaria(altura: 48),
          onPressed: onPressed,
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Cancelar corrida'),
        ),
      ),
    );
  }
}

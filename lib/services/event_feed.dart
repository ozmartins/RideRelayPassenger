import 'dart:async';
import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart' as nostr;

import 'package:passenger/domain/identity.dart';
import 'package:passenger/domain/nostr_event.dart';
import 'package:passenger/domain/received_quote.dart';
import 'package:passenger/domain/ride_request.dart';
import 'package:passenger/services/event_verifier.dart';
import 'package:passenger/services/message_cipher.dart';
import 'package:passenger/services/relay_hub.dart';
import 'package:passenger/services/subscription_request.dart';
import 'package:passenger/shared/prototype_marker.dart';

/// `kind` da "Solicitação de corrida" (D1 de
/// `specs/006-solicitar-corrida/research.md`; contrato: emenda 04 de
/// `specs/002-nostr-relay-connection/contracts/nostr-events.md`). Faixa
/// efêmera do NIP-01 (20000–29999): relays não retêm nem reenviam a
/// inscrições futuras.
const rideRequestKind = 20001;

/// `kind` do "Orçamento de corrida" (emendas 05/06 do contrato) — recebido
/// pelo passageiro (feature 008 dele).
const rideQuoteKind = 20002;

/// `kind` da "Aceitação de orçamento" (emenda 07 do contrato).
const quoteAcceptedKind = 20003;

/// `kind` da "Recusa de orçamento" (emenda 07 do contrato).
const quoteRejectedKind = 20004;

/// `kind` da "Localização do motorista" (emenda 08 do contrato, definida
/// pela feature 010 do motorista) — consumida pelo passageiro pela primeira
/// vez na feature 009 dele (emenda 10), só para reconhecer sua primeira
/// ocorrência por corrida, não para exibir a posição.
const driverLocationKind = 20005;

/// `kind` da "Chegada do motorista" à origem (emenda 09 do contrato,
/// definida pela feature 011 do motorista) — consumida pelo passageiro pela
/// primeira vez nesta feature (010 dele).
const driverArrivalKind = 20007;

/// `kind` do "Encontro confirmado" (emenda 11 do contrato, definida pela
/// feature 012 do motorista) — publicada pelo passageiro nesta feature.
const meetingConfirmedKind = 20008;

/// `kind` da "Chegada ao destino" (emenda 11 do contrato) — consumida pelo
/// passageiro nesta feature.
const destinationArrivalKind = 20009;

/// `kind` do "Destino confirmado" (emenda 11 do contrato) — publicada pelo
/// passageiro nesta feature.
const destinationConfirmedKind = 20010;

/// `kind` da "Rota da corrida" (emenda 13 do contrato, definida pela feature
/// 017 do motorista) — consumida pelo passageiro nesta feature (018 dele):
/// o trajeto até o destino, desenhado no mapa em "Em corrida".
const rideRouteKind = 20011;

/// `kind` da "Corrida cancelada" (emenda 14 do contrato, definida pela feature
/// 018 do motorista) — consumida pelo passageiro nesta feature (019 dele): o
/// motorista cancelou a corrida aceita.
const rideCancelledKind = 20012;

/// `kind` da "Corrida cancelada pelo passageiro" (emenda 19 do contrato,
/// definida pela feature 020 do motorista) — **publicada** pelo passageiro
/// nesta feature (023 dele); o motorista a consome. O passageiro não se
/// inscreve nele.
const rideCancelledByPassengerKind = 20013;

/// `kind` da "Corrida não pode mais ser atendida (emenda 08 do contrato,
/// definida pela feature 010 do motorista, ampliada pela emenda 16) —
/// consumida pelo passageiro nesta feature (020 dele): o motorista da corrida
/// aceita já está comprometido com outra e não pode atendê-la.
const rideUnavailableKind = 20006;

/// Desfecho da publicação em um relay.
enum PublishStatus { accepted, rejected, noAnswer }

/// Resultado da publicação, relay a relay (FR-007).
class PublishReport {
  const PublishReport({required this.eventId, required this.byRelay});

  final String eventId;
  final Map<String, PublishStatus> byRelay;

  bool get anyAccepted =>
      byRelay.values.any((s) => s == PublishStatus.accepted);
}

/// Recebe, verifica e deduplica os eventos do protótipo; publica eventos
/// assinados pela identidade local.
///
/// Toda a lógica que o Princípio II obriga a testar — verificação de
/// assinatura, descarte e deduplicação — vive aqui, fora da árvore de widgets e
/// sem depender de relay real.
class EventFeed {
  EventFeed({
    required this.relayService,
    this.verifier = const NostrEventVerifier(),
    this.windowSize = 200,
    this.publishTimeout = const Duration(seconds: 10),
    Set<int>? acceptedKinds,
    MessageCipher? cipher,
  }) : acceptedKinds = acceptedKinds ?? const {rideQuoteKind},
       _cipher = cipher ?? MessageCipher();

  final RelayHub relayService;
  final EventVerifier verifier;

  /// Cifra o `content` dos kinds com destinatário (emenda 17 do contrato).
  final MessageCipher _cipher;

  /// Kinds que este `EventFeed` aceita e expõe via [events]/[current]; os
  /// demais são ignorados sem erro (regra 4 de recepção). Também define a
  /// lista `kinds` da inscrição.
  final Set<int> acceptedKinds;

  /// Quantos eventos são mantidos em memória. A rede pública entrega volume
  /// arbitrário; a janela sustenta SC-006 sem congelar a interface.
  final int windowSize;

  /// Quanto esperar pela confirmação de cada relay antes de reportar
  /// [PublishStatus.noAnswer].
  final Duration publishTimeout;

  static const subscriptionId = eventSubscriptionId;

  final _events = <NostrEvent>[];
  final _seenIds = <String>{};

  /// Chave de ordenação de cada evento exibido, por id.
  final _sortKeys = <String, DateTime>{};
  final _controller = StreamController<List<NostrEvent>>.broadcast();
  final _okWaiters = <String, Map<String, Completer<PublishStatus>>>{};
  StreamSubscription<RelayMessage>? _subscription;
  var _disposed = false;

  /// Eventos válidos recebidos, do mais recente para o mais antigo.
  List<NostrEvent> get current => List.unmodifiable(_events);

  /// Emite a lista a cada mudança.
  Stream<List<NostrEvent>> get events => _controller.stream;

  /// Decifra o `content` de um [evento] recebido (emenda 17, regra de recepção
  /// 7), **depois** de a assinatura ter sido verificada em `_onEvent`.
  ///
  /// Devolve uma cópia do evento com o texto decifrado, ou `null` — e o
  /// chamador descarta o evento em silêncio, sem efeito — se a tag `p` não for
  /// a chave de [identity], se o conteúdo estiver em claro, adulterado ou
  /// cifrado a outra chave, ou, com [emptyMarker] (os kinds sem dado próprio),
  /// se o texto decifrado não for exatamente `{}`. Nunca lança nem registra
  /// chave ou texto.
  NostrEvent? decrypted(
    NostrEvent evento,
    Identity identity, {
    bool emptyMarker = false,
  }) {
    if (evento.recipientPublicKey != identity.publicKey) return null;
    final texto = _cipher.decryptFrom(
      identity,
      evento.authorPublicKey,
      evento.content,
      emptyMarker: emptyMarker,
    );
    return texto == null ? null : evento.withContent(texto);
  }

  /// Passa a ouvir os relays e registra a inscrição filtrada pelo marcador.
  ///
  /// A inscrição é registrada, não apenas enviada: o [RelayHub] a reenvia a
  /// todo relay que conectar depois, inclusive após queda de rede.
  void start() {
    _subscription ??= relayService.messages.listen(_onMessage);
    relayService.subscribe(subscriptionId, subscriptionRequest());
  }

  /// A inscrição, conforme o contrato (emendas 01 e 02): filtra por `kind` e
  /// pelo marcador, e limita o histórico entregue ao estabelecer a inscrição.
  /// Sem o `#t`, o relay entrega o tráfego social da rede inteira; sem o
  /// `limit`, o histórico cresce a cada reconexão, porque esta mesma
  /// inscrição é reenviada a todo relay que conecta ou reconecta (regra de
  /// vivacidade do [RelayService]).
  ///
  /// A lista `kinds` é [acceptedKinds].
  ///
  /// MUST NOT usar `since`: com a inscrição reenviada a cada conexão, um
  /// `since` calculado uma vez aqui ficaria cada vez mais velho — o contrato
  /// descarta essa opção pelo mesmo motivo.
  String subscriptionRequest() => buildSubscriptionRequest(acceptedKinds);

  /// Publica uma solicitação de corrida (`kind: 20001`) assinada por
  /// [identity], reportando o desfecho por relay — mesmo mecanismo das
  /// demais publicações (D6 de `specs/006-solicitar-corrida/research.md`).
  ///
  /// `content` segue o formato JSON de
  /// `specs/006-solicitar-corrida/contracts/ride-request-event.md`: `origin`
  /// e `destination` com `lat`/`lon` em graus decimais, sem truncamento de
  /// precisão, e `payment` com o valor de contrato de [RideRequest.payment].
  Future<PublishReport> publishRideRequest(
    RideRequest request,
    Identity identity,
  ) => _publish(
    kind: rideRequestKind,
    content: jsonEncode({
      'origin': {
        'lat': request.origin.latitude,
        'lon': request.origin.longitude,
      },
      'destination': {
        'lat': request.destination.latitude,
        'lon': request.destination.longitude,
      },
      'payment': request.payment.contractValue,
    }),
    identity: identity,
  );

  /// Publica uma aceitação de orçamento (`kind: 20003`, emenda 07 do
  /// contrato) assinada por [identity], referenciando [quote] e dirigida ao
  /// motorista que o enviou (FR-008 de `specs/008-receber-orcamentos/spec.md`).
  Future<PublishReport> publishQuoteAcceptance(
    ReceivedQuote quote,
    Identity identity,
  ) => _publish(
    kind: quoteAcceptedKind,
    content: '',
    identity: identity,
    recipientPubkey: quote.driverPubkey,
    extraTags: [
      ['e', quote.quoteId],
      ['p', quote.driverPubkey],
    ],
  );

  /// Publica uma recusa de orçamento (`kind: 20004`, emenda 07 do contrato)
  /// — mesmo formato de [publishQuoteAcceptance], para um orçamento que não
  /// foi o escolhido (FR-009).
  Future<PublishReport> publishQuoteRejection(
    ReceivedQuote quote,
    Identity identity,
  ) => _publish(
    kind: quoteRejectedKind,
    content: '',
    identity: identity,
    recipientPubkey: quote.driverPubkey,
    extraTags: [
      ['e', quote.quoteId],
      ['p', quote.driverPubkey],
    ],
  );

  /// Publica a confirmação de encontro (`kind: 20008`, emenda 11 do
  /// contrato) assinada por [identity], referenciando [quoteId] e dirigida
  /// ao motorista [driverPubkey] — mesmo formato de [publishQuoteAcceptance]
  /// (feature 010: Confirmar encontro e destino).
  Future<PublishReport> publishMeetingConfirmation(
    String quoteId,
    String driverPubkey,
    Identity identity,
  ) => _publish(
    kind: meetingConfirmedKind,
    content: '',
    identity: identity,
    recipientPubkey: driverPubkey,
    extraTags: [
      ['e', quoteId],
      ['p', driverPubkey],
    ],
  );

  /// Publica a confirmação de destino (`kind: 20010`, emenda 11 do
  /// contrato) — mesmo formato de [publishMeetingConfirmation].
  Future<PublishReport> publishDestinationConfirmation(
    String quoteId,
    String driverPubkey,
    Identity identity,
  ) => _publish(
    kind: destinationConfirmedKind,
    content: '',
    identity: identity,
    recipientPubkey: driverPubkey,
    extraTags: [
      ['e', quoteId],
      ['p', driverPubkey],
    ],
  );

  /// Publica o cancelamento da corrida aceita (`kind: 20013`, emenda 19 do
  /// contrato) ao motorista [driverPubkey] — mesmo formato de
  /// [publishMeetingConfirmation] (feature 023).
  Future<PublishReport> publishRideCancellation(
    String quoteId,
    String driverPubkey,
    Identity identity,
  ) => _publish(
    kind: rideCancelledByPassengerKind,
    content: '',
    identity: identity,
    recipientPubkey: driverPubkey,
    extraTags: [
      ['e', quoteId],
      ['p', driverPubkey],
    ],
  );

  Future<PublishReport> _publish({
    required int kind,
    required String content,
    required Identity identity,
    List<List<String>> extraTags = const [],
    String? recipientPubkey,
  }) async {
    final par = nostr.NostrKeyPairs(private: identity.privateKey);

    // Emenda 17: com destinatário, o `content` sai cifrado a ele (texto vazio
    // vira `{}`). Se não der para cifrar, nada é assinado nem transmitido em
    // claro: o relatório vazio é lido por `anyAccepted` como "nenhum relay
    // aceitou", o mesmo caminho de falha que as telas já tratam (FR-004).
    // Sem destinatário (20001 — a exceção) o `content` segue em claro.
    final String conteudo;
    try {
      conteudo = recipientPubkey == null
          ? content
          : _cipher.encryptFor(identity, recipientPubkey, content);
    } on Object {
      return const PublishReport(eventId: '', byRelay: {});
    }

    final evento = nostr.NostrEvent.fromPartialData(
      kind: kind,
      content: conteudo,
      keyPairs: par,
      tags: [prototypeMarkerTag, ...extraTags],
    );
    final id = evento.id!;

    final destinos = relayService.connectedUrls;
    if (destinos.isEmpty) {
      return PublishReport(eventId: id, byRelay: const {});
    }

    final aguardando = <String, Completer<PublishStatus>>{
      for (final url in destinos) url: Completer<PublishStatus>(),
    };
    _okWaiters[id] = aguardando;

    relayService.broadcast(evento.serialized());

    final resultados = <String, PublishStatus>{};
    await Future.wait(
      aguardando.entries.map((e) async {
        try {
          resultados[e.key] = await e.value.future.timeout(publishTimeout);
        } on TimeoutException {
          resultados[e.key] = PublishStatus.noAnswer;
        }
      }),
    );
    _okWaiters.remove(id);

    return PublishReport(eventId: id, byRelay: resultados);
  }

  void _onMessage(RelayMessage mensagem) {
    final dados = _decodificar(mensagem.payload);
    if (dados == null || dados.isEmpty) return;

    switch (dados.first) {
      case 'EVENT':
        if (dados.length < 3) return;
        final payload = dados[2];
        if (payload is! Map<String, dynamic>) return;
        _onEvent(payload);
      case 'OK':
        if (dados.length < 3) return;
        final id = dados[1];
        final aceito = dados[2];
        if (id is! String || aceito is! bool) return;
        // Um relay pode confirmar o mesmo evento duas vezes — relay
        // defeituoso, reconexão. Sem a checagem, a segunda confirmação lança
        // Bad state ao completar um Completer já concluído, e o erro
        // assíncrono derruba a espera pelos relays que ainda não responderam.
        final aguardando = _okWaiters[id]?[mensagem.url];
        if (aguardando != null && !aguardando.isCompleted) {
          aguardando.complete(
            aceito ? PublishStatus.accepted : PublishStatus.rejected,
          );
        }
      default:
        // NOTICE, EOSE, CLOSED e o que mais a rede inventar: ignorar sem erro.
        return;
    }
  }

  void _onEvent(Map<String, dynamic> payload) {
    final id = payload['id'];
    if (id is! String) return;

    // Deduplicar antes de verificar: verificação é a parte cara, e o mesmo
    // evento chega por vários relays (FR-010).
    if (_seenIds.contains(id)) return;

    // Regra 1 de recepção: verificar a assinatura **antes** de qualquer outro
    // processamento.
    if (!verifier.isValid(payload)) return;

    // Regra 6: o relay pode ignorar o filtro #t da inscrição; não dependemos do
    // bom comportamento dele.
    if (!hasPrototypeMarker(payload['tags'] as List<dynamic>?)) return;

    // Regra 4: kind fora do que este EventFeed aceita é ignorado sem erro.
    final kind = payload['kind'];
    if (kind is! int || !acceptedKinds.contains(kind)) return;

    final declarado = DateTime.fromMillisecondsSinceEpoch(
      (payload['created_at'] as int) * 1000,
    );
    final evento = NostrEvent(
      id: id,
      authorPublicKey: payload['pubkey'] as String,
      createdAt: declarado,
      kind: kind,
      content: payload['content'] as String,
      isSignatureValid: true,
      tags: (payload['tags'] as List<dynamic>? ?? const [])
          .map((t) => (t as List<dynamic>).map((e) => e.toString()).toList())
          .toList(),
    );

    // Ordem de exibição: mais novo primeiro, pela data declarada. Não pela
    // ordem de chegada — um relay entrega o histórico do mais novo para o mais
    // velho, e inserir cada um no topo invertia a lista.
    //
    // A data é declarada pelo autor e não é confiável (regra 5 do contrato).
    // Ordenar exibição por ela é aceitável; o que não pode é um evento datado
    // no futuro ficar preso no topo e nunca ser descartado pela janela. Por
    // isso a data futura é limitada ao instante de chegada.
    final agora = DateTime.now();
    final chave = declarado.isAfter(agora) ? agora : declarado;

    _seenIds.add(id);
    _sortKeys[id] = chave;

    // Insere antes do primeiro evento com chave menor ou igual: empates ficam
    // com o mais recém-chegado na frente.
    var indice = _events.indexWhere((e) => !_sortKeys[e.id]!.isAfter(chave));
    if (indice == -1) indice = _events.length;
    _events.insert(indice, evento);

    if (_events.length > windowSize) {
      final descartados = _events.sublist(windowSize);
      _events.removeRange(windowSize, _events.length);
      // Os ids descartados saem do conjunto de vistos e das chaves: manter
      // tudo faria esses conjuntos crescerem sem limite, que é o vazamento que
      // a janela evita.
      for (final e in descartados) {
        _seenIds.remove(e.id);
        _sortKeys.remove(e.id);
      }
    }

    if (!_controller.isClosed) _controller.add(current);
  }

  static List<dynamic>? _decodificar(String payload) {
    try {
      final dados = jsonDecode(payload);
      return dados is List ? dados : null;
    } on FormatException {
      return null;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_subscription?.cancel() ?? Future<void>.value());
    _controller.close();
  }
}

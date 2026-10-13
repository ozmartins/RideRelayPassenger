import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:passenger/domain/background_notification_rule.dart';
import 'package:passenger/domain/relay.dart';
import 'package:passenger/domain/service_state.dart';
import 'package:passenger/services/background/message_channel.dart';
import 'package:passenger/services/background/service_messages.dart';
import 'package:passenger/services/background/service_state_store.dart';
import 'package:passenger/services/event_verifier.dart';
import 'package:passenger/services/relay_hub.dart';
import 'package:passenger/services/relay_repository.dart';
import 'package:passenger/services/ride_message_notifier.dart';
import 'package:passenger/services/subscription_request.dart';
import 'package:passenger/shared/prototype_marker.dart';

/// O que roda dentro do serviço em segundo plano (feature 026): hospeda a
/// conexão com os relays, verifica o que chega, repassa à interface e decide
/// quando uma mensagem do motorista merece notificação.
///
/// Não conhece o plugin do serviço, a chave privada nem a cifra — só um
/// [RelayHub], um [MessageChannel] e um [RideMessageNotifier], todos
/// injetados, o que o deixa testável sem rede, sem Android e sem identidade
/// (Princípios I e II; constituição 2.15.0). A decisão de notificar usa só
/// dados públicos do evento ([BackgroundNotificationRule]): o `content` é
/// cifrado ao passageiro e aqui nunca é lido.
class RelayHostCore {
  RelayHostCore({
    required this.relays,
    required this.channel,
    required this.stateStore,
    required this.relayRepository,
    required this.notifier,
    Set<int>? acceptedKinds,
    this.verifier = const NostrEventVerifier(),
    this.pendingValidity = const Duration(minutes: 5),
    this.maxSeenIds = 500,
    DateTime Function()? now,
    this.onStopRequested,
  }) : acceptedKinds = acceptedKinds ?? passengerConsumedKinds,
       _now = now ?? DateTime.now;

  /// A conexão com os relays que este serviço hospeda.
  final RelayHub relays;

  /// A ponta do canal que fala com a interface.
  final MessageChannel channel;

  final ServiceStateStore stateStore;
  final RelayRepository relayRepository;
  final RideMessageNotifier notifier;

  /// Kinds que o app consome; os demais são ignorados sem erro.
  final Set<int> acceptedKinds;
  final DateTime Function() _now;

  /// Verificador de assinatura (com recálculo do `id`). Injetável para teste.
  final EventVerifier verifier;

  /// Por quanto tempo uma mensagem recebida sem a interface visível continua
  /// valendo para a reentrega (FR-007).
  final Duration pendingValidity;

  /// Tamanho da janela de ids vistos, para a memória não crescer sem limite.
  final int maxSeenIds;

  /// Chamado quando a interface pede para encerrar o serviço.
  final Future<void> Function()? onStopRequested;

  ServiceState _state = const ServiceState();
  final LinkedHashSet<String> _seenIds = LinkedHashSet<String>();
  final LinkedHashSet<String> _notified = LinkedHashSet<String>();
  final List<_Pending> _pending = [];
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _disposed = false;

  int _discardedInvalid = 0;
  int _discardedUnmarked = 0;
  int _discardedDuplicate = 0;

  /// Eventos descartados por assinatura inválida ou malformação.
  int get discardedInvalidCount => _discardedInvalid;

  /// Eventos legítimos, mas sem o marcador do protótipo (regra 6 do contrato).
  int get discardedUnmarkedCount => _discardedUnmarked;

  /// Entregas repetidas (mesmo `id`) absorvidas.
  int get discardedDuplicateCount => _discardedDuplicate;

  /// O estado que a interface mandou por último (ou o persistido).
  ServiceState get state => _state;

  /// Conecta sozinho a partir da lista persistida (não depende da interface),
  /// registra a inscrição (um serviço reiniciado pelo sistema não tem
  /// interface para fazê-lo) e avisa que está pronto.
  ///
  /// [restoreState] diz se o estado guardado vale: sim quando o sistema
  /// reiniciou o serviço sozinho, não quando o app o iniciou — a interface
  /// refaz o estado logo em seguida, e um estado antigo de um processo morto
  /// não pode notificar por uma corrida que já acabou.
  Future<void> start({bool restoreState = true}) async {
    if (restoreState) {
      _state = await stateStore.load();
    } else {
      _state = const ServiceState();
      await stateStore.save(_state);
    }

    _subscriptions
      ..add(channel.incoming.listen(_onMessage))
      ..add(relays.messages.listen(_onRelayMessage))
      ..add(relays.relays.listen((_) => channel.send(_relaysChanged())));

    relays.subscribe(
      eventSubscriptionId,
      buildSubscriptionRequest(acceptedKinds),
    );
    final lista = await relayRepository.load();
    // Avisa antes de conectar: a interface pode enviar comandos já, e eles
    // esperam na fila do canal enquanto os relays conectam.
    channel.send(const ServiceReady());
    await relays.start(lista);
    relays.enableAutoRetry();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await relays.dispose();
    await channel.close();
  }

  ServiceRelaysChanged _relaysChanged() => ServiceRelaysChanged(relays.current);

  // ---------------------------------------------------------------- recepção

  void _onRelayMessage(RelayMessage message) {
    final dados = _decode(message.payload);
    if (dados == null || dados.isEmpty) return;

    if (dados.first != 'EVENT') {
      // OK, EOSE, NOTICE: o `EventFeed` os usa (confirmação de publicação);
      // sem interface do outro lado, perdem-se sem dano.
      channel.send(
        ServiceRelayMessage(relayUrl: message.url, payload: message.payload),
      );
      return;
    }

    if (dados.length < 3 || dados[2] is! Map<String, dynamic>) return;
    final payload = dados[2] as Map<String, dynamic>;

    // 1. assinatura antes de qualquer outro processamento (Princípio IV)
    if (!verifier.isValid(payload)) {
      _discardedInvalid++;
      return;
    }

    // kind desconhecido é ignorado sem erro (contrato, regra 4)
    final kind = payload['kind'] as int;
    if (!acceptedKinds.contains(kind)) return;

    // 2. marcador do protótipo (contrato, regra 6)
    if (!hasPrototypeMarker(payload['tags'] as List<dynamic>?)) {
      _discardedUnmarked++;
      return;
    }

    // 3. deduplicação por id entre os relays
    final id = payload['id'] as String;
    if (!_seenIds.add(id)) {
      _discardedDuplicate++;
      return;
    }
    if (_seenIds.length > maxSeenIds) _seenIds.remove(_seenIds.first);

    channel.send(
      ServiceRelayMessage(relayUrl: message.url, payload: message.payload),
    );

    _maybeNotify(message, payload);
  }

  void _maybeNotify(RelayMessage message, Map<String, dynamic> payload) {
    // Com a interface visível quem trata é a tela.
    if (_state.appInForeground) return;

    final aviso = BackgroundNotificationRule.evaluate(payload, _state);
    if (aviso == null) return;

    // Uma notificação por notícia: o 20007 se repete a cada 5 s no raio.
    final chave = BackgroundNotificationRule.dedupeKey(aviso, payload);
    if (!_notified.add(chave)) return;
    if (_notified.length > maxSeenIds) _notified.remove(_notified.first);

    _pending.add(_Pending(message.url, message.payload, _now()));
    unawaited(notifier.notify(aviso, payload['id'] as String));
  }

  // ------------------------------------------------------------------ comandos

  void _onMessage(ServiceMessage message) {
    switch (message) {
      case ServiceHello(:final foreground):
        _state = _state.copyWith(appInForeground: foreground);
        if (foreground) unawaited(notifier.cancelAll());
        channel.send(
          ServiceHelloAck(relays: relays.current, pending: _takePending()),
        );
      case ServiceStateUpdate(:final state):
        _state = state;
        if (state.appInForeground) unawaited(notifier.cancelAll());
        unawaited(stateStore.save(state));
      case ServiceStart(relays: final lista):
        unawaited(_reconcile(lista));
      case ServiceAddRelay(:final relay):
        unawaited(relays.add(relay));
      case ServiceRemoveRelay(:final url):
        unawaited(relays.remove(url));
      case ServiceRetryUnavailable():
        // Responde sempre, mudando ou não algum estado: é o que a interface
        // espera para soltar o botão "Reconectando…".
        unawaited(
          relays.retryUnavailable().whenComplete(
            () => channel.send(_relaysChanged()),
          ),
        );
      case ServiceSubscribe(:final subscriptionId, :final request):
        relays.subscribe(subscriptionId, request);
      case ServiceBroadcast(message: final texto):
        relays.broadcast(texto);
      case ServiceStop():
        unawaited(_stop());
      // Só a interface recebe estas; chegando aqui são ignoradas.
      case ServiceReady() ||
          ServiceHelloAck() ||
          ServiceRelaysChanged() ||
          ServiceRelayMessage():
        break;
    }
  }

  /// Concilia a lista da interface com a do serviço sem reconectar quem já
  /// está conectado.
  Future<void> _reconcile(List<Relay> lista) async {
    final atuais = {for (final r in relays.current) r.url};
    final desejadas = {for (final r in lista) r.url};
    for (final url in atuais.difference(desejadas)) {
      await relays.remove(url);
    }
    for (final relay in lista) {
      if (!atuais.contains(relay.url)) await relays.add(relay);
    }
  }

  Future<void> _stop() async {
    await onStopRequested?.call();
    await dispose();
  }

  /// As mensagens ainda válidas, entregues uma única vez à interface.
  List<PendingRelayMessage> _takePending() {
    final limite = _now().subtract(pendingValidity);
    final validas = [
      for (final p in _pending)
        if (p.receivedAt.isAfter(limite))
          PendingRelayMessage(relayUrl: p.relayUrl, payload: p.payload),
    ];
    _pending.clear();
    return validas;
  }

  static List<dynamic>? _decode(String payload) {
    try {
      final d = jsonDecode(payload);
      return d is List ? d : null;
    } on FormatException {
      return null;
    }
  }
}

class _Pending {
  _Pending(this.relayUrl, this.payload, this.receivedAt);
  final String relayUrl;
  final String payload;
  final DateTime receivedAt;
}

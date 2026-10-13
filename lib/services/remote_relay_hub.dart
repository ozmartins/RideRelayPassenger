import 'dart:async';

import 'package:passenger/domain/relay.dart';
import 'package:passenger/services/background/message_channel.dart';
import 'package:passenger/services/background/service_messages.dart';
import 'package:passenger/services/relay_hub.dart';

/// O [RelayHub] visto pela interface quando a conexão vive no serviço em
/// segundo plano (feature 026): cada operação vira uma mensagem para o
/// serviço, e o estado dos relays e as mensagens recebidas voltam por
/// mensagens.
///
/// A lista de relays é um **espelho** mantido por `relaysChanged`; é nele que
/// [connectedUrls] e [broadcast] se baseiam, de forma síncrona, como o
/// `RelayService`. Os comandos enviados antes de o serviço responder ao
/// `hello` esperam numa fila e saem, na ordem, quando ele responde. O serviço
/// pode estar ainda subindo (a mensagem se perde se ninguém a recebe), então o
/// `hello` é repetido até a resposta.
class RemoteRelayHub implements RelayHub {
  RemoteRelayHub(
    this._channel, {
    this.helloRetry = const Duration(milliseconds: 500),
    this.retryTimeout = const Duration(seconds: 15),
    this.maxHelloAttempts = 20,
  }) {
    _subscription = _channel.incoming.listen(_onMessage);
  }

  final MessageChannel _channel;

  /// Intervalo entre repetições do `hello` enquanto o serviço não responde.
  final Duration helloRetry;

  /// Quantas vezes o `hello` é enviado antes de desistir até o próximo
  /// [attach] — um serviço que não sobe não pode manter a interface mandando
  /// mensagem para ninguém para sempre.
  final int maxHelloAttempts;

  /// Prazo para o serviço responder a um "tentar de novo".
  final Duration retryTimeout;

  late final StreamSubscription<ServiceMessage> _subscription;
  final StreamController<RelayMessage> _messages =
      StreamController<RelayMessage>.broadcast();
  final StreamController<List<Relay>> _relaysController =
      StreamController<List<Relay>>.broadcast();
  final StreamController<void> _attachedEvents =
      StreamController<void>.broadcast();

  List<Relay> _relays = const [];
  final Map<String, String> _subscriptions = {};
  bool _attached = false;
  bool _disposed = false;
  bool _foreground = true;
  Timer? _helloTimer;
  final List<void Function()> _queue = [];

  /// Emite cada vez que o serviço responde ao `hello` — na primeira ligação e
  /// quando ele reinicia. Quem guarda estado a reenviar (o controlador do
  /// serviço) o reenvia aqui.
  Stream<void> get attached => _attachedEvents.stream;

  /// Verdadeiro depois de o serviço responder ao `hello`.
  bool get isAttached => _attached;

  @override
  Stream<List<Relay>> get relays => _relaysController.stream;

  @override
  Stream<RelayMessage> get messages => _messages.stream;

  @override
  List<Relay> get current => List.unmodifiable(_relays);

  @override
  bool get hasAnyConnected =>
      _relays.any((r) => r.status == RelayStatus.connected);

  @override
  List<String> get connectedUrls => [
    for (final r in _relays)
      if (r.status == RelayStatus.connected) r.url,
  ];

  /// Apresenta-se ao serviço. Repete o `hello` até a resposta; chamar de novo
  /// (app voltando ao primeiro plano) refaz o handshake e entrega ao app as
  /// mensagens que o serviço guardou.
  void attach({required bool foreground}) {
    if (_disposed) return;
    _foreground = foreground;
    _attached = false;
    _helloTimer?.cancel();
    _sendHello();
    var tentativas = 1;
    _helloTimer = Timer.periodic(helloRetry, (timer) {
      if (++tentativas > maxHelloAttempts) {
        timer.cancel();
        _helloTimer = null;
        return;
      }
      _sendHello();
    });
  }

  /// Para de procurar o serviço: ele foi encerrado de propósito.
  void detach() {
    _helloTimer?.cancel();
    _helloTimer = null;
    _attached = false;
    _queue.clear();
  }

  void _sendHello() => _channel.send(ServiceHello(foreground: _foreground));

  void _onMessage(ServiceMessage message) {
    switch (message) {
      case ServiceReady():
        // Serviço (re)iniciado: o handshake anterior não vale mais.
        if (_attached || _helloTimer != null) attach(foreground: _foreground);
      case ServiceHelloAck(:final relays, :final pending):
        _helloTimer?.cancel();
        _helloTimer = null;
        // O serviço é a fonte da verdade; só aceita a lista dele se ele já
        // tem relays (um serviço que acabou de nascer pode responder vazio
        // antes de carregar a lista, e o espelho otimista da interface vale).
        if (relays.isNotEmpty) _setRelays(relays);
        _attached = true;
        // Reentrega pelo mesmo caminho de qualquer mensagem (verificação e
        // deduplicação do EventFeed valem também para ela).
        for (final p in pending) {
          _messages.add(RelayMessage(url: p.relayUrl, payload: p.payload));
        }
        final fila = List.of(_queue);
        _queue.clear();
        for (final comando in fila) {
          comando();
        }
        // Um serviço reiniciado perdeu as inscrições.
        _subscriptions.forEach(
          (id, request) => _channel.send(
            ServiceSubscribe(subscriptionId: id, request: request),
          ),
        );
        _attachedEvents.add(null);
      case ServiceRelaysChanged(:final relays):
        _setRelays(relays);
      case ServiceRelayMessage(:final relayUrl, :final payload):
        _messages.add(RelayMessage(url: relayUrl, payload: payload));
      // Só o serviço recebe estas.
      case ServiceHello() ||
          ServiceStateUpdate() ||
          ServiceStart() ||
          ServiceAddRelay() ||
          ServiceRemoveRelay() ||
          ServiceRetryUnavailable() ||
          ServiceSubscribe() ||
          ServiceBroadcast() ||
          ServiceStop():
        break;
    }
  }

  void _setRelays(List<Relay> relays) {
    _relays = relays;
    if (!_relaysController.isClosed) _relaysController.add(current);
  }

  /// Envia uma mensagem de controle ao serviço, na hora ou assim que ele
  /// responder ao `hello` — o estado do app, que o controlador do serviço
  /// manda.
  void sendToService(ServiceMessage message) =>
      _whenAttached(() => _channel.send(message));

  /// Executa [comando] agora, ou guarda até o serviço responder ao `hello`.
  void _whenAttached(void Function() comando) {
    if (_attached) {
      comando();
    } else {
      _queue.add(comando);
    }
  }

  @override
  Future<void> start(List<Relay> initial) async {
    _setRelays([
      for (final r in initial)
        r.copyWith(status: RelayStatus.connecting, clearError: true),
    ]);
    // O serviço já conectou sozinho à lista persistida: ele concilia, sem
    // derrubar conexões que estão boas.
    _whenAttached(() => _channel.send(ServiceStart(initial)));
  }

  @override
  Future<void> add(Relay relay) async {
    if (_relays.any((r) => r.url == relay.url)) return;
    _setRelays([
      ..._relays,
      relay.copyWith(status: RelayStatus.connecting, clearError: true),
    ]);
    _whenAttached(() => _channel.send(ServiceAddRelay(relay)));
  }

  @override
  Future<void> remove(String url) async {
    _setRelays([
      for (final r in _relays)
        if (r.url != url) r,
    ]);
    _whenAttached(() => _channel.send(ServiceRemoveRelay(url)));
  }

  @override
  Future<void> retryUnavailable() async {
    if (_disposed) return;
    final resposta = _relaysController.stream.first;
    _whenAttached(() => _channel.send(const ServiceRetryUnavailable()));
    try {
      await resposta.timeout(retryTimeout);
    } on TimeoutException {
      // O serviço não respondeu a tempo; o botão volta mesmo assim.
    } on StateError {
      // Fechado durante a espera.
    }
  }

  @override
  void subscribe(String subscriptionId, String request) {
    _subscriptions[subscriptionId] = request;
    _whenAttached(
      () => _channel.send(
        ServiceSubscribe(subscriptionId: subscriptionId, request: request),
      ),
    );
  }

  @override
  List<String> broadcast(String message) {
    final alcancados = connectedUrls;
    if (alcancados.isEmpty) return const [];
    _whenAttached(() => _channel.send(ServiceBroadcast(message)));
    return alcancados;
  }

  /// A retentativa e a sonda de vivacidade rodam no serviço.
  @override
  void enableAutoRetry() {}

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _helloTimer?.cancel();
    await _subscription.cancel();
    await _messages.close();
    await _relaysController.close();
    await _attachedEvents.close();
  }
}

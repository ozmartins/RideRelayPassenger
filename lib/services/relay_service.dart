import 'dart:async';
import 'dart:convert';

import 'package:passenger/domain/relay.dart';
import 'package:passenger/services/relay_hub.dart';
import 'package:passenger/services/relay_transport.dart';

export 'package:passenger/services/relay_hub.dart' show RelayMessage;

/// Mantém as conexões com os relays e o estado observável de cada uma.
///
/// Cada relay é independente: a falha de um nunca derruba os demais (FR-003).
/// A máquina de estados segue `specs/002-nostr-relay-connection/data-model.md`.
///
/// Recebe o [RelayTransport] por injeção para que os testes rodem com dublês em
/// memória, sem rede — exigência do Princípio II da constituição e da decisão
/// D5 da pesquisa.
class RelayService implements RelayHub {
  RelayService({
    required this.transport,
    this.connectTimeout = const Duration(seconds: 10),
    this.livenessTimeout = const Duration(seconds: 10),
    this.retryInterval = const Duration(seconds: 15),
  });

  /// Transporte injetado. Público para que o teste possa fornecer um dublê sem
  /// que a classe precise de uma fábrica só para isso.
  final RelayTransport transport;

  /// Limite para estabelecer a conexão com o relay.
  final Duration connectTimeout;

  /// Limite para o relay dar o primeiro sinal de vida depois de conectado.
  /// Sem ele, um relay que aceita a conexão e emudece ficaria em `connecting`
  /// para sempre.
  final Duration livenessTimeout;

  /// Intervalo entre retentativas automáticas dos relays indisponíveis.
  ///
  /// FR-014 exige reconexão **sem intervenção manual** quando a rede volta.
  /// Retentar periodicamente resolve isso sem acrescentar uma dependência de
  /// monitoramento de conectividade: a tentativa de conexão é, ela mesma, o
  /// teste de que a rede voltou. O botão de atualizar continua existindo para
  /// quem não quiser esperar o próximo ciclo.
  final Duration retryInterval;

  Timer? _retryTimer;

  final _relays = <String, Relay>{};
  final _connections = <String, RelayConnection>{};

  /// Tentativa de conexão vigente por url. Uma tentativa que termina depois de
  /// o relay ser removido — ou de outra tentativa começar — encontra outro
  /// valor aqui e descarta a própria conexão, em vez de deixá-la órfã
  /// entregando eventos de um relay que não está mais na lista.
  final _attempts = <String, Object>{};

  /// Inscrições ativas, por identificador. No protocolo Nostr uma inscrição é
  /// **estado da conexão**: o relay a esquece quando a conexão cai. Por isso
  /// ficam guardadas aqui e são reenviadas a toda conexão que se estabelece —
  /// relay novo ou relay reconectado.
  final _activeRequests = <String, String>{};
  final _subscriptions = <String, StreamSubscription<String>>{};
  final _controller = StreamController<List<Relay>>.broadcast();

  /// Mensagens cruas recebidas de qualquer relay, com a origem.
  ///
  /// Quem consome (o feed de eventos) é que interpreta o JSON do protocolo —
  /// este serviço cuida apenas de transporte e estado de conexão.
  final _messages = StreamController<RelayMessage>.broadcast();

  /// Estado de todos os relays, emitido a cada mudança.
  @override
  Stream<List<Relay>> get relays => _controller.stream;

  /// Mensagens vindas dos relays.
  @override
  Stream<RelayMessage> get messages => _messages.stream;

  /// Estado corrente, na ordem em que os relays foram adicionados.
  @override
  List<Relay> get current => List.unmodifiable(_relays.values);

  /// Verdadeiro se ao menos um relay está conectado — condição para publicar
  /// (US3 cenário 5).
  @override
  bool get hasAnyConnected =>
      _relays.values.any((r) => r.status == RelayStatus.connected);

  /// Urls dos relays conectados neste instante. É o conjunto sobre o qual a
  /// publicação reporta aceitação ou recusa (FR-007).
  @override
  List<String> get connectedUrls => [
    for (final r in _relays.values)
      if (r.status == RelayStatus.connected) r.url,
  ];

  /// Coloca todos os relays em `connecting` e tenta conectar em paralelo.
  ///
  /// Não lança: falha de relay é estado, não exceção.
  @override
  Future<void> start(List<Relay> initial) async {
    _relays
      ..clear()
      ..addEntries(
        initial.map(
          (r) => MapEntry(
            r.url,
            r.copyWith(status: RelayStatus.connecting, clearError: true),
          ),
        ),
      );
    _emit();
    await Future.wait(_relays.keys.map(_connect));
  }

  /// Acrescenta um relay e tenta conectar.
  @override
  Future<void> add(Relay relay) async {
    if (_relays.containsKey(relay.url)) return;
    _relays[relay.url] = relay.copyWith(
      status: RelayStatus.connecting,
      clearError: true,
    );
    _emit();
    await _connect(relay.url);
  }

  /// Encerra a conexão e retira o relay da lista (FR-011, US5 cenário 3).
  @override
  Future<void> remove(String url) async {
    _attempts.remove(url);
    _disconnect(url);
    _relays.remove(url);
    _emit();
  }

  /// Retenta apenas os relays em `unavailable` — usado no retorno de rede
  /// (FR-014).
  @override
  Future<void> retryUnavailable() async {
    final alvos = _relays.values
        .where((r) => r.status == RelayStatus.unavailable)
        .map((r) => r.url)
        .toList();
    for (final url in alvos) {
      _relays[url] = _relays[url]!.copyWith(
        status: RelayStatus.connecting,
        clearError: true,
      );
    }
    if (alvos.isEmpty) return;
    _emit();
    await Future.wait(alvos.map(_connect));
  }

  /// Registra uma inscrição e a envia aos relays já conectados.
  ///
  /// A inscrição passa a ser reenviada automaticamente a toda conexão que se
  /// estabelecer depois — relay acrescentado ou reconectado após queda de rede.
  /// Sem isso, o relay ficaria "conectado" e surdo: a interface diria que está
  /// tudo bem enquanto nenhum evento chega. Registrar de novo o mesmo
  /// [subscriptionId] não reenvia.
  @override
  void subscribe(String subscriptionId, String request) {
    final nova = !_activeRequests.containsKey(subscriptionId);
    _activeRequests[subscriptionId] = request;
    if (!nova) return;
    for (final url in connectedUrls) {
      _connections[url]?.send(request);
    }
  }

  /// Envia uma mensagem a todos os relays conectados, devolvendo as urls
  /// alcançadas.
  @override
  List<String> broadcast(String message) {
    final alcancados = <String>[];
    for (final entry in _connections.entries) {
      if (_relays[entry.key]?.status != RelayStatus.connected) continue;
      entry.value.send(message);
      alcancados.add(entry.key);
    }
    return alcancados;
  }

  /// Liga o ciclo de retentativas automáticas exigido por FR-014. Idempotente.
  ///
  /// Fica separado de [start] de propósito: um `Timer.periodic` ativo faz o
  /// framework de testes de widget falhar com "pending timer", e testar a
  /// interface não deveria exigir ligar o relógio de reconexão. Quem precisa do
  /// comportamento automático — a aplicação de verdade, em `main.dart`, e os
  /// testes de unidade que o verificam — chama este método explicitamente.
  @override
  void enableAutoRetry() {
    if (_disposed) return;
    _retryTimer ??= Timer.periodic(retryInterval, (_) {
      if (_relays.values.any((r) => r.status == RelayStatus.unavailable)) {
        retryUnavailable();
      }
    });
  }

  Future<void> _connect(String url) async {
    final tentativa = Object();
    _attempts[url] = tentativa;
    bool vigente() => identical(_attempts[url], tentativa) && !_disposed;

    try {
      final conexao = await transport.connect(url, timeout: connectTimeout);
      if (!vigente()) {
        unawaited(conexao.close().catchError((Object _) {}));
        return;
      }
      _disconnect(url);
      _connections[url] = conexao;

      final vivo = Completer<void>();
      _subscriptions[url] = conexao.messages.listen(
        (mensagem) {
          if (!vivo.isCompleted) vivo.complete();
          _messages.add(RelayMessage(url: url, payload: mensagem));
        },
        onError: (Object erro) => _markUnavailable(url, _resumir(erro)),
        onDone: () => _markUnavailable(url, 'conexão encerrada pelo relay'),
      );

      // Sonda de vivacidade: um relay pode aceitar a conexão TCP e nunca
      // responder. Filtra por um id inexistente de propósito — não depende de
      // kind nem de tag, portanto não é afetada por emendas no contrato de
      // eventos.
      conexao.send(
        jsonEncode([
          'REQ',
          _probeId,
          {
            'ids': [_idInexistente],
          },
        ]),
      );

      await vivo.future.timeout(livenessTimeout);
      if (!vigente()) return;
      _markConnected(url);
    } on TimeoutException {
      if (!vigente()) return;
      _markUnavailable(url, 'sem resposta do relay');
    } on Object catch (erro) {
      if (!vigente()) return;
      _markUnavailable(url, _resumir(erro));
    }
  }

  /// Desfaz a conexão com [url].
  ///
  /// O fechamento do socket é disparado sem `await` de propósito: assim que a
  /// conexão sai de `_connections` e sua assinatura é cancelada, ela não
  /// influencia mais o estado do serviço, e esperar a desmontagem do transporte
  /// só acoplaria o fluxo de controle a ela — o que trava sob o relógio falso
  /// dos testes de widget. Falha ao fechar uma conexão já morta é ignorada.
  void _disconnect(String url) {
    unawaited(_subscriptions.remove(url)?.cancel() ?? Future<void>.value());
    final conexao = _connections.remove(url);
    if (conexao == null) return;
    unawaited(conexao.close().catchError((Object _) {}));
  }

  void _markConnected(String url) {
    final relay = _relays[url];
    if (relay == null) return;
    _relays[url] = relay.copyWith(
      status: RelayStatus.connected,
      clearError: true,
    );

    // Reinscreve nesta conexão. Roda uma vez por conexão estabelecida, então
    // não duplica: a conexão anterior, se houve, já morreu.
    final conexao = _connections[url];
    if (conexao != null) {
      for (final request in _activeRequests.values) {
        conexao.send(request);
      }
    }
    _emit();
  }

  void _markUnavailable(String url, String motivo) {
    final relay = _relays[url];
    if (relay == null) return;
    // Desfaz a conexão morta (ou meio morta: um erro pode não fechar o
    // stream). Sem isto, uma mensagem que ainda chegasse pela assinatura
    // antiga seria tratada como legítima, com o relay já dado como fora do
    // ar — inclusive quando quem chama já tinha desconectado, então a
    // idempotência de _disconnect é o que importa aqui.
    _disconnect(url);
    if (relay.status == RelayStatus.unavailable && relay.lastError == motivo) {
      return;
    }
    _relays[url] = relay.copyWith(
      status: RelayStatus.unavailable,
      lastError: motivo,
    );
    _emit();
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(current);
  }

  /// Traduz a falha técnica em motivo compreensível para exibição.
  ///
  /// FR-015 proíbe erro técnico cru na interface. Mensagens como
  /// `SocketException: Failed host lookup (OS Error: ..., errno = 7)` não
  /// dizem nada ao passageiro, então são classificadas aqui — o texto original
  /// não chega à tela.
  static String _resumir(Object erro) {
    final texto = erro.toString().toLowerCase();

    if (texto.contains('failed host lookup') ||
        texto.contains('no address associated')) {
      return 'endereço não encontrado — verifique a conexão do aparelho';
    }
    if (texto.contains('connection refused')) {
      return 'conexão recusada pelo relay';
    }
    if (texto.contains('connection reset') ||
        texto.contains('conexão perdida') ||
        texto.contains('broken pipe')) {
      return 'conexão interrompida';
    }
    if (texto.contains('timed out') || texto.contains('timeout')) {
      return 'sem resposta do relay';
    }
    if (texto.contains('network is unreachable') ||
        texto.contains('unreachable')) {
      return 'rede indisponível';
    }
    if (texto.contains('handshake') || texto.contains('certificate')) {
      return 'falha na conexão segura com o relay';
    }
    return 'não foi possível conectar';
  }

  static const _probeId = 'liveness';
  static const _idInexistente =
      '0000000000000000000000000000000000000000000000000000000000000000';

  var _disposed = false;

  /// Encerra todas as conexões, cancela o ciclo de retentativas e para de
  /// emitir estado. Idempotente: chamar duas vezes não é erro, o que permite
  /// descartar o serviço no corpo do teste e de novo no `tearDown`.
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    for (final url in _connections.keys.toList()) {
      _disconnect(url);
    }
    await _controller.close();
    await _messages.close();
  }
}

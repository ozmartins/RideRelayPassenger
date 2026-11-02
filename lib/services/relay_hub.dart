import 'package:passenger/domain/relay.dart';

/// Uma mensagem crua recebida de um relay específico.
class RelayMessage {
  const RelayMessage({required this.url, required this.payload});

  /// Relay de origem — necessário para reportar aceitação de publicação por
  /// relay (FR-007).
  final String url;

  /// JSON do protocolo, ainda não interpretado.
  final String payload;
}

/// A conexão com os relays, vista pela interface (feature 026).
///
/// Duas implementações reais: `RelayService`, que mantém os sockets no próprio
/// isolate (testes e o serviço em segundo plano), e `RemoteRelayHub`, que fala
/// por mensagens com o `RelayService` que vive no serviço em primeiro plano do
/// Android (produção). Telas e [EventFeed] dependem só deste contrato.
abstract interface class RelayHub {
  /// Estado de todos os relays, emitido a cada mudança.
  Stream<List<Relay>> get relays;

  /// Mensagens cruas vindas dos relays.
  Stream<RelayMessage> get messages;

  /// Estado corrente, na ordem em que os relays foram adicionados.
  List<Relay> get current;

  /// Verdadeiro se ao menos um relay está conectado.
  bool get hasAnyConnected;

  /// Urls dos relays conectados neste instante.
  List<String> get connectedUrls;

  Future<void> start(List<Relay> initial);

  Future<void> add(Relay relay);

  Future<void> remove(String url);

  Future<void> retryUnavailable();

  /// Registra uma inscrição, reenviada a toda conexão estabelecida.
  void subscribe(String subscriptionId, String request);

  /// Envia [message] aos relays conectados, devolvendo as urls alcançadas.
  List<String> broadcast(String message);

  void enableAutoRetry();

  Future<void> dispose();
}

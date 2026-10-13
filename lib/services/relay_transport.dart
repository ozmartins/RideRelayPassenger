/// Contrato de transporte de um relay: uma conexão, mensagens de texto em
/// ambos os sentidos.
///
/// Abstrai o WebSocket para que [RelayService] e o feed de eventos sejam
/// testáveis com dublês em memória. O Princípio II da constituição proíbe que
/// o teste de assinatura, verificação e descarte dependa de relay real, e a
/// decisão D5 registra que nenhum teste automatizado contata relay público.
abstract interface class RelayTransport {
  /// Abre a conexão com [url]. Lança se não for possível conectar dentro de
  /// [timeout] — é o que produz a transição para `unavailable`.
  Future<RelayConnection> connect(String url, {Duration timeout});
}

/// Uma conexão aberta com um relay.
abstract interface class RelayConnection {
  /// Mensagens vindas do relay, como texto cru (JSON do protocolo).
  Stream<String> get messages;

  /// Envia uma mensagem de texto ao relay.
  void send(String message);

  /// Encerra a conexão.
  Future<void> close();
}

import 'dart:async';
import 'dart:io';

import 'package:passenger/services/relay_transport.dart';

/// Transporte real: WebSocket do `dart:io`.
///
/// É a única implementação que toca rede. Os testes usam dublês do contrato
/// [RelayTransport], nunca esta classe (decisão D5).
class WsRelayTransport implements RelayTransport {
  const WsRelayTransport({this.pingInterval = const Duration(seconds: 30)});

  /// Intervalo de ping do WebSocket.
  ///
  /// Uma conexão pode morrer sem erro nem fechamento: depois de uma troca de
  /// Wi-Fi para dados móveis o TCP fica meio aberto, e o socket não percebe por
  /// minutos. Com ping ligado, o `dart:io` fecha a conexão quando o pong não
  /// chega dentro do intervalo; o fechamento vira `onDone` no `RelayService`,
  /// que marca o relay como indisponível e o devolve ao ciclo de retentativas.
  final Duration pingInterval;

  @override
  Future<RelayConnection> connect(String url, {Duration? timeout}) async {
    // `.timeout()` só desiste de esperar; não cancela WebSocket.connect(), que
    // continua tentando em segundo plano. Se o handshake terminar depois do
    // timeout — quando RelayService já tratou como falha e seguiu adiante —,
    // ninguém mais tem referência ao socket para fechá-lo. Por isso o próprio
    // future original é observado à parte, e um socket que chega atrasado é
    // fechado assim que aparece.
    var expirado = false;
    final conexao = WebSocket.connect(url);
    unawaited(
      conexao.then((socket) {
        if (expirado) unawaited(socket.close());
      }, onError: (Object _) {}),
    );

    try {
      final socket = await conexao.timeout(
        timeout ?? const Duration(seconds: 10),
      );
      socket.pingInterval = pingInterval;
      return _WsConnection(socket);
    } on TimeoutException {
      expirado = true;
      rethrow;
    }
  }
}

class _WsConnection implements RelayConnection {
  _WsConnection(this._socket)
    : messages = _socket
          .where((dado) => dado is String)
          .cast<String>()
          .asBroadcastStream();

  final WebSocket _socket;

  @override
  final Stream<String> messages;

  @override
  void send(String message) => _socket.add(message);

  @override
  Future<void> close() => _socket.close();
}

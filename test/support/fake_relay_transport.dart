import 'dart:async';
import 'dart:convert';

import 'package:passenger/services/relay_transport.dart';

/// Comportamento programável de um relay falso.
enum FakeBehavior {
  /// Conecta e responde à sonda de vivacidade.
  healthy,

  /// Recusa a conexão.
  refuseConnection,

  /// Conecta, mas nunca responde — o edge case do relay mudo.
  silent,

  /// Conecta e responde, mas depois a conexão cai.
  dropsAfterConnect,
}

class FakeConnection implements RelayConnection {
  FakeConnection(this.url, this.behavior);

  final String url;
  final FakeBehavior behavior;
  final _controller = StreamController<String>.broadcast();
  final enviadas = <String>[];
  var fechada = false;

  @override
  Stream<String> get messages => _controller.stream;

  /// Se falso, o relay recusa as publicações — como um que exige pagamento.
  var aceitaPublicacao = true;

  /// Se falso, o relay nunca confirma a publicação.
  var confirmaPublicacao = true;

  @override
  void send(String message) {
    enviadas.add(message);
    if (behavior == FakeBehavior.silent) return;

    final decodificada = jsonDecode(message) as List;
    final tipo = decodificada.first;

    scheduleMicrotask(() {
      if (_controller.isClosed) return;

      if (tipo == 'EVENT') {
        if (!confirmaPublicacao) return;
        final evento = decodificada[1] as Map<String, dynamic>;
        _controller.add(
          jsonEncode([
            'OK',
            evento['id'],
            aceitaPublicacao,
            aceitaPublicacao ? '' : 'blocked: pagamento exigido',
          ]),
        );
        return;
      }

      // REQ: responde com EOSE, como um relay real faria.
      _controller.add('["EOSE","${_subIdDe(message)}"]');
      if (behavior == FakeBehavior.dropsAfterConnect) {
        _controller.addError('conexão perdida');
      }
    });
  }

  static String _subIdDe(String req) {
    final partes = req.split('"');
    return partes.length > 3 ? partes[3] : 'sonda';
  }

  void derrubar() => _controller.addError('conexão perdida');

  /// Simula o relay enviando [mensagem] para o aplicativo.
  void emitir(String mensagem) {
    if (!_controller.isClosed) _controller.add(mensagem);
  }

  @override
  Future<void> close() async {
    fechada = true;
    await _controller.close();
  }
}

class FakeTransport implements RelayTransport {
  FakeTransport(this.comportamentos);

  /// url → comportamento. Ausente significa [FakeBehavior.healthy].
  final Map<String, FakeBehavior> comportamentos;
  final conexoes = <String, FakeConnection>{};
  var tentativas = 0;

  /// url → portão. Enquanto o portão não é liberado, a conexão com a url fica
  /// em handshake — permite agir sobre o relay durante `connecting`.
  final portoes = <String, Completer<void>>{};

  @override
  Future<RelayConnection> connect(String url, {Duration? timeout}) async {
    tentativas++;
    await portoes[url]?.future;
    final comportamento = comportamentos[url] ?? FakeBehavior.healthy;
    if (comportamento == FakeBehavior.refuseConnection) {
      throw Exception('host inalcançável');
    }
    final conexao = FakeConnection(url, comportamento);
    conexoes[url] = conexao;
    return conexao;
  }
}

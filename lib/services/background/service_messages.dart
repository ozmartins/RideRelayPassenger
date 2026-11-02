import 'package:passenger/domain/relay.dart';
import 'package:passenger/domain/service_state.dart';

/// Mensagens entre a interface e o serviço em segundo plano — contrato interno
/// em `specs/026-conexao-em-segundo-plano/contracts/service-channel.md`.
///
/// Cada mensagem vira um `Map<String, dynamic>` só de tipos primitivos (é o que
/// o canal entre isolates aceita), com o tipo em `t` e a versão em `v`.
/// **Nenhuma mensagem carrega chave privada, semente ou texto decifrado**
/// (Princípio I): quem assina e cifra é a interface, e o serviço só repassa o
/// texto pronto do relay.
sealed class ServiceMessage {
  const ServiceMessage();

  static const int version = 1;

  /// Tipo da mensagem, o valor do campo `t`.
  String get type;

  Map<String, dynamic> toMap() => {'t': type, 'v': version, ...body()};

  /// Campos próprios de cada mensagem.
  Map<String, dynamic> body();

  /// Lê uma mensagem recebida do canal. Devolve `null` — nunca lança — para
  /// dado que não é mapa, de outra versão, de tipo desconhecido ou
  /// malformado: o que chega pelo canal é entrada, não instrução.
  static ServiceMessage? fromMap(Object? raw) {
    if (raw is! Map || raw['v'] != version) return null;
    final map = Map<String, dynamic>.from(raw);
    try {
      return switch (map['t']) {
        'ready' => const ServiceReady(),
        'hello' => ServiceHello(foreground: map['foreground'] as bool),
        'helloAck' => ServiceHelloAck(
          relays: _relays(map['relays']),
          pending: _pending(map['pending']),
        ),
        'state' => ServiceStateUpdate(
          ServiceState.fromJson(Map<String, dynamic>.from(map['state'] as Map)),
        ),
        'start' => ServiceStart(_relays(map['relays'])),
        'addRelay' => ServiceAddRelay(_relays([map['relay']]).single),
        'removeRelay' => ServiceRemoveRelay(map['url'] as String),
        'retryUnavailable' => const ServiceRetryUnavailable(),
        'subscribe' => ServiceSubscribe(
          subscriptionId: map['subscriptionId'] as String,
          request: map['request'] as String,
        ),
        'broadcast' => ServiceBroadcast(map['message'] as String),
        'relaysChanged' => ServiceRelaysChanged(_relays(map['relays'])),
        'message' => ServiceRelayMessage(
          relayUrl: map['relayUrl'] as String,
          payload: map['payload'] as String,
        ),
        'stop' => const ServiceStop(),
        _ => null,
      };
    } on Object {
      return null;
    }
  }

  static List<Relay> _relays(Object? raw) => ((raw as List?) ?? const [])
      .map(
        (r) => Relay(
          url: (r as Map)['url'] as String,
          status: r['status'] == null
              ? RelayStatus.connecting
              : RelayStatus.values.byName(r['status'] as String),
          lastError: r['error'] as String?,
          isDefault: r['isDefault'] == true,
        ),
      )
      .toList();

  static List<PendingRelayMessage> _pending(Object? raw) =>
      ((raw as List?) ?? const [])
          .map(
            (p) => PendingRelayMessage(
              relayUrl: (p as Map)['relayUrl'] as String,
              payload: p['payload'] as String,
            ),
          )
          .toList();

  static List<Map<String, dynamic>> relaysToMaps(List<Relay> relays) => [
    for (final r in relays)
      {
        'url': r.url,
        'status': r.status.name,
        'error': r.lastError,
        'isDefault': r.isDefault,
      },
  ];
}

/// Uma mensagem de relay guardada pelo serviço enquanto a interface não
/// estava à vista, para reentrega.
class PendingRelayMessage {
  const PendingRelayMessage({required this.relayUrl, required this.payload});
  final String relayUrl;

  /// Texto cru do protocolo (`["EVENT", ...]`).
  final String payload;
}

/// S→UI: o isolate do serviço está de pé; até recebê-la a interface enfileira
/// os comandos.
class ServiceReady extends ServiceMessage {
  const ServiceReady();
  @override
  String get type => 'ready';
  @override
  Map<String, dynamic> body() => {};
}

/// UI→S: handshake ao abrir o app ou voltar ao primeiro plano.
class ServiceHello extends ServiceMessage {
  const ServiceHello({required this.foreground});
  final bool foreground;
  @override
  String get type => 'hello';
  @override
  Map<String, dynamic> body() => {'foreground': foreground};
}

/// S→UI: resposta ao `hello`, com o estado dos relays e as mensagens guardadas
/// (no máximo 5 minutos) enquanto a interface não estava à vista.
class ServiceHelloAck extends ServiceMessage {
  const ServiceHelloAck({required this.relays, required this.pending});
  final List<Relay> relays;
  final List<PendingRelayMessage> pending;
  @override
  String get type => 'helloAck';
  @override
  Map<String, dynamic> body() => {
    'relays': ServiceMessage.relaysToMaps(relays),
    'pending': [
      for (final p in pending) {'relayUrl': p.relayUrl, 'payload': p.payload},
    ],
  };
}

/// UI→S: o estado de que o serviço depende.
class ServiceStateUpdate extends ServiceMessage {
  const ServiceStateUpdate(this.state);
  final ServiceState state;
  @override
  String get type => 'state';
  @override
  Map<String, dynamic> body() => {'state': state.toJson()};
}

/// UI→S: a lista de relays que a interface carregou; o serviço a concilia
/// com a que já tem.
class ServiceStart extends ServiceMessage {
  const ServiceStart(this.relays);
  final List<Relay> relays;
  @override
  String get type => 'start';
  @override
  Map<String, dynamic> body() => {
    'relays': ServiceMessage.relaysToMaps(relays),
  };
}

class ServiceAddRelay extends ServiceMessage {
  const ServiceAddRelay(this.relay);
  final Relay relay;
  @override
  String get type => 'addRelay';
  @override
  Map<String, dynamic> body() => {
    'relay': ServiceMessage.relaysToMaps([relay]).single,
  };
}

class ServiceRemoveRelay extends ServiceMessage {
  const ServiceRemoveRelay(this.url);
  final String url;
  @override
  String get type => 'removeRelay';
  @override
  Map<String, dynamic> body() => {'url': url};
}

class ServiceRetryUnavailable extends ServiceMessage {
  const ServiceRetryUnavailable();
  @override
  String get type => 'retryUnavailable';
  @override
  Map<String, dynamic> body() => {};
}

/// UI→S: registra a inscrição (o serviço a reenvia a toda conexão).
class ServiceSubscribe extends ServiceMessage {
  const ServiceSubscribe({required this.subscriptionId, required this.request});
  final String subscriptionId;
  final String request;
  @override
  String get type => 'subscribe';
  @override
  Map<String, dynamic> body() => {
    'subscriptionId': subscriptionId,
    'request': request,
  };
}

/// UI→S: texto de um `["EVENT", ...]` já assinado (e cifrado) pela interface.
class ServiceBroadcast extends ServiceMessage {
  const ServiceBroadcast(this.message);
  final String message;
  @override
  String get type => 'broadcast';
  @override
  Map<String, dynamic> body() => {'message': message};
}

/// S→UI: espelho da lista de relays.
class ServiceRelaysChanged extends ServiceMessage {
  const ServiceRelaysChanged(this.relays);
  final List<Relay> relays;
  @override
  String get type => 'relaysChanged';
  @override
  Map<String, dynamic> body() => {
    'relays': ServiceMessage.relaysToMaps(relays),
  };
}

/// S→UI: mensagem crua do relay. `EVENT` só depois de assinatura, marcador e
/// deduplicação.
class ServiceRelayMessage extends ServiceMessage {
  const ServiceRelayMessage({required this.relayUrl, required this.payload});
  final String relayUrl;
  final String payload;
  @override
  String get type => 'message';
  @override
  Map<String, dynamic> body() => {'relayUrl': relayUrl, 'payload': payload};
}

class ServiceStop extends ServiceMessage {
  const ServiceStop();
  @override
  String get type => 'stop';
  @override
  Map<String, dynamic> body() => {};
}

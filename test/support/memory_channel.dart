import 'dart:async';

import 'package:passenger/services/background/message_channel.dart';
import 'package:passenger/services/background/service_messages.dart';

/// Um par de pontas de [MessageChannel] ligadas em memória: o que uma envia, a
/// outra recebe (já passando por `toMap`/`fromMap`, como no canal real, para o
/// teste enxergar o que de fato atravessaria entre isolates).
class MemoryChannelPair {
  MemoryChannelPair() {
    ui = _MemoryEnd(this, true);
    service = _MemoryEnd(this, false);
  }

  late final MessageChannel ui;
  late final MessageChannel service;

  /// Tudo que atravessou o canal, nos dois sentidos, em forma de mapa.
  final List<Map<String, dynamic>> traffic = [];
}

class _MemoryEnd implements MessageChannel {
  _MemoryEnd(this._pair, this._isUi);

  final MemoryChannelPair _pair;
  final bool _isUi;
  final StreamController<ServiceMessage> _incoming =
      StreamController<ServiceMessage>.broadcast();

  _MemoryEnd get _other => (_isUi ? _pair.service : _pair.ui) as _MemoryEnd;

  @override
  Stream<ServiceMessage> get incoming => _incoming.stream;

  @override
  void send(ServiceMessage message) {
    final mapa = message.toMap();
    _pair.traffic.add(mapa);
    final recebida = ServiceMessage.fromMap(mapa);
    if (recebida != null && !_other._incoming.isClosed) {
      _other._incoming.add(recebida);
    }
  }

  @override
  Future<void> close() => _incoming.close();
}

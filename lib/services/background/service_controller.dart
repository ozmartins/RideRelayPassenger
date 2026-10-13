import 'dart:async';

import 'package:passenger/domain/service_state.dart';
import 'package:passenger/services/background/background_service.dart';
import 'package:passenger/services/background/service_messages.dart';
import 'package:passenger/services/remote_relay_hub.dart';

/// Decide quando o serviço em segundo plano roda e o que ele sabe do app
/// (feature 026, FR-001, FR-009, FR-011, FR-012).
///
/// O serviço roda enquanto o app está em primeiro plano **ou** há solicitação
/// ou corrida ativa — e, com o app fechado, só se o aparelho deixa mostrar
/// notificação: sem ela não haveria como avisar, e manter a conexão seria só
/// gasto de bateria.
class ServiceController {
  ServiceController({required this.service, required this.hub}) {
    _attachedSubscription = hub.attached.listen((_) {
      // O serviço (re)apareceu: devolve a ele o que a interface decidiu.
      _sendState();
    });
  }

  final BackgroundService service;
  final RemoteRelayHub hub;
  late final StreamSubscription<void> _attachedSubscription;

  ServiceState _state = const ServiceState(appInForeground: true);
  bool _foreground = true;

  /// Só depois da primeira informação da tela o controlador manda estado: antes
  /// disso o padrão (sem corrida) apagaria o que o serviço guardou.
  bool _reported = false;
  bool _canNotify = true;
  bool _disposed = false;

  static const String textRide = 'Acompanhando sua corrida';
  static const String textConnected = 'Conectado aos relays';

  /// A regra de FR-001: em primeiro plano, ou com corrida ativa e capaz de
  /// avisar.
  static bool shouldRun({
    required bool foreground,
    required bool hasActiveRide,
    required bool canNotify,
  }) => foreground || (hasActiveRide && canNotify);

  /// Inicia o serviço (se não estiver rodando) e se apresenta a ele.
  Future<void> start() async {
    _canNotify = await service.hasNotificationPermission();
    await service.start(text: _text);
    hub.attach(foreground: _foreground);
  }

  /// A tela informa o estado de que o serviço depende. Chamada à vontade: só
  /// age se algo mudou.
  void update(ServiceState state) {
    if (_disposed) return;
    final novo = state.copyWith(appInForeground: _foreground);
    if (_reported && novo == _state) return;
    _reported = true;
    _state = novo;
    _sendState();
    unawaited(service.updateText(_text));
    _reconsider();
  }

  /// O app foi para segundo plano ou voltou à tela.
  Future<void> onForeground(bool foreground) async {
    if (_disposed || foreground == _foreground) return;
    _foreground = foreground;
    _state = _state.copyWith(appInForeground: foreground);
    if (foreground) {
      _canNotify = await service.hasNotificationPermission();
      if (!await service.isRunning) await service.start(text: _text);
      hub.attach(foreground: true);
      return;
    }
    // Avisa o serviço de que não há mais interface visível, para ele passar a
    // notificar, e só então decide se continua.
    hub.attach(foreground: false);
    _sendState();
    _reconsider();
  }

  /// Pede a permissão de notificação (Android 13+) se ainda não foi dada.
  /// Devolve se o app pode notificar.
  Future<bool> ensureNotificationPermission() async {
    var concedida = await service.hasNotificationPermission();
    if (!concedida) concedida = await service.requestNotificationPermission();
    _canNotify = concedida;
    _reconsider();
    return concedida;
  }

  /// A interface está sendo destruída.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _attachedSubscription.cancel();
  }

  String get _text => _state.hasActiveRide ? textRide : textConnected;

  void _sendState() {
    if (!_reported || _disposed) return;
    hub.sendToService(ServiceStateUpdate(_state));
  }

  void _reconsider() {
    if (_disposed) return;
    final deve = shouldRun(
      foreground: _foreground,
      hasActiveRide: _state.hasActiveRide,
      canNotify: _canNotify,
    );
    if (!deve) {
      hub.detach();
      unawaited(service.stop());
    }
  }
}

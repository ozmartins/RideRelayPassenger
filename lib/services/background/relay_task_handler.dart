import 'dart:async';
import 'dart:ui';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:passenger/services/background/foreground_task_channels.dart';
import 'package:passenger/services/background/relay_host_core.dart';
import 'package:passenger/services/background/service_state_store.dart';
import 'package:passenger/services/local_ride_message_notifier.dart';
import 'package:passenger/services/prefs_key_value_store.dart';
import 'package:passenger/services/relay_repository.dart';
import 'package:passenger/services/relay_service.dart';
import 'package:passenger/services/ws_relay_transport.dart';

/// Ponto de entrada do isolate do serviço em segundo plano (feature 026).
/// Precisa ser uma função de nível superior e ficar visível ao AOT.
@pragma('vm:entry-point')
void relayServiceCallback() {
  FlutterForegroundTask.setTaskHandler(RelayTaskHandler());
}

/// O `TaskHandler` que monta o [RelayHostCore] com as dependências reais.
/// Fina de propósito: a lógica está no núcleo, testado sem o plugin.
///
/// Nada aqui toca a identidade nem o armazenamento protegido (Princípio I): só
/// transporte de relay, `shared_preferences` e a notificação local.
class RelayTaskHandler extends TaskHandler {
  final ServiceSideChannel _channel = ServiceSideChannel();
  RelayHostCore? _core;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Plugins com implementação em Dart (shared_preferences) precisam ser
    // registrados no isolate do serviço.
    DartPluginRegistrant.ensureInitialized();

    const store = FreshPrefsKeyValueStore();
    _core = RelayHostCore(
      relays: RelayService(transport: const WsRelayTransport()),
      channel: _channel,
      stateStore: ServiceStateStore(store),
      relayRepository: RelayRepository(store),
      notifier: LocalRideMessageNotifier(),
      onStopRequested: () async {
        await FlutterForegroundTask.stopService();
      },
    );
    // Iniciado pelo app: o estado guardado de uma execução anterior não vale
    // (a interface o refaz). Reiniciado pelo sistema (sem a interface): vale,
    // é tudo que há.
    await _core!.start(restoreState: starter != TaskStarter.developer);
  }

  @override
  void onReceiveData(Object data) => _channel.deliver(data);

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _core?.dispose();
  }
}

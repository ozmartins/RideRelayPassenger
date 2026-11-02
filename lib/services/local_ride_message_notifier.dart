import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:passenger/domain/background_notification_rule.dart';
import 'package:passenger/services/ride_message_notifier.dart';

/// Notificação local sobre `flutter_local_notifications` (decisão D2 de
/// `specs/026-conexao-em-segundo-plano/research.md`). Roda no isolate do
/// serviço, sem passar por nenhum servidor de push.
///
/// Único arquivo, junto do serviço em primeiro plano, que conhece o plugin
/// (Princípio III).
class LocalRideMessageNotifier implements RideMessageNotifier {
  LocalRideMessageNotifier({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initialized;

  /// Importância alta (aviso na tela e som). A notificação fixa do serviço fica
  /// em outro canal, de importância baixa.
  static const AndroidNotificationDetails _details = AndroidNotificationDetails(
    'ride_messages',
    'Mensagens do motorista',
    channelDescription: 'Avisa quando o motorista envia algo sobre a corrida.',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> _ensureInitialized() => _initialized ??= _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  @override
  Future<void> notify(
    BackgroundNotification notification,
    String eventId,
  ) async {
    await _ensureInitialized();
    final conteudo = RideMessageNotificationContent.of(notification, eventId);
    await _plugin.show(
      id: conteudo.id,
      title: conteudo.title,
      body: conteudo.body,
      notificationDetails: const NotificationDetails(android: _details),
    );
  }

  @override
  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }
}

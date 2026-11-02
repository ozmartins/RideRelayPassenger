import 'package:passenger/domain/background_notification_rule.dart';

/// Avisa o passageiro, fora do app, de que chegou uma mensagem do motorista.
///
/// Abstração do projeto (Princípio III): a implementação real usa
/// `flutter_local_notifications`; os testes usam um dublê. O texto é sempre
/// fixo por tipo — nunca nome, placa, endereço, coordenada nem chave de
/// terceiros (constituição 2.15.0, SC-003).
abstract class RideMessageNotifier {
  /// Mostra o aviso de [notification] para o evento [eventId]. O mesmo id
  /// substitui o aviso anterior em vez de duplicá-lo.
  Future<void> notify(BackgroundNotification notification, String eventId);

  /// Remove os avisos ainda na bandeja (o app voltou à tela).
  Future<void> cancelAll();
}

/// O conteúdo do aviso, sem nada que venha do evento além do id usado só para
/// não duplicar. Vive fora do plugin para poder ser testado.
class RideMessageNotificationContent {
  const RideMessageNotificationContent._(this.id, this.title, this.body);

  /// Identificador numérico do aviso, estável para o mesmo evento e sempre
  /// positivo (o Android o exige como `int` de 32 bits).
  final int id;
  final String title;
  final String body;

  static const String fixedBody = 'Toque para ver';

  factory RideMessageNotificationContent.of(
    BackgroundNotification notification,
    String eventId,
  ) => RideMessageNotificationContent._(
    eventId.hashCode & 0x7fffffff,
    notification.title,
    fixedBody,
  );
}

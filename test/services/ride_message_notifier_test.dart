import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/background_notification_rule.dart';
import 'package:passenger/services/ride_message_notifier.dart';

void main() {
  group('RideMessageNotificationContent (SC-003)', () {
    const eventId =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    test('título fixo por tipo e corpo genérico', () {
      final textos = {
        BackgroundNotification.novoOrcamento: 'Novo orçamento de corrida',
        BackgroundNotification.motoristaChegou: 'Seu motorista chegou',
        BackgroundNotification.chegouAoDestino: 'Você chegou ao destino',
        BackgroundNotification.canceladaPeloMotorista:
            'Corrida cancelada pelo motorista',
        BackgroundNotification.motoristaIndisponivel: 'Motorista indisponível',
      };
      for (final entrada in textos.entries) {
        final c = RideMessageNotificationContent.of(entrada.key, eventId);
        expect(c.title, entrada.value);
        expect(c.body, RideMessageNotificationContent.fixedBody);
      }
    });

    test('nenhum texto contém dado do evento', () {
      for (final tipo in BackgroundNotification.values) {
        final c = RideMessageNotificationContent.of(tipo, eventId);
        expect(c.title.contains(eventId), isFalse);
        expect(c.body.contains(eventId), isFalse);
      }
    });

    test('o id é estável por evento e positivo de 32 bits', () {
      final a = RideMessageNotificationContent.of(
        BackgroundNotification.novoOrcamento,
        eventId,
      );
      final b = RideMessageNotificationContent.of(
        BackgroundNotification.novoOrcamento,
        eventId,
      );
      expect(a.id, b.id);
      expect(a.id, inInclusiveRange(0, 0x7fffffff));
    });
  });
}

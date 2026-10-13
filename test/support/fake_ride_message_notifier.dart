import 'package:passenger/domain/background_notification_rule.dart';
import 'package:passenger/services/ride_message_notifier.dart';

class FakeRideMessageNotifier implements RideMessageNotifier {
  final List<(BackgroundNotification, String)> notified = [];
  int cancelAllCalls = 0;

  @override
  Future<void> notify(BackgroundNotification notification, String eventId) async {
    notified.add((notification, eventId));
  }

  @override
  Future<void> cancelAll() async => cancelAllCalls++;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/background_notification_rule.dart';
import 'package:passenger/domain/passenger_ride_status.dart';
import 'package:passenger/domain/service_state.dart';

final _passageiro = 'a' * 64;
final _motorista = 'b' * 64;
final _outro = 'c' * 64;

Map<String, dynamic> _evento(
  int kind, {
  String? author,
  String? p = 'DEFAULT',
  String? e = 'q1',
  String id = 'evt1',
}) => {
  'id': id,
  'pubkey': author ?? _motorista,
  'kind': kind,
  'content': 'cifrado',
  'tags': [
    ['t', 'tcc-ufsc-caronas'],
    if (p != null) ['p', p == 'DEFAULT' ? _passageiro : p],
    if (e != null) ['e', e],
  ],
};

ServiceState _estado(PassengerRideStatus s) => ServiceState(
  passengerPubkey: _passageiro,
  rideStatus: s,
  requestId: 'r1',
  quoteId: 'q1',
  driverPubkey: _motorista,
);

void main() {
  group('BackgroundNotificationRule.evaluate', () {
    test('20002 em aguardandoOrcamentos referenciando a solicitação ativa', () {
      final r = BackgroundNotificationRule.evaluate(
        _evento(20002, e: 'r1', author: _outro),
        _estado(PassengerRideStatus.aguardandoOrcamentos),
      );
      expect(r, BackgroundNotification.novoOrcamento);
    });

    test('20007 em motoristaACaminho do motorista da corrida', () {
      expect(
        BackgroundNotificationRule.evaluate(
          _evento(20007),
          _estado(PassengerRideStatus.motoristaACaminho),
        ),
        BackgroundNotification.motoristaChegou,
      );
    });

    test('20009 em emCorrida', () {
      expect(
        BackgroundNotificationRule.evaluate(
          _evento(20009),
          _estado(PassengerRideStatus.emCorrida),
        ),
        BackgroundNotification.chegouAoDestino,
      );
    });

    test('20012 nas três fases de corrida aceita', () {
      for (final s in [
        PassengerRideStatus.orcamentoAceito,
        PassengerRideStatus.motoristaACaminho,
        PassengerRideStatus.emCorrida,
      ]) {
        expect(
          BackgroundNotificationRule.evaluate(_evento(20012), _estado(s)),
          BackgroundNotification.canceladaPeloMotorista,
          reason: '$s',
        );
      }
    });

    test('20006 só em orcamentoAceito', () {
      expect(
        BackgroundNotificationRule.evaluate(
          _evento(20006),
          _estado(PassengerRideStatus.orcamentoAceito),
        ),
        BackgroundNotification.motoristaIndisponivel,
      );
      expect(
        BackgroundNotificationRule.evaluate(
          _evento(20006),
          _estado(PassengerRideStatus.motoristaACaminho),
        ),
        isNull,
      );
    });

    test('20005 e 20011 nunca notificam', () {
      for (final kind in [20005, 20011]) {
        for (final s in PassengerRideStatus.values) {
          expect(
            BackgroundNotificationRule.evaluate(_evento(kind), _estado(s)),
            isNull,
            reason: '$kind em $s',
          );
        }
      }
    });

    test('tag p alheia ou ausente: nada', () {
      final estado = _estado(PassengerRideStatus.emCorrida);
      expect(
        BackgroundNotificationRule.evaluate(_evento(20009, p: _outro), estado),
        isNull,
      );
      expect(
        BackgroundNotificationRule.evaluate(_evento(20009, p: null), estado),
        isNull,
      );
    });

    test('autor que não é o motorista da corrida: nada', () {
      expect(
        BackgroundNotificationRule.evaluate(
          _evento(20009, author: _outro),
          _estado(PassengerRideStatus.emCorrida),
        ),
        isNull,
      );
    });

    test('tag e que não é a da corrida ou da solicitação: nada', () {
      expect(
        BackgroundNotificationRule.evaluate(
          _evento(20009, e: 'outro'),
          _estado(PassengerRideStatus.emCorrida),
        ),
        isNull,
      );
      expect(
        BackgroundNotificationRule.evaluate(
          _evento(20002, e: 'outra', author: _outro),
          _estado(PassengerRideStatus.aguardandoOrcamentos),
        ),
        isNull,
      );
      expect(
        BackgroundNotificationRule.evaluate(
          _evento(20009, e: null),
          _estado(PassengerRideStatus.emCorrida),
        ),
        isNull,
      );
    });

    test('estados sem corrida ativa nunca notificam', () {
      for (final s in [
        PassengerRideStatus.inicial,
        PassengerRideStatus.destinoConfirmadoAguardandoAvaliacao,
      ]) {
        for (final kind in BackgroundNotificationRule.notifiableKinds) {
          expect(
            BackgroundNotificationRule.evaluate(_evento(kind), _estado(s)),
            isNull,
            reason: '$kind em $s',
          );
        }
      }
    });

    test('20007 fora de motoristaACaminho: nada (guarda de confirmar encontro)',
        () {
      for (final s in [
        PassengerRideStatus.orcamentoAceito,
        PassengerRideStatus.emCorrida,
      ]) {
        expect(
          BackgroundNotificationRule.evaluate(_evento(20007), _estado(s)),
          isNull,
          reason: '$s',
        );
      }
    });

    test('sem chave pública do passageiro no estado: nada', () {
      expect(
        BackgroundNotificationRule.evaluate(
          _evento(20009),
          const ServiceState(rideStatus: PassengerRideStatus.emCorrida),
        ),
        isNull,
      );
    });

    test('evento malformado não lança', () {
      expect(
        BackgroundNotificationRule.evaluate(
          {'kind': 'x', 'tags': 5},
          _estado(PassengerRideStatus.emCorrida),
        ),
        isNull,
      );
    });
  });

  group('BackgroundNotificationRule.dedupeKey', () {
    test('o 20007 repetido tem a mesma chave por corrida', () {
      final a = BackgroundNotificationRule.dedupeKey(
        BackgroundNotification.motoristaChegou,
        _evento(20007, id: 'x1'),
      );
      final b = BackgroundNotificationRule.dedupeKey(
        BackgroundNotification.motoristaChegou,
        _evento(20007, id: 'x2'),
      );
      expect(a, b);
    });

    test('cada orçamento é uma notícia própria', () {
      final a = BackgroundNotificationRule.dedupeKey(
        BackgroundNotification.novoOrcamento,
        _evento(20002, e: 'r1', id: 'o1'),
      );
      final b = BackgroundNotificationRule.dedupeKey(
        BackgroundNotification.novoOrcamento,
        _evento(20002, e: 'r1', id: 'o2'),
      );
      expect(a, isNot(b));
    });

    test('corridas diferentes têm chaves diferentes', () {
      expect(
        BackgroundNotificationRule.dedupeKey(
          BackgroundNotification.motoristaChegou,
          _evento(20007, e: 'q1'),
        ),
        isNot(
          BackgroundNotificationRule.dedupeKey(
            BackgroundNotification.motoristaChegou,
            _evento(20007, e: 'q2'),
          ),
        ),
      );
    });
  });
}

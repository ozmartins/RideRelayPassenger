import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/passenger_ride_status.dart';

void main() {
  group('PassengerRideRules.canRequestRide (FR-003)', () {
    test('permite solicitar corrida a partir de inicial', () {
      expect(
        PassengerRideRules.canRequestRide(PassengerRideStatus.inicial),
        isTrue,
      );
    });

    test('impede solicitar corrida a partir de aguardandoOrcamentos', () {
      expect(
        PassengerRideRules.canRequestRide(
          PassengerRideStatus.aguardandoOrcamentos,
        ),
        isFalse,
      );
    });

    test('impede solicitar corrida a partir de orcamentoAceito', () {
      expect(
        PassengerRideRules.canRequestRide(PassengerRideStatus.orcamentoAceito),
        isFalse,
      );
    });
  });

  group('PassengerRideRules.canAcceptQuote (FR-004, FR-010)', () {
    test('permite aceitar orçamento a partir de aguardandoOrcamentos', () {
      expect(
        PassengerRideRules.canAcceptQuote(
          PassengerRideStatus.aguardandoOrcamentos,
        ),
        isTrue,
      );
    });

    test('impede aceitar orçamento a partir de inicial', () {
      expect(
        PassengerRideRules.canAcceptQuote(PassengerRideStatus.inicial),
        isFalse,
      );
    });

    test(
      'impede aceitar orçamento a partir de orcamentoAceito '
      '(orçamento tardio, idempotência)',
      () {
        expect(
          PassengerRideRules.canAcceptQuote(
            PassengerRideStatus.orcamentoAceito,
          ),
          isFalse,
        );
      },
    );
  });

  group('PassengerRideRules.canNotifyMovement (FR-005)', () {
    test('permite notificar movimento a partir de orcamentoAceito', () {
      expect(
        PassengerRideRules.canNotifyMovement(
          PassengerRideStatus.orcamentoAceito,
        ),
        isTrue,
      );
    });

    test('impede notificar movimento a partir de aguardandoOrcamentos', () {
      expect(
        PassengerRideRules.canNotifyMovement(
          PassengerRideStatus.aguardandoOrcamentos,
        ),
        isFalse,
      );
    });

    test(
      'impede notificar movimento a partir de motoristaACaminho '
      '(idempotência)',
      () {
        expect(
          PassengerRideRules.canNotifyMovement(
            PassengerRideStatus.motoristaACaminho,
          ),
          isFalse,
        );
      },
    );
  });

  group('PassengerRideRules.canConfirmMeeting (FR-006, FR-010)', () {
    test('permite confirmar encontro a partir de motoristaACaminho', () {
      expect(
        PassengerRideRules.canConfirmMeeting(
          PassengerRideStatus.motoristaACaminho,
        ),
        isTrue,
      );
    });

    test('impede confirmar encontro a partir de orcamentoAceito', () {
      expect(
        PassengerRideRules.canConfirmMeeting(
          PassengerRideStatus.orcamentoAceito,
        ),
        isFalse,
      );
    });

    test('impede confirmar encontro a partir de emCorrida', () {
      expect(
        PassengerRideRules.canConfirmMeeting(
          PassengerRideStatus.emCorrida,
        ),
        isFalse,
      );
    });
  });

  group('PassengerRideRules.canConfirmDestinationArrival (FR-007, FR-010)', () {
    test('permite confirmar destino a partir de emCorrida', () {
      expect(
        PassengerRideRules.canConfirmDestinationArrival(
          PassengerRideStatus.emCorrida,
        ),
        isTrue,
      );
    });

    test('impede confirmar destino a partir de motoristaACaminho', () {
      expect(
        PassengerRideRules.canConfirmDestinationArrival(
          PassengerRideStatus.motoristaACaminho,
        ),
        isFalse,
      );
    });

    test(
      'impede confirmar destino a partir de '
      'destinoConfirmadoAguardandoAvaliacao',
      () {
        expect(
          PassengerRideRules.canConfirmDestinationArrival(
            PassengerRideStatus.destinoConfirmadoAguardandoAvaliacao,
          ),
          isFalse,
        );
      },
    );
  });

  group('PassengerRideRules.canFinishRating (FR-008)', () {
    test(
      'permite concluir avaliação a partir de '
      'destinoConfirmadoAguardandoAvaliacao',
      () {
        expect(
          PassengerRideRules.canFinishRating(
            PassengerRideStatus.destinoConfirmadoAguardandoAvaliacao,
          ),
          isTrue,
        );
      },
    );

    test('impede concluir avaliação a partir de emCorrida', () {
      expect(
        PassengerRideRules.canFinishRating(
          PassengerRideStatus.emCorrida,
        ),
        isFalse,
      );
    });

    test('impede concluir avaliação a partir de inicial', () {
      expect(
        PassengerRideRules.canFinishRating(PassengerRideStatus.inicial),
        isFalse,
      );
    });
  });

  group('PassengerRideRules.canCancelRequest (FR-009/FR-011 da feature 015)', () {
    test('permite cancelar a partir de aguardandoOrcamentos', () {
      expect(
        PassengerRideRules.canCancelRequest(
          PassengerRideStatus.aguardandoOrcamentos,
        ),
        isTrue,
      );
    });

    test('impede cancelar a partir de inicial', () {
      expect(
        PassengerRideRules.canCancelRequest(PassengerRideStatus.inicial),
        isFalse,
      );
    });

    test('impede cancelar a partir de orcamentoAceito', () {
      expect(
        PassengerRideRules.canCancelRequest(
          PassengerRideStatus.orcamentoAceito,
        ),
        isFalse,
      );
    });
  });

  group('PassengerRideRules.canShowDriverRoute (feature 018)', () {
    test('vale só em emCorrida', () {
      for (final status in PassengerRideStatus.values) {
        expect(
          PassengerRideRules.canShowDriverRoute(status),
          status == PassengerRideStatus.emCorrida,
          reason: '$status',
        );
      }
    });
  });

  group('PassengerRideRules.canBeCancelledByDriver (feature 019)', () {
    test('vale só em orcamentoAceito, motoristaACaminho e emCorrida', () {
      const validos = {
        PassengerRideStatus.orcamentoAceito,
        PassengerRideStatus.motoristaACaminho,
        PassengerRideStatus.emCorrida,
      };
      for (final status in PassengerRideStatus.values) {
        expect(
          PassengerRideRules.canBeCancelledByDriver(status),
          validos.contains(status),
          reason: '$status',
        );
      }
    });
  });

  group('PassengerRideRules.canCancelRide (feature 023)', () {
    test('vale só em orcamentoAceito, motoristaACaminho e emCorrida', () {
      const validos = {
        PassengerRideStatus.orcamentoAceito,
        PassengerRideStatus.motoristaACaminho,
        PassengerRideStatus.emCorrida,
      };
      for (final status in PassengerRideStatus.values) {
        expect(
          PassengerRideRules.canCancelRide(status),
          validos.contains(status),
          reason: '$status',
        );
      }
    });
  });

  group('PassengerRideRules.canBeDeclinedByDriver (feature 020)', () {
    test('vale só em orcamentoAceito', () {
      for (final status in PassengerRideStatus.values) {
        expect(
          PassengerRideRules.canBeDeclinedByDriver(status),
          status == PassengerRideStatus.orcamentoAceito,
          reason: '$status',
        );
      }
    });
  });
}

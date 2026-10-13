import 'package:passenger/domain/passenger_ride_status.dart';
import 'package:passenger/domain/service_state.dart';

/// Que aviso o passageiro deve receber, com o app fora de primeiro plano, de
/// uma mensagem do motorista (feature 026, FR-005 e FR-006).
enum BackgroundNotification {
  /// `kind: 20002` — um orçamento para a solicitação ativa.
  novoOrcamento('Novo orçamento de corrida'),

  /// `kind: 20007` — o motorista chegou ao ponto de encontro.
  motoristaChegou('Seu motorista chegou'),

  /// `kind: 20009` — chegada ao destino.
  chegouAoDestino('Você chegou ao destino'),

  /// `kind: 20012` — o motorista cancelou a corrida.
  canceladaPeloMotorista('Corrida cancelada pelo motorista'),

  /// `kind: 20006` — o motorista não pode atender a corrida aceita.
  motoristaIndisponivel('Motorista indisponível');

  const BackgroundNotification(this.title);

  /// Texto fixo da notificação: nunca nome, placa, endereço, coordenada nem
  /// chave de terceiros (constituição 2.15.0, SC-003).
  final String title;
}

/// A regra única que decide se uma mensagem merece notificação — usada pela
/// interface (teste de paridade) e pelo serviço em segundo plano.
///
/// **Decide só por dados públicos do evento** (kind, autor, tags `p` e `e`) e
/// pelo [ServiceState]: o `content` é cifrado ao passageiro (NIP-44, emenda 17)
/// e o serviço não tem a chave. As guardas de estado são as mesmas de
/// [PassengerRideRules] que `MapScreen` usa ao tratar cada kind; a interface
/// continua decifrando e descartando o que for ilegível ao abrir.
abstract final class BackgroundNotificationRule {
  /// O aviso devido a [payload] (evento já verificado, no formato do protocolo)
  /// no [state], ou `null` se nada deve ser notificado.
  static BackgroundNotification? evaluate(
    Map<String, dynamic> payload,
    ServiceState state,
  ) {
    final passenger = state.passengerPubkey;
    if (passenger == null) return null;

    final kind = payload['kind'];
    final author = payload['pubkey'];
    if (kind is! int || author is! String) return null;

    final tags = payload['tags'];
    if (_tagValue(tags, 'p') != passenger) return null;
    final reference = _tagValue(tags, 'e');
    if (reference == null) return null;

    if (kind == _rideQuoteKind) {
      if (state.rideStatus != PassengerRideStatus.aguardandoOrcamentos) {
        return null;
      }
      if (reference != state.requestId) return null;
      return BackgroundNotification.novoOrcamento;
    }

    // Os demais avisos são da corrida aceita: autor e `["e", quoteId]`.
    if (author != state.driverPubkey) return null;
    if (reference != state.quoteId) return null;
    final status = state.rideStatus;
    return switch (kind) {
      _driverArrivalKind when PassengerRideRules.canConfirmMeeting(status) =>
        BackgroundNotification.motoristaChegou,
      _destinationArrivalKind
          when PassengerRideRules.canConfirmDestinationArrival(status) =>
        BackgroundNotification.chegouAoDestino,
      _rideCancelledKind
          when PassengerRideRules.canBeCancelledByDriver(status) =>
        BackgroundNotification.canceladaPeloMotorista,
      _rideUnavailableKind
          when PassengerRideRules.canBeDeclinedByDriver(status) =>
        BackgroundNotification.motoristaIndisponivel,
      _ => null,
    };
  }

  /// Chave que identifica "a mesma notícia" para não notificar de novo: o
  /// `20007` se repete a cada 5 s enquanto o motorista está no raio (emenda 20
  /// do contrato), então vale uma notificação por corrida e tipo. Cada
  /// orçamento (`20002`) é uma notícia própria.
  static String dedupeKey(
    BackgroundNotification notification,
    Map<String, dynamic> payload,
  ) => notification == BackgroundNotification.novoOrcamento
      ? 'q:${payload['id']}'
      : '${notification.name}:${_tagValue(payload['tags'], 'e')}';

  static String? _tagValue(Object? tags, String name) {
    if (tags is! List) return null;
    for (final tag in tags) {
      if (tag is List && tag.length >= 2 && tag[0] == name) {
        return tag[1]?.toString();
      }
    }
    return null;
  }

  // Duplicados de event_feed.dart: o domínio não importa serviços.
  static const int _rideQuoteKind = 20002;
  static const int _rideUnavailableKind = 20006;
  static const int _driverArrivalKind = 20007;
  static const int _destinationArrivalKind = 20009;
  static const int _rideCancelledKind = 20012;

  /// Kinds que a regra pode notificar (o serviço os usa para reter).
  static const Set<int> notifiableKinds = {
    _rideQuoteKind,
    _rideUnavailableKind,
    _driverArrivalKind,
    _destinationArrivalKind,
    _rideCancelledKind,
  };
}

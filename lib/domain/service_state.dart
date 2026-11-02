import 'package:passenger/domain/passenger_ride_status.dart';

/// O que o serviço em segundo plano precisa saber do app para decidir uma
/// notificação (feature 026, FR-011). A interface o calcula e o envia; o
/// serviço o guarda para relê-lo se o sistema o reiniciar.
///
/// **Só dados públicos**: a chave pública do passageiro, o estado da corrida e
/// os ids/chaves públicas que a identificam. Nunca a chave privada nem a
/// semente (Princípio I; constituição 2.15.0).
class ServiceState {
  const ServiceState({
    this.passengerPubkey,
    this.rideStatus = PassengerRideStatus.inicial,
    this.requestId,
    this.quoteId,
    this.driverPubkey,
    this.appInForeground = false,
  });

  /// Chave pública do passageiro; sem ela nenhuma mensagem é "para ele".
  final String? passengerPubkey;

  final PassengerRideStatus rideStatus;

  /// `id` do `kind: 20001` ativo.
  final String? requestId;

  /// `id` do orçamento aceito (a tag `["e", ...]` dos avisos da corrida).
  final String? quoteId;

  /// Chave pública do motorista da corrida aceita.
  final String? driverPubkey;

  /// Só em memória: ao reiniciar o serviço assume `false`.
  final bool appInForeground;

  /// Verdadeiro se há solicitação ou corrida a acompanhar, o que mantém o
  /// serviço vivo com o app fechado (FR-001).
  bool get hasActiveRide => switch (rideStatus) {
    PassengerRideStatus.aguardandoOrcamentos ||
    PassengerRideStatus.orcamentoAceito ||
    PassengerRideStatus.motoristaACaminho ||
    PassengerRideStatus.emCorrida => true,
    PassengerRideStatus.inicial ||
    PassengerRideStatus.destinoConfirmadoAguardandoAvaliacao => false,
  };

  ServiceState copyWith({
    String? passengerPubkey,
    PassengerRideStatus? rideStatus,
    String? requestId,
    String? quoteId,
    String? driverPubkey,
    bool? appInForeground,
    bool clearRide = false,
  }) => ServiceState(
    passengerPubkey: passengerPubkey ?? this.passengerPubkey,
    rideStatus: rideStatus ?? this.rideStatus,
    requestId: clearRide ? null : (requestId ?? this.requestId),
    quoteId: clearRide ? null : (quoteId ?? this.quoteId),
    driverPubkey: clearRide ? null : (driverPubkey ?? this.driverPubkey),
    appInForeground: appInForeground ?? this.appInForeground,
  );

  /// Formato do canal (inclui [appInForeground]).
  Map<String, dynamic> toJson() => {
    'passengerPubkey': passengerPubkey,
    'rideStatus': rideStatus.name,
    'requestId': requestId,
    'quoteId': quoteId,
    'driverPubkey': driverPubkey,
    'appInForeground': appInForeground,
  };

  /// Formato guardado em disco: sem [appInForeground].
  Map<String, dynamic> toStorageJson() => {
    'passengerPubkey': passengerPubkey,
    'rideStatus': rideStatus.name,
    'requestId': requestId,
    'quoteId': quoteId,
    'driverPubkey': driverPubkey,
  };

  /// Lê o que o canal ou o disco trouxeram. Estado desconhecido volta a
  /// `inicial` em vez de lançar: o que chega é entrada, não instrução.
  factory ServiceState.fromJson(Map<String, dynamic> json) {
    final status = PassengerRideStatus.values.where(
      (s) => s.name == json['rideStatus'],
    );
    return ServiceState(
      passengerPubkey: json['passengerPubkey'] as String?,
      rideStatus: status.isEmpty ? PassengerRideStatus.inicial : status.first,
      requestId: json['requestId'] as String?,
      quoteId: json['quoteId'] as String?,
      driverPubkey: json['driverPubkey'] as String?,
      appInForeground: json['appInForeground'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ServiceState &&
      other.passengerPubkey == passengerPubkey &&
      other.rideStatus == rideStatus &&
      other.requestId == requestId &&
      other.quoteId == quoteId &&
      other.driverPubkey == driverPubkey &&
      other.appInForeground == appInForeground;

  @override
  int get hashCode => Object.hash(
    passengerPubkey,
    rideStatus,
    requestId,
    quoteId,
    driverPubkey,
    appInForeground,
  );

  @override
  String toString() =>
      'ServiceState($rideStatus, request: $requestId, quote: $quoteId, '
      'foreground: $appInForeground)';
}

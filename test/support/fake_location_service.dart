import 'dart:async';

import 'package:passenger/domain/passenger_position.dart';
import 'package:passenger/services/location_service.dart';

/// Dublê em memória: nenhum teste toca sensor de localização real (decisão
/// D1 de `specs/004-mapa-destino-passageiro/research.md`, Princípio III).
class FakeLocationService implements LocationService {
  FakeLocationService({this.permissionError});

  /// Se preenchido, [ensurePermission] lança este erro.
  Object? permissionError;

  final _controller = StreamController<PassengerPosition>.broadcast();

  @override
  Stream<PassengerPosition> get positions => _controller.stream;

  @override
  Future<void> ensurePermission() async {
    final erro = permissionError;
    if (erro != null) throw erro;
  }

  void emitir(PassengerPosition posicao) => _controller.add(posicao);

  void emitirErro(Object erro) => _controller.addError(erro);

  Future<void> fechar() => _controller.close();
}

PassengerPosition posicaoDeTeste({double lat = -28.935, double lng = -49.49}) =>
    PassengerPosition(
      latitude: lat,
      longitude: lng,
      capturedAt: DateTime.now(),
    );

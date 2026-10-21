import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/accepted_ride.dart';

import '../support/receipt_builders.dart';
import '../support/receipt_harness.dart';

/// Verificação de não vazamento (Princípio I) para os recibos: a chave privada
/// nunca aparece em evento publicado, no recibo nem no que o serviço devolve;
/// `20014`/`20015` nunca saem em claro.
void main() {
  test(
    'nem a chave privada nem texto em claro saem nos eventos publicados',
    () async {
      final c = RecibosCenario();
      addTearDown(c.fechar);
      await c.iniciar();
      final corrida = AcceptedRide(
        quoteId: guidDe(1),
        driverPubkey: c.motorista.publicKey,
      );

      // Emissão (20014) e confirmação (20015).
      await c.service.issueFor(corrida, 5);
      final recibo = emitirRecibo(
        de: c.motorista,
        para: c.eu.publicKey,
        seq: 0,
        guid: guidDe(2),
      );
      c.conhecer(recibo.guidCorrida);
      c.entregar(c.eventoDeRecibo(recibo));
      await c.assentar();
      await c.service.settled();

      final enviado = c.transport.conexoes['wss://a.test']!.enviadas.join('\n');
      expect(enviado, isNot(contains(c.eu.privateKey)));
      expect(enviado, isNot(contains(c.motorista.privateKey)));

      for (final kind in [20014, 20015]) {
        final publicados = c.publicadosDe(kind);
        expect(publicados, isNotEmpty, reason: 'kind $kind');
        for (final p in publicados) {
          final conteudo = p['content'] as String;
          // Em claro seria JSON; cifrado NIP-44 é base64 e não decodifica como JSON.
          expect(() => jsonDecode(conteudo), throwsFormatException);
          expect(conteudo, isNot(contains('id_recibo')));
          expect(conteudo, isNot(contains('guid_corrida')));
          expect(conteudo, isNot(contains(c.eu.publicKey)));
        }
      }
    },
  );

  test('o recibo emitido contém só chaves públicas', () async {
    final c = RecibosCenario();
    addTearDown(c.fechar);
    final corrida = AcceptedRide(
      quoteId: guidDe(1),
      driverPubkey: c.motorista.publicKey,
    );

    await c.service.issueFor(corrida, 5);

    final emitido = (await c.store.issuedFor(corrida.quoteId))!;
    final texto = jsonEncode(emitido.toJson());
    expect(texto, isNot(contains(c.eu.privateKey)));
    expect(emitido.toString(), isNot(contains(c.eu.privateKey)));
  });
}

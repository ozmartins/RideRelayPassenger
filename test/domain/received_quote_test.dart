import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/nostr_event.dart';
import 'package:passenger/domain/received_quote.dart';
import 'package:passenger/domain/reputation.dart';

import '../support/receipt_builders.dart';

NostrEvent _eventoDe(
  String content, {
  String id = 'id-orcamento',
  List<List<String>>? tags,
}) => NostrEvent(
  id: id,
  authorPublicKey: 'a' * 64,
  createdAt: DateTime.now(),
  kind: 20002,
  content: content,
  isSignatureValid: true,
  tags: tags ?? const [['e', 'id-solicitacao']],
);

void main() {
  group('ReceivedQuote.fromNostrEvent (data-model.md da feature 008)', () {
    test('decodifica todos os campos de um content válido, com etaMinutes', () {
      final evento = _eventoDe(
        '{"pricePerKm":2.5,"total":25.0,"driverName":"Fulano da Silva",'
        '"carBrand":"Fiat","carModel":"Palio","carYear":2018,'
        '"etaMinutes":6}',
        id: 'id-do-orcamento',
      );

      final quote = ReceivedQuote.fromNostrEvent(evento);

      expect(quote.quoteId, 'id-do-orcamento');
      expect(quote.requestId, 'id-solicitacao');
      expect(quote.driverPubkey, 'a' * 64);
      expect(quote.driverName, 'Fulano da Silva');
      expect(quote.carBrand, 'Fiat');
      expect(quote.carModel, 'Palio');
      expect(quote.carYear, 2018);
      expect(quote.pricePerKm, 2.5);
      expect(quote.total, 25.0);
      expect(quote.etaMinutes, 6);
    });

    test('etaMinutes fica nulo quando a chave está ausente', () {
      final evento = _eventoDe(
        '{"pricePerKm":2.5,"total":25.0,"driverName":"Fulano da Silva",'
        '"carBrand":"Fiat","carModel":"Palio","carYear":2018}',
      );

      final quote = ReceivedQuote.fromNostrEvent(evento);

      expect(quote.etaMinutes, isNull);
    });

    group('reputacao (emenda 25, feature 027)', () {
      const base =
          '"pricePerKm":2.5,"total":25.0,"driverName":"Fulano da Silva",'
          '"carBrand":"Fiat","carModel":"Palio","carYear":2018';

      Object? reputacaoValida() {
        final dono = identidadeNova();
        final c = cadeiaDeRecibos(avaliador: identidadeNova(), dono: dono);
        return reputacaoDe([c[2], c[1], c[0]], seqProximo: 3).toJson();
      }

      test('presente e válida: é lida', () {
        final evento = _eventoDe(
          '{$base,"reputacao":${jsonEncode(reputacaoValida())}}',
        );

        final quote = ReceivedQuote.fromNostrEvent(evento);

        expect(quote.reputation, isA<Reputation>());
        expect(quote.reputation!.recibos, hasLength(3));
        expect(quote.reputation!.seqProximo, 3);
      });

      test('ausente: fica nula', () {
        final quote = ReceivedQuote.fromNostrEvent(_eventoDe('{$base}'));

        expect(quote.reputation, isNull);
      });

      for (final ruim in [
        '"texto"',
        '[]',
        '{}',
        '{"corridas":1}',
        '{"corridas":-1,"avaliacoes":0,"seq_proximo":0,"recibos":[]}',
      ]) {
        test('malformada ($ruim): o orçamento segue válido, sem reputação', () {
          final quote = ReceivedQuote.fromNostrEvent(
            _eventoDe('{$base,"reputacao":$ruim}'),
          );

          expect(quote.driverName, 'Fulano da Silva');
          expect(quote.total, 25.0);
          expect(quote.reputation, isNull);
        });
      }

      test('null explícito: fica nula', () {
        final quote = ReceivedQuote.fromNostrEvent(
          _eventoDe('{$base,"reputacao":null}'),
        );

        expect(quote.reputation, isNull);
      });
    });

    test('lança FormatException quando não há tag e (solicitação)', () {
      final evento = _eventoDe(
        '{"pricePerKm":2.5,"total":25.0,"driverName":"Fulano da Silva",'
        '"carBrand":"Fiat","carModel":"Palio","carYear":2018}',
        tags: const [],
      );

      expect(
        () => ReceivedQuote.fromNostrEvent(evento),
        throwsFormatException,
      );
    });

    test('lança FormatException para content que não é JSON', () {
      final evento = _eventoDe('não é json');

      expect(
        () => ReceivedQuote.fromNostrEvent(evento),
        throwsFormatException,
      );
    });

    test('lança FormatException para content sem um campo obrigatório', () {
      final evento = _eventoDe('{"pricePerKm":2.5,"total":25.0}');

      expect(
        () => ReceivedQuote.fromNostrEvent(evento),
        throwsFormatException,
      );
    });
  });
}

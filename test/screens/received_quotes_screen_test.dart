import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/received_quote.dart';
import 'package:passenger/domain/reputation.dart';
import 'package:passenger/screens/identidade_visual.dart';
import 'package:passenger/screens/received_quotes_screen.dart';

import '../support/receipt_builders.dart';

ReceivedQuote _quote({
  String quoteId = 'q1',
  int? etaMinutes = 6,
}) => ReceivedQuote(
  quoteId: quoteId,
  requestId: 'r1',
  driverPubkey: 'a' * 64,
  driverName: 'Fulano da Silva',
  carBrand: 'Fiat',
  carModel: 'Palio',
  carYear: 2018,
  pricePerKm: 2.5,
  total: 25.0,
  etaMinutes: etaMinutes,
);

Future<void> _montar(
  WidgetTester tester, {
  required ValueListenable<List<ReceivedQuote>> quotes,
  Future<String?> Function(ReceivedQuote)? onAccept,
  VoidCallback? onCancel,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ReceivedQuotesScreen(
        quotes: quotes,
        onAccept: onAccept ?? (_) async => null,
        onCancel: onCancel ?? () {},
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final comOrcamentos in [false, true]) {
    testWidgets(
      'o botão "Cancelar" é roxo com texto branco e contraste >= 4,5:1, '
      '${comOrcamentos ? 'com' : 'sem'} orçamentos '
      '(feature 024: FR-002, FR-003, SC-001, SC-002)',
      (tester) async {
        final notifier = ValueNotifier<List<ReceivedQuote>>(
          comOrcamentos ? [_quote()] : const [],
        );
        await _montar(tester, quotes: notifier);

        final botao = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Cancelar'),
        );
        expect(
          find.descendant(
            of: find.widgetWithText(FilledButton, 'Cancelar'),
            matching: find.byIcon(Icons.close),
          ),
          findsOneWidget,
        );
        expect(
          tester.getSize(find.widgetWithText(FilledButton, 'Cancelar')).height,
          48,
        );
        final fundo = botao.style!.backgroundColor!.resolve({})!;
        final texto = botao.style!.foregroundColor!.resolve({})!;
        expect(fundo, IdentidadeVisual.roxo);
        expect(texto, Colors.white);
        final claro = fundo.computeLuminance() > texto.computeLuminance()
            ? fundo
            : texto;
        final escuro = identical(claro, fundo) ? texto : fundo;
        expect(
          (claro.computeLuminance() + 0.05) /
              (escuro.computeLuminance() + 0.05),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
  }

  testWidgets(
    'lista vazia mostra "Aguardando orçamentos…" e o botão "Cancelar" '
    'visível (FR-003, FR-008)',
    (tester) async {
      final notifier = ValueNotifier<List<ReceivedQuote>>(const []);
      await _montar(tester, quotes: notifier);

      expect(find.textContaining('Aguardando orçamentos'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Cancelar'), findsOneWidget);
    },
  );

  testWidgets(
    'exibe nome do motorista, veículo, total e tempo estimado de cada '
    'orçamento, em formato condensado (FR-004, FR-005)',
    (tester) async {
      final notifier = ValueNotifier<List<ReceivedQuote>>([_quote()]);
      await _montar(tester, quotes: notifier);

      expect(
        find.textContaining('Fulano da Silva — Fiat Palio 2018'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Total: R\$ 25.00 · 6 min estimados'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'exibe "tempo estimado não disponível" quando etaMinutes é nulo, nunca '
    'zero',
    (tester) async {
      final notifier = ValueNotifier<List<ReceivedQuote>>([
        _quote(etaMinutes: null),
      ]);
      await _montar(tester, quotes: notifier);

      expect(
        find.textContaining('tempo estimado não disponível'),
        findsOneWidget,
      );
      expect(find.textContaining('0 min'), findsNothing);
    },
  );

  testWidgets(
    'um segundo orçamento é adicionado à lista sem remover o primeiro '
    '(FR-004)',
    (tester) async {
      final notifier = ValueNotifier<List<ReceivedQuote>>([
        _quote(quoteId: 'q1'),
      ]);
      await _montar(tester, quotes: notifier);
      expect(find.widgetWithText(FilledButton, 'Aceitar'), findsOneWidget);

      notifier.value = [...notifier.value, _quote(quoteId: 'q2')];
      await tester.pump();

      expect(find.widgetWithText(FilledButton, 'Aceitar'), findsNWidgets(2));
    },
  );

  testWidgets('tocar "Aceitar" chama onAccept com o orçamento do item (FR-006)', (
    tester,
  ) async {
    final notifier = ValueNotifier<List<ReceivedQuote>>([_quote()]);
    ReceivedQuote? recebido;
    await _montar(
      tester,
      quotes: notifier,
      onAccept: (quote) async {
        recebido = quote;
        return null;
      },
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Aceitar'));
    await tester.pump();

    expect(recebido?.quoteId, 'q1');
  });

  testWidgets('erro de onAccept é exibido no item, sem fechar nada', (
    tester,
  ) async {
    final notifier = ValueNotifier<List<ReceivedQuote>>([_quote()]);
    await _montar(
      tester,
      quotes: notifier,
      onAccept: (_) async => 'Nenhum relay conectado.',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Aceitar'));
    await tester.pump();

    expect(find.text('Nenhum relay conectado.'), findsOneWidget);
  });

  testWidgets('tocar "Cancelar" chama onCancel (FR-009)', (tester) async {
    final notifier = ValueNotifier<List<ReceivedQuote>>(const []);
    var cancelado = false;
    await _montar(
      tester,
      quotes: notifier,
      onCancel: () => cancelado = true,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar'));
    await tester.pump();

    expect(cancelado, isTrue);
  });

  group('reputação do motorista (feature 027)', () {
    final motorista = identidadeNova();
    final cadeia = cadeiaDeRecibos(
      avaliador: identidadeNova(),
      dono: motorista,
    );

    ReceivedQuote comReputacao(Reputation? reputacao) => ReceivedQuote(
      quoteId: 'q1',
      requestId: 'r1',
      driverPubkey: motorista.publicKey,
      driverName: 'Fulano da Silva',
      carBrand: 'Fiat',
      carModel: 'Palio',
      carYear: 2018,
      pricePerKm: 2.5,
      total: 25.0,
      etaMinutes: 6,
      reputation: reputacao,
    );

    Future<void> mostrar(WidgetTester tester, Reputation? reputacao) =>
        _montar(
          tester,
          quotes: ValueNotifier([comReputacao(reputacao)]),
        );

    testWidgets('sem reputação: motorista sem histórico', (tester) async {
      await mostrar(tester, null);

      expect(find.text('Sem histórico de avaliações'), findsOneWidget);
      expect(find.textContaining('Verificado'), findsNothing);
    });

    testWidgets('verificado em destaque e declarado em texto menor', (
      tester,
    ) async {
      final tres = [cadeia[2], cadeia[1], cadeia[0]];
      await mostrar(tester, reputacaoDe(tres, seqProximo: 3));

      expect(find.text('Verificado nos últimos 3: ★ 2.0'), findsOneWidget);
      expect(
        find.text('Declarado: 3 corridas · 3 avaliações · média 2.00'),
        findsOneWidget,
      );
      expect(find.textContaining('inconsistente'), findsNothing);
      expect(find.textContaining('não apresentado'), findsNothing);
    });

    testWidgets('declarado alto não altera o verificado', (tester) async {
      final base = reputacaoDe([cadeia[2], cadeia[1], cadeia[0]], seqProximo: 3);
      await mostrar(
        tester,
        Reputation(
          corridas: 500,
          avaliacoes: 500,
          media: 5.0,
          seqProximo: base.seqProximo,
          head: base.head,
          recibos: base.recibos,
        ),
      );

      expect(find.text('Verificado nos últimos 3: ★ 2.0'), findsOneWidget);
      expect(
        find.text('Declarado: 500 corridas · 500 avaliações · média 5.00'),
        findsOneWidget,
      );
    });

    testWidgets('reputação inconsistente é destacada', (tester) async {
      await mostrar(
        tester,
        reputacaoDe(
          [cadeia[2], cadeia[1], cadeia[0]],
          seqProximo: 3,
          head: cadeia[0].idRecibo,
        ),
      );

      expect(find.text('Reputação inconsistente'), findsOneWidget);
    });

    testWidgets('lacuna: "N recibos não apresentados"', (tester) async {
      await mostrar(
        tester,
        reputacaoDe([cadeia[6], cadeia[5], cadeia[3]], seqProximo: 7),
      );

      expect(find.text('1 recibo não apresentado'), findsOneWidget);
    });

    testWidgets('recibo adulterado é descartado e contado', (tester) async {
      await mostrar(
        tester,
        reputacaoDe(
          [cadeia[2], comNotaTrocada(cadeia[1]), cadeia[0]],
          seqProximo: 3,
        ),
      );

      expect(find.text('Verificado nos últimos 2: ★ 2.0'), findsOneWidget);
      expect(find.text('1 recibo inválido descartado'), findsOneWidget);
    });

    testWidgets('nenhum recibo verificado quando todos são inválidos', (
      tester,
    ) async {
      final outroDono = identidadeNova();
      final alheios = cadeiaDeRecibos(
        avaliador: identidadeNova(),
        dono: outroDono,
        tamanho: 2,
      );
      await mostrar(tester, reputacaoDe(alheios.reversed.toList(), seqProximo: 2));

      expect(find.text('Nenhum recibo verificado'), findsOneWidget);
      expect(find.text('2 recibos inválidos descartados'), findsOneWidget);
    });
  });
}

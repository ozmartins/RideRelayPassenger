import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/received_quote.dart';
import 'package:passenger/screens/identidade_visual.dart';
import 'package:passenger/screens/received_quotes_screen.dart';

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
}

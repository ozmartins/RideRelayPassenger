import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/screens/name_screen.dart';

Future<void> montar(
  WidgetTester tester, {
  String? initialName,
  required Future<void> Function(String) onSave,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: NameScreen(initialName: initialName, onSave: onSave),
    ),
  );
  await tester.pump();
}

void main() {
  group('NameScreen — primeira execução (US1)', () {
    testWidgets('recusa confirmar com campo vazio, com explicação', (
      tester,
    ) async {
      var chamado = false;
      await montar(tester, onSave: (_) async => chamado = true);

      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();

      expect(find.textContaining('obrigatório'), findsOneWidget);
      expect(chamado, isFalse);
    });

    testWidgets('recusa confirmar com campo só de espaços em branco', (
      tester,
    ) async {
      var chamado = false;
      await montar(tester, onSave: (_) async => chamado = true);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();

      expect(find.textContaining('obrigatório'), findsOneWidget);
      expect(chamado, isFalse);
    });

    testWidgets('recusa confirmar com nome acima de 60 caracteres', (
      tester,
    ) async {
      var chamado = false;
      await montar(tester, onSave: (_) async => chamado = true);

      await tester.enterText(find.byType(TextField), 'a' * 61);
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();

      expect(find.textContaining('60 caracteres'), findsOneWidget);
      expect(chamado, isFalse);
    });

    testWidgets('confirma com nome válido, chamando onSave com o valor '
        'trimado', (tester) async {
      String? recebido;
      await montar(tester, onSave: (nome) async => recebido = nome);

      await tester.enterText(find.byType(TextField), '  Maria  ');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();

      expect(recebido, 'Maria');
    });

    testWidgets('mostra erro e mantém a tela quando o salvamento falha', (
      tester,
    ) async {
      await montar(
        tester,
        onSave: (_) async => throw Exception('falha de armazenamento'),
      );

      await tester.enterText(find.byType(TextField), 'Maria');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();

      expect(find.byType(NameScreen), findsOneWidget);
      expect(find.textContaining('Não foi possível salvar'), findsOneWidget);
    });
  });

  group('NameScreen — alteração de nome (US2)', () {
    testWidgets('campo aparece preenchido com o nome atual', (tester) async {
      await montar(tester, initialName: 'Maria', onSave: (_) async {});

      expect(find.text('Maria'), findsOneWidget);
    });

    testWidgets('salva um novo nome válido, chamando onSave com o valor '
        'trimado', (tester) async {
      String? recebido;
      await montar(
        tester,
        initialName: 'Maria',
        onSave: (nome) async => recebido = nome,
      );

      await tester.enterText(find.byType(TextField), 'João');
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pump();

      expect(recebido, 'João');
    });

    testWidgets('recusa salvar com o campo apagado', (tester) async {
      var chamado = false;
      await montar(
        tester,
        initialName: 'Maria',
        onSave: (_) async => chamado = true,
      );

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pump();

      expect(find.textContaining('obrigatório'), findsOneWidget);
      expect(chamado, isFalse);
    });

    testWidgets('sair sem confirmar não chama onSave', (tester) async {
      var chamado = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  child: const Text('Abrir'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NameScreen(
                        initialName: 'Maria',
                        onSave: (_) async => chamado = true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Abrir'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'João');
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(chamado, isFalse);
      expect(find.byType(NameScreen), findsNothing);
    });
  });
}

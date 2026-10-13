import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/identity.dart';
import 'package:passenger/screens/identity_screen.dart';

void main() {
  final identidade = Identity(
    publicKey: 'a1b2c3d4' * 8,
    privateKey: 'f0e1d2c3' * 8,
  );

  Future<void> montar(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(home: IdentityScreen(identity: identidade)),
  );

  testWidgets('exibe a chave pública', (tester) async {
    await montar(tester);

    expect(find.text(identidade.publicKey), findsOneWidget);
  });

  testWidgets('não exibe a chave privada em nenhum widget da árvore', (
    tester,
  ) async {
    await montar(tester);

    // Varre todo widget de texto da árvore procurando a chave privada —
    // verificação de não vazamento exigida pelo Princípio I e por SC-007.
    final textos = <String>[];
    for (final w in tester.allWidgets) {
      if (w is Text && w.data != null) textos.add(w.data!);
      if (w is SelectableText && w.data != null) textos.add(w.data!);
      if (w is EditableText) textos.add(w.controller.text);
    }

    expect(textos, isNotEmpty);
    for (final texto in textos) {
      expect(
        texto,
        isNot(contains(identidade.privateKey)),
        reason: 'a chave privada apareceu na interface',
      );
    }
  });

  testWidgets('a chave pública é selecionável, para poder ser copiada', (
    tester,
  ) async {
    await montar(tester);

    expect(find.byType(SelectableText), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Copiar chave pública'),
      findsOneWidget,
    );
  });

  testWidgets('avisa que desinstalar destrói a identidade', (tester) async {
    await montar(tester);

    expect(find.textContaining('Desinstalar'), findsOneWidget);
  });
}

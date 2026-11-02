import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/screens/driver_unavailable_modal.dart';

void main() {
  testWidgets('mostra título, mensagem e o botão "OK"', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DriverUnavailableModal(onClose: () {})),
      ),
    );

    expect(find.text('Motorista indisponível'), findsOneWidget);
    expect(find.textContaining('não pode atender'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'OK'), findsOneWidget);
  });

  testWidgets('tocar "OK" chama onClose', (tester) async {
    var fechou = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DriverUnavailableModal(onClose: () => fechou++)),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pump();

    expect(fechou, 1);
  });
}

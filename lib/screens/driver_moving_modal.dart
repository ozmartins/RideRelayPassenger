import 'package:flutter/material.dart';
import 'package:passenger/screens/identidade_visual.dart';

/// Modal exibida quando o motorista aceito começa a se deslocar até o
/// passageiro (feature 009, US1).
///
/// Widget apresentacional (como `ReceivedQuotesScreen`): renderizada
/// diretamente na árvore de `MapScreen`, não via `showDialog` — mesmo
/// motivo já documentado para `ReceivedQuotesScreen` (T019 de
/// `specs/008-receber-orcamentos/tasks.md`). [onClose] é responsabilidade
/// de quem chama.
class DriverMovingModal extends StatelessWidget {
  const DriverMovingModal({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ModalTematizado(
      titulo: 'Motorista a caminho',
      conteudo: const Text('O motorista começou a se deslocar até você.'),
      acoes: [
        FilledButton(
          style: IdentidadeVisual.estiloAcaoPrimaria(altura: 48)
              .copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 48))),
          onPressed: onClose,
          child: const Text('OK'),
        ),
      ],
    );
  }
}

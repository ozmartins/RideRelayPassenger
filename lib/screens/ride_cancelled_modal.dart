import 'package:flutter/material.dart';
import 'package:passenger/screens/identidade_visual.dart';

/// Modal exibida quando o motorista cancela a corrida aceita (feature 019,
/// US1).
///
/// Widget apresentacional (como `DriverMovingModal`): renderizada
/// diretamente na árvore de `MapScreen`, não via `showDialog` — mesmo motivo
/// já documentado para `ReceivedQuotesScreen` (T019 de
/// `specs/008-receber-orcamentos/tasks.md`). [onClose] é responsabilidade de
/// quem chama; a corrida já foi encerrada quando a modal aparece.
class RideCancelledModal extends StatelessWidget {
  const RideCancelledModal({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ModalTematizado(
      titulo: 'Corrida cancelada',
      conteudo: const Text(
        'O motorista cancelou a corrida. Você pode solicitar outra.',
      ),
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

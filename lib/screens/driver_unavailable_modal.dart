import 'package:flutter/material.dart';
import 'package:passenger/screens/identidade_visual.dart';

/// Modal exibida quando o motorista da corrida aceita avisa que não pode
/// atendê-la (feature 020, US1) — por exemplo, porque já está comprometido
/// com outra corrida.
///
/// Widget apresentacional (como `RideCancelledModal`): renderizada
/// diretamente na árvore de `MapScreen`, não via `showDialog` (T019 de
/// `specs/008-receber-orcamentos/tasks.md`). [onClose] é responsabilidade de
/// quem chama; a corrida já foi encerrada quando a modal aparece.
class DriverUnavailableModal extends StatelessWidget {
  const DriverUnavailableModal({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ModalTematizado(
      titulo: 'Motorista indisponível',
      conteudo: const Text(
        'O motorista não pode atender a sua corrida agora. '
        'Você pode solicitar outra.',
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

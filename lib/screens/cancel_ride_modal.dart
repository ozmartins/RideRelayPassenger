import 'package:flutter/material.dart';
import 'package:passenger/screens/identidade_visual.dart';

/// Confirmação do cancelamento da corrida aceita (feature 023, FR-002).
///
/// Widget apresentacional (como `RideCancelledModal`): renderizada
/// diretamente na árvore de `MapScreen`, não via `showDialog` — mesmo motivo
/// já documentado para `ReceivedQuotesScreen` (T019 de
/// `specs/008-receber-orcamentos/tasks.md`). [onConfirm] e [onBack] são
/// responsabilidade de quem chama, incluindo esconder a modal.
class CancelRideModal extends StatelessWidget {
  const CancelRideModal({
    super.key,
    required this.onConfirm,
    required this.onBack,
  });

  /// Chamado ao tocar em "Cancelar corrida" — efetiva o cancelamento.
  final VoidCallback onConfirm;

  /// Chamado ao tocar em "Voltar" — desiste sem nenhum efeito.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ModalTematizado(
      titulo: 'Cancelar corrida?',
      conteudo: const Text(
        'O motorista será avisado de que você cancelou a corrida.',
      ),
      acoes: [
        TextButton(
          style: IdentidadeVisual.estiloAcaoSecundaria,
          onPressed: onBack,
          child: const Text('Voltar'),
        ),
        FilledButton(
          style: IdentidadeVisual.estiloAcaoPrimaria(altura: 48)
              .copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 48))),
          onPressed: onConfirm,
          child: const Text('Cancelar corrida'),
        ),
      ],
    );
  }
}

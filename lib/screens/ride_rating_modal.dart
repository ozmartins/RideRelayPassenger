import 'package:flutter/material.dart';
import 'package:passenger/screens/identidade_visual.dart';

/// Modal de avaliação da corrida, exibida ao final dela (feature 011, US1)
/// — por analogia estrutural a `DestinationArrivedModal`, mas com seleção de
/// estrelas em vez de uma única ação de confirmação.
class RideRatingModal extends StatefulWidget {
  const RideRatingModal({
    super.key,
    required this.onConfirm,
    required this.onSkip,
  });

  /// Confirma a avaliação com a nota escolhida (1 a 5).
  final void Function(int stars) onConfirm;

  /// Fecha a modal sem registrar nenhuma nota (FR-008).
  final VoidCallback onSkip;

  @override
  State<RideRatingModal> createState() => _RideRatingModalState();
}

class _RideRatingModalState extends State<RideRatingModal> {
  int? _notaSelecionada;

  @override
  Widget build(BuildContext context) {
    return ModalTematizado(
      titulo: 'Avalie a corrida',
      conteudo: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (indice) {
          final posicao = indice + 1;
          final selecionada =
              _notaSelecionada != null && posicao <= _notaSelecionada!;
          return IconButton(
            onPressed: () => setState(() => _notaSelecionada = posicao),
            icon: Icon(
              selecionada ? Icons.star : Icons.star_border,
              color: selecionada
                  ? IdentidadeVisual.roxo
                  : IdentidadeVisual.desabilitado,
            ),
          );
        }),
      ),
      acoes: [
        TextButton(
          style: IdentidadeVisual.estiloAcaoSecundaria,
          onPressed: widget.onSkip,
          child: const Text('Pular'),
        ),
        FilledButton(
          style: IdentidadeVisual.estiloAcaoPrimaria(altura: 48)
              .copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 48))),
          onPressed: _notaSelecionada == null
              ? null
              : () => widget.onConfirm(_notaSelecionada!),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

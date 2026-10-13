import 'package:flutter/material.dart';
import 'package:passenger/screens/identidade_visual.dart';

/// Modal exibida quando a corrida aceita informa que o motorista chegou ao
/// ponto de encontro (feature 010, US1).
///
/// Widget apresentacional (como `ReceivedQuotesScreen`): renderizada
/// diretamente na árvore de `MapScreen`, não via `showDialog` (mesmo motivo
/// já documentado, T019 de `specs/008-receber-orcamentos/tasks.md`).
/// [onConfirm] publica a confirmação de encontro; quem chama fecha a modal
/// (`setState`) só em caso de sucesso — mesmo padrão de
/// `ReceivedQuotesScreen.onAccept`.
class DriverArrivedModal extends StatefulWidget {
  const DriverArrivedModal({super.key, required this.onConfirm});

  /// Confirma o encontro; devolve a mensagem de falha (nenhum relay
  /// aceitou), ou `null` em caso de sucesso.
  final Future<String?> Function() onConfirm;

  @override
  State<DriverArrivedModal> createState() => _DriverArrivedModalState();
}

class _DriverArrivedModalState extends State<DriverArrivedModal> {
  var _confirmando = false;
  String? _erro;

  Future<void> _confirmar() async {
    if (_confirmando) return;
    setState(() {
      _confirmando = true;
      _erro = null;
    });
    final erro = await widget.onConfirm();
    if (!mounted) return;
    setState(() {
      _confirmando = false;
      _erro = erro;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ModalTematizado(
      titulo: 'Motorista chegou',
      conteudo: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('O motorista chegou ao ponto de encontro.'),
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _erro!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      acoes: [
        FilledButton(
          style: IdentidadeVisual.estiloAcaoPrimaria(altura: 48)
              .copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 48))),
          onPressed: _confirmando ? null : _confirmar,
          child: _confirmando
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirmo que encontrei o motorista'),
        ),
      ],
    );
  }
}

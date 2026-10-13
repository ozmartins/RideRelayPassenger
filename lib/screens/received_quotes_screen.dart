import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/received_quote.dart';
import 'identidade_visual.dart';

/// Tela dedicada ao acompanhamento dos orçamentos recebidos para a
/// solicitação ativa (feature 015) — substitui a antiga `RideQuotesModal`
/// (D1/D5 de `research.md`): não é uma modal sobreposta ao mapa, é a
/// própria tela enquanto o passageiro está em
/// `PassengerRideStatus.aguardandoOrcamentos`.
///
/// Widget apresentacional (como as demais telas/modais do app):
/// [onAccept] e [onCancel] são responsabilidade de quem a chama — publicar
/// os eventos e decidir a transição de estado, não deste widget.
class ReceivedQuotesScreen extends StatelessWidget {
  const ReceivedQuotesScreen({
    super.key,
    required this.quotes,
    required this.onAccept,
    required this.onCancel,
  });

  final ValueListenable<List<ReceivedQuote>> quotes;

  /// Aceita [quote]; devolve a mensagem a exibir em caso de falha (nenhum
  /// relay aceitou), ou `null` em caso de sucesso — mesmo contrato de
  /// `RideQuotesModal.onAccept`.
  final Future<String?> Function(ReceivedQuote quote) onAccept;

  /// Cancela a solicitação ativa (FR-008 a FR-011).
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return TelaDeConteudo(
      tituloBarra: 'Caronas Passageiro',
      titulo: 'Orçamentos recebidos',
      child: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder<List<ReceivedQuote>>(
              valueListenable: quotes,
              builder: (context, lista, _) {
                if (lista.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Aguardando orçamentos…',
                      style: TextStyle(color: IdentidadeVisual.textoSuave),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  itemCount: lista.length,
                  itemBuilder: (context, indice) => _ItemDeOrcamento(
                    quote: lista[indice],
                    onAccept: onAccept,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: IdentidadeVisual.estiloAcaoPrimaria(altura: 48),
                onPressed: onCancel,
                icon: const Icon(Icons.close, size: 20),
                label: const Text('Cancelar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Item condensado — mesmos dados de `RideQuotesModal._LinhaDeOrcamento`
/// (FR-005), num layout mais compacto (uma linha de texto em vez de um
/// card avulso por orçamento).
class _ItemDeOrcamento extends StatefulWidget {
  const _ItemDeOrcamento({required this.quote, required this.onAccept});

  final ReceivedQuote quote;
  final Future<String?> Function(ReceivedQuote quote) onAccept;

  @override
  State<_ItemDeOrcamento> createState() => _ItemDeOrcamentoState();
}

class _ItemDeOrcamentoState extends State<_ItemDeOrcamento> {
  var _aceitando = false;
  String? _erro;

  Future<void> _aceitar() async {
    if (_aceitando) return;
    setState(() {
      _aceitando = true;
      _erro = null;
    });
    final erro = await widget.onAccept(widget.quote);
    if (!mounted) return;
    setState(() {
      _aceitando = false;
      _erro = erro;
    });
  }

  @override
  Widget build(BuildContext context) {
    final quote = widget.quote;
    final tempoEstimado = quote.etaMinutes == null
        ? 'tempo estimado não disponível'
        : '${quote.etaMinutes} min estimados';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: IdentidadeVisual.campo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${quote.driverName} — ${quote.carBrand} '
                      '${quote.carModel} ${quote.carYear}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: IdentidadeVisual.texto,
                      ),
                    ),
                    Text(
                      'Total: R\$ ${quote.total.toStringAsFixed(2)} · '
                      '$tempoEstimado',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: IdentidadeVisual.textoSuave,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: FilledButton(
                  style: IdentidadeVisual.estiloAcaoPrimaria(altura: 36)
                      .copyWith(
                        minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                  onPressed: _aceitando ? null : _aceitar,
                  child: _aceitando
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Aceitar'),
                ),
              ),
            ],
          ),
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _erro!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

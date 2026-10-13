import 'package:flutter/material.dart';

import 'package:passenger/domain/relay.dart';
import 'package:passenger/services/relay_repository.dart';
import 'package:passenger/screens/identidade_visual.dart';
import 'package:passenger/services/relay_hub.dart';

/// Permite ao passageiro ver, acrescentar e remover relays (FR-011, FR-013).
///
/// A tela altera o repositório (que persiste) e o serviço (que conecta): as
/// duas coisas precisam andar juntas, senão a lista guardada e as conexões
/// vivas divergem.
class RelaysScreen extends StatefulWidget {
  const RelaysScreen({
    required this.repository,
    required this.relayService,
    super.key,
  });

  final RelayRepository repository;
  final RelayHub relayService;

  @override
  State<RelaysScreen> createState() => _RelaysScreenState();
}

class _RelaysScreenState extends State<RelaysScreen> {
  final _controller = TextEditingController();
  String? _erro;
  bool _reconectando = false;

  Future<void> _reconectar() async {
    // Desabilita o botão durante a chamada: toque duplo não sobrepõe rodadas.
    setState(() => _reconectando = true);
    try {
      await widget.relayService.retryUnavailable();
    } finally {
      if (mounted) setState(() => _reconectando = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TelaDeConteudo(
      tituloBarra: 'Caronas Passageiro',
      titulo: 'Relays',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autocorrect: false,
                    style: IdentidadeVisual.estiloValor,
                    decoration: decoracaoCampo(
                      rotulo: 'Endereço do relay',
                      dica: 'wss://exemplo.com',
                      erro: _erro,
                    ),
                    onSubmitted: (_) => _adicionar(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _adicionar,
                  style: IdentidadeVisual.estiloAcaoPrimaria().copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(0, 56)),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                  child: const Text('Adicionar'),
                ),
              ],
            ),
          ),
          StreamBuilder<List<Relay>>(
            stream: widget.relayService.relays,
            initialData: widget.relayService.current,
            builder: (context, snapshot) {
              if ((snapshot.data ?? const <Relay>[]).isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('botao-reconectar'),
                    onPressed: _reconectando ? null : _reconectar,
                    style: IdentidadeVisual.estiloAcaoPrimaria(),
                    icon: const Icon(Icons.sync, size: 18),
                    label: Text(_reconectando ? 'Reconectando…' : 'Reconectar'),
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<List<Relay>>(
              stream: widget.relayService.relays,
              initialData: widget.relayService.current,
              builder: (context, snapshot) {
                final relays = snapshot.data ?? const <Relay>[];
                if (relays.isEmpty) return _listaVazia(context);
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  itemCount: relays.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final relay = relays[i];
                    return Material(
                      color: IdentidadeVisual.campo,
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        title: Text(
                          relay.url,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: IdentidadeVisual.texto,
                          ),
                        ),
                        subtitle: Text(
                          _descrever(relay),
                          style: TextStyle(
                            fontSize: 12,
                            color: relay.status == RelayStatus.unavailable
                                ? Theme.of(context).colorScheme.error
                                : IdentidadeVisual.textoSuave,
                          ),
                        ),
                        leading: relay.isDefault
                            ? const Tooltip(
                                message: 'Relay da lista padrão',
                                child: Icon(
                                  Icons.star_outline,
                                  color: IdentidadeVisual.roxo,
                                ),
                              )
                            : const Icon(
                                Icons.person_outline,
                                color: IdentidadeVisual.roxo,
                              ),
                        trailing: IconButton(
                          tooltip: 'Remover',
                          color: IdentidadeVisual.roxo,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _remover(relay.url),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _listaVazia(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 48,
              color: IdentidadeVisual.textoSuave,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhum relay configurado',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: IdentidadeVisual.texto,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sem relays o aplicativo não alcança motoristas. Acrescente um '
              'endereço acima ou volte à lista padrão.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: IdentidadeVisual.texto),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: IdentidadeVisual.estiloAcaoPrimaria(),
              onPressed: _restaurarPadrao,
              child: const Text('Restaurar lista padrão'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _adicionar() async {
    final resultado = await widget.repository.add(_controller.text);

    switch (resultado) {
      case AddRelayResult.invalid:
        setState(() => _erro = 'Endereço inválido. Use wss:// ou ws://.');
      case AddRelayResult.duplicate:
        setState(() => _erro = 'Este relay já está na lista.');
      case AddRelayResult.added:
        final adicionado = widget.repository.relays.last;
        setState(() {
          _erro = null;
          _controller.clear();
        });
        await widget.relayService.add(adicionado);
    }
  }

  Future<void> _remover(String url) async {
    await widget.repository.remove(url);
    await widget.relayService.remove(url);
  }

  Future<void> _restaurarPadrao() async {
    await widget.repository.restoreDefaults();
    await widget.relayService.start(widget.repository.relays);
    widget.relayService.enableAutoRetry();
  }

  static String _descrever(Relay relay) => switch (relay.status) {
    RelayStatus.connecting => 'Conectando…',
    RelayStatus.connected => 'Conectado',
    RelayStatus.unavailable =>
      'Indisponível — ${relay.lastError ?? "motivo desconhecido"}',
  };
}

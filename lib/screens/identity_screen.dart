import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:passenger/screens/identidade_visual.dart';

import 'package:passenger/domain/identity.dart';

/// Exibe a identidade Nostr do passageiro.
///
/// Mostra **apenas** a chave pública, em formato legível e copiável (FR-006).
/// A chave privada não é exibida nem tem widget que possa revelá-la: o
/// Princípio I da constituição é não negociável, e a tela simplesmente não a
/// recebe em lugar algum da árvore.
class IdentityScreen extends StatelessWidget {
  const IdentityScreen({required this.identity, super.key});

  final Identity identity;

  @override
  Widget build(BuildContext context) {
    return TelaDeConteudo(
      tituloBarra: 'Caronas Passageiro',
      titulo: 'Minha identidade',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              'Chave pública',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: IdentidadeVisual.texto,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'É o seu identificador na rede Nostr. Pode ser compartilhada '
              'livremente.',
              style: TextStyle(
                fontSize: 12,
                color: IdentidadeVisual.textoSuave,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: IdentidadeVisual.campo,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(
              identity.publicKey,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                height: 1.4,
                color: IdentidadeVisual.texto,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: IdentidadeVisual.estiloAcaoPrimaria(),
            onPressed: () => _copiar(context),
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copiar chave pública'),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              'Sobre a sua chave privada',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: IdentidadeVisual.texto,
              ),
            ),
          ),
          const Text(
            'A chave privada é o que assina os seus eventos — ela é você nesta '
            'rede. Fica guardada apenas no armazenamento protegido deste '
            'aparelho e não é exibida.',
            style: TextStyle(fontSize: 12, color: IdentidadeVisual.textoSuave),
          ),
          const SizedBox(height: 12),
          Text(
            'Desinstalar o aplicativo apaga a chave privada e, com ela, a sua '
            'identidade: ao reinstalar, uma identidade nova é criada e a '
            'anterior não pode ser recuperada.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copiar(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: identity.publicKey));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Chave pública copiada.')));
  }
}

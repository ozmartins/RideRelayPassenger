import 'package:flutter/material.dart';

import 'package:passenger/domain/user_profile.dart';
import 'package:passenger/screens/identidade_visual.dart';

/// Pede ou altera o nome/apelido de exibição do usuário (FR-002, FR-005).
///
/// A mesma tela serve às duas jornadas — criar (primeira execução,
/// [initialName] nulo) e editar (nome atual em [initialName]) — porque
/// validação e layout são idênticos (decisão D2 de
/// specs/003-nome-usuario/research.md).
class NameScreen extends StatefulWidget {
  const NameScreen({required this.onSave, this.initialName, super.key});

  /// Nome atual, ou `null` na primeira execução.
  final String? initialName;

  /// Persiste o nome. Lançar sinaliza falha: a tela permanece aberta e
  /// mostra o erro, em vez de perder o texto digitado (FR-010).
  final Future<void> Function(String name) onSave;

  bool get _editando => initialName != null;

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  late final _controller = TextEditingController(
    text: widget.initialName ?? '',
  );
  String? _erro;
  var _salvando = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final UserProfile perfil;
    try {
      perfil = UserProfile.fromInput(_controller.text);
    } on ArgumentError catch (e) {
      setState(() => _erro = e.message.toString());
      return;
    }

    setState(() {
      _erro = null;
      _salvando = true;
    });

    try {
      await widget.onSave(perfil.displayName);
    } on Object {
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _erro = 'Não foi possível salvar o nome. Tente novamente.';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _salvando = false);
    // Modo criação: a tela é a raiz do app (não foi empilhada), e é quem a
    // exibiu que decide trocar para a tela principal ao ver o nome salvo.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget._editando;
    return TelaDeConteudo(
      tituloBarra: 'Caronas Passageiro',
      titulo: editando ? 'Alterar nome' : 'Como podemos te chamar?',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!editando)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Esse nome ou apelido é usado só neste aparelho, para você '
                  'se identificar dentro do app.',
                  style: TextStyle(fontSize: 15, color: IdentidadeVisual.texto),
                ),
              ),
            TextField(
              controller: _controller,
              autofocus: !editando,
              style: IdentidadeVisual.estiloValor,
              decoration: decoracaoCampo(
                rotulo: 'Nome ou apelido',
                dica: 'Seu nome ou apelido',
                erro: _erro,
              ),
              onSubmitted: (_) => _salvando ? null : _salvar(),
            ),
            const Spacer(),
            FilledButton(
              style: IdentidadeVisual.estiloAcaoPrimaria(),
              onPressed: _salvando ? null : _salvar,
              child: _salvando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(editando ? 'Salvar' : 'Continuar'),
            ),
          ],
        ),
      ),
    );
  }
}

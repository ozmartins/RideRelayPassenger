import 'package:flutter/material.dart';

import 'package:passenger/domain/identity.dart';
import 'package:passenger/domain/relay.dart';
import 'package:passenger/screens/identidade_visual.dart';
import 'package:passenger/screens/identity_screen.dart';
import 'package:passenger/screens/name_screen.dart';
import 'package:passenger/screens/relays_screen.dart';
import 'package:passenger/services/relay_repository.dart';
import 'package:passenger/services/relay_hub.dart';
import 'package:passenger/shared/app_info.dart';

/// Tela "Mais" do passageiro: estado das conexões e o menu de acesso a
/// nome, identidade e relays. A reconexão manual fica na tela de relays.
///
/// A lista de eventos recebidos e a publicação de teste, que já estiveram
/// aqui, saíram (feature 013): o usuário final não precisa delas, e o
/// `EventFeed` segue alimentando o mapa por baixo.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.relayService,
    this.relayRepository,
    this.identity,
    this.displayName,
    this.onSaveName,
    super.key,
  });

  final RelayHub relayService;

  /// Opcionais para que os testes de widget montem a tela sem precisar de
  /// armazenamento ou identidade.
  final RelayRepository? relayRepository;
  final Identity? identity;

  /// Nome/apelido atual do usuário. O item de alterar nome só aparece quando
  /// ambos [displayName] e [onSaveName] são fornecidos (FR-005).
  final String? displayName;

  /// Persiste um novo nome, reaproveitado pela `NameScreen` em modo edição.
  final Future<void> Function(String)? onSaveName;

  void _abrir(BuildContext context, Widget tela) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => tela));
  }

  @override
  Widget build(BuildContext context) {
    return TelaDeConteudo(
      tituloBarra: appDisplayName,
      titulo: 'Mais',
      child: StreamBuilder<List<Relay>>(
        stream: relayService.relays,
        initialData: relayService.current,
        builder: (context, snapshot) {
          final relays = snapshot.data ?? const <Relay>[];
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _FaixaConexao(relays: relays),
              if (displayName != null && onSaveName != null)
                _ItemDeMenu(
                  tooltip: 'Meu nome',
                  icone: Icons.person_outline,
                  titulo: 'Meu nome',
                  subtitulo: displayName!,
                  onTap: () => _abrir(
                    context,
                    NameScreen(initialName: displayName, onSave: onSaveName!),
                  ),
                ),
              if (identity != null)
                _ItemDeMenu(
                  tooltip: 'Minha identidade',
                  icone: Icons.badge_outlined,
                  titulo: 'Minha identidade',
                  subtitulo: 'Sua chave pública na rede',
                  onTap: () =>
                      _abrir(context, IdentityScreen(identity: identity!)),
                ),
              if (relayRepository != null)
                _ItemDeMenu(
                  tooltip: 'Relays',
                  icone: Icons.dns_outlined,
                  titulo: 'Relays',
                  subtitulo: 'Servidores por onde o app se comunica',
                  onTap: () => _abrir(
                    context,
                    RelaysScreen(
                      repository: relayRepository!,
                      relayService: relayService,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Cartão de menu: o "cartão de lista" da identidade, com seta à direita.
class _ItemDeMenu extends StatelessWidget {
  const _ItemDeMenu({
    required this.tooltip,
    required this.icone,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  final String tooltip;
  final IconData icone;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: IdentidadeVisual.campo,
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            leading: Icon(icone, color: IdentidadeVisual.roxo),
            title: Text(
              titulo,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: IdentidadeVisual.texto,
              ),
            ),
            subtitle: Text(
              subtitulo,
              style: const TextStyle(
                fontSize: 12,
                color: IdentidadeVisual.textoSuave,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: IdentidadeVisual.roxo,
            ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

/// Resumo do estado das conexões no topo da tela.
class _FaixaConexao extends StatelessWidget {
  const _FaixaConexao({required this.relays});

  final List<Relay> relays;

  @override
  Widget build(BuildContext context) {
    if (relays.isEmpty) {
      return _faixa(
        context,
        alerta: true,
        icone: Icons.cloud_off,
        texto: 'Nenhum relay configurado. Acrescente um na tela de relays.',
      );
    }

    final conectados = relays
        .where((r) => r.status == RelayStatus.connected)
        .length;
    if (conectados > 0) {
      return _faixa(
        context,
        alerta: false,
        icone: Icons.cloud_done_outlined,
        texto: '$conectados de ${relays.length} relays conectados',
      );
    }

    final tentando = relays.any((r) => r.status == RelayStatus.connecting);
    return _faixa(
      context,
      alerta: true,
      icone: tentando ? Icons.wifi_find : Icons.wifi_off,
      texto: tentando
          ? 'Conectando aos relays…'
          : 'Sem conexão com nenhum relay. Verifique se o aparelho está '
                'conectado à internet e tente novamente.',
    );
  }

  Widget _faixa(
    BuildContext context, {
    required bool alerta,
    required IconData icone,
    required String texto,
  }) {
    final cor = alerta
        ? Theme.of(context).colorScheme.error
        : IdentidadeVisual.roxo;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      decoration: BoxDecoration(
        color: IdentidadeVisual.campo,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icone, color: cor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 13,
                color: alerta ? cor : IdentidadeVisual.texto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

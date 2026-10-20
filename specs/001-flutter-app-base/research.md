# Phase 0 — Research: Base do Aplicativo do Passageiro

Nenhum item do Technical Context ficou como NEEDS CLARIFICATION. As decisões abaixo consolidam o que
foi verificado no ambiente real de desenvolvimento, o que foi decidido na clarificação do spec e o que
foi herdado por simetria da feature equivalente do motorista
(`Prototipo/driver/specs/001-flutter-app-base/research.md`).

**Princípio transversal**: as duas apps do protótipo não compartilham código nem backend — só se falam
por eventos Nostr. Divergir gratuitamente de versão de toolchain, layout ou convenção entre elas
aumentaria o custo de manter idênticos os formatos de evento que serão definidos nas features de
comunicação. Por isso, onde não há motivo para divergir, o passageiro espelha o motorista.

## D1 — Versão do Flutter/Dart

- **Decision**: Flutter 3.47.4 (canal stable) com Dart 3.13.3.
- **Rationale**: verificado nesta sessão via `flutter --version` na máquina do autor; é exatamente a
  mesma versão registrada na feature do motorista, mantendo as duas apps sobre um único toolchain. A
  versão fica registrada no README para reprodutibilidade por terceiros (SC-001).
- **Alternatives considered**: fixar via FVM — descartado como complexidade desnecessária para um
  protótipo com um único desenvolvedor; canal beta/master — descartado por instabilidade em trabalho
  acadêmico avaliado.

## D2 — Escopo de plataformas

- **Decision**: gerar apenas `android/` (`flutter create --platforms android`).
- **Rationale**: decidido na clarificação (Android apenas). `flutter doctor` nesta sessão confirma
  Android toolchain ✓ (Android SDK 37.0.0) e um dispositivo conectado, enquanto Chrome e o toolchain
  Linux desktop estão ausentes — plataformas que não podem ser compiladas nem validadas não devem
  entrar no repositório como artefatos mortos (FR-005). iOS exigiria macOS, indisponível.
- **Alternatives considered**: gerar todas as plataformas por padrão — descartado por deixar ~5
  diretórios nunca compilados no repositório do TCC; incluir web — descartado por ausência de Chrome
  configurado e por o alvo do trabalho ser mobilidade em dispositivo móvel.

## D3 — Identificador e nome do aplicativo

- **Decision**: `--org br.ufsc.tcc.corridas` + nome de projeto `passenger` → `applicationId`
  `br.ufsc.tcc.corridas.passenger`; nome de exibição "Corridas Passageiro" em
  `android/app/src/main/AndroidManifest.xml`.
- **Rationale**: o identificador `br.ufsc.tcc.corridas.passenger` já estava **reservado** pela feature do
  motorista justamente para esta app. `applicationId` distinto de `br.ufsc.tcc.corridas.driver` permite
  as duas apps instaladas no mesmo aparelho, condição necessária para testar a troca de eventos Nostr
  ponta a ponta nas features futuras (FR-010). O `applicationId` é derivado automaticamente por
  `flutter create` a partir de `--org` + nome do projeto, sem edição manual.
- **Alternatives considered**: editar o `applicationId` manualmente depois — descartado por ser mais
  trabalhoso e propenso a ficar inconsistente com o namespace Kotlin/Gradle gerado; escolher um
  namespace novo só para o passageiro — descartado por quebrar a simetria já registrada no motorista.

## D4 — Nome do pacote Dart

- **Decision**: nome do pacote `passenger` (`--project-name passenger`), igual ao diretório.
- **Rationale**: o diretório já é `Prototipo/passenger`; `passenger` é um identificador Dart válido
  (minúsculas, sem hífen) e mantém os imports internos curtos (`package:passenger/...`). Espelha a
  decisão D4 do motorista.
- **Alternatives considered**: `corridas_passenger` — mais descritivo, mas divergiria do nome do
  diretório e do caminho já consolidado no CLAUDE.md do repositório.

## D5 — `flutter create` sobre diretório não vazio

- **Decision**: rodar `flutter create` no diretório existente `Prototipo/passenger`, que já contém
  `.specify/`, `.claude/` e `specs/`.
- **Rationale**: `flutter create` em diretório existente adiciona os arquivos que faltam e não remove
  conteúdo não relacionado; manter o scaffold do spec-kit e a app no mesmo diretório é necessário
  porque as skills `speckit-*` exigem `.specify/` na raiz do projeto.
- **Risco/mitigação**: o `.gitignore` gerado pelo Flutter sobrescreveria um `.gitignore` local
  existente — verificado nesta sessão que `Prototipo/passenger/` não contém nenhum, então não há perda.
  Após a geração, conferir com `git status` que nada em `.specify/`, `.claude/` ou `specs/` foi alterado.
- **Alternatives considered**: gerar em diretório temporário e copiar — descartado por ser equivalente
  com passos extras.

## D6 — Conteúdo da tela "vazia"

- **Decision**: substituir o app de contador do template por um `MaterialApp` com `title`
  "Corridas Passageiro", `AppBar` com o mesmo título e um corpo centralizado com uma mensagem de
  placeholder identificando o app do passageiro. Sem `FloatingActionButton`, sem `setState`, sem
  contador.
- **Rationale**: "vazio" no spec significa sem lógica de negócio (FR-002); deixar o contador gerado
  seria lógica de exemplo sem propósito, que o avaliador do TCC leria como código morto — e FR-003 o
  proíbe explicitamente. O `Scaffold`/`AppBar` mínimo usa o tema do sistema, satisfazendo o edge case
  de tema escuro sem inventar UI de produto.
- **Alternatives considered**: `Container` cru sem `MaterialApp` — descartado por não exibir título nem
  respeitar tema do sistema; manter o contador — descartado como boilerplate morto.

## D7 — Estrutura de diretórios de `lib/`

- **Decision**: `lib/main.dart` (ponto de entrada + widget raiz), `lib/screens/home_screen.dart`
  (interface) e `lib/shared/app_info.dart` (constantes de identidade do app, consumidas pelos dois).
- **Rationale**: FR-008 exige separação explícita entre ponto de entrada, telas/interface e código
  compartilhado. O `lib/shared/app_info.dart` não é pasta vazia de enfeite: centraliza o nome de
  exibição usado em `MaterialApp.title`, na `AppBar` e assertado pelo teste, evitando a string duplicada
  em três lugares. Esta é a **única divergência deliberada** em relação ao motorista (que é plano, com
  tudo em `main.dart`), e decorre de um requisito explícito do spec do passageiro.
- **Alternatives considered**: `lib/` plano como no motorista — rejeitado por conflitar com FR-008;
  camadas completas (`models/`, `services/`, `repositories/`) — descartado por serem diretórios sem
  consumidor nesta etapa, dado que a feature tem zero entidades de domínio.

## D8 — Estratégia de teste

- **Decision**: um widget test (`test/home_screen_test.dart`) que monta o app e verifica que o título da
  tela inicial é exibido e que nenhum widget de contador do template sobreviveu; `flutter analyze` com
  `flutter_lints` como gate de análise estática.
- **Rationale**: atende FR-006/FR-007 e SC-003 com o menor custo possível; o teste protege contra a
  regressão mais provável nesta base (alguém reintroduzir o boilerplate ou quebrar o build da tela).
  Testes de integração/`integration_test` não se justificam sem fluxo de usuário real.
- **Alternatives considered**: nenhum teste — rejeitado por FR-006; `integration_test` no emulador —
  descartado como desproporcional para uma tela estática e por exigir emulador em CI.

## D9 — Dependências de terceiros

- **Decision**: nenhuma. Apenas `flutter`, `cupertino_icons` (se vier do template) e, em dev,
  `flutter_test` + `flutter_lints`.
- **Rationale**: FR-011 proíbe explicitamente dependências de rede, Nostr ou criptografia nesta etapa.
  Escolher agora gerenciador de estado, cliente Nostr ou roteador seria decisão arquitetural sem
  requisito que a sustente — e a viabilidade de cada biblioteca Nostr é justamente objeto de
  investigação do TCC, não algo a fixar no scaffold.
- **Alternatives considered**: já adicionar Provider/Riverpod/Bloc e uma biblioteca Nostr (ex.:
  `dart_nostr`) — descartado como decisão prematura; o spec-kit já prevê features futuras onde essa
  escolha será fundamentada.

### D9-R1 — Revisão: `dart_nostr` adicionado (2026-09-15)

- **Status de D9**: **parcialmente superada**. A parte "nenhuma dependência de terceiros" deixou de
  valer; a parte sobre gerenciador de estado e roteador continua valendo — nenhum foi adicionado.
- **Decision**: adicionar `dart_nostr: ^10.0.1` às dependências de produção, por decisão do autor
  tomada após a conclusão desta feature.
- **Rationale**: a escolha da biblioteca Nostr é caminho crítico do TCC — é ela que determina se o
  protótipo consegue assinar eventos, conectar a relays e gerenciar chaves. Antecipar a instalação
  permite começar a investigar viabilidade sem esperar a especificação da próxima feature. A
  biblioteca foi verificada empiricamente antes de ser aceita: um teste de fumaça descartável
  confirmou geração de par de chaves, assinatura de evento (`NostrEvent.fromPartialData`) e
  verificação de assinatura (`isVerified()`).
- **Consequências medidas**: 17 dependências transitivas, das quais as relevantes são
  `web_socket_channel` (relays), `pointycastle` + `crypto` (secp256k1, SHA-256) e `http`.
  `flutter analyze` continua sem violações, os 2 testes de widget continuam passando, e os builds
  debug e release continuam compilando. O comportamento do app não mudou: nenhum código de `lib/`
  importa a biblioteca ainda.
- **Pendência conhecida — permissão de rede**: o APK de **release não declara**
  `android.permission.INTERNET`. Em debug a permissão existe, mas vem de
  `android/app/src/debug/AndroidManifest.xml`, que o Flutter gera para o hot reload — não da
  biblioteca. Consequência: a primeira conexão a um relay funcionará em debug e **falhará
  silenciosamente em release** até que se acrescente
  `<uses-permission android:name="android.permission.INTERNET"/>` a
  `android/app/src/main/AndroidManifest.xml`. A permissão foi deliberadamente **não** adicionada
  agora, porque o app ainda não acessa a rede e declarar permissão antes do uso é decisão que
  merece justificativa própria na discussão de privacidade do trabalho.
- **Impacto em FR-011**: o requisito "o projeto MUST NOT introduzir dependência de rede, Nostr ou
  criptografia" fica registrado como **superado por esta revisão**, não como violado — ele descrevia
  corretamente o escopo da base no momento em que ela foi entregue e validada. Ver a nota
  correspondente em `spec.md`.
- **Alternatives considered**: especificar uma nova feature spec-kit antes de instalar — caminho mais
  ortodoxo, descartado pelo autor por burocratizar um passo exploratório; manter a base inerte e
  instalar só quando a feature de comunicação começasse — descartado por adiar a investigação de
  viabilidade, que é o objeto do TCC.

## D10 — Verificação de ambiente

- **Decision**: o README documenta `flutter doctor` como primeiro passo e registra que apenas o grupo
  "Android toolchain" precisa estar ✓ (Chrome/Linux desktop podem falhar sem impacto).
- **Rationale**: atende o edge case de ambiente sem SDK configurado, apontando explicitamente o que
  falta em vez de falhar de forma obscura. Sustenta SC-001 (15 minutos do clone ao app rodando).
- **Alternatives considered**: script próprio de checagem — desnecessário, `flutter doctor` já faz isso.

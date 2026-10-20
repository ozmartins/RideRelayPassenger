# Phase 1 — Data Model: Base do Aplicativo do Passageiro

## Entidades de domínio

**Nenhuma.** O spec declara explicitamente (seção Key Entities) que esta feature não introduz dados
persistidos nem entidades de domínio. Não há banco de dados, armazenamento local, cache, nem modelo de
usuário, corrida ou chave criptográfica nesta etapa — tudo isso é escopo das features seguintes.

## Estado da aplicação

O app é deliberadamente **sem estado**: nenhuma variável muda em resposta a interação do usuário
(FR-002, FR-003). A tela inicial é um `StatelessWidget`.

| Elemento | Tipo | Mutabilidade | Valor / observação |
|---|---|---|---|
| Nome de exibição do app | constante de compilação (`String`) | imutável | `"Corridas Passageiro"`; definido em `lib/shared/app_info.dart`, consumido por `MaterialApp.title`, pela `AppBar` e pelo teste de widget |
| Mensagem de placeholder da tela inicial | constante de compilação (`String`) | imutável | texto curto identificando o app do passageiro no corpo da tela |
| Tema | derivado do sistema operacional | reativo (framework) | `ThemeMode.system`; sem tema customizado, garantindo legibilidade em claro e escuro |

Por não haver estado mutável, não há transições de estado, ciclo de vida de entidade nem regras de
validação a modelar nesta feature.

## Identidade do aplicativo (configuração, não dado)

Estes valores são configuração de build e identidade de produto — registrados aqui porque FR-010 os
torna verificáveis e porque precisam permanecer coerentes com a app irmã.

- `applicationId` / namespace Android: `br.ufsc.tcc.corridas.passenger`
- nome do pacote Dart: `passenger` (imports como `package:passenger/screens/home_screen.dart`)
- nome de exibição (`android:label`): `Corridas Passageiro`
- identificador irmão, já existente (fora desta feature): `br.ufsc.tcc.corridas.driver` / "Corridas Motorista"

O namespace comum `br.ufsc.tcc.corridas` com sufixos distintos é o que permite as duas apps coexistirem
no mesmo dispositivo — pré-requisito para os testes ponta a ponta de troca de eventos Nostr das features
futuras.

## Nota de arquitetura para as próximas features

Quando entidades aparecerem (perfil de usuário, par de chaves, oferta de corrida, solicitação, mensagem),
elas **não** serão compartilhadas por um backend: não existe servidor no protótipo. Cada entidade
trafegada entre as duas apps é, na prática, um **formato de evento Nostr** (kind, tags, conteúdo
criptografado) que precisa ser replicado de forma idêntica nas apps do motorista e do passageiro. Mudou
o formato de um lado, muda no outro na mesma alteração.

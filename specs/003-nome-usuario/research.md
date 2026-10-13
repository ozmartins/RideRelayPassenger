# Phase 0 Research: Nome do Usuário no Passageiro

Não há nenhum `NEEDS CLARIFICATION` no Technical Context do `plan.md` — a feature não introduz
tecnologia nova. Esta pesquisa registra as duas decisões de design ainda assim tomadas, conforme
exige o Princípio V (decisão não óbvia registrada com alternativas descartadas).

## D1 — Mecanismo de armazenamento do nome

**Decisão**: reaproveitar `KeyValueStore`/`PrefsKeyValueStore` (decisão D3 de
`specs/002-nostr-relay-connection/research.md`, que já escolheu `shared_preferences` para dados
não sensíveis do app) para persistir o nome sob uma nova chave (ex.: `user_display_name`).

**Rationale**: o nome/apelido não é material criptográfico (não é a chave privada nem deriva
dela) — o Princípio I não se aplica a ele. `flutter_secure_storage`/`SecureStore` já é usado
exclusivamente para a identidade Nostr (`IdentityService`); usá-lo aqui misturaria, no mesmo
armazenamento protegido, um segredo com um dado de exibição, sem necessidade. `KeyValueStore` já
é a abstração usada por `RelayRepository` para um dado local não sensível (a lista de relays
escolhida pelo usuário), que é exatamente a mesma categoria de dado que o nome.

**Alternatives considered**:
- **`flutter_secure_storage`/`SecureStore`** — descartado: não é segredo, e usá-lo ampliaria sem
  motivo a superfície do Princípio I (mais um dado que precisaria ser auditado como "não pode
  vazar", quando na verdade pode ser lido/exibido livremente).
- **Nova dependência (ex.: `sqflite`, como o app do motorista usa para o cadastro do
  motorista)** — descartada: um único campo de texto não justifica um banco relacional; o
  `driver/` usa SQLite porque seu cadastro tem múltiplos campos estruturados (nome, UF/cidade,
  dados do veículo), o que não é o caso aqui. Introduzir `sqflite` só para isso violaria o
  Princípio V (estrutura sem consumidor proporcional) e exigiria uma nova entrada de decisão de
  dependência de terceiros sem necessidade real.

## D2 — Uma tela única para criação e edição, versus duas telas separadas

**Decisão**: uma única `NameScreen`, parametrizada por um `initialName` opcional (`null` na
primeira execução, valor atual na edição), com o texto do botão e do título variando conforme o
modo.

**Rationale**: as duas jornadas (US1 e US2 do spec) pedem o mesmo formulário — um campo de texto,
a mesma validação (não vazio após trim, limite de 60 caracteres) e a mesma ação de salvar. Ter
duas telas duplicaria a lógica de validação e o layout sem nenhum ganho, o que o Princípio V
proíbe (estrutura sem consumidor além da conveniência de nomear a rota de outro jeito).

**Alternatives considered**:
- **Duas telas (`FirstNameScreen` e `EditNameScreen`)** — descartada: mesma validação e mesmo
  layout, diferindo só em texto e em navegação de saída (uma navega para a `HomeScreen`, a outra
  faz `pop`); a diferença cabe inteira em um parâmetro, não em duas classes.

# Feature Specification: Nome do Usuário no Passageiro

**Feature Branch**: `003-nome-usuario`

**Created**: 2026-09-17

**Status**: Draft

**Input**: User description: "Modifique o app do passageiro de modo que solicite o nome (ou apelido) do usuário na primeira execução do app. Uma tela para a mudança deste nome também deve ser criada."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Informar o nome na primeira abertura (Priority: P1)

Uma pessoa instala e abre o app do passageiro pela primeira vez. Antes de chegar à tela
principal, o app pede que ela informe um nome ou apelido pelo qual quer ser identificada.
Depois de confirmar, o app guarda esse nome e segue para a tela principal normalmente.

**Why this priority**: Sem essa etapa não existe identidade legível de usuário no app — é o
pré-requisito para qualquer tela ou evento que precise exibir "quem" está usando o app. É o
núcleo mínimo da funcionalidade.

**Independent Test**: Instalar o app do zero (sem dados persistidos), abrir, verificar que a
tela de nome aparece antes da tela principal, informar um nome, confirmar, e verificar que a
tela principal é exibida em seguida.

**Acceptance Scenarios**:

1. **Given** o app está sendo aberto pela primeira vez (nenhum nome salvo), **When** a pessoa
   abre o app, **Then** a tela de solicitação de nome é exibida antes de qualquer outra tela.
2. **Given** a tela de solicitação de nome está visível, **When** a pessoa digita um nome válido
   e confirma, **Then** o nome é salvo e a tela principal do app é exibida.
3. **Given** a tela de solicitação de nome está visível, **When** a pessoa tenta confirmar sem
   digitar nada, **Then** o app impede a confirmação e indica que o nome é obrigatório.

---

### User Story 2 - Alterar o nome depois de já cadastrado (Priority: P2)

Uma pessoa que já usa o app quer mudar o nome ou apelido que informou anteriormente. Ela acessa
uma tela dedicada a isso, vê o nome atual preenchido, edita e salva a mudança.

**Why this priority**: Depende do nome já existir (User Story 1), mas entrega valor próprio:
sem ela, um nome digitado errado ou desatualizado ficaria travado para sempre.

**Independent Test**: Com um nome já salvo, abrir a tela de alteração de nome, verificar que o
nome atual aparece preenchido, trocar por outro valor, salvar, fechar e reabrir o app, e
verificar que o novo nome persiste.

**Acceptance Scenarios**:

1. **Given** o app já tem um nome salvo, **When** a pessoa abre a tela de alteração de nome,
   **Then** o campo aparece preenchido com o nome atualmente salvo.
2. **Given** a tela de alteração de nome está aberta, **When** a pessoa troca o valor por um
   nome válido diferente e salva, **Then** o novo nome passa a ser o nome salvo do usuário.
3. **Given** a tela de alteração de nome está aberta, **When** a pessoa apaga o campo e tenta
   salvar, **Then** o app impede o salvamento e indica que o nome é obrigatório.
4. **Given** a pessoa está na tela de alteração de nome, **When** ela sai da tela sem salvar,
   **Then** o nome anteriormente salvo permanece inalterado.

---

### Edge Cases

- O que acontece se a pessoa fechar o app (ou o app for encerrado pelo sistema) no meio da tela
  de primeira abertura, antes de confirmar o nome? Na próxima abertura, a tela de solicitação de
  nome deve aparecer novamente, já que nenhum nome foi salvo.
- O que acontece se a pessoa digitar um nome contendo apenas espaços em branco? Deve ser tratado
  como campo vazio e recusado, na primeira abertura e na tela de alteração.
- O que acontece se a pessoa informar um nome muito longo? O app deve limitar o tamanho aceito
  (ver FR-006) para evitar problemas de exibição nas telas que mostrarão esse nome no futuro.
- O que acontece se o armazenamento do nome falhar (ex.: erro de disco/permissão)? A pessoa deve
  ver uma mensagem de erro e permanecer na tela até conseguir salvar com sucesso.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O app MUST verificar, a cada abertura, se já existe um nome de usuário salvo.
- **FR-002**: Quando não existir nome salvo, o app MUST exibir a tela de solicitação de nome
  antes de exibir a tela principal.
- **FR-003**: A tela de solicitação de nome MUST exigir que a pessoa informe um valor não vazio
  (após remover espaços nas extremidades) antes de permitir a confirmação.
- **FR-004**: Ao confirmar um nome válido na primeira abertura, o app MUST persistir esse nome
  localmente e navegar para a tela principal.
- **FR-005**: O app MUST fornecer uma tela separada, acessível a partir da tela principal, para
  alterar o nome já salvo.
- **FR-006**: A tela de alteração de nome MUST pré-carregar o campo com o nome atualmente salvo
  e MUST aplicar o mesmo limite de tamanho e a mesma validação de não vazio usados na primeira
  abertura (limite: 60 caracteres).
- **FR-007**: Ao salvar um novo nome válido na tela de alteração, o app MUST substituir o nome
  anteriormente salvo pelo novo valor.
- **FR-008**: Se a pessoa sair da tela de alteração de nome sem salvar, o app MUST manter o nome
  anteriormente salvo sem alterações.
- **FR-009**: O nome salvo MUST persistir entre execuções do app (sobreviver ao fechamento e
  reabertura do app).
- **FR-010**: Se a tentativa de salvar o nome (primeira abertura ou alteração) falhar, o app
  MUST exibir uma mensagem de erro para a pessoa e MUST manter a pessoa na tela até que o
  salvamento seja concluído com sucesso ou ela decida tentar novamente.

### Key Entities

- **Perfil do usuário (local)**: representa a identificação legível escolhida pela pessoa que
  usa o app do passageiro. Atributo principal: nome/apelido (texto). Não se confunde com a
  identidade criptográfica Nostr já existente no app (chave pública/privada) — é um dado
  complementar, apenas de exibição local, sem relação com o contrato de eventos Nostr.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% das primeiras aberturas do app (sem nome salvo) mostram a tela de
  solicitação de nome antes de qualquer outra tela.
- **SC-002**: Uma pessoa consegue informar o nome e chegar à tela principal em menos de 15
  segundos na primeira abertura.
- **SC-003**: Depois de salvar um nome (na primeira abertura ou na tela de alteração), o mesmo
  nome está presente em 100% das reaberturas subsequentes do app, até ser alterado de novo.
- **SC-004**: Uma pessoa consegue localizar e abrir a tela de alteração de nome a partir da tela
  principal em no máximo 2 toques/ações.

## Assumptions

- O nome/apelido é um dado local do app do passageiro, sem contrapartida no protocolo Nostr ou
  no app do motorista — não faz parte do contrato de eventos (`nostr-events.md`) e não precisa
  ser replicado no app do motorista, pois essa feature não toca esse contrato.
- Não há verificação de unicidade, formato específico (ex.: exigir nome completo) nem qualquer
  validação de conteúdo além de "não vazio" e limite de tamanho — qualquer texto dentro do
  limite é aceito.
- O armazenamento local já usado pelo app (mecanismo de chave-valor existente, via
  `KeyValueStore`/`SecureStore`, conforme já usado por outras preferências do app) é reaproveitado
  para persistir o nome; não é necessário um mecanismo de armazenamento novo nem uso do Android
  Keystore, já que o nome não é um segredo criptográfico.
- A tela de alteração de nome é acessada a partir da tela principal (`home_screen`) do app,
  seguindo o mesmo padrão de navegação já usado para acessar a tela de identidade e a tela de
  relays.
- Não há requisito de sincronizar o nome entre dispositivos ou reinstalações — ele é local ao
  aparelho, assim como a identidade Nostr atual.

# Feature Specification: Botões de cancelar corrida em roxo (passageiro)

**Feature Branch**: `024-botao-cancelar-roxo` (sem branch git: trabalho direto na `master`)

**Created**: 2026-10-07

**Status**: Draft

**Input**: User description: "Modifique a aparência dos botões que permitem cancelar uma corrida. Todos eles
devem ter o fundo roxo e uma cor de fonte que contraste com o roxo (já existem outros botões na aplicação com
esta aparência)." Contrapartida do passageiro da feature `022-botao-cancelar-roxo` do motorista.

## Clarifications

### Session 2026-10-07 (decisões tomadas antes da especificação, a partir do que o código mostra)

- Q: Quais botões que cancelam uma corrida existem hoje no app do passageiro? → A: três. (1) "Cancelar
  corrida" do mapa (feature 023): botão de texto com ícone e texto em `ColorScheme.error`, num cartão claro;
  (2) "Cancelar corrida" de confirmação da modal "Cancelar corrida?", que **já** usa a ação primária (roxo,
  texto branco); (3) "Cancelar" da lista de orçamentos recebidos (feature 015), hoje em vermelho cheio.
- Q: O botão (3) cancela uma "corrida"? → A: cancela a solicitação de corrida ainda sem motorista. Entra no
  escopo porque o pedido é "todos os botões que permitem cancelar uma corrida" e deixar só ele em vermelho
  contrariaria a intenção de unificar; o rótulo e o comportamento não mudam.
- Q: Qual roxo e qual cor de texto? → A: os da ação primária existente (fundo `roxo`, texto branco); nenhum
  valor de cor novo.
- Q: A constituição permite? → A: sim. A emenda 2.12.0 (commit `662fda7`, nas duas constituições) já trocou o
  componente "Botão de ação destrutiva" pelo "Botão de cancelamento de corrida" em roxo.
- Q: O cartão claro ao redor do botão do mapa continua? → A: sim; só o botão muda de aparência (posição,
  elevação e cartão intactos).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Botão de cancelar do mapa em roxo (Priority: P1)

Como passageiro com uma corrida aceita (orçamento aceito, motorista a caminho ou em corrida), quero que o
botão "Cancelar corrida" do mapa tenha fundo roxo e texto legível, como as demais ações do app.

**Why this priority**: é a parte visível mais frequente do pedido.

**Independent Test**: levar o app a cada um dos três estados e conferir fundo roxo e texto e ícone claros no
botão `botao-cancelar-corrida`.

**Acceptance Scenarios**:

1. **Given** a corrida em "orçamento aceito", "motorista a caminho" ou "em corrida", **When** o mapa é exibido,
   **Then** o botão "Cancelar corrida" tem fundo roxo da identidade visual e texto e ícone brancos.
2. **Given** o botão em roxo, **When** é tocado, **Then** abre a mesma confirmação de antes.

---

### User Story 2 - "Cancelar" da lista de orçamentos em roxo (Priority: P2)

Como passageiro aguardando orçamentos, quero que o botão "Cancelar" da lista tenha fundo roxo e texto claro.

**Why this priority**: mesma intenção, em outra tela.

**Independent Test**: abrir a lista de orçamentos recebidos (vazia ou não) e conferir as cores do botão.

**Acceptance Scenarios**:

1. **Given** a tela de orçamentos recebidos, **Then** o botão "Cancelar" tem fundo roxo e texto branco.
2. **Given** o botão, **When** tocado, **Then** o cancelamento da solicitação ocorre como antes.

---

### User Story 3 - Confirmação igual aos demais (Priority: P2)

Como passageiro, quero que o botão "Cancelar corrida" da confirmação seja igual ao do mapa.

**Independent Test**: comparar as cores resolvidas dos dois botões.

**Acceptance Scenarios**:

1. **Given** a confirmação "Cancelar corrida?", **Then** seu botão "Cancelar corrida" tem as mesmas cores de
   fundo e de texto que o do mapa.

---

### Edge Cases

- Botão desabilitado: não ocorre hoje; valeria o estilo de desabilitado das ações primárias.
- Tema do sistema (claro/escuro): o roxo é fixo; a cor do botão não muda com ele.
- Duplo toque, publicação do `kind: 20013`/`20004`, encerramento local e persistência: inalterados.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O botão "Cancelar corrida" do mapa MUST ter fundo roxo igual ao das demais ações primárias.
- **FR-002**: O botão "Cancelar" da lista de orçamentos recebidos MUST ter fundo roxo igual ao das demais
  ações primárias.
- **FR-003**: Texto e ícone de cada um MUST ter cor que contraste com o roxo, razão mínima de 4,5:1.
- **FR-004**: O botão "Cancelar corrida" da confirmação MUST manter fundo roxo e texto claro e MUST ter as
  mesmas cores do botão do mapa.
- **FR-005**: Todo botão do app que efetiva o cancelamento de uma corrida ou de uma solicitação MUST seguir
  FR-001 a FR-004.
- **FR-006**: Posição, largura, altura, rótulo, ícone, chave de teste e cartão do botão do mapa, e rótulo,
  ícone, posição e tamanho do "Cancelar" da lista, MUST permanecer; só as cores mudam.
- **FR-007**: Nenhum comportamento MUST mudar: quando cada botão aparece, o que o toque faz, o que é publicado,
  o estado e o que é persistido.

### Key Entities

Nenhuma.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Em 100 % das exibições dos botões do mapa e da lista, fundo roxo da identidade visual e texto e
  ícone brancos.
- **SC-002**: Razão de contraste texto/fundo ≥ 4,5:1 (branco sobre o roxo dá cerca de 6:1), verificada por
  teste automatizado.
- **SC-003**: Os três botões têm as mesmas cores de fundo e de texto, verificado por teste automatizado.
- **SC-004**: Nenhum teste de comportamento do cancelamento precisa mudar além da cor esperada e do localizador
  do botão da confirmação (que deixa de ser único por tipo e rótulo).
- **SC-005**: A aparência final dos botões de cancelar do passageiro é a mesma do motorista (mesma cor, texto
  e forma).

## Assumptions

- "Roxo" e "cor que contrasta" são os da ação primária existente (branco sobre `roxo`).
- O botão da lista de orçamentos entra no escopo (ver Clarifications); se o autor não o quiser, basta retirar
  a User Story 2.
- Sem contrato, sem contrapartida obrigatória no motorista (que tem a feature `022-botao-cancelar-roxo`).
- Validação em aparelho pode ficar pendente; os testes de widget cobrem as cores.

# Feature Specification: Busca de Endereço via Photon

**Feature Branch**: `005-busca-endereco-photon`

**Created**: 2026-09-17

**Status**: Draft

**Input**: User description: "Existe uma API chamada Photon que retorna dados relacionados a geolocalização. Modifique o campo de busca de endereço do app do passageiro de modo que ele use a referida API para obter um endereço específico a partir do texto digitado pelo usuário. Portanto, o endereço de destino não será o que o usuário digitou propriamente dito, mas sim o endereço retornado pela Photon API (com base no texto informado pelo usuário) e que foi explicitamente selecionado (clicado) pelo usuário."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver sugestões de endereço enquanto digita (Priority: P1)

O passageiro digita um trecho do endereço de destino no campo de texto da tela
inicial e, conforme digita, vê uma lista de endereços correspondentes,
buscados pelo serviço de geocodificação Photon a partir do texto informado.

**Why this priority**: É a base de toda a feature — sem sugestões buscadas a
partir do texto, não há o que selecionar. Sem isso, o app continua com o
campo de texto livre da feature 004, que é exatamente o que esta feature
substitui.

**Independent Test**: Digitar um trecho de endereço reconhecível no campo de
destino e verificar que aparece uma lista de endereços sugeridos, atualizada
conforme o texto muda, sem que nada seja gravado como destino ainda.

**Acceptance Scenarios**:

1. **Given** a tela inicial do passageiro está aberta, **When** o usuário
   digita um trecho de um endereço existente no campo de destino, **Then** o
   sistema exibe uma lista de endereços sugeridos correspondentes ao texto.
2. **Given** uma lista de sugestões já está visível, **When** o usuário
   continua digitando ou apaga parte do texto, **Then** a lista de sugestões
   é atualizada para refletir o novo texto.
3. **Given** o campo de destino está vazio, **When** o usuário não digitou
   nada, **Then** nenhuma lista de sugestões é exibida.

---

### User Story 2 - Selecionar um endereço sugerido como destino (Priority: P1)

O passageiro toca em um dos endereços sugeridos na lista, e esse endereço —
exatamente como retornado pelo serviço de geocodificação, não o texto que o
usuário havia digitado — passa a ser o destino da corrida.

**Why this priority**: É o objetivo final da feature: o destino registrado
precisa ser um endereço validado por geocodificação, nunca o texto bruto
digitado pelo usuário. Sem a seleção explícita, a busca da User Story 1 não
tem efeito prático.

**Independent Test**: Buscar um endereço, tocar em uma das sugestões e
verificar que o destino passa a ser exatamente o endereço da sugestão
selecionada — inclusive quando o texto da sugestão difere do texto
originalmente digitado (abreviações expandidas, complementos, etc.).

**Acceptance Scenarios**:

1. **Given** uma lista de sugestões de endereço está visível, **When** o
   usuário toca em uma das sugestões, **Then** o sistema registra aquele
   endereço específico como destino e mostra seu texto completo no campo.
2. **Given** um endereço já foi selecionado como destino, **When** o usuário
   volta a editar o texto do campo, **Then** a busca de sugestões recomeça a
   partir do novo texto e o destino permanece o último endereço
   explicitamente selecionado até que uma nova sugestão seja escolhida.
3. **Given** o usuário digitou um texto mas não tocou em nenhuma sugestão,
   **When** ele sai do campo ou continua usando o app, **Then** nenhum
   destino é registrado a partir do texto digitado por si só.

---

### User Story 3 - Lidar com buscas sem resultado ou com falha (Priority: P2)

Quando a busca não encontra nenhum endereço correspondente, ou quando o
serviço de geocodificação não responde, o passageiro recebe uma indicação
clara disso em vez de uma lista vazia sem explicação ou de uma tela travada.

**Why this priority**: Trata os casos de exceção do fluxo principal. Não
bloqueia o valor entregue pelas User Stories 1 e 2, mas evita que o
passageiro fique sem entender por que nenhuma sugestão aparece.

**Independent Test**: Digitar um texto sem correspondência real e verificar a
mensagem de "nenhum resultado"; simular indisponibilidade do serviço de
geocodificação e verificar a mensagem de falha, sem travamento da tela.

**Acceptance Scenarios**:

1. **Given** o usuário digitou um texto para o qual a busca não retorna
   nenhum endereço, **When** a busca é concluída, **Then** o sistema informa
   que nenhum endereço foi encontrado para aquele texto.
2. **Given** o serviço de geocodificação está indisponível ou a busca falha
   (ex.: sem conexão à internet), **When** o usuário digita um texto no
   campo de destino, **Then** o sistema informa que não foi possível buscar
   endereços no momento, sem travar a tela nem impedir nova tentativa.

---

### Edge Cases

- O que acontece se o usuário selecionar uma sugestão e, em seguida, apagar
  todo o texto do campo? O destino selecionado deixa de valer e volta ao
  estado "nenhum destino definido" (mesmo estado da abertura do app).
- O que acontece se duas sugestões tiverem o mesmo texto (endereços
  homônimos em bairros diferentes, por exemplo)? Cada sugestão é tratada
  como um endereço distinto e a seleção usa o item exato tocado pelo
  usuário, não apenas o texto exibido.
- O que acontece se o usuário digitar muito rápido? A busca não precisa
  disparar uma requisição a cada tecla digitada; é aceitável agrupar
  digitações próximas no tempo antes de buscar (ver Assumptions).
- O que acontece se a posição atual do passageiro não estiver disponível
  (permissão negada, GPS desligado)? A busca de endereço continua
  funcionando normalmente, sem depender da posição (mantém a garantia já
  existente da feature 004).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema MUST permitir que o passageiro digite texto livre no
  campo de destino da tela inicial.
- **FR-002**: O sistema MUST consultar o serviço de geocodificação Photon com
  o texto digitado pelo usuário e exibir os endereços retornados como uma
  lista de sugestões selecionáveis.
- **FR-003**: O sistema MUST atualizar a lista de sugestões conforme o texto
  digitado muda, sem exigir uma ação explícita de "buscar" além de digitar.
- **FR-004**: O destino da corrida MUST ser sempre um dos endereços
  retornados pelo serviço de geocodificação, nunca o texto bruto digitado
  pelo usuário — mesmo que o texto digitado coincida exatamente com o texto
  de um endereço real.
- **FR-005**: O sistema MUST registrar como destino apenas o endereço que o
  usuário selecionar explicitamente (toque/clique) dentre as sugestões
  exibidas.
- **FR-006**: Ao selecionar uma sugestão, o sistema MUST exibir no campo o
  texto completo do endereço selecionado.
- **FR-007**: O sistema MUST permitir que o usuário troque a seleção,
  editando o texto novamente e escolhendo uma nova sugestão; o destino
  MUST permanecer o da última seleção explícita até que isso aconteça.
- **FR-008**: O sistema MUST informar visualmente quando a busca não retornar
  nenhum endereço correspondente ao texto digitado.
- **FR-009**: O sistema MUST informar visualmente quando a busca falhar por
  indisponibilidade do serviço de geocodificação ou falta de conexão, sem
  travar a tela e permitindo nova tentativa.
- **FR-010**: A busca e a seleção de endereço MUST continuar funcionando
  independentemente de a posição atual do passageiro estar disponível
  (mantém a garantia da feature 004).
- **FR-011**: O endereço de destino selecionado MUST continuar a existir
  apenas em memória local, durante a sessão do aplicativo, sem persistência
  entre execuções nem publicação em relay Nostr (mantém a garantia da
  feature 004 — o campo de destino não recebe `RelayService`/`EventFeed`).
- **FR-012**: Se o usuário apagar todo o texto do campo de destino após ter
  selecionado um endereço, o sistema MUST considerar que não há mais destino
  definido.

### Key Entities

- **Sugestão de Endereço**: um endereço candidato retornado pelo serviço de
  geocodificação a partir do texto digitado — tem um texto completo exibível
  e é distinto de outras sugestões mesmo que o texto exibido coincida.
- **Endereço de Destino**: o endereço efetivamente registrado como destino
  da corrida; só existe depois de o usuário selecionar explicitamente uma
  Sugestão de Endereço; substitui o conceito de texto livre da feature 004.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Ao digitar um trecho de um endereço real, o passageiro vê
  sugestões correspondentes buscadas automaticamente, sem precisar tocar em
  um botão de busca separado.
- **SC-002**: 100% dos destinos registrados pelo sistema correspondem a um
  endereço retornado pelo serviço de geocodificação e explicitamente
  selecionado pelo usuário — nunca ao texto bruto digitado.
- **SC-003**: Quando a busca não encontra resultados ou falha, o passageiro
  recebe uma mensagem explicativa em até 1 segundo após o fim da tentativa
  de busca, sem a tela travar.
- **SC-004**: A busca de endereço continua funcionando normalmente mesmo com
  a posição do passageiro indisponível, em 100% dos casos testados.

## Assumptions

- O serviço de geocodificação Photon é consultado por uma instância pública
  já operada por terceiros (não há previsão, nesta feature, de hospedar uma
  instância própria) — decisão de dependência de terceiros a ser registrada
  no `research.md` da fase de planejamento (Princípio III da constituição).
- Não é necessária uma ação explícita de "buscar"; um agrupamento razoável de
  digitações próximas no tempo antes de disparar a busca é suficiente para
  evitar excesso de requisições, sem que isso implique um requisito de
  desempenho específico.
- Como o serviço já tem alcance mundial, e o protótipo não restringe onde a
  corrida acontece, as buscas não são limitadas a nenhuma região ou
  priorizadas pela posição atual do passageiro — todos os resultados
  retornados pelo serviço são elegíveis para seleção.
- A busca de endereço é substitutiva: o campo de texto livre da feature
  004-mapa-destino-passageiro deixa de existir como tal, dando lugar ao
  campo de busca com sugestões desta feature.

# Feature Specification: Solicitar corrida

**Feature Branch**: `006-solicitar-corrida`

**Created**: 2026-09-20

**Status**: Draft

**Input**: User description: "Modifique o app de passageiros, adicionando o botão \"Solicitar corrida\" na tela do mapa. Quando ele for pressionado, deve-se validar se um destino já foi escolhido. Se a validação indicar que um destino foi escolhido, deve-se montar uma mensagem no formato aceito pelo protocolo NOSTR (NIP 1) que contenha as coordenadas atuais do passageiro, as coordenadas do local pra onde ele deseja ir e como ele deseja pagar (dinheiro, PIX ou cartão)."

## Clarifications

### Session 2026-09-20

- Q: Esta feature deve publicar o evento de solicitação de corrida nos relays configurados, ou apenas montar o evento (assinado, mas sem transmitir)? → A: Publica em relay — reaproveitando o `RelayService` já validado na feature 002, mudando a fronteira estrutural atual da `MapScreen` (que hoje nunca recebe `RelayService`/`EventFeed`) só para esta finalidade.
- Q: Como o passageiro escolhe a forma de pagamento (dinheiro, PIX ou cartão) na tela do mapa? → A: Uma opção vem pré-selecionada por padrão (ex.: "Dinheiro"); o passageiro pode trocá-la antes de tocar em "Solicitar corrida".

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Solicitar corrida com destino e pagamento definidos (Priority: P1)

O passageiro já escolheu um destino (buscando e selecionando uma sugestão de
endereço na tela do mapa) e uma forma de pagamento. Ele toca em "Solicitar
corrida" e o aplicativo monta o evento de solicitação, pronto para ser
assinado e publicado em relay.

**Why this priority**: É o caminho principal da feature — sem ele, o botão
não tem nenhuma utilidade. Todas as outras histórias tratam de casos em que
o caminho principal não pode ser seguido.

**Independent Test**: Com o `LocationService` e o `GeocodingService`
substituídos por dublês, selecionar uma sugestão de endereço, escolher uma
forma de pagamento e tocar em "Solicitar corrida"; verificar que o evento
montado contém as coordenadas atuais do passageiro, as coordenadas do
destino e a forma de pagamento escolhida, no formato descrito no contrato de
eventos.

**Acceptance Scenarios**:

1. **Given** o passageiro tem uma posição atual válida, já selecionou um
   destino a partir de uma sugestão de endereço e escolheu uma forma de
   pagamento, **When** ele toca em "Solicitar corrida", **Then** o
   aplicativo monta um evento no formato do contrato de eventos Nostr do
   protótipo, contendo as coordenadas atuais do passageiro, as coordenadas
   do destino e a forma de pagamento escolhida.
2. **Given** o evento de solicitação foi montado com sucesso, **When** o
   passageiro observa a tela, **Then** o aplicativo confirma visivelmente
   que a solicitação foi enviada (ex.: mensagem de confirmação), sem expor
   o conteúdo técnico do evento.

---

### User Story 2 - Tentar solicitar corrida sem destino escolhido (Priority: P2)

O passageiro ainda não selecionou nenhuma sugestão de endereço como destino
(campo vazio ou com texto digitado mas não confirmado) e toca em "Solicitar
corrida". O aplicativo precisa impedir a montagem do evento e explicar por
quê, sem travar nem encerrar a tela.

**Why this priority**: É a validação que o pedido do usuário nomeia
explicitamente como passo anterior à montagem da mensagem — sem ela, o
aplicativo poderia tentar montar um evento com destino ausente.

**Independent Test**: Com o campo de destino vazio (ou com texto digitado
sem seleção de sugestão), tocar em "Solicitar corrida"; verificar que
nenhum evento é montado e que o aplicativo mostra uma mensagem orientando o
passageiro a escolher um destino primeiro.

**Acceptance Scenarios**:

1. **Given** o passageiro não selecionou nenhuma sugestão de endereço como
   destino, **When** ele toca em "Solicitar corrida", **Then** o aplicativo
   não monta nenhum evento e mostra uma mensagem informando que é preciso
   escolher um destino antes de solicitar a corrida.
2. **Given** o passageiro digitou texto no campo de destino mas não tocou em
   nenhuma sugestão da lista, **When** ele toca em "Solicitar corrida",
   **Then** o aplicativo trata a situação como destino não escolhido (mesmo
   comportamento do cenário anterior), pois `DestinationAddress` só existe
   depois de uma seleção explícita (FR-004/FR-005 da feature 005).

---

### User Story 3 - Tentar solicitar corrida sem posição atual disponível (Priority: P3)

O passageiro já escolheu destino e forma de pagamento, mas a posição atual
não está disponível no momento (permissão de localização negada, sensor
indisponível, ou leitura ainda não chegou). Como o evento exige coordenadas
atuais do passageiro, a solicitação não pode ser montada nesse estado.

**Why this priority**: É um caso de borda menos frequente que a ausência de
destino (a tela já lida com indisponibilidade de posição desde a feature
004), mas precisa de uma resposta explícita para não deixar o botão em
estado indefinido.

**Independent Test**: Com o `LocationService` de dublê configurado para não
emitir nenhuma posição, escolher um destino e uma forma de pagamento, tocar
em "Solicitar corrida"; verificar que nenhum evento é montado e que o
aplicativo mostra uma mensagem coerente com a indisponibilidade de posição
já usada na tela.

**Acceptance Scenarios**:

1. **Given** o passageiro escolheu destino e forma de pagamento, mas nenhuma
   posição atual foi lida ainda, **When** ele toca em "Solicitar corrida",
   **Then** o aplicativo não monta nenhum evento e mostra uma mensagem
   informando que a posição atual ainda não está disponível.

---

### Edge Cases

- O passageiro seleciona uma sugestão de endereço e, antes de tocar em
  "Solicitar corrida", apaga o campo de destino: o aplicativo trata como
  destino não escolhido (mesma regra do FR-012 da feature 005), então o
  botão se comporta como na User Story 2.
- O passageiro toca em "Solicitar corrida" repetidamente em sequência rápida
  antes de qualquer confirmação aparecer: cada toque válido monta e envia um
  evento de solicitação independente; o aplicativo não deduplica toques do
  próprio usuário nesta feature (fora de escopo — ver Assumptions).
- A posição atual do passageiro muda entre a seleção do destino e o toque no
  botão: o evento usa a posição mais recente conhecida no momento do toque.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A tela do mapa MUST exibir um botão "Solicitar corrida".
- **FR-002**: Ao tocar no botão, o sistema MUST validar se um destino já foi
  escolhido, usando a mesma regra da feature 005 (um `DestinationAddress`
  só existe a partir da seleção explícita de uma sugestão de endereço).
- **FR-003**: Quando nenhum destino foi escolhido, o sistema MUST impedir a
  montagem do evento de solicitação e MUST mostrar uma mensagem orientando
  o passageiro a escolher um destino, sem travar a tela nem descartar o que
  já foi digitado no campo de destino.
- **FR-004**: Ao tocar no botão, o sistema MUST também validar se a posição
  atual do passageiro está disponível; quando não estiver, MUST impedir a
  montagem do evento e MUST mostrar uma mensagem informando a
  indisponibilidade, reaproveitando o padrão de mensagem já usado para
  indisponibilidade de localização na tela do mapa.
- **FR-005**: A tela do mapa MUST oferecer ao passageiro uma forma de
  escolher entre as três formas de pagamento aceitas: dinheiro, PIX e
  cartão, antes de tocar em "Solicitar corrida". Uma das três MUST vir
  pré-selecionada por padrão ao abrir a tela, e o passageiro MUST poder
  trocá-la livremente antes de solicitar a corrida.
- **FR-006**: Quando destino e posição atual estiverem disponíveis, o
  sistema MUST montar um evento de solicitação de carona contendo: as
  coordenadas atuais do passageiro, as coordenadas do destino escolhido e a
  forma de pagamento selecionada.
- **FR-007**: O evento de solicitação de carona MUST seguir o envelope
  padrão do protocolo Nostr (NIP-01): `id`, `pubkey`, `created_at`, `kind`,
  `tags`, `content` e `sig`, e MUST ser adicionado ao contrato de eventos
  do protótipo (`specs/002-nostr-relay-connection/contracts/nostr-events.md`)
  como o kind "Solicitação de carona" hoje listado como *futuro*, replicado
  de forma idêntica na app do motorista na mesma alteração (Princípio IV da
  constituição).
- **FR-008**: O sistema MUST usar a identidade Nostr local do passageiro
  (já persistida desde a feature 002) para assinar o evento de solicitação.
- **FR-009**: Depois de montar (e, conforme FR-011, publicar) o evento com
  sucesso, o sistema MUST confirmar visivelmente ao passageiro que a
  solicitação foi enviada.
- **FR-010**: O sistema MUST tratar falha ao montar ou publicar o evento
  (ex.: identidade indisponível, todos os relays desconectados) mostrando
  uma mensagem de erro ao passageiro, sem encerrar o aplicativo.
- **FR-011**: O sistema MUST publicar o evento de solicitação de carona nos
  relays configurados, reaproveitando o `RelayService` já usado pela app
  para publicação (mesmo padrão de conectividade validado na feature 002),
  e não apenas construí-lo em memória.

### Key Entities

- **RideRequest (Solicitação de carona)**: representa a intenção do
  passageiro de contratar uma corrida a partir da posição atual até o
  destino escolhido, com a forma de pagamento desejada. Vida útil limitada
  ao instante da montagem/publicação do evento — não é uma entidade
  persistida localmente; existe como o `content`/`tags` do evento Nostr
  publicado.
- **Forma de pagamento**: um entre três valores fixos — dinheiro, PIX ou
  cartão — escolhido pelo passageiro antes de solicitar a corrida.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Com destino, forma de pagamento e posição atual disponíveis,
  o passageiro consegue solicitar uma corrida (tocar no botão até ver a
  confirmação) em uma única interação, sem passos adicionais.
- **SC-002**: 100% das tentativas de solicitar corrida sem destino
  escolhido são bloqueadas antes de qualquer publicação em relay, com uma
  mensagem explicando o motivo.
- **SC-003**: 100% das tentativas de solicitar corrida sem posição atual
  disponível são bloqueadas antes de qualquer publicação em relay, com uma
  mensagem explicando o motivo.
- **SC-004**: O evento de solicitação de carona publicado por esta feature é
  reconhecido como válido (assinatura verificada, campos legíveis) por
  qualquer cliente Nostr compatível com NIP-01, sem depender de nenhuma
  extensão proprietária de formato.

## Assumptions

- A escolha da forma de pagamento é feita na própria tela do mapa, junto do
  botão "Solicitar corrida" — não é uma tela separada, para manter o fluxo
  em uma única interação (SC-001).
- Esta feature publica o evento de solicitação de carona nos relays
  configurados (FR-011); a app do motorista consumir e reagir a esse evento
  é trabalho de uma feature futura, fora de escopo aqui.
- O destino usado é sempre o último `DestinationAddress` selecionado na
  tela (feature 005) — esta feature não introduz uma forma alternativa de
  definir destino.
- Deduplicação de múltiplos toques rápidos no botão (ex.: desabilitar o
  botão enquanto uma solicitação está em andamento) é uma melhoria de UX
  razoável, mas não é medida por nenhum critério de sucesso desta feature;
  a implementação MAY incluir isso como boa prática sem que seja um
  requisito formal.
- O `content` do evento é texto simples (sem criptografia), assim como o
  evento de teste da feature 002 — a introdução de criptografia de conteúdo
  entre passageiro e motorista é a mensagem bidirecional "a definir" já
  prevista na tabela de kinds do contrato, fora de escopo aqui.

### Justificativa de privacidade (Restrições de Segurança e Privacidade da constituição)

Esta feature publica em relay público, sem criptografia, três dados que
identificam o passageiro no espaço e no tempo: sua posição atual, o destino
desejado e a forma de pagamento. A constituição exige que qualquer dado
pessoal trafegando sem criptografia entre pares seja justificado por escrito
na especificação — segue a justificativa:

- Uma solicitação de carona é, por natureza, um **anúncio** dirigido a
  qualquer motorista interessado, não uma mensagem a um destinatário
  específico — o passageiro ainda não escolheu motorista nenhum quando
  solicita. Restringir o alcance exigiria uma forma de descoberta de
  motoristas anterior à solicitação, que não existe neste protótipo. A
  tabela de kinds do contrato já reserva a "Mensagem entre pares" —
  bidirecional, entre passageiro e motorista já pareados — como o ponto em
  que a criptografia de conteúdo (NIP-44/NIP-59) se torna aplicável; a
  solicitação, por ser broadcast, fica fora desse escopo.
- O evento carrega apenas o necessário para um motorista avaliar a corrida:
  coordenadas de origem/destino e forma de pagamento. Não carrega nome,
  apelido de exibição nem qualquer identificador além da `pubkey` — que já é
  pública por definição no protocolo Nostr.
- O mesmo padrão (dado sensível em `kind` público, sem criptografia) já é
  aceito pelo contrato para o evento de teste da feature 002; esta feature
  não introduz uma categoria nova de exposição, apenas o primeiro dado
  realmente sensível (posição) transitando por ela.
- Risco aceito e registrado: qualquer pessoa com acesso ao relay pode
  observar de forma permanente e mundial o histórico de origem/destino/forma
  de pagamento de cada solicitação. Isso é consistente com o objetivo do
  TCC — avaliar a viabilidade do Nostr como transporte P2P para caronas,
  incluindo suas limitações de privacidade — e não com um produto pronto
  para uso real; mitigar esse risco (ex.: geohash truncado, criptografia
  endereçada a um motorista específico) é trabalho futuro, fora de escopo
  aqui.

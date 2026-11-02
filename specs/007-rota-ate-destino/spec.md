# Feature Specification: Rota real até o destino

**Feature Branch**: `007-rota-ate-destino`

**Created**: 2026-09-20

**Status**: Draft

**Input**: User description: "Usar a biblioteca open_route_service (já adicionada ao pubspec.yaml)
para calcular a distância real da rota (não linha reta) entre a posição atual do passageiro e o
destino escolhido (DestinationAddress, já existente desde a feature 005-busca-endereco-photon), e
traçar essa rota no mapa da tela inicial. É cálculo local ao app — não altera o contrato de eventos
Nostr entre motorista e passageiro nem o formato do evento kind:20001 já publicado pela feature
006-solicitar-corrida."

## Clarifications

### Session 2026-09-20

- Q: A API do OpenRouteService (nível gratuito) tem limite de requisições por minuto; quando a rota deve ser recalculada à medida que a posição atual do passageiro muda? → A: recalcular só quando a posição se afastar mais que uma distância mínima (50 m) do ponto de origem usado no último cálculo.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver a distância real até o destino (Priority: P1)

Como passageiro que já escolheu um destino no mapa, quero ver a distância real do trajeto rodoviário
até lá — não a distância em linha reta —, para saber quão longe a corrida realmente vai ser antes de
solicitá-la.

**Why this priority**: é o pedido central desta feature — sem isso, o passageiro não tem nenhuma
noção confiável de distância, só a posição dos dois pontos no mapa.

**Independent Test**: com a posição atual disponível, escolher um destino pela busca de endereço
(feature 005) e verificar que a tela passa a mostrar uma distância maior ou igual à distância em
linha reta entre os dois pontos (a rota real nunca é mais curta que a linha reta).

**Acceptance Scenarios**:

1. **Given** a posição atual do passageiro disponível e nenhum destino escolhido, **When** o
   passageiro seleciona uma sugestão de endereço, **Then** a tela do mapa passa a exibir a distância
   do trajeto até o destino.
2. **Given** um destino já escolhido com distância exibida, **When** o passageiro escolhe outro
   destino, **Then** a distância exibida é recalculada para o novo destino.
3. **Given** um destino escolhido, **When** o passageiro limpa o destino, **Then** a distância deixa
   de ser exibida.

---

### User Story 2 - Ver o trajeto traçado no mapa (Priority: P2)

Como passageiro que já vê a distância até o destino, quero também ver o caminho desenhado no mapa,
para entender visualmente por onde a corrida vai passar.

**Why this priority**: é um complemento visual à User Story 1 — a distância numérica já entrega o
valor principal; o traçado no mapa reforça a informação, mas o app já é útil sem ele.

**Independent Test**: com um destino escolhido e a distância exibida (User Story 1), verificar que uma
linha contínua aparece no mapa ligando a posição atual ao destino, seguindo vias reais e não uma
linha reta.

**Acceptance Scenarios**:

1. **Given** um destino escolhido, **When** o cálculo da rota é concluído, **Then** o mapa exibe uma
   linha contínua entre a posição atual e o destino, seguindo o trajeto rodoviário.
2. **Given** uma rota já traçada, **When** o passageiro escolhe outro destino, **Then** a linha
   anterior é substituída pela nova rota.
3. **Given** uma rota já traçada, **When** a posição atual do passageiro se afasta mais que 50 metros
   do ponto de origem usado no último cálculo, **Then** a rota é recalculada a partir da nova posição.

---

### User Story 3 - Lidar com rota indisponível (Priority: P3)

Como passageiro, se o cálculo de rota falhar (sem rede, serviço fora do ar, destino inacessível por
via), quero continuar vendo o destino escolhido e conseguir solicitar a corrida normalmente, para que
uma falha num serviço externo não me impeça de usar o app.

**Why this priority**: é tratamento de falha de uma dependência externa nova — importante para não
regredir a funcionalidade já existente (feature 006, solicitar corrida), mas não é o caminho
principal.

**Independent Test**: simular indisponibilidade do serviço de rota com um destino já escolhido e
verificar que a tela continua funcional (sem distância/traçado, mas sem erro bloqueante) e que
"Solicitar corrida" continua operante.

**Acceptance Scenarios**:

1. **Given** um destino escolhido, **When** o cálculo de rota falha (erro de rede ou do serviço),
   **Then** a tela indica que a distância não pôde ser calculada, sem impedir nenhuma outra ação.
2. **Given** uma falha anterior no cálculo de rota, **When** o passageiro solicita a corrida (feature
   006), **Then** a solicitação é publicada normalmente, sem depender do resultado do cálculo de rota.

---

### Edge Cases

- O que acontece se a posição atual do passageiro ainda não estiver disponível quando um destino é
  escolhido? A distância/rota só é calculada quando ambos os pontos existem; até lá, nada é exibido.
- O que acontece se origem e destino coincidirem (mesmo ponto)? A distância exibida é zero e nenhuma
  linha de rota é desenhada.
- O que acontece se o destino não for alcançável por via terrestre (ex.: ilha sem ponte)? Trata-se
  como falha do cálculo de rota (User Story 3).
- O que acontece se o passageiro escolher um novo destino antes do cálculo anterior terminar? O
  cálculo em andamento é descartado e um novo é iniciado para o destino mais recente; só o resultado
  do destino atual é exibido.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema MUST calcular a distância do trajeto rodoviário real (não linha reta) entre a
  posição atual do passageiro e o destino escolhido, sempre que ambos estiverem disponíveis.
- **FR-002**: O sistema MUST exibir essa distância na tela do mapa, associada ao destino atualmente
  escolhido.
- **FR-003**: O sistema MUST recalcular a distância e o trajeto sempre que o destino escolhido mudar,
  e também quando a posição atual do passageiro se afastar mais que 50 metros do ponto de origem
  usado no último cálculo — nunca a cada atualização de posição, para não exceder o limite de
  requisições do serviço de rota (Clarifications, sessão 2026-09-20).
- **FR-004**: O sistema MUST desenhar no mapa uma representação visual do trajeto calculado, ligando a
  posição atual ao destino.
- **FR-005**: O sistema MUST remover a distância exibida e o trajeto desenhado quando o destino for
  limpo ou quando a posição atual deixar de estar disponível.
- **FR-006**: O sistema MUST continuar permitindo a solicitação de corrida (feature 006) independente
  do resultado do cálculo de rota, incluindo quando ele falha.
- **FR-007**: O sistema MUST indicar de forma não bloqueante quando a distância/trajeto não pôde ser
  calculado (falha de rede ou do serviço de rota), sem impedir nenhuma outra ação da tela.
- **FR-008**: O sistema MUST descartar o resultado de um cálculo de rota anterior se um novo destino
  for escolhido antes dele terminar, exibindo apenas o resultado referente ao destino atual.
- **FR-009**: O cálculo de rota MUST ser local ao aparelho do passageiro — não MUST publicar, alterar
  nem depender de nenhum evento Nostr, e não MUST alterar o contrato de eventos nem o formato do
  evento `kind: 20001` (feature 006).

### Key Entities

- **Rota calculada**: resultado do cálculo de trajeto entre dois pontos geográficos — a sequência de
  coordenadas que compõe o caminho e a distância total percorrida. Existe apenas em memória, local ao
  aparelho, durante a sessão do aplicativo; não é persistida nem publicada em relay.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Ao escolher um destino com posição atual disponível, o passageiro vê a distância do
  trajeto real exibida na tela em até 3 segundos em condições normais de rede.
- **SC-002**: A distância exibida nunca é menor que a distância em linha reta entre os dois pontos,
  em nenhum destino testado.
- **SC-003**: Uma falha no cálculo de rota nunca impede o passageiro de solicitar a corrida — a ação
  "Solicitar corrida" permanece disponível em 100% dos casos de falha simulados.
- **SC-004**: Trocar de destino sempre substitui a distância e o trajeto exibidos pelos do novo
  destino, nunca misturando informação de dois destinos diferentes.

## Assumptions

- A posição atual do passageiro já está disponível pela feature 004 (mapa como tela inicial); esta
  feature apenas consome essa posição, sem alterar como ela é obtida.
- O destino usado é sempre o `DestinationAddress` já resolvido pela busca Photon (feature 005) —
  esta feature não introduz nenhuma nova forma de escolher destino.
- "Trajeto rodoviário" significa o perfil de rota adequado a um carro de passeio; não há necessidade
  de suportar outros perfis (a pé, bicicleta) neste protótipo.
- O cálculo de rota depende de conectividade com um serviço externo (o mesmo tipo de dependência já
  aceito para a busca de endereço via Photon, feature 005); não há expectativa de funcionamento
  totalmente offline.
- Não há requisito de exibir instruções de navegação passo a passo — só a distância e o traçado da
  rota no mapa.

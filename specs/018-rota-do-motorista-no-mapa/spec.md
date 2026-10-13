# Feature Specification: Rota da corrida enviada pelo motorista, no mapa do passageiro

**Feature Branch**: `018-rota-do-motorista-no-mapa` (trabalho direto na `master`; ver Padrão de Commits)

**Created**: 2026-10-03

**Status**: Draft

**Input**: User description: "Metade do passageiro (contrapartida da feature 017-publicar-rota-ao-passageiro do motorista, que define o contrato — emenda 13, kind 20011 'Rota da corrida'). Pedido original do usuário: 'Quando o app do passageiro estiver no estado Em corrida, a rota até o destino deve ser traçada no mapa. O app do passageiro não deve calcular a rota, em vez disso, o app do motorista enviará ao passageiro a rota sempre que esta for calculada ou recalculada.' Escopo desta feature (passageiro): passar a receber o kind 20011; traçar no mapa a rota válida da corrida aceita enquanto o passageiro está em 'Em corrida'; cada rota nova substitui a anterior; conteúdo inválido é descartado sem alterar o traçado; só em memória; o traçado some ao sair de 'Em corrida'; o app do passageiro não calcula rota para este trecho."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver no mapa o caminho até o destino durante a corrida (Priority: P1)

O passageiro confirmou o encontro e a corrida está em andamento ("Em corrida"). O app do motorista
calcula o trajeto da posição dele até o destino e o envia. O mapa do passageiro passa a mostrar esse
trajeto como uma linha até o destino, para que ele acompanhe por onde a corrida vai.

**Why this priority**: é o núcleo do pedido; sem ele o passageiro não vê o caminho em nenhum
momento da corrida.

**Independent Test**: com o app em "Em corrida", entregar uma rota válida da corrida aceita e
confirmar que a linha aparece no mapa.

**Acceptance Scenarios**:

1. **Given** o estado "Em corrida" e uma rota válida do motorista da corrida aceita, **When** ela
   chega, **Then** o trajeto é traçado no mapa.
2. **Given** um trajeto já traçado, **When** chega uma rota mais nova do mesmo motorista, **Then** o
   trajeto traçado passa a ser o da rota nova, e o anterior deixa de ser mostrado.
3. **Given** um trajeto já traçado, **When** chega uma rota mais antiga que a exibida (entrega fora
   de ordem), **Then** o traçado não muda.
4. **Given** o app reaberto em "Em corrida" sem rota recebida ainda, **When** o motorista envia a
   próxima rota, **Then** ela é traçada (a rota não é guardada entre sessões).

---

### User Story 2 - O passageiro não calcula a rota (Priority: P1)

Em "Em corrida", o app do passageiro não consulta nenhum serviço de rotas e não desenha por conta
própria o trajeto até o destino: a única linha de rota do trecho é a recebida do motorista.

**Why this priority**: é parte explícita do pedido e evita duas linhas diferentes (a do motorista e
a calculada localmente) disputando o mesmo trecho, além de consultas desnecessárias a um serviço de
cota limitada.

**Independent Test**: em "Em corrida", com um destino escolhido e posição do passageiro variando,
confirmar que nenhuma consulta ao serviço de rotas é feita e que, sem rota recebida, nenhuma linha de
rota é mostrada.

**Acceptance Scenarios**:

1. **Given** o estado "Em corrida" e uma rota local do passageiro já traçada antes de a corrida
   começar, **When** o estado passa a "Em corrida", **Then** a linha local deixa de ser mostrada.
2. **Given** "Em corrida" e o passageiro se deslocando mais de 50 m, **When** a posição dele muda,
   **Then** nenhuma nova consulta de rota é feita.
3. **Given** "Em corrida" sem nenhuma rota recebida do motorista, **When** o mapa é exibido,
   **Then** nenhuma linha de rota é mostrada (apenas os marcadores).

---

### User Story 3 - Só rota legítima e só durante a corrida (Priority: P1)

O passageiro só vê rotas realmente enviadas pelo motorista da corrida dele, e só enquanto a corrida
está em andamento. Ao terminar (destino confirmado) o traçado some.

**Why this priority**: o `kind` é público no relay; sem checagem de autoria e de corrida, qualquer um
poderia desenhar uma linha no mapa do passageiro.

**Independent Test**: entregar rotas com autor errado, com orçamento de outra corrida, com conteúdo
inválido e fora de "Em corrida", e confirmar que nenhuma altera o mapa.

**Acceptance Scenarios**:

1. **Given** "Em corrida", **When** chega uma rota assinada por uma chave que não é a do motorista
   cujo orçamento foi aceito, **Then** ela é ignorada.
2. **Given** "Em corrida", **When** chega uma rota que referencia um orçamento diferente do aceito,
   **Then** ela é ignorada.
3. **Given** "Em corrida", **When** chega uma rota com conteúdo malformado, com menos de 2 pontos,
   com mais de 1000 pontos ou com coordenadas fora de faixa, **Then** ela é ignorada e o traçado
   atual não muda.
4. **Given** qualquer estado diferente de "Em corrida" (por exemplo "motorista a caminho"), **When**
   chega uma rota válida, **Then** nada é traçado.
5. **Given** "Em corrida" com trajeto traçado, **When** o destino é confirmado e o estado deixa
   "Em corrida", **Then** o trajeto deixa de ser mostrado.

---

### Edge Cases

- Rota válida chega antes de o passageiro entrar em "Em corrida" (por exemplo, enquanto ainda está em
  "motorista a caminho"): ignorada; o motorista só envia em "Em corrida" e a próxima rota (em até
  ~50 m) será traçada.
- Duas rotas com o mesmo `created_at`: vale a que já está exibida (nenhuma troca desnecessária).
- Sem posição do passageiro ou do motorista disponível: a rota recebida é traçada mesmo assim, pois
  não depende de nenhuma das duas posições locais.
- Rota recebida de relays diferentes (mesmo evento duas vezes): processada uma só vez.
- Destino confirmado (`kind: 20010`) com um traçado em exibição e uma rota tardia chegando em seguida:
  a rota tardia é ignorada (já fora de "Em corrida").
- Evento com assinatura inválida: descartado antes de qualquer outra coisa, como todos os demais.
- Linha recebida diferente do destino escolhido localmente: o traçado recebido manda; o app não tenta
  conferir o destino.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O app MUST passar a receber o `kind: 20011` ("Rota da corrida", emenda 13 do contrato),
  incluindo-o na lista de tipos de evento da sua inscrição, com o mesmo filtro de marcador e limite
  das demais.
- **FR-002**: Enquanto o passageiro está em "Em corrida", o app MUST traçar no mapa a rota recebida
  que seja válida segundo as regras de consumo do contrato.
- **FR-003**: Uma rota é válida somente se (a) a assinatura confere, (b) o autor é o motorista cujo
  orçamento o passageiro aceitou, (c) referencia o orçamento aceito da corrida atual, e (d) o
  `content` traz de 2 a 1000 pontos com latitude entre −90 e 90 e longitude entre −180 e 180.
- **FR-004**: Quando chega uma rota válida mais nova (maior `created_at`) que a exibida, o app MUST
  substituí-la; uma rota mais antiga ou igual MUST NOT alterar o traçado.
- **FR-005**: Uma rota inválida, de outro autor, de outra corrida ou recebida fora de "Em corrida"
  MUST ser ignorada sem erro e sem alterar o traçado atual.
- **FR-006**: Ao deixar "Em corrida", o app MUST deixar de mostrar o traçado recebido e descartar a
  rota guardada.
- **FR-007**: A rota recebida MUST existir só em memória durante a sessão; MUST NOT ser persistida.
- **FR-008**: Em "Em corrida", o app MUST NOT consultar serviço de rotas nem mostrar a linha de rota
  calculada localmente (feature 007); a única linha de rota do trecho é a recebida do motorista.
- **FR-009**: O estilo visual da linha MUST seguir a seção Identidade Visual e Design da constituição
  (a mesma cor e espessura da rota já definidas), sem componente novo.
- **FR-010**: Nenhum contrato novo é criado: esta feature só consome o `kind: 20011` definido pela
  feature 017 do motorista; a cópia local do contrato MUST já conter a emenda 13 (idêntica à do
  motorista) antes de qualquer código.

### Key Entities

- **Rota da corrida recebida**: sequência ordenada de pontos (latitude/longitude) do trajeto da
  posição do motorista até o destino, com o instante de criação do evento; só em memória, uma por vez.
- **Corrida aceita (`AcceptedRide`, já existente)**: fornece o orçamento aceito e o motorista
  (autoria) para validar a rota recebida; nenhum atributo novo.
- **Estado da corrida (`PassengerRideStatus`, já existente)**: "Em corrida" (`emCorrida`) define
  quando a rota vale.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Em 100 % das rotas válidas recebidas em "Em corrida", o trajeto aparece no mapa em até
  2 s depois do recebimento.
- **SC-002**: Em 100 % dos casos de autor errado, orçamento diferente, conteúdo inválido ou estado
  diferente de "Em corrida", o mapa permanece exatamente como estava.
- **SC-003**: Em 100 % das rotas mais novas válidas, a linha exibida passa a ser a da mais nova; em
  nenhuma situação duas linhas de rota são exibidas ao mesmo tempo no trecho de "Em corrida".
- **SC-004**: Em "Em corrida", o número de consultas ao serviço de rotas feitas pelo app do passageiro
  é zero.
- **SC-005**: Em 100 % das saídas de "Em corrida", o traçado some em até 1 s.

## Assumptions

- A feature 017 do motorista define e publica o `kind: 20011`; a emenda 13 do contrato precisa estar
  nas duas cópias antes do código desta feature. **Hoje ela ainda não foi escrita em nenhuma cópia**
  (é o primeiro item das tarefas da 017) — o `/speckit-plan` e o `/speckit-tasks` desta feature MUST
  registrá-la como dependência bloqueante.
- "Em corrida" é o estado `emCorrida` do passageiro, já existente, que corresponde ao "Em corrida" do
  motorista; nenhum estado novo.
- O cálculo local de rota da feature 007 (posição atual → destino escolhido) continua valendo nos
  demais estados; só em "Em corrida" ele deixa de ser calculado e exibido. Mudar o comportamento dos
  outros estados está fora de escopo.
- O desempate de rotas por `created_at` segue o critério já usado para a posição do motorista
  (feature 016): não é decisão de segurança, só evita que um evento antigo sobrescreva um novo.
- O enquadramento da câmera em "Em corrida" não muda nesta feature; o mapa continua com o
  comportamento atual desse estado.
- Os marcadores existentes (passageiro, destino escolhido) permanecem como estão.

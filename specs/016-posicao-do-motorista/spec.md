# Feature Specification: Posição do motorista no mapa do passageiro

**Feature Branch**: `016-posicao-do-motorista` (trabalho direto na `master`; ver Padrão de Commits)

**Created**: 2026-09-30

**Status**: Draft

**Input**: User description: "Quando o app do passageiro estiver no estado motoristaACaminho e receber uma mensagem com a informação sobre a localização do motorista, o app do passageiro deve mostrar a posição do motorista na tela. O motorista deve ser representado pela mesma imagem usada no app do motorista."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver onde o motorista está (Priority: P1)

O passageiro aceitou um orçamento e o motorista já começou a se deslocar (estado "motorista a
caminho"). A cada localização que o motorista publica, o mapa do passageiro mostra o motorista no
ponto informado, para que o passageiro acompanhe a aproximação.

**Why this priority**: é o pedido inteiro. Hoje o passageiro só recebe um aviso de que o motorista
saiu; a posição chega ao app e é descartada.

**Independent Test**: com o app em "motorista a caminho" e uma corrida aceita, entregar uma
localização do motorista e confirmar que o marcador dele aparece nas coordenadas recebidas.

**Acceptance Scenarios**:

1. **Given** o estado "motorista a caminho" e uma corrida aceita, **When** chega uma localização do
   motorista dessa corrida, **Then** o mapa mostra o marcador do motorista naquele ponto.
2. **Given** o marcador já exibido, **When** chega uma localização mais nova, **Then** o marcador
   passa para o novo ponto, sem duplicar.
3. **Given** a primeira localização que leva o app de "orçamento aceito" a "motorista a caminho",
   **When** o estado muda, **Then** essa mesma localização já aparece no mapa (não só a partir da
   seguinte).
4. **Given** o app reaberto em "motorista a caminho", **When** a próxima localização chegar,
   **Then** o marcador volta a aparecer.
5. **Given** o marcador exibido pela primeira vez, **When** o mapa é mostrado, **Then** motorista e
   passageiro cabem na tela e o mapa não volta a recentralizar sozinho no passageiro nas
   atualizações de GPS seguintes.
6. **Given** o mapa deslocado do passageiro (sem segui-lo), **When** o passageiro toca em
   "Centralizar", **Then** o mapa vai para a posição dele e volta a segui-lo.

   *(Cenários 5 e 6 superados pela feature 017, ver FR-007.)*

---

### User Story 2 - Reconhecer o motorista pelo mesmo símbolo (Priority: P1)

O motorista é desenhado no mapa do passageiro com o mesmo símbolo que ele vê da própria posição no
app do motorista: o círculo escuro com borda branca e o ícone de carro na cor de destaque. O
marcador do próprio passageiro continua com o símbolo dele, e os dois são facilmente distinguíveis.

**Why this priority**: faz parte do pedido e evita confundir o passageiro com o motorista.

**Independent Test**: com os dois marcadores no mapa, comparar o do motorista com o do app do
motorista (formato, tamanho, cores, ícone) e com o do próprio passageiro.

**Acceptance Scenarios**:

1. **Given** o marcador do motorista exibido, **When** comparado ao marcador da própria posição no
   app do motorista, **Then** formato, tamanho, cores e ícone são os mesmos.
2. **Given** os marcadores do passageiro e do motorista no mapa, **When** o passageiro os olha,
   **Then** distingue qual é qual pelo símbolo.

---

### User Story 3 - Só o motorista certo, só no momento certo (Priority: P2)

O marcador só existe enquanto o app está em "motorista a caminho", e só reflete localizações vindas
do motorista cujo orçamento o passageiro aceitou, para aquela corrida.

**Why this priority**: dá confiabilidade; sem isso, qualquer evento público com a mesma referência
moveria o marcador.

**Independent Test**: entregar uma localização de outro autor, de outra corrida, ou fora do estado,
e confirmar que o mapa não muda.

**Acceptance Scenarios**:

1. **Given** "motorista a caminho", **When** chega uma localização referenciando a corrida aceita
   mas assinada por outra chave que não a do motorista aceito, **Then** é ignorada.
2. **Given** "motorista a caminho", **When** chega uma localização referenciando outra corrida,
   **Then** é ignorada.
3. **Given** o app em qualquer outro estado (inicial, aguardando orçamentos, orçamento aceito,
   encontro confirmado, destino confirmado), **When** o mapa é exibido, **Then** nenhum marcador do
   motorista aparece.
4. **Given** o marcador exibido, **When** o estado deixa "motorista a caminho" (por exemplo, o
   passageiro confirma o encontro), **Then** o marcador some.

---

### Edge Cases

- Localização com conteúdo malformado (JSON inválido, sem `lat`/`lon`, fora de faixa, não numérico):
  não cria nem altera o marcador e não gera erro visível. Vinda do motorista aceito, ela ainda conta
  como o sinal de "motorista a caminho" (comportamento já existente das features 009/014): a
  transição de estado não depende da validade do conteúdo.
- Localizações fora de ordem: uma mais antiga que a já exibida não faz o marcador voltar atrás.
- Mesma localização chegando por mais de um relay: tratada uma vez.
- Nenhuma localização recebida ainda (ou o motorista parou de publicar): sem marcador, ou o último
  ponto conhecido; sem indicador de "desatualizado" nesta versão.
- Posição do próprio passageiro indisponível: o marcador do motorista aparece mesmo assim.
- Marcador do motorista fora da área visível do mapa: o passageiro precisa conseguir enxergá-lo (ver
  FR-007).
- Reinício do app: a posição não é guardada; o marcador reaparece com a próxima localização.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Em "motorista a caminho", ao receber uma localização válida do motorista da corrida
  aceita, o app MUST mostrar no mapa o marcador do motorista nas coordenadas recebidas.
- **FR-002**: A localização que causa a transição de "orçamento aceito" para "motorista a caminho"
  MUST também ser exibida, não apenas as seguintes.
- **FR-003**: A cada localização válida mais nova, o marcador MUST ser movido para o novo ponto;
  nunca haverá mais de um marcador do motorista.
- **FR-004**: O marcador do motorista MUST ter o mesmo aspecto do usado pelo app do motorista para
  a própria posição (círculo de 44 px na cor de fundo da identidade visual, borda branca de 2 px,
  ícone de carro na cor de destaque) e MUST ser distinguível do marcador do próprio passageiro.
- **FR-005**: O app MUST considerar apenas localizações cujo autor é o motorista cujo orçamento foi
  aceito e que referenciam a corrida aceita; qualquer outra MUST ser ignorada.
- **FR-006**: Fora de "motorista a caminho", o marcador do motorista MUST NOT ser exibido, e MUST
  sumir quando o estado deixar de ser "motorista a caminho".
- **FR-007**: Ao exibir o marcador pela primeira vez numa corrida, o app MUST deixar o motorista
  visível na tela (enquadrando-o junto à posição do passageiro, quando conhecida). As atualizações
  seguintes MUST NOT reenquadrar o mapa nem recentralizá-lo sozinho na posição do passageiro, para
  não desfazer o enquadramento; enquanto o mapa não segue o passageiro, um botão "Centralizar" MUST
  devolver o foco à posição dele e voltar a seguir.
  *(Superado pela feature 017: em "motorista a caminho" o mapa passa a centralizar e seguir o
  motorista, e o botão "Centralizar" deixa de existir. Mantido acima como registro histórico.)*
- **FR-008**: Localização malformada, fora de faixa válida, duplicada ou mais antiga que a exibida
  MUST ser descartada sem alterar o marcador.
- **FR-009**: A posição do motorista MUST existir só em memória durante a corrida: não é gravada em
  disco nem reenviada a terceiro; reiniciar o app apaga o marcador até a próxima localização.
- **FR-010**: Nenhum formato de evento é criado ou alterado, e nenhum evento novo é publicado; o app
  só passa a usar o que já recebe no `kind: 20005`. O app do motorista não muda. A nota de consumo do
  `kind: 20005` no contrato é atualizada (emenda 12), igualmente nas duas cópias.
- **FR-011**: O modal de aviso de motorista a caminho (feature 009) MUST continuar aparecendo
  uma única vez por corrida, como hoje.
- **FR-012**: O novo marcador MUST seguir a seção Identidade Visual e Design da constituição (sem
  nova cor, tamanho ou raio).

### Key Entities

- **Posição do motorista**: ponto (latitude, longitude) informado pelo motorista da corrida aceita,
  com o instante declarado pelo autor; derivada de uma mensagem já recebida, efêmera, só em memória.
- **Corrida aceita (já existente)**: identifica o orçamento aceito e o motorista (autor esperado das
  localizações).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Em 100 % dos casos de localização válida do motorista aceito, em "motorista a
  caminho", o marcador aparece nas coordenadas recebidas em até 1 s depois de a mensagem chegar ao
  app.
- **SC-002**: Em 100 % das localizações de outro autor, de outra corrida, malformadas, duplicadas ou
  mais antigas que a exibida, o marcador não muda.
- **SC-003**: Em 100 % dos outros cinco estados da corrida, nenhum marcador do motorista aparece.
- **SC-004**: Numa inspeção lado a lado, um avaliador identifica o marcador do motorista no app do
  passageiro como idêntico ao do app do motorista (formato, tamanho, cores, ícone) e o distingue do
  marcador do passageiro, em 5 de 5 verificações.
- **SC-005**: Ao aparecer pela primeira vez, o motorista fica visível na tela sem o passageiro
  precisar mover o mapa.

## Assumptions

- O pedido restringe a exibição ao estado "motorista a caminho"; depois do encontro confirmado o
  marcador some. Acompanhar o motorista durante a corrida em si fica fora de escopo.
- "Mesma imagem" é entendida como o mesmo símbolo de marcador do app do motorista (círculo + ícone
  de carro); nenhum arquivo de imagem é usado em nenhuma das duas apps hoje.
- A localização chega pelo `kind: 20005` já definido (emenda 08) e já assinado pelo app; sem novo
  kind, nem mudança no motorista. A nota "não decodifica nem exibe lat/lon" do contrato (emenda 10)
  deixa de valer e é atualizada, igualmente nas duas cópias do contrato, na fase de planejamento.
- O motorista publica a cada 5 s; o app exibe o último ponto conhecido, sem aviso de dado
  desatualizado, nesta versão.
- Ordenação por instante declarado pelo autor basta aqui: não é uma decisão de segurança, só impede
  um ponto antigo de sobrescrever um mais novo.
- A validade do conteúdo da localização afeta só o marcador, não o reconhecimento de que o motorista
  saiu (G1 da análise da feature).
- Hoje o mapa do passageiro recentraliza na posição dele a cada atualização de GPS e não tem botão
  "Centralizar" (que a constituição já define como componente de tela de mapa); o enquadramento do
  FR-007 exige os dois.
- O passageiro já possui o mapa com a própria posição e a rota até o destino (features 004/007);
  esta feature só acrescenta o marcador do motorista.

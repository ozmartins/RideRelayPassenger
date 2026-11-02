# Feature Specification: Avaliar corrida (passageiro)

**Feature Branch**: `011-avaliar-corrida`

**Created**: 2026-09-22

**Status**: Draft

**Input**: User description: "Quando a corrida terminar, o passageiro deve ver uma tela que lhe
permita avaliar a corrida com 1 a 5 estrelas. A avaliação fica salva no banco de dados local do app
do passageiro. O uso posterior das avaliações persistidas está fora do escopo desta spec."

> Esta é a metade do passageiro de um pedido que também se aplica ao motorista — a contrapartida
> dele é uma feature de spec-kit própria, especificada separadamente dentro de `driver/`, sem
> nenhum evento Nostr novo conectando as duas (ver Assumptions).

## Clarifications

### Session 2026-09-22

- Q: Se o passageiro fechar o app antes de avaliar uma corrida, a tela de avaliação deve
  reaparecer na próxima abertura? → A: Não — a oportunidade de avaliar aquela corrida se perde;
  a tela não é reexibida depois que o app fecha sem a avaliação ter sido feita.
- Q: A avaliação é obrigatória ou o passageiro pode dispensá-la sem avaliar? → A: Opcional — a
  tela tem uma ação de fechar/pular sem selecionar nota nenhuma.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Avaliar a corrida ao final (Priority: P1)

Depois de confirmar a chegada ao destino, o passageiro vê uma tela de avaliação da corrida que
acabou de terminar, com cinco estrelas selecionáveis. Ele toca na quinta estrela contando da
esquerda, o que seleciona uma nota de 5, e confirma. A nota fica registrada localmente no
dispositivo do passageiro, associada àquela corrida específica.

**Why this priority**: É o próprio pedido do usuário — sem isso, a corrida termina sem nenhum
registro de satisfação do passageiro, e a feature não existe.

**Independent Test**: Pode ser testado de ponta a ponta simulando o fim de uma corrida (destino
confirmado) e verificando que a tela de avaliação aparece, que tocar numa estrela seleciona a nota
correspondente e que, ao confirmar, a nota é persistida no banco local associada ao identificador
da corrida.

**Acceptance Scenarios**:

1. **Given** o passageiro acabou de confirmar a chegada ao destino de uma corrida em andamento,
   **When** a confirmação é publicada com sucesso, **Then** a tela de avaliação da corrida é
   exibida, com cinco estrelas e nenhuma nota pré-selecionada.
2. **Given** a tela de avaliação está visível, **When** o passageiro toca na estrela de posição N
   (1 a 5), **Then** as estrelas de 1 até N aparecem preenchidas/selecionadas e as demais não.
3. **Given** o passageiro selecionou uma nota de 1 a 5, **When** ele confirma a avaliação,
   **Then** a nota é salva no banco de dados local do app associada à corrida encerrada, e a tela
   de avaliação é fechada.
4. **Given** a tela de avaliação está visível, **When** o passageiro toca em fechar/pular sem
   selecionar nenhuma nota, **Then** a tela é fechada sem nenhuma nota persistida para aquela
   corrida, e a tela não volta a ser exibida para ela.

---

### Edge Cases

- Se o passageiro fechar o aplicativo (ou o sistema encerrar o processo) antes de avaliar a
  corrida, a oportunidade de avaliar aquela corrida específica se perde — a tela de avaliação não
  reaparece numa próxima abertura do app.
- O passageiro pode fechar a tela de avaliação sem escolher nenhuma nota (avaliação opcional) —
  ver User Story 1, cenário 4.
- O que acontece se o passageiro tiver mais de uma corrida encerrada em sequência antes de
  avaliar a anterior? Assume-se que isso não ocorre no protótipo, já que o app só acompanha uma
  corrida ativa por vez (`AcceptedRide` existente) — a tela de avaliação corresponde sempre à
  única corrida recém-encerrada.
- O que acontece se o passageiro tentar avaliar a mesma corrida duas vezes (por exemplo, reabrindo
  a tela de alguma forma depois de já ter avaliado)? A avaliação já registrada não é sobrescrita;
  a tela de avaliação não é exibida de novo para uma corrida já avaliada.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema MUST exibir uma tela de avaliação da corrida imediatamente após o
  encerramento de uma corrida (confirmação de chegada ao destino publicada com sucesso).
- **FR-002**: A tela de avaliação MUST oferecer exatamente cinco estrelas selecionáveis,
  representando notas inteiras de 1 a 5.
- **FR-003**: Ao tocar na estrela de posição N, o sistema MUST marcar como selecionadas todas as
  estrelas de 1 até N e nenhuma das demais.
- **FR-004**: Ao confirmar uma nota escolhida, o sistema MUST persistir a nota (um número inteiro
  de 1 a 5) no banco de dados local do app, associada à corrida encerrada que a originou.
- **FR-005**: A avaliação MUST ficar salva exclusivamente no banco de dados local do app do
  passageiro — não é publicada como evento Nostr nem enviada ao app do motorista.
- **FR-006**: O sistema MUST impedir que a mesma corrida seja avaliada mais de uma vez (uma
  corrida já avaliada não volta a exibir a tela de avaliação).
- **FR-007**: O uso posterior das avaliações persistidas (exibição, agregação, envio, etc.) está
  fora do escopo desta feature — esta spec cobre somente a captura e o armazenamento local da
  nota.
- **FR-008**: A tela de avaliação MUST oferecer uma ação de fechar/pular sem selecionar nenhuma
  nota; nesse caso, nenhuma nota é persistida para aquela corrida.
- **FR-009**: O sistema MUST NOT reexibir a tela de avaliação de uma corrida depois que o app é
  fechado sem ela ter sido avaliada (nem por nota escolhida, nem por pular) — a oportunidade de
  avaliar aquela corrida específica se perde.

### Key Entities *(include if feature involves data)*

- **RideRating**: representa a avaliação de uma corrida feita pelo passageiro — identificador da
  corrida avaliada (mesma referência já usada para correlacionar a corrida aceita, como o
  identificador do orçamento aceito em `AcceptedRide.quoteId`), nota de 1 a 5 e momento do
  registro. Existe no máximo uma por corrida.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Depois de uma corrida encerrar, o passageiro vê a tela de avaliação da corrida em
  até 2 segundos, sem precisar navegar manualmente até ela.
- **SC-002**: Em 100% das corridas em que o passageiro seleciona uma nota e confirma, a nota
  correspondente é encontrada no banco de dados local do app imediatamente depois, associada à
  corrida correta.
- **SC-003**: Uma corrida já avaliada nunca volta a exibir a tela de avaliação para o passageiro.

## Assumptions

- Não há campo de comentário/texto livre acompanhando a nota — só a nota numérica de 1 a 5, como
  descrito no pedido do usuário.
- O momento de "corrida encerrada" é o mesmo já estabelecido pelo fluxo existente: a confirmação
  de destino publicada com sucesso, que hoje fecha a modal de chegada ao destino (feature
  `010-confirmar-encontro-destino`, `kind: 20010`).
- O passageiro só tem uma corrida ativa por vez (já garantido pelo modelo existente,
  `AcceptedRide`), então não há ambiguidade sobre qual corrida está sendo avaliada quando a tela
  aparece.
- A tela de avaliação é local ao app do passageiro — nenhum evento Nostr novo é definido por esta
  feature, e o contrato de eventos entre as duas apps não é tocado. A avaliação equivalente do
  motorista é uma feature de spec-kit separada, especificada e persistida inteiramente dentro de
  `driver/`, sem depender desta.

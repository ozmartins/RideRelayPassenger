# Feature Specification: Corrida cancelada pelo motorista (passageiro)

**Feature Branch**: `019-corrida-cancelada-pelo-motorista`

**Created**: 2026-10-04

**Status**: Draft

**Input**: User description (metade do passageiro de um pedido que também toca o app do motorista,
especificada em `driver/specs/018-cancelar-corrida-motorista`): "Modifique o app do passageiro de
modo que, ao receber do app do motorista o aviso de cancelamento da corrida (kind 20012, emenda 14
do contrato, definida na feature 018 do motorista), exiba uma modal informando o cancelamento e
cancele a corrida no app do passageiro, voltando ao estado inicial."

## Clarifications

### Session 2026-10-04 (decisões tomadas antes da especificação, na conversa que a originou)

- Q: Como dividir o pedido original ("motorista pode cancelar; o passageiro é avisado por modal e
  tem a corrida cancelada") em specs de spec-kit? → A: duas features, uma por app, mesmo padrão
  das features 012/010. A do motorista (`driver/018`) já está especificada e define o evento; esta
  (`passenger`) é a contrapartida: consumir o aviso, exibir a modal e encerrar a corrida local.
- Q: Quem define o formato do aviso? → A: a feature do motorista (emenda 14 do contrato, kind
  `20012`, "Corrida cancelada", sem conteúdo, tags de marcador, orçamento aceito e destinatário).
  Esta feature só o consome, contra o contrato já escrito; a cópia do contrato do passageiro é
  atualizada pela alteração da feature do motorista (Princípio IV).
- Q: O passageiro também passará a poder cancelar depois de aceitar o orçamento? → A: fora de
  escopo — o pedido é só o aviso recebido do motorista.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ser avisado e voltar ao início quando o motorista cancela (Priority: P1)

Como passageiro com um orçamento aceito, quando o motorista cancela a corrida (a caminho ou já em
andamento), quero ser avisado numa modal e ter o app de volta ao estado inicial, para poder pedir
outra corrida em vez de esperar um motorista que não virá.

**Why this priority**: hoje, depois de aceitar, o passageiro não tem saída por conta própria; sem
este consumo, o cancelamento do motorista deixaria o passageiro preso em "motorista a caminho" ou
"em corrida".

**Independent Test**: com o passageiro em "motorista a caminho" (ou "em corrida"), simular o
recebimento do aviso de cancelamento referenciando o orçamento aceito, assinado pelo motorista dele;
verificar que a modal aparece, e que, ao tocar "OK", o app volta ao estado inicial.

**Acceptance Scenarios**:

1. **Given** o passageiro em "motorista a caminho", **When** chega o aviso de cancelamento do
   motorista da corrida aceita, **Then** uma modal informa que o motorista cancelou a corrida e a
   corrida local é encerrada.
2. **Given** o passageiro em "em corrida", **When** chega o mesmo aviso, **Then** o resultado é o
   mesmo: modal informativa e corrida encerrada.
3. **Given** o passageiro em "orçamento aceito" (motorista ainda não começou a se deslocar),
   **When** chega o aviso, **Then** o resultado é o mesmo.
4. **Given** a modal de cancelamento aberta, **When** o passageiro toca "OK", **Then** a modal
   fecha e o app mostra o estado inicial: painel de solicitação disponível, sem rota, sem marcador
   do motorista.

---

### User Story 2 - Nada da corrida cancelada sobra no app (Priority: P1)

Como passageiro, quero que, ao ser avisado do cancelamento, nenhum vestígio da corrida cancelada
permaneça (posição do motorista, rota, destino da corrida) nem volte a aparecer ao reabrir o app.

**Why this priority**: sem a limpeza completa e persistida, o app mostraria um motorista fantasma
ou reabriria numa corrida que não existe mais.

**Independent Test**: depois do cancelamento, verificar que o mapa não tem marcador do motorista
nem rota do motorista, que o estado persistido é "inicial", e que reabrir o app (nova instância
sobre o mesmo armazenamento) não reexibe a modal nem a corrida.

**Acceptance Scenarios**:

1. **Given** o passageiro cancelado, **When** o mapa é exibido, **Then** o marcador do motorista e
   o trajeto enviado por ele não aparecem.
2. **Given** o passageiro cancelado, **When** o app é reiniciado, **Then** abre no estado inicial,
   sem corrida aceita e sem modal.
3. **Given** a corrida cancelada, **When** o passageiro faz uma nova solicitação, **Then** o fluxo
   segue normalmente, sem interferência da corrida anterior.

---

### User Story 3 - Ignorar avisos que não valem para a corrida atual (Priority: P2)

Como passageiro, não quero ser incomodado por avisos de cancelamento forjados, duplicados ou
referentes a outra corrida.

**Why this priority**: a tag que referencia a corrida é pública no relay; qualquer um poderia
publicar um aviso com ela. Só o motorista da corrida aceita pode cancelá-la.

**Independent Test**: simular avisos com autor diferente do motorista da corrida, com referência a
outro orçamento, fora de uma corrida aceita, e duplicados; verificar que nenhum abre modal nem muda
o estado.

**Acceptance Scenarios**:

1. **Given** uma corrida aceita, **When** chega um aviso assinado por outra chave que não a do
   motorista dela, **Then** é ignorado: sem modal, sem mudança de estado.
2. **Given** uma corrida aceita, **When** chega um aviso referenciando outro orçamento, **Then** é
   ignorado.
3. **Given** o passageiro no estado inicial, aguardando orçamentos ou aguardando avaliação, **When**
   chega um aviso, **Then** é ignorado.
4. **Given** o aviso já tratado, **When** o mesmo evento é reentregue (outro relay), **Then** nada
   acontece além do primeiro tratamento.

---

### Edge Cases

- Aviso chegando com o passageiro em "destino confirmado, aguardando avaliação": a corrida já foi
  concluída, então o aviso é ignorado e a avaliação segue normalmente.
- O aviso chega enquanto outra modal da corrida está aberta (por exemplo, "motorista chegou"):
  o cancelamento prevalece e as modais da corrida cancelada não permanecem.
- Eventos posteriores ao cancelamento referentes à corrida cancelada (localização `20005`, chegada
  `20007`/`20009`, rota `20011`): ignorados, pois já não há corrida aceita.
- O app é fechado antes de o passageiro tocar "OK": ao reabrir, a corrida já está encerrada e a
  modal não reaparece (a oportunidade de ler o aviso se perde, como nas demais modais informativas
  da corrida).
- O aviso nunca chega (relay fora do ar no momento do cancelamento): o passageiro permanece no
  estado em que estava; resolver isso é trabalho futuro (ver Assumptions).
- A modal de avaliação **não** é aberta por um cancelamento (a avaliação é só de corrida concluída).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O app MUST passar a receber o aviso de cancelamento da corrida (`kind: 20012`,
  emenda 14 do contrato), para o que MUST incluí-lo nos kinds da sua inscrição.
- **FR-002**: Um aviso só MUST ser aceito se (a) tiver a assinatura verificada, (b) tiver sido
  assinado pelo motorista da corrida aceita, (c) referenciar o orçamento aceito dessa corrida e (d)
  chegar com o passageiro em "orçamento aceito", "motorista a caminho" ou "em corrida". Qualquer
  outro aviso MUST ser ignorado sem erro e sem efeito.
- **FR-003**: Ao aceitar o aviso, o app MUST exibir uma modal informando que o motorista cancelou a
  corrida, com um único botão "OK".
- **FR-004**: Ao aceitar o aviso, o app MUST encerrar a corrida no app do passageiro: voltar ao
  estado inicial e descartar a corrida aceita, persistindo isso de modo que sobreviva a um
  reinício.
- **FR-005**: O encerramento MUST ser aplicado no instante do recebimento (não só quando o
  passageiro tocar "OK"), de modo que fechar o app com a modal aberta não reabra a corrida.
- **FR-006**: O encerramento MUST remover do mapa o marcador do motorista e a rota enviada por ele,
  e MUST parar de aceitar eventos da corrida cancelada.
- **FR-007**: O cancelamento MUST NOT abrir a modal de avaliação da corrida.
- **FR-008**: O aviso MUST ter efeito uma única vez por corrida; reentregas MUST NOT reabrir a modal.
- **FR-009**: Depois do encerramento, o app MUST permitir uma nova solicitação de corrida
  normalmente.
- **FR-010**: Esta feature MUST NOT alterar o formato de nenhum evento: consome o `kind: 20012`
  exatamente como definido pela emenda 14 (Princípio IV).

### Key Entities

- **Corrida aceita (existente)**: orçamento aceito pelo passageiro e a chave pública do motorista
  escolhido. Passa a poder ser encerrada por cancelamento do motorista, além da conclusão normal.
- **Estado de corrida do passageiro (existente)**: ganha uma transição de qualquer fase de corrida
  aceita (exceto a de avaliação) de volta ao estado inicial, por cancelamento.
- **Aviso de cancelamento (definido pela feature do motorista)**: evento do motorista, sem
  conteúdo, que identifica a corrida pelo orçamento aceito e o passageiro pelo destinatário.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Em 100% dos avisos válidos recebidos nas três fases canceláveis, a modal aparece e o
  app já está no estado inicial no instante em que ela aparece.
- **SC-002**: Em 100% dos avisos inválidos (autor errado, outra corrida, fase errada, duplicado,
  assinatura inválida), nenhuma modal aparece e nenhum estado muda.
- **SC-003**: Depois do cancelamento e de um reinício do app, 100% das aberturas mostram o
  passageiro no estado inicial, sem corrida aceita e sem modal.
- **SC-004**: Depois do cancelamento, o passageiro consegue solicitar e concluir uma nova corrida
  sem nenhuma interferência da cancelada.
- **SC-005**: Em 0% dos cancelamentos a modal de avaliação é aberta.

## Assumptions

- Divisão de escopo: esta feature é só o lado do passageiro; o botão, a modal de confirmação e a
  publicação do aviso são `driver/018-cancelar-corrida-motorista`. Para um teste ponta a ponta,
  as duas são necessárias; sem a do motorista, o aviso só existe simulado em teste.
- O encerramento é aplicado ao receber o aviso, não ao tocar "OK" — a mesma escolha de
  `movementNotified` (feature 009) e das confirmações (feature 010), que marcam no momento em que a
  modal abre, para nunca reexibir num reinício. Consequência aceita: fechar o app antes de ler a
  modal perde o texto do aviso, mas nunca deixa a corrida aberta.
- Os orçamentos já recebidos e persistidos da solicitação cancelada não são tratados aqui: seguem
  como histórico local, sem uso, como já acontece em corridas concluídas.
- Sem confirmação ou resposta ao motorista: o cancelamento é uma notificação de via única; nenhum
  evento é publicado pelo passageiro nesta feature.
- Falta de entrega do aviso (sem relay no momento) não é tratada; o passageiro continua no estado
  anterior. Expiração por silêncio do motorista é trabalho futuro.
- A modal é informativa, no padrão visual das demais (`DriverMovingModal`: mensagem + "OK").
- Dependência: reaproveita o estado persistido do passageiro, a armazenagem da corrida aceita e a
  verificação de autor já usada pelas features 016 e 018.

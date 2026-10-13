# Feature Specification: Conexão do Passageiro com Relays Nostr

**Feature Branch**: `002-nostr-relay-connection`

**Created**: 2026-09-15

**Status**: Draft

**Input**: User description: "Conexão do aplicativo do passageiro com relays Nostr: identidade criptográfica própria e persistente, conexão simultânea a múltiplos relays com estado observável, publicação e recepção de eventos assinados, e gerenciamento da lista de relays. Feature simétrica à 002-nostr-relay-connection do aplicativo do motorista, herdando dela o contrato de eventos e as decisões técnicas, e acrescentando uma user story P1 de validação cross-app."

## Clarifications

### Session 2026-09-15

Nenhuma pergunta foi necessária: as duas ambiguidades que a feature equivalente do motorista precisou
clarificar já vêm resolvidas por herança e constam da descrição de entrada.

- Q: O que entra no escopo de identidade (chaves Nostr) nesta feature? → A: herdado do motorista —
  chave gerada uma vez e persistida no aparelho, mantendo a mesma identidade entre execuções
- Q: Como os relays são escolhidos nesta feature? → A: herdado do motorista — lista inicial padrão
  embutida + tela para adicionar e remover relays, com a lista persistida

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Conectar-se a relays e enxergar o estado da conexão (Priority: P1)

Como passageiro, quero que o aplicativo se conecte aos relays configurados ao ser aberto e me mostre
claramente quais estão conectados, para saber se consigo ou não alcançar motoristas pela rede.

**Why this priority**: sem conexão estabelecida e observável, nenhuma troca de eventos é possível e
nenhuma das demais histórias tem como ser validada.

**Independent Test**: abrir o aplicativo com a lista padrão de relays e verificar que o estado de cada
relay é exibido e evolui de "conectando" para "conectado" ou "indisponível", sem travar a interface.

**Acceptance Scenarios**:

1. **Given** o aplicativo instalado e com conectividade de rede, **When** o passageiro o abre,
   **Then** cada relay da lista aparece com seu estado de conexão atualizado em tempo real.
2. **Given** um relay inalcançável na lista, **When** a conexão falha, **Then** apenas aquele relay é
   marcado como indisponível, com o motivo resumido, e os demais permanecem conectados.
3. **Given** o aparelho sem conectividade de rede, **When** o aplicativo é aberto, **Then** é exibida
   uma mensagem explicando a ausência de rede, sem travamento nem erro técnico cru.
4. **Given** o aplicativo conectado, **When** o passageiro o coloca em segundo plano e retorna,
   **Then** o estado exibido reflete a situação real das conexões naquele momento.

---

### User Story 2 - Ter uma identidade Nostr própria e estável (Priority: P1)

Como passageiro, quero que o aplicativo tenha uma identidade criptográfica própria, criada uma única vez
e mantida entre execuções, para que meus eventos sejam sempre atribuídos a mim e verificáveis por
qualquer pessoa na rede.

**Why this priority**: sem identidade estável não é possível assinar eventos nem ser reconhecido pelo
motorista entre sessões; publicar e receber (US3) dependem dela.

**Independent Test**: abrir o aplicativo, anotar a identidade pública exibida, fechar completamente,
reabrir e verificar que a identidade é exatamente a mesma.

**Acceptance Scenarios**:

1. **Given** o aplicativo aberto pela primeira vez, **When** a inicialização ocorre, **Then** uma
   identidade é criada e sua chave pública é exibida ao passageiro em formato legível e copiável.
2. **Given** o aplicativo já usado antes, **When** ele é reaberto, **Then** a mesma identidade é
   recuperada, sem gerar uma nova.
3. **Given** a identidade existente, **When** o passageiro consulta a tela de identidade, **Then** a
   chave privada **não** é exibida em tela por padrão.
4. **Given** o aplicativo desinstalado e reinstalado, **When** ele é aberto, **Then** uma nova identidade
   é criada, e essa consequência está documentada para o usuário.
5. **Given** as duas apps do protótipo instaladas no mesmo aparelho, **When** ambas são abertas,
   **Then** cada uma exibe uma chave pública **distinta**, confirmando que as identidades são
   independentes e que uma app não acessa o armazenamento seguro da outra.

---

### User Story 3 - Publicar um evento assinado e recebê-lo de volta (Priority: P1)

Como passageiro, quero publicar um evento assinado nos relays conectados e ver os eventos que chegam por
eles, para comprovar que a comunicação de ida e volta funciona sem nenhum servidor próprio.

**Why this priority**: é a metade da prova de conceito que depende só desta app, e não da outra. Depende
de US1 e US2 e é pré-requisito de US4.

**Independent Test**: publicar um evento de teste pelo aplicativo e observar que ele retorna pela
assinatura de recepção, exibido na lista de eventos recebidos, com origem identificada.

**Acceptance Scenarios**:

1. **Given** ao menos um relay conectado e a identidade criada, **When** o passageiro publica um evento
   de teste, **Then** o aplicativo informa por relay se a publicação foi aceita ou recusada.
2. **Given** uma assinatura ativa de eventos, **When** um evento correspondente chega de um relay,
   **Then** ele é exibido na lista com autor, horário e conteúdo.
3. **Given** um evento recebido com assinatura inválida, **When** ele chega, **Then** é descartado e não
   aparece na lista.
4. **Given** o mesmo evento entregue por dois relays diferentes, **When** ambos chegam, **Then** ele é
   exibido uma única vez.
5. **Given** nenhum relay conectado, **When** o passageiro tenta publicar, **Then** a ação é impedida com
   explicação, sem perda silenciosa do conteúdo.

---

### User Story 4 - Receber e verificar um evento publicado pelo motorista (Priority: P1)

Como autor do TCC, quero que o aplicativo do passageiro receba e verifique um evento publicado pelo
aplicativo do motorista, para comprovar que duas aplicações independentes, sem backend e sem se
conhecerem, interoperam através de relays Nostr públicos.

**Why this priority**: esta é a hipótese central do trabalho. US3 prova que a app fala com a rede; esta
prova que **as duas pontas do protótipo se falam**, que é o que o TCC afirma ser viável. É a única
história cujo resultado não pode ser obtido por nenhuma das duas apps sozinha.

**Independent Test**: com as duas apps instaladas no mesmo aparelho, publicar um evento de teste pelo app
do motorista e verificar que ele aparece na lista de eventos recebidos do app do passageiro, com a
assinatura verificada e o autor igual à chave pública exibida pelo app do motorista.

**Dependência externa**: exige o aplicativo do motorista com a feature `002-nostr-relay-connection`
**implementada**, não apenas especificada. Essa app é mantida em outro diretório
(`Prototipo/driver`) e por outra pessoa/sessão — a validação desta história é o único ponto desta
feature que não depende só deste projeto.

**Acceptance Scenarios**:

1. **Given** as duas apps conectadas ao menos a um relay em comum, **When** o motorista publica um evento
   de teste, **Then** ele aparece na lista de eventos recebidos do passageiro.
2. **Given** o evento recebido do motorista, **When** o passageiro o inspeciona, **Then** o autor exibido
   é exatamente a chave pública exibida pela tela de identidade do app do motorista.
3. **Given** o evento recebido do motorista, **When** sua assinatura é verificada, **Then** a verificação
   é bem-sucedida e o evento é exibido; caso contrário, é descartado sem ser exibido.
4. **Given** as duas apps sem nenhum relay em comum na lista, **When** o motorista publica, **Then** o
   evento **não** chega ao passageiro — comprovando que o relay compartilhado é o meio de transporte, e
   não uma comunicação direta entre as apps.

---

### User Story 5 - Gerenciar a lista de relays (Priority: P2)

Como passageiro, quero adicionar e remover relays da minha lista, para testar diferentes provedores, não
depender de um conjunto fixo escolhido pelo desenvolvedor e garantir que compartilho ao menos um relay
com o motorista.

**Why this priority**: é o que permite avaliar comportamento em relays distintos — dado relevante para a
análise de viabilidade — e é também o que torna o cenário 4 da User Story 4 executável. Mas o aplicativo
já é demonstrável com a lista padrão, então não bloqueia as histórias P1.

**Independent Test**: adicionar um relay novo, confirmar que ele passa a ser usado, removê-lo, fechar e
reabrir o aplicativo, verificando que a lista persistiu.

**Acceptance Scenarios**:

1. **Given** a tela de relays, **When** o passageiro adiciona um endereço de relay válido, **Then** o
   aplicativo tenta conectar-se a ele e passa a exibi-lo na lista.
2. **Given** um endereço inválido ou duplicado, **When** o passageiro tenta adicioná-lo, **Then** a
   adição é recusada com explicação, e a lista permanece inalterada.
3. **Given** um relay na lista, **When** o passageiro o remove, **Then** a conexão é encerrada e ele
   deixa de receber ou publicar eventos por ele.
4. **Given** alterações feitas na lista, **When** o aplicativo é fechado e reaberto, **Then** a lista
   alterada é restaurada.
5. **Given** a lista esvaziada pelo passageiro, **When** ele abre a tela principal, **Then** o aplicativo
   explica que nenhum relay está configurado e oferece restaurar a lista padrão.

---

### Edge Cases

- Como o sistema se comporta quando um relay aceita a conexão mas nunca responde? Deve haver limite de
  espera, após o qual o relay é marcado como indisponível.
- O que acontece quando a rede cai durante o uso? As conexões devem ser marcadas como perdidas e
  reestabelecidas quando a rede voltar, sem intervenção manual.
- O que acontece quando a rede alterna entre Wi-Fi e dados móveis? A reconexão deve ocorrer sem
  duplicar eventos já recebidos.
- Como o sistema se comporta quando um relay exige pagamento ou autenticação para publicar? A recusa
  deve ser reportada por relay, sem sugerir que a publicação foi bem-sucedida.
- O que acontece quando um relay envia um volume muito grande de eventos? A interface deve permanecer
  responsiva, limitando o que é mantido em memória.
- O que acontece se o armazenamento seguro da identidade estiver indisponível no aparelho? O aplicativo
  deve informar o problema em vez de gerar silenciosamente uma identidade nova a cada abertura.
- O que acontece quando o relay entrega um evento de um kind desconhecido, vindo de outro cliente da
  rede pública? Deve ser ignorado sem erro e sem poluir a lista exibida.
- O que acontece se o conteúdo de um evento recebido contiver marcação ou algo que aparente ser
  instrução? Deve ser exibido como texto simples, nunca interpretado.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O aplicativo MUST conectar-se, na inicialização, a todos os relays da lista configurada.
- **FR-002**: O aplicativo MUST exibir o estado de cada relay (conectando, conectado, indisponível) e
  atualizá-lo em tempo real.
- **FR-003**: Falha em um relay MUST NOT impedir o funcionamento com os demais.
- **FR-004**: O aplicativo MUST criar uma identidade criptográfica na primeira execução e reutilizá-la
  nas execuções seguintes.
- **FR-005**: A chave privada MUST ser guardada no armazenamento protegido do aparelho e MUST NOT ser
  exibida por padrão, registrada em log ou enviada a qualquer relay.
- **FR-006**: O aplicativo MUST exibir a chave pública da identidade em formato legível e copiável.
- **FR-007**: O aplicativo MUST publicar eventos assinados com a identidade do passageiro e MUST
  reportar, por relay, se a publicação foi aceita ou recusada.
- **FR-008**: O aplicativo MUST receber eventos dos relays por assinatura e exibi-los com autor, horário
  e conteúdo.
- **FR-009**: O aplicativo MUST verificar a assinatura de todo evento recebido **antes** de qualquer
  outro processamento e MUST descartar os eventos cuja assinatura não seja válida.
- **FR-010**: O aplicativo MUST exibir uma única vez um evento entregue por mais de um relay,
  deduplicando pelo identificador do evento.
- **FR-011**: O aplicativo MUST permitir adicionar e remover relays, validando o endereço informado e
  rejeitando duplicados.
- **FR-012**: A lista de relays MUST ser persistida no aparelho e restaurada ao reabrir o aplicativo.
- **FR-013**: O aplicativo MUST oferecer restaurar a lista padrão de relays quando a lista estiver vazia.
- **FR-014**: O aplicativo MUST reconectar-se automaticamente aos relays após perda e retorno de rede.
- **FR-015**: O aplicativo MUST tratar ausência de rede e falhas de relay com mensagens compreensíveis,
  sem exibir erro técnico cru nem travar.
- **FR-016**: O aplicativo MUST declarar a permissão de acesso à rede no manifesto principal, e não
  apenas no de depuração, para que funcione em build de produção.
- **FR-017**: O trabalho MUST registrar, em documento versionado junto à feature, a biblioteca Nostr
  adotada, as alternativas avaliadas com versões e datas de publicação, e os critérios que levaram à
  escolha — insumo direto da análise de viabilidade do TCC e exigência do Princípio III da constituição.
- **FR-018**: O aplicativo MUST tratar o conteúdo de eventos recebidos como dado, exibindo-o como texto
  simples, nunca como marcação ou instrução; kinds desconhecidos MUST ser ignorados sem erro.
- **FR-019**: O formato dos eventos trafegados MUST ser idêntico ao especificado pelo contrato da app do
  motorista, replicado sem divergência em `contracts/nostr-events.md` desta feature.
- **FR-020**: O aplicativo MUST exibir eventos recebidos de outros autores identificando o autor, de modo
  que um evento publicado pelo motorista seja distinguível de um evento publicado pelo próprio
  passageiro.

### Key Entities

- **Identidade do passageiro**: par de chaves criptográficas; a chave pública identifica o passageiro na
  rede, a privada assina os eventos. Criada uma vez, persistida, nunca compartilhada. Independente da
  identidade do motorista, mesmo no mesmo aparelho.
- **Relay**: endereço de um servidor da rede Nostr, com estado de conexão e origem (padrão ou adicionado
  pelo passageiro). Vários relays coexistem de forma independente.
- **Evento**: mensagem assinada trafegada pelos relays, com identificador próprio, autor, horário, tipo
  e conteúdo. O identificador é o que permite reconhecer duplicatas entre relays; o autor é o que permite
  distinguir um evento do motorista de um evento próprio.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Com a lista padrão e rede disponível, ao menos um relay atinge o estado "conectado" em até
  5 segundos após a abertura do aplicativo, em 9 de 10 tentativas.
- **SC-002**: Um evento publicado pelo passageiro é recebido de volta pela assinatura do próprio
  aplicativo em até 5 segundos, em 9 de 10 tentativas.
- **SC-003**: Com um relay inalcançável na lista, o aplicativo continua publicando e recebendo pelos
  demais em 100% das tentativas.
- **SC-004**: A identidade permanece idêntica após 5 ciclos consecutivos de fechar e reabrir o
  aplicativo.
- **SC-005**: Alterações na lista de relays sobrevivem a 100% dos reinícios do aplicativo.
- **SC-006**: A interface permanece responsiva (sem congelamento perceptível) ao receber uma rajada de
  ao menos 100 eventos.
- **SC-007**: Nenhuma chave privada aparece em tela, em log do aplicativo ou em tráfego enviado aos
  relays, verificado por inspeção.
- **SC-008**: O documento de decisão da biblioteca lista ao menos duas alternativas avaliadas, com
  versão e data de publicação de cada uma, e os critérios aplicados.
- **SC-009**: Um evento publicado pelo aplicativo do motorista é recebido e exibido pelo aplicativo do
  passageiro em até 10 segundos, em 8 de 10 tentativas, com o autor batendo com a chave pública do
  motorista.
- **SC-010**: As chaves públicas exibidas pelas duas apps no mesmo aparelho são diferentes em 100% das
  instalações.

## Assumptions

- Esta feature **herda** as decisões técnicas da feature equivalente do motorista
  (`Prototipo/driver/specs/002-nostr-relay-connection/research.md`), que é anterior: biblioteca
  `dart_nostr ^10.0.1`, armazenamento seguro para a chave privada, preferências locais para a lista de
  relays, deduplicação por identificador do evento, testes com dublês e mesma lista padrão de relays.
  Essas decisões são registradas como herdadas, e não re-decididas — divergir delas sem motivo criaria
  duas apps incompatíveis.
- O `contracts/nostr-events.md` desta feature é **cópia congelada** do contrato do motorista. Qualquer
  mudança futura no formato de evento MUST ser aplicada nas duas apps na mesma alteração, e este projeto
  não edita o diretório do motorista — mudanças precisam ser comunicadas a quem o mantém.
  > **Superado em 2026-09-16**: a sessão dedicada ao motorista foi encerrada e uma única sessão passou
  > a manter as duas apps; a constituição 2.0.0 exige replicação direta nos dois lados. A premissa
  > permanece como registro fiel das condições em que esta especificação foi escrita.
- O evento publicado nesta etapa é um **evento de teste genérico** (`kind: 1`), não um formato de domínio
  de caronas. Oferta, solicitação e mensagem entre pares são objeto de features posteriores.
- Criptografia de conteúdo entre pares está fora do escopo: os eventos desta etapa são públicos e servem
  para comprovar conectividade e interoperabilidade.
- A validação da User Story 4 exige a app do motorista implementada; as histórias 1 a 3 são validáveis
  apenas com esta app.
- O alvo continua sendo exclusivamente Android, conforme decidido na feature 001.
- Assume-se conectividade de internet intermitente como cenário realista de uso em mobilidade urbana.
- A constituição do projeto foi ratificada (versão 1.0.0) antes desta feature: diferentemente da feature
  001, os gates de constituição aqui são avaliados de verdade, não por vacuidade.

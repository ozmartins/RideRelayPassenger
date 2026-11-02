# Feature Specification: Mapa e Destino do Passageiro

**Feature Branch**: `004-mapa-destino-passageiro`

**Created**: 2026-09-17

**Status**: Draft

**Input**: User description: "A tela inicial do app do passageiro deve ser um mapa. O mapa deve
corresponder ao local real onde o passageiro está. O mapa deve possuir um indicador da posição do
passageiro no mapa (o icone de um carro, como feito no app do motorista). Ainda nesta tela, o
passageiro deve ter acesso a um campo que lhe permmita informar o endereço para onde deseja ir.
Nenhuma mensagem deve ser enviada relay quando o usuário informar o local pra onde deseja ir (por
enquanto)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver a própria posição no mapa ao abrir o aplicativo (Priority: P1)

Como passageiro, quero que a tela inicial do aplicativo mostre um mapa centrado onde eu realmente
estou, com um indicador visual da minha posição, para saber de imediato que o aplicativo sabe onde
estou antes de informar para onde quero ir.

**Why this priority**: é a pré-condição de tudo o mais nesta feature — sem mapa e sem posição real não
há contexto para o passageiro avaliar se o destino que vai informar faz sentido a partir de onde ele
está.

**Independent Test**: abrir o aplicativo com localização disponível e verificar que a tela inicial é
um mapa centrado na posição real do aparelho, com um indicador de carro naquele ponto.

**Acceptance Scenarios**:

1. **Given** o aplicativo instalado, com permissão de localização concedida e localização disponível,
   **When** o passageiro o abre, **Then** a tela inicial exibe um mapa centrado na posição atual do
   aparelho, com um ícone de carro marcando aquele ponto.
2. **Given** a tela de mapa aberta, **When** o passageiro se desloca fisicamente, **Then** o indicador
   de posição acompanha o deslocamento em um intervalo perceptível como "tempo real", sem exigir ação
   manual para atualizar.
3. **Given** o aplicativo aberto pela primeira vez, **When** a permissão de localização ainda não foi
   concedida, **Then** o aplicativo solicita a permissão, explicando por que ela é necessária.
4. **Given** a permissão de localização negada, ou a localização indisponível por qualquer motivo,
   **When** o passageiro está na tela de mapa, **Then** uma mensagem compreensível explica a situação,
   sem travar o aplicativo nem exibir erro técnico cru.

---

### User Story 2 - Informar o endereço de destino (Priority: P2)

Como passageiro, quero um campo na própria tela de mapa para digitar o endereço para onde quero ir,
para deixar registrada minha intenção de destino antes de qualquer busca por motorista.

**Why this priority**: depende do mapa já estar na tela (US1) para fazer sentido como parte do mesmo
fluxo, mas é a segunda peça explicitamente pedida para essa tela — sem ela, a tela de mapa não avança a
intenção do passageiro além de mostrar onde ele está.

**Independent Test**: com o mapa exibido, tocar no campo de destino, digitar um endereço e verificar
que o texto informado fica visível na tela, sem nenhuma comunicação de rede disparada pela ação.

**Acceptance Scenarios**:

1. **Given** a tela de mapa exibida, **When** o passageiro toca no campo de destino e digita um
   endereço, **Then** o texto digitado fica visível no campo enquanto ele digita.
2. **Given** um endereço já digitado no campo de destino, **When** o passageiro altera ou apaga o
   texto, **Then** o campo reflete sempre o conteúdo mais recente digitado.
3. **Given** o passageiro digitando ou já tendo digitado um endereço no campo de destino, **When**
   essa ação ocorre, **Then** nenhuma mensagem é publicada em nenhum relay como consequência dela.
4. **Given** o campo de destino vazio, **When** a tela de mapa é exibida, **Then** o campo aparece
   vazio, com um texto de apoio indicando o que digitar (ex.: "Para onde você quer ir?").

### Edge Cases

- O que acontece se o passageiro negar a permissão de localização permanentemente (opção "não
  perguntar de novo")? A mensagem de localização indisponível permanece, com uma indicação de como
  conceder a permissão pelas configurações do aparelho — o aplicativo não insiste com o pedido a cada
  abertura.
- O que acontece com o indicador de posição se a localização ficar temporariamente imprecisa (sinal
  fraco)? O indicador continua na última posição conhecida; não há requisito nesta feature de exibir o
  grau de precisão.
- O que acontece se o passageiro trocar de aba ou tela e voltar para o mapa? O texto já digitado no
  campo de destino permanece, contanto que o aplicativo não tenha sido encerrado por completo.
- O que acontece se o passageiro informar um texto que não corresponde a um endereço real (endereço
  incompleto, inválido, ou aleatório)? O aplicativo aceita o texto como digitado, sem validar se é um
  endereço real — essa validação não é parte desta feature.
- O que acontece se a localização do passageiro estiver indisponível quando ele já tiver digitado um
  destino? O campo de destino continua funcionando normalmente; ele não depende da posição atual estar
  disponível.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O aplicativo MUST exibir um mapa como tela inicial, centrado na posição real do
  aparelho.
- **FR-002**: O mapa MUST exibir um ícone de carro como indicador visual da posição atual do
  passageiro.
- **FR-003**: O indicador de posição MUST acompanhar a posição real do passageiro conforme ela mude,
  sem exigir atualização manual.
- **FR-004**: O aplicativo MUST solicitar a permissão de localização ao passageiro quando ela ainda
  não tiver sido concedida, explicando por que é necessária.
- **FR-005**: Se a permissão de localização for negada ou a localização estiver indisponível por
  qualquer motivo, o aplicativo MUST exibir uma mensagem compreensível na própria tela de mapa, sem
  travar nem exibir erro técnico cru.
- **FR-006**: A mesma tela do mapa MUST oferecer um campo de texto onde o passageiro pode informar o
  endereço para onde deseja ir.
- **FR-007**: O aplicativo MUST aceitar qualquer texto digitado no campo de destino, sem exigir que
  corresponda a um endereço real ou validável.
- **FR-008**: Informar, alterar ou apagar o texto do campo de destino MUST NOT publicar nem enviar
  nenhuma mensagem a nenhum relay.
- **FR-009**: O campo de destino MUST refletir sempre o valor mais recente digitado, enquanto a tela
  estiver em uso.
- **FR-010**: O funcionamento do campo de destino MUST NOT depender de a posição atual do passageiro
  estar disponível.

### Key Entities

- **Posição do passageiro**: coordenadas geográficas atuais do aparelho. Existe apenas em memória,
  atualizada continuamente enquanto o aplicativo está em uso; não é persistida entre execuções nem
  enviada a nenhum relay ou servidor nesta feature.
- **Endereço de destino**: texto livre informado pelo passageiro na tela de mapa, indicando para onde
  ele deseja ir. Existe apenas em memória, local ao aparelho; não é persistido entre execuções nem
  enviado a nenhum relay ou servidor nesta feature — é preparação para uma feature futura que decidirá
  como e se essa intenção passa a ser comunicada.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Com localização disponível, o passageiro vê sua posição real marcada no mapa, com o
  ícone de carro, em até 5 segundos após abrir o aplicativo, em 9 de 10 tentativas.
- **SC-002**: O indicador de posição reflete um deslocamento real do aparelho em até 10 segundos, em 9
  de 10 tentativas.
- **SC-003**: O texto digitado no campo de destino aparece refletido na tela em até 1 segundo após
  cada caractere, em 100% das tentativas.
- **SC-004**: Em 100% das tentativas de informar, alterar ou apagar o texto do campo de destino,
  nenhuma mensagem é publicada em nenhum relay como consequência direta dessa ação.
- **SC-005**: Em 100% das tentativas de negar ou perder a permissão de localização, o aplicativo exibe
  uma explicação compreensível na tela de mapa, sem travar.

## Assumptions

- A tela de mapa passa a ser a **aba inicial** da navegação do aplicativo, seguindo o mesmo padrão já
  adotado pelo motorista na feature equivalente (`driver/specs/004-mapa-status-motorista`): uma barra
  de navegação inferior com o mapa como primeiro destino. O conteúdo atual da tela inicial (lista de
  eventos recebidos) passa a ser uma aba própria, e as telas de Identidade e Relays continuam
  acessíveis a partir da navegação, sem serem removidas — a descrição da feature pede uma nova tela
  inicial, não a eliminação das demais.
- O ícone de carro é a escolha explícita do usuário para o indicador de posição (ao contrário da
  feature equivalente do motorista, que deixava o visual em aberto); a implementação deve reaproveitar
  o mesmo ícone/estilo já usado no app do motorista para consistência visual entre as duas apps, ainda
  que isso não seja um requisito de contrato entre elas.
- O campo de destino é texto livre, sem geocodificação, sem autocompletar de endereços e sem exibir o
  destino no próprio mapa nesta feature — a descrição pede apenas a coleta do texto, e o "por enquanto"
  explícito sobre não enviar nada a relay indica que a comunicação desse destino é assunto de feature
  futura.
- O texto do campo de destino não precisa sobreviver ao encerramento completo do aplicativo; persistir
  apenas durante a sessão em uso (por exemplo, ao trocar de aba e voltar) atende ao pedido. Persistência
  entre execuções não foi solicitada e não é assumida.
- Local e acesso à localização do aparelho: esta é a feature que justifica, perante a constituição
  (Restrições de Segurança e Privacidade), o acesso a esse dado sensível no app do passageiro — coleta
  a posição geográfica atual, usa-a apenas para centrar o mapa e mostrar o indicador, e mantém-na só em
  memória, nunca persistida nem enviada a terceiros nesta etapa.
- "Tempo real" no indicador de posição (US1 cenário 2) é interpretado como a atualização contínua e
  automática já coberta, de forma mensurável, por SC-002 — não há exigência adicional de frequência
  além da ali definida.

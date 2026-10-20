# Feature Specification: Mensagens cifradas entre as apps (passageiro)

**Feature Branch**: `022-mensagens-cifradas`

**Created**: 2026-10-06

**Status**: Draft

**Input**: User description (pedido original, que toca as duas apps — ver Clarifications):
"Toda mensagem enviada de um app ao outro deve ser criptografada e assinada (usando-se o par de
chaves assimétricas)."

## Clarifications

### Session 2026-10-06 (decisões tomadas antes da especificação, na conversa que a originou)

- Q: Como dividir entre as apps? → A: duas features, uma por app. A do **motorista**
  (`Prototipo/driver/specs/019-mensagens-cifradas`) **define** o contrato — emenda 17 — e a
  constituição 2.11.0; esta (passageiro) é a contrapartida: replica o contrato, cifra o que o
  passageiro publica e decifra o que recebe. Formato, kinds, marcador `{}` e exceção do `20001` são
  os de lá e **não** são redefinidos aqui.
- Q: O `20001` (Solicitação de corrida) é anúncio a qualquer motorista, sem destinatário. → A:
  **exceção deliberada**: o passageiro continua o publicando só assinado, em claro; posição e
  destino ficam públicos, justificado na emenda e na constituição.
- Q: Qual padrão de cifragem? → A: NIP-44 v2, entre a chave privada do remetente e a pública do
  destinatário (tag `p`). A cifra é implementada no app (o pacote que a traz não resolve junto da
  biblioteca Nostr já usada) e validada com os vetores oficiais — decisão D1 do motorista.
- Q: As tags continuam em claro? → A: sim (`t`, `e`, `p`); só o `content` é cifrado; a assinatura do
  envelope cobre o `content` cifrado.
- Q: O que se cifra nos kinds de `content` vazio? → A: o marcador fixo `{}` (o padrão rejeita entrada
  vazia).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - O que o passageiro envia só o motorista certo lê (Priority: P1)

Como passageiro, quero que a aceitação e a recusa de orçamentos e as confirmações de encontro e de
destino que meu app publica só possam ser lidas pelo motorista a quem se dirigem, para que um
observador do relay não saiba quem aceitei nem o andamento da minha corrida.

**Why this priority**: é o ganho de privacidade do pedido do lado do passageiro.

**Independent Test**: publicar `20003`, `20004`, `20008` e `20010` com o dublê de transporte e
verificar `content` opaco, assinatura válida, tags `t`/`e`/`p` em claro, decifrável só pela chave do
motorista; e que o `20001` continua em claro.

**Acceptance Scenarios**:

1. **Given** um orçamento escolhido, **When** o passageiro toca "Aceitar", **Then** o `20003` sai
   cifrado ao motorista do orçamento e assinado, e os `20004` aos demais, cada um cifrado ao
   respectivo motorista.
2. **Given** o aviso de chegada, **When** o passageiro confirma encontro ou destino, **Then** o
   `20008`/`20010` sai cifrado ao motorista da corrida e assinado.
3. **Given** falha ao cifrar, **When** o app tentaria publicar, **Then** nada é publicado em claro e
   a falha é tratada como "nenhum relay aceitou" já é hoje, sem tela nova.
4. **Given** o passageiro solicitando uma corrida, **When** publica o `20001`, **Then** ele sai
   assinado e em claro, como hoje.

---

### User Story 2 - O que o passageiro recebe é decifrado e o fluxo segue igual (Priority: P1)

Como passageiro, quero que orçamentos, localização, chegada, rota e cancelamentos enviados pelo
motorista — agora cifrados a mim — apareçam e funcionem exatamente como antes.

**Why this priority**: sem decifrar, o fluxo inteiro do passageiro quebra assim que o motorista
passar a cifrar.

**Independent Test**: entregar ao app eventos `20002`, `20005`, `20006`, `20007`, `20009`, `20011` e
`20012` válidos, cifrados ao passageiro, e verificar os mesmos efeitos de hoje (lista de orçamentos,
modais, marcador, rota, encerramentos); entregar variantes inválidas e verificar descarte sem efeito.

**Acceptance Scenarios**:

1. **Given** um orçamento (`20002`) cifrado ao passageiro, com `["p", pubkey do passageiro]`, **When**
   chega, **Then** a assinatura é verificada primeiro, o conteúdo decifrado vira o mesmo
   `ReceivedQuote` de hoje, persistido e exibido.
2. **Given** `20005`, `20006`, `20007`, `20009`, `20011` ou `20012` cifrado ao passageiro, **When**
   chega, **Then** produz o efeito de hoje (marcador, "indisponível", modais de chegada, rota,
   cancelamento).
3. **Given** um evento com assinatura válida mas `p` alheia, em claro, cifrado a outra chave,
   adulterado ou (nos sem dado próprio) que não decifra para exatamente `{}`, **When** chega, **Then**
   é descartado sem erro, sem efeito e sem tocar o relógio de silêncio do motorista (ver FR-007).
4. **Given** assinatura inválida, **When** chega, **Then** é descartado antes de qualquer tentativa de
   decifrar (regra 1 de recepção inalterada).

---

### User Story 3 - Contrato e constituição idênticos nos dois lados (Priority: P2)

Como mantenedor, quero que a cópia do contrato e a constituição do passageiro reflitam a emenda 17 e
a 2.11.0 do motorista, idênticas, para que nenhuma app divirja do formato.

**Independent Test**: `diff` das duas cópias do contrato (menos o cabeçalho de procedência) e dos
corpos das duas constituições: vazio.

**Acceptance Scenarios**:

1. **Given** o contrato do passageiro, **When** lido, **Then** consta a emenda 17 com o cabeçalho de
   procedência atualizado.
2. **Given** as duas constituições, **When** comparadas, **Then** os corpos são idênticos salvo nome,
   escopo e perspectiva.

---

### Edge Cases

- Orçamento de uma versão antiga do motorista (em claro, sem tag `p`): descartado, sem
  compatibilidade (as duas apps atualizam juntas).
- Orçamentos já gravados em SQLite antes desta feature: continuam válidos e exibidos — o que se
  persiste são os campos já decodificados, não o `content` bruto; não há migração.
- Aceitação cifrada a um motorista cuja chave está malformada na tag `p`/autor do orçamento: a
  cifragem falha, nada é publicado (FR-004).
- Rota (`20011`) com até 1000 pontos: o `content` cifrado fica maior; segue dentro do limite de
  tamanho dos relays (medido na feature do motorista, SC-005).
- Localização do motorista a cada 5 s: decifrar cada uma não pode travar o mapa; a chave de conversa
  do par é calculada uma vez e reaproveitada em memória.
- Reabrir o app no meio da corrida: a restauração de estado não depende de nenhum conteúdo cifrado
  persistido; eventos novos chegam cifrados e são decifrados normalmente.
- Aviso de silêncio (feature 021): só conta como "sinal do motorista" o `20005` que passou na
  verificação, no autor, na tag `e`, na tag `p` e na decifração (FR-007).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O passageiro MUST cifrar o `content` de `20003`, `20004`, `20008` e `20010` com a chave
  privada dele e a chave pública do destinatário na tag `p` (motorista do orçamento / da corrida), e
  continuar assinando cada evento depois de cifrar (a assinatura cobre o `content` cifrado).
- **FR-002**: As tags `t`, `e` e `p` MUST permanecer em claro e inalteradas; só o `content` é cifrado.
- **FR-003**: Nos kinds sem dado próprio (`20003`, `20004`, `20008`, `20010`) o texto cifrado MUST ser
  o marcador fixo `{}`.
- **FR-004**: Se a cifragem falhar, o app MUST NOT publicar o evento em claro; a falha MUST ser tratada
  como publicação não aceita por nenhum relay, com a mesma mensagem e o mesmo comportamento que o app
  já tem para isso.
- **FR-005**: O passageiro MUST decifrar, depois da verificação de assinatura, do marcador, da
  deduplicação e da conferência de que a tag `p` é a chave dele, o `content` de `20002`, `20005`,
  `20006`, `20007`, `20009`, `20011` e `20012`, usando a chave privada dele e a pública do autor, e
  aplicar a lógica de hoje ao conteúdo decifrado.
- **FR-006**: Evento cuja tag `p` não é a do passageiro, que está em claro, que não decifra ou, nos
  kinds sem dado próprio (`20006`, `20007`, `20009`, `20012`), que não decifra para exatamente `{}`,
  MUST ser descartado sem erro, sem efeito e sem aparecer ao usuário.
- **FR-007**: O sinal de "motorista a caminho" (primeiro `20005`) e o relógio de silêncio da feature
  021 MUST considerar apenas `20005` que passaram em todas as conferências, **incluindo** a decifração;
  um `20005` que não decifra não rearma o relógio nem dispara "motorista a caminho". Um `20005` que
  decifra mas tem `content` inválido continua rearmando o relógio, como hoje.
- **FR-008**: O `20001` MUST continuar assinado e em claro, com formato inalterado.
- **FR-009**: Orçamentos persistidos MUST continuar sendo gravados como os campos já decodificados
  (sem o `content` cifrado), sem migração de esquema; a decifração acontece antes de qualquer gravação.
- **FR-010**: Nenhum segredo (chave privada, chave de conversa) MUST ser registrado em log, exibido ou
  persistido; valores decifrados MUST continuar sendo dados, nunca instruções (regra 3).
- **FR-011**: A cópia do contrato do passageiro MUST receber a emenda 17 idêntica à do motorista, com
  cabeçalho de procedência atualizado; a constituição do passageiro MUST receber a emenda 2.11.0
  idêntica à do motorista. Ambas são feitas pelas tarefas de gate da feature do motorista, na mesma
  alteração; esta feature apenas as verifica.
- **FR-012**: O comportamento observável do fluxo da corrida (lista de orçamentos, modais, marcador do
  motorista, rota, cancelamentos, expiração por silêncio, avaliação) MUST permanecer idêntico.
- **FR-013**: Código de cifragem, decifração e política MUST nascer com teste (Princípio II): vetores
  oficiais do NIP-44, ida e volta, destinatário errado, adulteração, `content` em claro e marcador
  `{}`; os publicadores e os consumidores têm teste de conteúdo cifrado.

### Key Entities

- **Evento cifrado**: evento de domínio cujo `content` é o texto cifrado ao destinatário; tags
  `t`/`e`/`p` em claro; assinado pelo autor.
- **Destinatário**: chave pública na tag `p`; única que decifra.
- **Exceção do kind 20001**: único kind de domínio sem cifragem, por não ter destinatário.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Em 100 % dos `20003`, `20004`, `20008` e `20010` publicados pelo passageiro, nenhum
  dado é legível sem a chave do motorista destinatário.
- **SC-002**: Em 100 % dos casos de teste de recepção inválida (assinatura inválida, `p` alheia, em
  claro, cifrado a outra chave, adulterado, texto ≠ `{}`), o evento é descartado sem alterar estado,
  sem mostrar erro e sem rearmar o relógio de silêncio.
- **SC-003**: O fluxo completo do passageiro (solicitar → orçamentos → aceitar → a caminho → encontro
  → rota → destino → avaliar, e os cancelamentos/expirações) funciona como antes, com a suíte existente
  passando após os ajustes.
- **SC-004**: O mapa continua a seguir o motorista a cada `20005` (5 s) sem atraso perceptível:
  decifrar leva menos de 100 ms por mensagem, **inclusive a primeira de cada par**, medido no
  emulador `Pixel_6_API34_1` e, se disponível, num aparelho físico.
- **SC-005**: Os corpos das duas constituições e as duas cópias do contrato (menos o cabeçalho de
  procedência) são idênticos.

## Assumptions

- Esta feature depende de `Prototipo/driver/specs/019-mensagens-cifradas` (contrato, constituição
  2.11.0 e gates) e deve ser concluída junto com ela: o formato quebra nos dois sentidos (Princípio
  IV); testes ponta a ponta exigem as duas apps.
- Não há compatibilidade com versões anteriores: evento em claro nos kinds `20002`–`20012` é inválido.
- A cifra NIP-44 é uma cópia, adaptada aos imports do passageiro, da implementada no motorista
  (não há pacote compartilhado entre as apps); os vetores de teste são os mesmos. Um defeito achado
  numa cópia MUST ser conferido na outra.
- `pointycastle` e `crypto` já estão no grafo (transitivos) e são promovidos a diretos aqui também;
  nenhum pacote novo (Princípio III, decisão D1 do motorista, replicada em `research.md`).
- Metadados (autor, `p`, `e`, kind, momento, tamanho) seguem visíveis no relay; ocultá-los está fora
  de escopo. Também fora: cifrar a avaliação (nunca sai do aparelho), cifrar o SQLite em repouso,
  mensagens de chat, rotação de chaves.

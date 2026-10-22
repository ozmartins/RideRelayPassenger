# Especificação: Tag de geohash na solicitação de corrida (passageiro)

**Feature**: `028-tag-geohash-solicitacao` · **App**: `passenger/` · **Data**: 2026-10-21 · **Status**: Draft
**Contrato de eventos**: muda. Emenda 27 de `specs/002-nostr-relay-connection/contracts/nostr-events.md`
(tag `g` do `kind: 20001`), definida pela feature 027 do motorista (`027-filtro-geografico-solicitacoes`) e
replicada aqui. O arquivo do contrato MUST ficar idêntico ao do motorista (exceto o cabeçalho de procedência) e
mudar na mesma alteração nos dois repositórios (Princípio IV da constituição).
**Entrada** (o "exatamente uma tag `g`" do pedido foi substituído por três; ver Clarificações): "Replicar a emenda 27 do contrato de eventos: o kind 20001 passa a incluir a tag `["g", "<geohash da
origem>"]` com a precisão fixada no contrato, calculada a partir da posição de origem da corrida. Escopo: só a
publicação da tag. O passageiro não tem raio nem filtro geográfico."

## Problema

O motorista que se coloca online passa a pedir ao relay só as solicitações da sua região (filtro `#g`). Para que o
relay consiga casar o pedido, a solicitação de corrida do passageiro precisa carregar uma tag `g` com o geohash da
origem. Sem ela, nenhum motorista com a emenda 27 aceita a solicitação do passageiro: a corrida nunca recebe
orçamento.

O relay compara o valor da tag por igualdade exata. Por isso a emenda 27 fixa **três tags `g`**, em 5, 4 e 3
caracteres (prefixos do mesmo geohash), e o motorista escolhe a precisão que cobre o seu raio. O rascunho do
motorista registrava isso como ponto aberto; o autor confirmou **três tags** (5, 4, 3) em 2026-10-21, o que
substitui a expressão "exatamente uma tag `g`" do pedido original.

## Clarificações

### Sessão 2026-10-21

- Q: O pedido dizia "exatamente uma tag `g`", mas o rascunho da emenda 27 no motorista define três (5, 4 e 3). Qual vale? → A: Três tags `g` (5, 4 e 3), conforme o rascunho do motorista.

## Cenários de usuário

### US1 — A solicitação chega ao motorista da região (P1)
O passageiro solicita uma corrida como hoje. O evento publicado leva, além do marcador, as três tags `g` derivadas
da origem da corrida, e nada mais muda para o passageiro (nenhuma tela nova, nenhum campo novo).

**Teste independente**: publicar uma solicitação com origem conhecida (fixture) e conferir as tags do evento
assinado e o `content`.

1. **Dado** uma solicitação com origem `(lat, lon)`, **quando** o `20001` é publicado, **então** o evento tem
   exatamente três tags `g`, com os geohashes de 5, 4 e 3 caracteres da origem, nessa ordem, além do marcador `t`.
2. **Dado** a mesma solicitação, **então** o `content` é o mesmo de antes da emenda (origem, destino, pagamento e,
   quando houver recibos, `reputacao` em claro), sem campo novo.
3. **Dado** uma origem em hemisfério sul/oeste, no antimeridiano ou perto dos polos, **então** os geohashes
   coincidem com o vetor compartilhado com o motorista.

### US2 — Vetor de contrato idêntico nas duas apps (P1)
O cálculo do geohash do passageiro e o do motorista não podem divergir nem por um caractere, senão o relay não
casa o filtro. Um vetor de teste compartilhado, copiado byte a byte do motorista, fixa os valores esperados.

**Teste independente**: rodar o teste do vetor e `diff` do arquivo contra o do motorista.

1. **Dado** `test/fixtures/geohash_vectors.json` idêntico ao do motorista, **quando** o teste roda, **então** o
   cálculo do passageiro reproduz as três precisões de cada ponto do vetor.
2. **Dado** os pontos de âncora públicos (`42.605, -5.603 → ezs42`; `57.64911, 10.40744 → u4pruydqqvj`),
   **então** o cálculo os reproduz.

### US3 — Contrato e documentação em dia (P2)
O texto da emenda 27 entra no contrato do passageiro igual ao do motorista; `CLAUDE.md` registra a nova
invariante entre as duas apps.

**Teste independente**: `diff` dos dois contratos mostra só o cabeçalho de procedência.

## Casos limite

- Origem nos limites de coordenada (±90, ±180): o cálculo MUST produzir geohash válido (não lançar nem repetir).
- Solicitação reenviada ou republicada: toda publicação de `20001` leva as três tags, sem exceção de caminho.
- Origem inválida (fora de −90..90 / −180..180) não ocorre pelo fluxo normal (vem do GPS); se ocorrer, a
  publicação falha de forma explícita, sem enviar evento sem `g` ou com `g` errada.
- Relay que ignora tags desconhecidas ou o filtro `#g`: sem efeito para o passageiro, que não filtra por `g`.
- Solicitações antigas, sem `g`, não são republicadas por esta feature.

## Requisitos

### Requisitos funcionais

- **FR-001**: Todo `kind: 20001` publicado MUST levar, além da tag de marcador `t`, exatamente três tags `g` com
  os geohashes de 5, 4 e 3 caracteres da `origin` do `content`; os de 4 e 3 são prefixos do de 5. A ordem
  `5, 4, 3` é escolha deste app (o contrato não a fixa); os testes a conferem, mas o motorista não pode depender dela.
- **FR-002**: O geohash MUST seguir o padrão do contrato (Niemeyer; alfabeto `0123456789bcdefghjkmnpqrstuvwxyz`,
  minúsculas, bits alternando longitude e latitude a partir da longitude) e ser idêntico ao do motorista para
  qualquer coordenada.
- **FR-003**: O `content` do `20001` (inclusive coordenadas e `reputacao` em claro) MUST permanecer exatamente
  como antes; a tag fica em claro, como o resto do `20001`.
- **FR-004**: O passageiro MUST NOT ter raio, filtro geográfico nem validação da tag `g` ao receber eventos; esta
  feature só publica.
- **FR-005**: O texto da emenda 27 MUST ser aplicado ao contrato do passageiro literalmente igual ao do
  motorista, na mesma alteração em que o código muda; o `CLAUDE.md` MUST citar a invariante do vetor de geohash.
- **FR-006**: `test/fixtures/geohash_vectors.json` MUST ser cópia byte a byte do arquivo gerado no motorista
  (`diff` sem saída), e um teste MUST conferir o cálculo do passageiro contra ele.
- **FR-007**: O cálculo do geohash MUST ser código próprio, sem dependência nova (Princípio III), e a decisão MUST
  ficar registrada no `research.md`.
- **FR-008**: Nenhum teste MUST contatar relay real; a publicação é verificada com o transporte dublê.

### Entidades-chave

- **Geohash da origem**: texto de 5, 4 ou 3 caracteres derivado da latitude/longitude de origem da corrida;
  não é persistido, é recalculado a cada publicação.
- **Vetor de geohash**: arquivo de teste compartilhado com o motorista, com pontos e as três precisões esperadas.

## Critérios de sucesso

- **SC-001**: 100% dos `20001` publicados nos testes têm exatamente três tags `g` corretas e uma tag `t`.
- **SC-002**: O vetor compartilhado passa integralmente nas duas apps e o `diff` do arquivo entre elas é vazio.
- **SC-003**: O `content` de um `20001` publicado é idêntico byte a byte ao de antes da emenda para a mesma
  entrada.
- **SC-004**: `flutter analyze` sem avisos e `flutter test` integral sem testes ignorados; nenhum teste usa relay
  real.
- **SC-005**: O `diff` entre os dois contratos de eventos mostra só o cabeçalho de procedência.

## Premissas e dependências

- A emenda 27 é definida pelo motorista; o texto literal está em
  `RideRelayDriver/specs/027-filtro-geografico-solicitacoes/contracts/emenda-27-tag-g.md` (ainda não commitado
  lá). Se o motorista mudar o texto antes do commit, esta feature acompanha.
- O vetor `geohash_vectors.json` e a ferramenta que o gera nascem no motorista; o passageiro só o copia.
- O motorista só aceita solicitações com `g` depois da sua feature; o contrato (emenda 27) MUST mudar como a mesma
  alteração lógica nos dois repositórios (Princípio IV), cada um no seu commit; a publicação da tag é inofensiva
  para versões antigas do motorista.
- A tag revela só o que o `content` já revela (a origem em claro, exceção da constituição 2.17.0).
- A inscrição do passageiro não muda (ele já não consome `20001`).

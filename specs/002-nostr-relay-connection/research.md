# Phase 0 — Research: Conexão do Passageiro com Relays Nostr

Nenhum item do Technical Context ficou como NEEDS CLARIFICATION.

**Natureza deste documento**: a feature equivalente do motorista
(`Prototipo/driver/specs/002-nostr-relay-connection/research.md`) é **anterior** e já fundamentou as
decisões técnicas comuns às duas apps. Este documento **herda** essas decisões em vez de re-decidi-las:
divergir sem motivo produziria duas apps incompatíveis num sistema onde o único acoplamento é o formato
dos eventos. Cada decisão abaixo marca se é **herdada** (mantida por simetria) ou **própria** (específica
do passageiro).

As decisões herdadas são reproduzidas aqui, e não apenas referenciadas, porque FR-017 e o Princípio III
da constituição exigem o registro versionado **junto à feature** — e porque uma referência a arquivo de
outro projeto quebra se ele for movido, renomeado ou publicado separadamente.

## D1 — Biblioteca Nostr para Dart/Flutter (herdada; atende FR-017 e SC-008)

**Decision**: adotar **`dart_nostr` versão `^10.0.1`** (instalada em 15/09/2026, antes desta feature).

**Contexto**: a instalação foi determinada pelo autor antes desta especificação, e a revisão D9-R1 da
feature 001 (`specs/001-flutter-app-base/research.md`) registrou a autorização, mas sem o detalhamento
de versões e datas que o Princípio III exige. **Este documento regulariza essa pendência**, que a
constituição registrou como follow-up aberto.

### Alternativas avaliadas

Levantamento feito no índice do pub.dev em 15/09/2026, reproduzido do estudo da app do motorista.

| Pacote | Versão | Última publicação | Observações |
|--------|--------|-------------------|-------------|
| **`dart_nostr`** | 10.0.1 | 2026-04-23 | API de alto nível orientada a clientes; cobre chaves, assinatura, eventos e gestão de relays num único pacote. Dependências: `bip340`, `bip39`, `bip32_bip44`, `bech32`, `crypto`, `pointycastle`, `web_socket_channel`. |
| `nostr` | 2.0.0 | 2026-05-22 | Biblioteca pura em Dart, **transport-agnostic**: cobre 35+ NIPs, incluindo NIP-44 e gift wrap, mas **não gerencia as conexões WebSocket** — o cliente implementaria transporte e política de reconexão. |
| `ndk` (Nostr Development Kit) | 0.9.3 | 2026-09-04 | O mais ativamente mantido e completo: cache, estratégias de relay, outbox model. Maior superfície conceitual, exige SDK Dart ≥ 3.6.0 e ainda é **0.x**, com API sujeita a quebras. |
| `nostr_tools` | 1.0.9 | 2023-08-27 | **Sem publicação há cerca de 3 anos**. Descartado por risco de abandono e incompatibilidade com Dart 3.13. |

### Critérios aplicados

1. **Cobertura do caso de uso com a menor superfície** — a feature precisa de chaves, assinatura,
   verificação, conexão a múltiplos relays e assinatura de eventos; `dart_nostr` entrega o conjunto
   completo, enquanto `nostr` deixaria transporte e reconexão (FR-014) por conta do protótipo.
2. **Manutenção ativa** — publicações em 2026 eliminam `nostr_tools`.
3. **Estabilidade de API** — `dart_nostr` está em versão maior estável (10.x); `ndk` ainda é 0.x, e
   quebras de API durante a redação de um TCC custam caro.
4. **Custo de aprendizado proporcional ao escopo** — o trabalho investiga a viabilidade do protocolo,
   não o desempenho de um cliente avançado.
5. **Simetria entre as duas apps** — critério **próprio do passageiro**: usar biblioteca diferente da do
   motorista tornaria qualquer incompatibilidade de interoperabilidade ambígua entre "o protocolo não
   serve" e "as duas bibliotecas discordam", destruindo o valor de evidência do experimento central
   (User Story 4).
6. **Verificação prática antes de assumir** — exercitada **neste projeto** em 15/09/2026:
   `Nostr.instance.services.keys.generateKeyPair()` gerou par de chaves hexadecimais de 64 caracteres, e
   `NostrEvent.fromPartialData(kind: 1, …)` produziu evento cuja assinatura passou em `isVerified()`.
   `flutter analyze` e `flutter test` seguiram limpos após a instalação.

### Riscos assumidos e mitigação

- **Acoplamento**: tipos de `dart_nostr` MUST ficar confinados a `lib/services/`; `lib/domain/` usa tipos
  próprios e as telas nunca importam a biblioteca (exigência do Princípio III da constituição).
- **Cobertura de NIPs**: a criptografia de conteúdo (NIP-44), necessária nas features futuras de
  mensagem privada entre passageiro e motorista, precisa ser confirmada. Verificar antes daquela
  feature; se ausente, `nostr` 2.0.0 é a alternativa documentada.
- **Risco acadêmico**: a escolha de uma biblioteca não é conclusão sobre o ecossistema. A tabela acima é
  insumo direto dos resultados do TCC — poucos pacotes, um abandonado e o mais completo ainda em 0.x é,
  em si, um achado sobre a maturidade do Nostr fora do JavaScript.

**Alternatives considered**: implementar o protocolo do zero sobre `web_socket_channel` + `bip340` —
descartado: reimplementar assinatura Schnorr e serialização canônica é fonte de erro criptográfico e
consumiria o tempo do TCC sem contribuir para a pergunta de pesquisa.

## D2 — Armazenamento da chave privada (herdada)

- **Decision**: `flutter_secure_storage`, que no Android usa o Keystore do sistema.
- **Rationale**: o Princípio I da constituição é NÃO NEGOCIÁVEL e exige armazenamento protegido do
  sistema operacional. Preferências simples guardam texto legível e não atendem.
- **Nota própria do passageiro**: cada app tem seu próprio armazenamento seguro, isolado por
  `applicationId` (`br.ufsc.tcc.corridas.passenger` vs `.driver`). É isso que garante identidades
  distintas com as duas apps no mesmo aparelho — verificável por US2 cenário 5 e SC-010.
- **Alternatives considered**: `shared_preferences` para tudo — viola o Princípio I; arquivo cifrado
  próprio — reimplementaria mal o que o Keystore já faz.

## D3 — Persistência da lista de relays (herdada)

- **Decision**: `shared_preferences`, guardando a lista como JSON (`url` + `isDefault`).
- **Rationale**: dado público, de baixo volume e não sensível; não justifica banco nem armazenamento
  seguro (Princípio V — estrutura só quando há consumidor).
- **Alternatives considered**: banco local — desproporcional para uma lista de poucos endereços.

## D4 — Deduplicação de eventos entre relays (herdada)

- **Decision**: deduplicar pelo campo `id` do evento, mantendo em memória o conjunto de ids já exibidos.
- **Rationale**: o `id` é o hash canônico definido pelo protocolo — é o identificador que o contrato
  (`contracts/nostr-events.md`, regra 2) designa para esse fim. Deduplicar por conteúdo ou por horário
  seria incorreto: eventos distintos podem ter o mesmo texto.
- **Alternatives considered**: deduplicar por `(pubkey, created_at)` — falha com dois eventos publicados
  no mesmo segundo.

## D5 — Estratégia de teste sem relay real (herdada)

- **Decision**: serviços recebem dependências por injeção (armazenamento e transporte de relay); testes
  usam dublês em memória. Nenhum teste automatizado contata relay público.
- **Rationale**: exigência direta do Princípio II da constituição. Testes dependentes de relay público
  são lentos, intermitentes e falham sem rede — e tornariam SC-003 (relay inalcançável) impossível de
  reproduzir de forma determinística. A validação contra relays reais fica no `quickstart.md`, como
  roteiro manual.
- **Alternatives considered**: integração contra relay público em CI — rejeitado pela intermitência;
  relay local em contêiner — desproporcional agora, registrado como opção para as features de domínio.

## D6 — Permissão de rede no manifesto principal (herdada)

- **Decision**: declarar `android.permission.INTERNET` em `android/app/src/main/AndroidManifest.xml`.
- **Rationale**: verificado neste projeto em 15/09/2026 que o APK de **release não declara** a permissão
  — em debug ela vem de `android/app/src/debug/AndroidManifest.xml`, que o Flutter gera para hot reload.
  Sem esta decisão, a conexão a relays funcionaria em desenvolvimento e falharia silenciosamente em
  produção (FR-016). Esta é também a feature que **autoriza** a permissão sob a regra de "nada de
  permissão para o futuro" das Restrições de Segurança e Privacidade: agora existe funcionalidade que a
  exige.
- **Alternatives considered**: manter só em debug — quebra o build de produção; declarar já na feature
  001 — teria violado a proibição de permissão antecipada.

## D7 — Lista padrão de relays (própria; resolve o achado F1 do analyze)

**Decision**: a lista padrão é composta por estes **três endereços fixos**:

```text
wss://nos.lol
wss://relay.primal.net
wss://offchain.pub
```

**Por que esta decisão deixou de ser "herdada"**: a decisão D7 da app do motorista definia apenas
*"3 relays públicos, confirmando a disponibilidade no momento da implementação"* — sem nomear nenhum
endereço. O `/speckit-analyze` desta feature classificou isso como achado HIGH: as duas apps precisam
compartilhar ao menos um relay para que a User Story 4 seja possível, e duas implementações
independentes escolhendo "3 relays públicos" podem perfeitamente escolher conjuntos disjuntos — fazendo
o experimento central do TCC falhar por configuração, e não por limitação do protocolo. Esta decisão
fixa a lista por escrito.

### Evidência medida (2026-09-15)

Princípio V da constituição: resultado apresentado como medição MUST ter sido medido. Os candidatos
foram sondados com `tool/check_relays.dart`, que publica um evento assinado por uma identidade
descartável e o recupera **por uma conexão separada** — a mesma mecânica da User Story 4.

| Relay | Leitura | Aceita publicação | Ida e volta entre conexões distintas | Situação |
|---|---|---|---|---|
| `wss://nos.lol` | ✓ | ✓ 377 ms | ✓ 1255 ms (id e autor conferem) | **adotado** |
| `wss://relay.primal.net` | ✓ | ✓ 224 ms | ✓ 1330 ms (id e autor conferem) | **adotado** |
| `wss://offchain.pub` | ✓ | ✓ 174 ms | ✓ 892 ms (id e autor conferem) | **adotado** |
| `wss://nostr.mom` | ✓ | ✓ 287 ms | não testado | reserva, caso um dos três saia do ar |
| `wss://relay.damus.io` | ✓ (1283 ms) | ✗ falha de conexão | — | **descartado**: aceitou leitura numa rodada e recusou a conexão na seguinte, minutos depois. O relay mais conhecido do ecossistema mostrou-se intermitente. |
| `wss://relay.nostr.band` | ✗ timeout de 10 s | — | — | **descartado** |

**Achado para o TCC**: dos 6 relays públicos sondados, 1 não respondeu e 1 — justamente o mais
difundido — foi intermitente entre duas execuções separadas por minutos. A volatilidade da
infraestrutura pública é, por si só, um resultado relevante sobre a viabilidade de sustentar um
aplicativo de corridas sobre relays abertos de terceiros, e sustenta diretamente o requisito FR-003
(falha de um relay não pode derrubar os demais) e o SC-003.

**Observação posterior — `nos.lol` (16/09/2026, durante a validação cross-app)**: mesmo tendo passado
nas três verificações da sondagem, `nos.lol` falhou em aceitar publicação **duas vezes** na mesma
sessão de testes: (1) ao receber uma publicação do passageiro, não devolveu confirmação dentro de 10 s
(`sem resposta`), embora o evento tenha circulado pelos outros relays; (2) uma publicação do motorista
chegou a `relay.primal.net` e `offchain.pub`, mas **não** a `nos.lol` — verificado consultando os três
relays diretamente. O relay continuou aceitando conexão e servindo leitura normalmente nos dois casos.
A falha é silenciosa do ponto de vista de quem lê: o relay parece saudável e simplesmente não tem o
evento.

Não houve troca da lista por isso: duas falhas em uma sessão não bastam para distinguir instabilidade
passageira de problema persistente, e trocar a cada falha tornaria a lista padrão ela mesma instável.
Mas o episódio reforça o achado: **nenhum relay isolado é confiável**, nem os que passaram na
sondagem. É a publicação em vários relays simultâneos — e não a escolha de um "bom" relay — que torna
a entrega robusta. Nas duas ocorrências o evento chegou ao destino pelos outros relays.

**Rationale da escolha**: os três adotados passaram nas três verificações — leitura, publicação e
recuperação por conexão separada — com ida e volta abaixo de 1,4 s, folgado dentro do limite de 5 s do
SC-002 e dos 10 s do SC-009. Três relays exercitam o comportamento multi-relay exigido por FR-003/SC-003
sem sobrecarregar a interface.

**Obrigação de simetria — resolvida em 16/09/2026**: a app do motorista tinha uma lista **divergente**
(`relay.damus.io`, `nos.lol`, `relay.primal.net`), porque verificara os relays apenas por documento
NIP-11 — que prova que o relay responde HTTP, não que aceita publicação. Com a sessão do motorista
encerrada e esta sessão assumindo as duas apps, a lista canônica acima foi aplicada aos dois lados na
mesma alteração, e a decisão D10 do motorista foi revisada (D10-R1) com a mesma evidência. O
`relay.damus.io` saiu por ter falhado 1 de 3 tentativas de conexão consecutivas: mantê-lo injetaria
ruído nas medições de SC-001 e SC-009.

**Manutenção**: a lista é volátil por natureza. `tool/check_relays.dart` re-executa a sondagem sob
demanda; se um relay falhar, `wss://nostr.mom` é a reserva já verificada. A lista vive em uma constante
única (`lib/shared/default_relays.dart`, tarefa T008) para que a substituição seja de uma linha.

**Alternatives considered**: manter a formulação vaga do motorista — é o que o achado F1 identificou
como defeito; lista própria do passageiro — quebraria a User Story 4 por construção; um único relay —
não exercita o comportamento distribuído, que é objeto do estudo; dezenas de relays — ruído sem ganho
analítico e risco de esgotar conexões no aparelho.

## D8 — Estrutura de pastas (própria)

- **Decision**: acrescentar `lib/domain/` e `lib/services/` ao `lib/main.dart` + `lib/screens/` +
  `lib/shared/` já existentes, sem reorganizar o que a feature 001 criou.
- **Rationale**: a feature 001 do passageiro tinha FR-008 exigindo separação explícita, que o motorista
  não tinha — por isso as duas apps partem de pontos diferentes e chegam à mesma separação lógica
  (domínio / serviços / telas) por caminhos distintos. Introduzir `domain/` e `services/` agora tem
  consumidor real e é exigido pelo Princípio III (tipos de terceiros confinados aos serviços) e pelo
  Princípio II (lógica testável sem árvore de widgets). `shared/` permanece para o que não é nem
  domínio nem serviço (identidade visual do app).
- **Alternatives considered**: espelhar a árvore do motorista exatamente — exigiria desfazer a estrutura
  da feature 001 sem ganho; acrescentar `repositories/` e `usecases/` — proibido pelo Princípio V, sem
  consumidor.

## D9 — Estratégia de validação cross-app (própria)

- **Decision**: a User Story 4 é validada **manualmente**, pelo roteiro do `quickstart.md`, com as duas
  apps instaladas no mesmo aparelho; não há teste automatizado para ela.
- **Rationale**: automatizá-la exigiria orquestrar duas aplicações e um relay público real no mesmo
  teste — proibido pelo Princípio II (testes não contatam relay real) e frágil por depender de código
  mantido em outro projeto por outra pessoa. O que **é** automatizável e será testado com dublês: a
  recepção de evento de autor diferente do próprio, a verificação de assinatura e a atribuição correta
  do autor exibido.
- **Consequência registrada**: SC-009 é um critério de validação manual, e seu resultado MUST ser
  relatado com o método de medição junto do número (Princípio V), inclusive se falhar.
- **Alternatives considered**: relay local em contêiner orquestrando as duas apps — a única forma
  rigorosa de automatizar, registrada como trabalho futuro caso as features de domínio precisem de
  cenários multi-cliente repetíveis.

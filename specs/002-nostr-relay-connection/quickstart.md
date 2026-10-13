# Phase 1 — Quickstart / Validação: Conexão do Passageiro com Relays Nostr

Comandos executados a partir de `Prototipo/passenger`. Detalhes de decisão em
[research.md](./research.md); entidades em [data-model.md](./data-model.md); formato dos eventos em
[contracts/nostr-events.md](./contracts/nostr-events.md).

## Pré-requisitos

- Ambiente da feature 001 já funcionando (`flutter doctor` com Android toolchain ✓).
- Emulador ou aparelho Android **com acesso à internet** — esta feature, ao contrário da 001, depende
  de rede.
- Para os cenários da User Story 4: o aplicativo do motorista com a feature `002-nostr-relay-connection`
  **implementada**, instalado no mesmo aparelho e usando a **mesma lista padrão de relays** fixada na
  decisão D7 de [research.md](./research.md).

## Relays padrão

Fixados em D7 e verificados em 2026-09-15 (publicação + recuperação por conexão separada):

```text
wss://nos.lol
wss://relay.primal.net
wss://offchain.pub
```

Reserva já verificada, caso um saia do ar: `wss://nostr.mom`. Para reconfirmar a disponibilidade a
qualquer momento:

```bash
dart run tool/check_relays.dart
```

O script publica um evento assinado e o recupera por uma conexão separada — a mesma mecânica da User
Story 4. Ele contata relays reais de propósito e por isso **não** vive em `test/` (Princípio II).

## Setup e gates automatizados

```bash
flutter pub get
flutter analyze        # gate 1 da constituição — sem apontamentos
flutter test           # gate 2 — suíte completa, sem teste ignorado
```

Testes individuais:

```bash
flutter test test/event_feed_test.dart
flutter test --plain-name "descarta evento com assinatura inválida"
```

## Cenários automatizados

Cobertos por `flutter test`, todos com dublês em memória e **sem relay real** (Princípio II, D5):

| # | Cenário | Origem |
|---|---|---|
| A1 | Identidade é criada na primeira execução e recuperada na seguinte | US2 cenários 1–2, FR-004 |
| A2 | Chave recuperada fora do formato hexadecimal de 64 caracteres é tratada como corrompida | data-model.md |
| A3 | Evento com assinatura válida é aceito; com assinatura adulterada é descartado | FR-009, Princípio II |
| A4 | Evento com autor divergente da assinatura é descartado | Princípio II (caso inválido) |
| A5 | Mesmo evento chegando por dois relays é exibido uma única vez | FR-010, D4 |
| A6 | Evento de autor diferente do local é exibido com o autor correto | FR-020, base da US4 |
| A7 | Kind desconhecido é ignorado sem erro | FR-018 |
| A8 | Conteúdo com marcação é exibido como texto simples | FR-018, Princípio IV |
| A9 | Relay que falha passa a `unavailable` sem afetar os demais | FR-003, SC-003 |
| A10 | Retorno de rede dispara nova tentativa nos relays indisponíveis | FR-014 |
| A11 | Endereço inválido ou duplicado é recusado na adição | FR-011 |
| A12 | Lista de relays é persistida e restaurada | FR-012, SC-005 |

## Cenários manuais — esta app sozinha

Com o aplicativo instalado e rede disponível:

| # | Verificação | Origem |
|---|---|---|
| M1 | Ao abrir, os relays evoluem de "conectando" a "conectado"; ao menos um conecta em ≤ 5 s | US1 cenário 1, SC-001 |
| M2 | Com um relay inalcançável na lista, os demais seguem conectados e ele exibe o motivo | US1 cenário 2, SC-003 |
| M3 | Em modo avião, o app explica a ausência de rede sem erro técnico cru nem travamento | US1 cenário 3, FR-015 |
| M4 | Segundo plano e retorno refletem o estado real das conexões | US1 cenário 4 |
| M5 | A chave pública é exibida, legível e copiável; a privada **não** aparece | US2 cenários 1 e 3, FR-006 |
| M6 | Fechar e reabrir 5 vezes mantém a mesma chave pública | SC-004 |
| M7 | Publicar um evento de teste retorna pela assinatura em ≤ 5 s | US3, SC-002 |
| M8 | Sem relay conectado, publicar é impedido com explicação | US3 cenário 5 |
| M9 | Adicionar, remover e reabrir preserva a lista alterada | US5 cenários 1–4, FR-011/FR-012, SC-005 |
| M10 | Esvaziar a lista oferece restaurar os relays padrão | US5 cenário 5, FR-013 |

## Cenários manuais — validação cross-app (User Story 4)

**Este é o experimento central do TCC.** Requer as duas apps instaladas no mesmo aparelho e conectadas a
pelo menos um relay em comum.

| # | Verificação | Origem |
|---|---|---|
| X1 | As duas apps exibem chaves públicas **diferentes** | US2 cenário 5, SC-010 |
| X2 | Evento publicado pelo motorista aparece na lista do passageiro em ≤ 10 s | US4 cenário 1, SC-009 |
| X3 | O autor exibido no passageiro é exatamente a chave pública da tela de identidade do motorista | US4 cenário 2 |
| X4 | O evento recebido tem assinatura verificada; se inválida, não é exibido | US4 cenário 3, FR-009 |
| X5 | Removendo todos os relays em comum, o evento do motorista **não** chega — provando que o transporte é o relay, e não uma comunicação direta | US4 cenário 4 |

**Protocolo de medição de SC-009** (Princípio V — resultado apresentado como medição precisa ter sido
medido): repetir X2 dez vezes, anotando o intervalo entre a confirmação de publicação no app do
motorista e o aparecimento do evento no passageiro. Registrar as dez medições, o relay usado, o tipo de
rede (Wi-Fi ou dados móveis) e o aparelho. **Relatar o resultado mesmo se ficar abaixo do critério** —
uma taxa de entrega ruim em relays públicos é um achado legítimo sobre viabilidade, não uma falha a
esconder.

## Verificação de não vazamento (Princípio I — obrigatória)

Executar e **registrar o resultado** antes de considerar a feature concluída:

```bash
# 1. Nenhuma chave privada no log do aplicativo
adb logcat -d | grep -iE 'privkey|private|nsec|[0-9a-f]{64}'

# 2. Nenhuma chave privada no código-fonte ou em arquivo de configuração
grep -rniE 'nsec|privateKey *= *"' lib/ android/

# 3. Inspeção do tráfego enviado aos relays: confirmar que os eventos publicados
#    carregam apenas pubkey, id, sig, kind, tags e content — nunca a chave privada
```

O item 3 é inspeção manual do conteúdo publicado, conferido contra o envelope descrito em
`contracts/nostr-events.md`. Resultado dos três itens MUST ser registrado junto da conclusão da feature.

---

## Resultados da validação cross-app (2026-09-16)

Executados com as duas apps instaladas no emulador `Pixel_6_API34_1` (Android 14, API 34, x86_64),
ambas com a lista canônica de relays (`nos.lol`, `relay.primal.net`, `offchain.pub`).

### Cenários X1–X5

| # | Resultado | Evidência |
|---|---|---|
| X1 | ✓ | Chaves públicas distintas, extraídas da árvore de acessibilidade (sem leitura de screenshot): motorista `5c499299…c6444f`, passageiro `747aa48e…ee365e8a` |
| X2 | ✓ | Evento `X2crossapp220052`, publicado pelo app do motorista, exibido pelo app do passageiro |
| X3 | ✓ | Autor exibido no passageiro: `5c499299cbd755c4…`, idêntico à chave da tela de identidade do motorista. Direção inversa também observada: o motorista exibia os eventos do passageiro atribuídos a `747aa48e…` |
| X4 | ✓ | O evento foi exibido, e o feed só exibe eventos que passaram na verificação com recálculo do `id`; o caso inválido é coberto por teste automatizado |
| X5 | ✓ | **Negativo**: passageiro conectado só a `nostr.mom`, motorista publicou `X5b220559` nos três relays canônicos — o evento **não** chegou em 20 s, com o passageiro online (1 de 1 conectado). **Controle positivo**: acrescentado `relay.primal.net` ao passageiro, sem reiniciar o app — o **mesmo** evento chegou. O relay é o único meio de transporte |

### SC-009 — medição

**Critério**: evento do motorista recebido pelo passageiro em até 10 s, em 8 de 10 tentativas.

**Resultado: 10 de 10 recebidos, todos em até 2,65 s. Aprovado.**

| Rodada | Latência (limite superior) | Publicado nos relays |
|---|---|---|
| 1 | 2,61 s | 3/3 |
| 2 | 2,61 s | 3/3 |
| 3 | 2,62 s | 3/3 |
| 4 | 2,61 s | 3/3 |
| 5 | 2,63 s | 3/3 |
| 6 | 2,60 s | 3/3 |
| 7 | 2,60 s | 3/3 |
| 8 | 2,65 s | 3/3 |
| 9 | 2,34 s | 3/3 |
| 10 | 2,33 s | 3/3 |

Mínimo 2,33 s · máximo 2,65 s · mediana 2,61 s.

**Método**: por rodada, o app do motorista é encerrado e reaberto do zero, aguarda os três relays
conectados, recebe um texto único e publica. O cronômetro inicia no toque em "Publicar"; em seguida o
app do passageiro é trazido à frente e sua árvore de acessibilidade é consultada repetidamente
(`uiautomator dump`) até o texto aparecer, com limite de 30 s. Ao final, os três relays são consultados
diretamente para confirmar que cada evento foi de fato publicado.

**O número é um limite superior, não a latência de entrega.** Ele inclui a troca de app e o ciclo de
consulta da árvore de acessibilidade, que levam cerca de 2 s por si. A uniformidade dos valores
(oito rodadas entre 2,60 e 2,65 s) indica que o tempo medido é dominado por esse piso do método: a
entrega real é menor, e este método não a resolve abaixo de ~2,6 s. Para o critério "até 10 s" isso
basta — se o limite superior cabe, a entrega real cabe.

**Primeira tentativa descartada, e por quê**: uma versão anterior do roteiro não reiniciava o motorista
entre rodadas. As rodadas pares aparentaram falhar (não recebidas em 30 s). Consultando os relays, os
eventos dessas rodadas **não existiam em nenhum deles**: o toque em "Publicar" errava por estado
residual de teclado e campo de texto, e o motorista nunca publicou. Todo evento efetivamente publicado
naquela tentativa chegou ao passageiro. Os resultados foram descartados por medirem o roteiro, não o
protocolo; a tentativa é registrada aqui para que a medição válida possa ser auditada.

### Defeitos encontrados durante a validação

A validação em aparelho real encontrou defeitos que a suíte automatizada não pegava. Todos foram
corrigidos com teste de regressão escrito antes da correção.

| Defeito | App | Como apareceu | Correção |
|---|---|---|---|
| **Relay surdo**: a inscrição era enviada uma única vez, no início. Relay acrescentado depois, ou reconectado após queda de rede, ficava "Conectado" sem receber evento algum | passageiro | Controle positivo do X5 falhou com o evento presente no relay | Inscrições ativas guardadas no `RelayService` e reenviadas a toda conexão estabelecida. O teste de reconexão da fase 4 não pegou porque verificava só o estado, não se os eventos voltavam a fluir |
| **Ordem invertida**: eventos ordenados por chegada; o relay entrega histórico do mais novo ao mais velho, então a lista saía com o mais antigo no topo e o recém-publicado fora da tela | passageiro e motorista | Evento recém-publicado ausente da parte visível da lista | Ordenação pela data declarada, com data futura limitada ao instante de chegada (regra 5 do contrato: a data não é confiável) |
| **Vazamento de memória**: a janela podava a lista de eventos, mas não o conjunto de ids já vistos, que crescia sem limite | motorista | Revisão do código ao investigar o defeito de ordem | Ids descartados pela janela saem também do conjunto de vistos |

## Verificação de não vazamento — Princípio I (2026-09-16)

Executada e registrada, como exige o gate 4 da constituição.

| Item | Método | Resultado |
|---|---|---|
| 1. Log do aplicativo | `adb logcat` filtrado pelo processo do passageiro, cobrindo abertura do app e uma publicação (49 linhas); busca por sequências de 64 caracteres hexadecimais e pelos termos `private`, `privkey`, `nsec`, `secret` | **Nenhuma ocorrência** |
| 2. Código-fonte e configuração | Varredura de `lib/` e `android/` nas **duas** apps por literal `nsec1…`, chave privada atribuída como texto, chave privada passando por `print`/`debugPrint`/log ou interpolada em texto; conferência de que `Identity.toString()` não expõe a chave nas duas apps | **Nenhuma ocorrência**; `toString` seguro nas duas |
| 3. Tráfego enviado aos relays | Consulta direta aos três relays pelos eventos de autoria do passageiro; conferência de que cada evento traz exatamente os 7 campos do envelope do contrato e de que não há sequência de 64 hex fora de `id` e `pubkey` | **Nenhuma violação**: só `id`, `pubkey`, `created_at`, `kind`, `tags`, `content`, `sig` |

## Cenários manuais M1–M10 (2026-09-16)

Executados no emulador `Pixel_6_API34_1`, gate 3 da constituição.

| # | Resultado | Quando |
|---|---|---|
| M1 | ✓ três relays conectados após abertura | fase 4 |
| M2 | ✓ relay inalcançável exibe motivo legível; demais seguem conectados | fases 4 e 6 |
| M3 | ✓ em modo avião, explicação em linguagem comum, sem erro técnico cru nem travamento | fase 4 |
| M4 | ✓ após ir à tela inicial do Android e voltar, "3 de 3 relays conectados" | fase 8 |
| M5 | ✓ chave pública exibida e copiável; chave privada ausente da tela | fase 3 |
| M6 | ✓ **5 de 5** ciclos de encerrar e reabrir o app com chave pública idêntica, conferida pela árvore de acessibilidade — atende SC-004 | fase 8 |
| M7 | ✓ evento publicado retorna pela inscrição e aparece como "eu" | fase 5 |
| M8 | ✓ em modo avião, publicar é impedido com "Nenhum relay conectado. O evento não foi publicado — conecte-se a um relay e tente novamente." | fase 8 |
| M9 | ✓ relay acrescentado, app encerrado e reaberto: lista preservada | fase 6 |
| M10 | ✓ lista esvaziada exibe "Nenhum relay configurado" e o botão de restaurar; restaurar devolve os três relays padrão | fase 8 |

Nenhum cenário falhou.

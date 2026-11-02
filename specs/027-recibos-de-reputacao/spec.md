# Especificação: Reputação por recibos assinados (passageiro)

**Feature**: `027-recibos-de-reputacao` · **App**: `passenger/` · **Data**: 2026-10-20 · **Status**: Draft
**Contrato de eventos**: muda. Emenda 25 de `specs/002-nostr-relay-connection/contracts/nostr-events.md`, cuja
seção "Reputação por recibos" (seção 1 de `especificacao-passageiro.md`) é idêntica à do app do motorista e MUST
mudar no mesmo commit nos dois repositórios (kinds `20014` e `20015`, campo `reputacao` em `20001` e `20002`).
**Entrada**: "Siga as instruções do arquivo especificacao-passageiro.md" (reputação por recibos assinados do app
do passageiro; contrato comum na seção 1 e mudanças específicas na seção 2).

## Problema

Hoje a avaliação que o passageiro dá ao motorista (features 011/012) fica só no aparelho de quem avaliou
(`ride_ratings`): ninguém mais a vê, e o passageiro não tem como saber se o motorista que lhe enviou um orçamento
é bem avaliado. O protótipo não tem backend e as mensagens de domínio são eventos efêmeros que os relays não
guardam, então a reputação não pode morar num servidor nem em relays.

A solução é uma reputação **sem backend e sem guardar avaliações em relays**: cada corrida concluída gera um
**recibo assinado** pelo avaliador, entregue ao avaliado, que o guarda no aparelho e apresenta os mais recentes a
quem for decidir se confia nele. Os recibos de cada avaliado formam uma cadeia numerada e encadeada por hash, o que
permite a quem recebe a reputação conferir autoria, integridade e coerência da apresentação.

Neste app o passageiro tem os dois papéis: **avaliador** do motorista (emite o recibo ao fim da corrida) e
**avaliado** pelo motorista (recebe recibos e declara a própria reputação na solicitação de corrida).

## Cenários de usuário

### US1 — Ver a reputação verificada do motorista antes de aceitar um orçamento (P1)
Na tela de orçamentos recebidos, cada orçamento mostra a reputação do motorista: a média e a contagem
**verificadas** (calculadas só sobre recibos com assinatura e encadeamento conferidos) e, em texto menor, o que o
motorista **declara** (corridas, avaliações, média). Reputação inconsistente ou com recibos omitidos é destacada.

**Teste independente**: injetar um `20002` com `reputacao` válida, outro com recibo adulterado e outro sem
`reputacao`, e conferir o que a tela exibe em cada caso.

1. **Dado** um orçamento cuja `reputacao` tem recibos válidos, **quando** a tela de orçamentos é exibida,
   **então** aparecem "verificado nos últimos N" (média e contagem só dos recibos válidos) separado do declarado.
2. **Dado** um orçamento sem `reputacao`, **então** o orçamento aparece normalmente como motorista sem histórico.
3. **Dado** uma `reputacao` malformada, **então** o orçamento continua válido e é tratado como sem reputação.
4. **Dado** uma `reputacao` cujo `head` não bate com o recibo de `seq = seq_proximo−1`, **então** ela é marcada
   "inconsistente".
5. **Dado** lacunas de `seq` na lista, **então** a tela mostra "N recibos não apresentados".
6. **Dado** o toque em "Aceitar", **então** a reputação declarada pelo motorista nessa corrida é guardada
   localmente, ligada à corrida, para uso na emissão do recibo.

### US2 — Emitir o recibo do motorista ao fim da corrida (P1)
Ao fechar a modal de avaliação (com nota ou "pular"), o app emite um recibo assinado, cifrado ao motorista,
encadeado à reputação que ele declarou nesta corrida. O recibo é gravado como pendente antes de publicar e é
reenviado até o motorista confirmar.

**Teste independente**: concluir uma corrida com reputação declarada válida, fechar a modal e conferir o recibo
gravado como pendente, o `20014` publicado cifrado e a baixa do pendente ao chegar o `20015`.

1. **Dado** corrida concluída e reputação declarada consistente, **quando** a modal é fechada com nota, **então**
   o recibo leva a `nota`, `seq = seq_proximo`, `hash_anterior = head`, assinado pelo passageiro, e é publicado.
2. **Dado** o fechamento por "pular", **então** o recibo é emitido sem `nota` (conta como corrida, não como
   avaliação).
3. **Dado** reputação declarada **inconsistente**, **então** nenhum recibo é emitido, o usuário recebe um aviso
   de uma linha e a nota local continua gravada.
4. **Dado** corrida cancelada ou não concluída, **então** nenhum recibo é emitido.
5. **Dado** recibo pendente e app reiniciado, relay reconectado ou 60 s com o app aberto, **então** o
   `20014` é reenviado até chegar o `20015` com o `id_recibo` correspondente.
6. **Dado** falha ao publicar, **então** a interface não é bloqueada.

### US3 — Receber recibos do motorista e declarar a própria reputação (P2)
Quando o motorista avalia o passageiro, chega um `20014`. O app valida, grava (imutável), responde `20015` e
atualiza a reputação do passageiro, que passa a ir (em claro) no `20001` das próximas solicitações. Sem recibos, o
`20001` sai sem `reputacao`. O recebimento de recibo é silencioso (sem notificação).

**Teste independente**: injetar `20014` válido, inválido e repetido e conferir gravação, `20015` e o conteúdo do
próximo `20001`.

1. **Dado** `20014` válido para o passageiro, **então** o recibo é gravado, um `20015` é publicado e
   `corridas`, `avaliacoes`, `media`, `seq_proximo` e `head` são recalculados.
2. **Dado** recibo já salvo para o mesmo `guid_corrida`: se idêntico, só reenvia `20015`; se diferente, ignora.
3. **Dado** recibo com assinatura, hash, destinatário ou autor inválidos, **então** é descartado.
4. **Dado** o passageiro sem recibos, **então** o `20001` não contém a chave `reputacao`.
5. **Dado** o passageiro com recibos, **então** o `20001` leva `reputacao` com os 5 mais recentes.

## Casos de borda

- Recibo com `id_recibo` que não confere, assinatura inválida, `v ≠ 1`, `nota` fora de 1..5, avaliador igual ao
  avaliado, `guid_corrida` repetido ou `seq` não decrescente: descartado e contado.
- Recibos fora de ordem são aceitos; ramos (mesmo `seq`, corridas diferentes) são tolerados e exibidos.
- Evento `20014`/`20015` com assinatura do evento inválida, sem marcador, duplicado ou não cifrado ao passageiro:
  descartado pelas regras gerais de recepção.
- Corrida removida do armazenamento de corrida aceita antes da emissão: o recibo não pode se perder por isso.
- Reputação grande: o `content` respeita o limite de 65 535 bytes da cifra.
- Reinício do app entre gravar o pendente e publicar: o recibo continua pendente e é reenviado.
- Nenhuma chave privada ou conteúdo decifrado em log.

## Requisitos funcionais

- **RF-001**: O app MUST implementar o contrato comum "Reputação por recibos" (recibo, forma canônica,
  `id_recibo` SHA-256, assinatura Schnorr sobre o `id_recibo`, cadeia por avaliado) idêntico ao do motorista.
- **RF-002**: O app MUST consumir os kinds `20014` (recibo) e `20015` (confirmação), cifrados NIP-44 ao
  destinatário, aplicando as regras de recepção existentes (assinatura, marcador, deduplicação, cifra).
- **RF-003**: O app MUST verificar uma `reputacao` recebida (recibos, `head`, encadeamento, lacunas) por função
  pura, descartando e contando recibos inválidos e marcando reputação inconsistente.
- **RF-004**: A tela de orçamentos MUST exibir a reputação **verificada** separada da **declarada**, sem nunca
  misturá-las, destacando "inconsistente" e "N recibos não apresentados".
- **RF-005**: Reputação ausente ou malformada em um orçamento MUST NOT invalidá-lo.
- **RF-006**: Ao aceitar um orçamento, o app MUST guardar a reputação declarada pelo motorista ligada à corrida.
- **RF-007**: Ao fechar a modal de avaliação de corrida concluída, o app MUST emitir o recibo conforme o
  contrato, gravá-lo como pendente antes de publicar e publicá-lo cifrado ao motorista; nenhum recibo para
  corrida cancelada ou não concluída, nem quando a reputação declarada for inconsistente.
- **RF-008**: Recibos pendentes MUST ser reenviados na abertura do app, a cada reconexão de relay e a cada 60 s
  enquanto o app estiver aberto, até chegar a confirmação correspondente. Com o app fechado, o reenvio espera a
  próxima abertura.
- **RF-009**: Ao receber um recibo válido, o app MUST gravá-lo de forma imutável, responder com `20015` e
  recalcular a reputação do passageiro; a assinatura MUST ser revalidada em cada leitura.
- **RF-010**: O `20001` MUST incluir `reputacao` (em claro) somente quando houver recibos; a chave é omitida,
  nunca `null`.
- **RF-011**: Os kinds `20014` e `20015` MUST ser acrescentados aos kinds consumidos pelo app e pela inscrição do
  serviço em segundo plano, mas MUST NOT gerar notificação.
- **RF-012**: A nota local (`ride_ratings`) MUST permanecer; falha ao emitir ou publicar recibo nunca bloqueia a
  interface nem apaga a nota.
- **RF-013**: A chave privada MUST NOT aparecer em hash, log ou evento; `20014`/`20015` MUST NOT sair em claro.
- **RF-014**: O contrato do app (`contracts/nostr-events.md`) MUST ser atualizado com a emenda 25 na mesma
  alteração do código, incluindo os limites conhecidos e a justificativa de privacidade do `20001` em claro.
- **RF-015**: Um vetor de teste de contrato (recibo canônico, `id_recibo`, assinatura, reputação válida e
  inválida) MUST existir e passar também no repositório do motorista.
- **RF-016** (emenda 26): Ao receber um recibo, o app MUST gravá-lo só se o `guid_corrida` for de um orçamento que **este passageiro recebeu do avaliador**, conforme o registro local dos orçamentos recebidos; recibo de corrida desconhecida, ou ligada a outro motorista, MUST ser descartado sem erro e sem confirmação, e a consulta MUST usar só o registro local. Uma `reputacao` com mais de 5 recibos MUST ser tratada como malformada (ausente).

## Entidades

- **Recibo**: prova assinada por um avaliador sobre uma corrida concluída (corrida, avaliador, avaliado, nota
  opcional, posição `seq` na cadeia do avaliado, ligação ao recibo anterior, identificador e assinatura).
- **Reputação**: resumo declarado (corridas, avaliações, média, próximo `seq`, `head`) mais os 5 recibos mais
  recentes.
- **Visão de reputação**: resultado da verificação (média/contagem verificadas, declarado, recibos descartados,
  lacunas, inconsistência).
- **Recibo emitido**: recibo que este passageiro assinou, com estado pendente/confirmado.
- **Recibo recebido**: recibo em que este passageiro é o avaliado (imutável).
- **Reputação declarada de uma corrida**: reputação que o motorista apresentou no orçamento aceito.

## Critérios de sucesso

- **CS-001**: 100% dos recibos com `id_recibo`, assinatura, autoria ou ordem adulterados nos vetores de teste são
  descartados e nenhum entra nos números "verificados".
- **CS-002**: O passageiro vê a reputação verificada de cada motorista na tela de orçamentos sem ação adicional.
- **CS-003**: Um recibo pendente sobrevive a reinício do app e é confirmado após a reconexão, sem duplicar a
  corrida na cadeia do motorista.
- **CS-004**: O vetor de contrato compartilhado produz os mesmos resultados nos dois apps.
- **CS-005**: Nenhum `20014`/`20015` é publicado em claro e nenhuma chave ou texto decifrado aparece em log.
- **CS-006**: `flutter analyze` sem problemas e `flutter test` integral verde, sem testes ignorados.

## Premissas e dependências

- Janela de apresentação de 5 recibos (`kReputacaoJanela`); o avaliado controla o que apresenta, e quem recria a
  identidade zera o histórico (limites conhecidos 1.9 do contrato, documentados e não escondidos).
- O `20001` em claro com recibos expõe chaves públicas de motoristas que avaliaram o passageiro. **Justificativa de
  privacidade**: aceito no protótipo; alternativa futura é enviar só o resumo no `20001` e os recibos após o
  orçamento.
- Dependência nova possível: `package:crypto` (SHA-256), a ser decidida no `research.md` (Princípio III).
- Depende do app do motorista implementar a contrapartida (feature equivalente) para a troca ponta a ponta.
- O reenvio de recibos pendentes não roda no serviço em segundo plano, porque ele não tem a chave privada nem
  decifra mensagens (constituição 2.15.0). Um recibo pendente com o app fechado só é reenviado na próxima abertura.
- Fora de escopo: backend, armazenamento de recibos em relays, migração retroativa de `ride_ratings`.
- A numeração da pasta segue o próximo número livre do repositório (027); `especificacao-passageiro.md` sugeria
  028 por considerar uma 027 que não existe neste repositório.

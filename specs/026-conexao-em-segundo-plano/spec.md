# Especificação: Conexão com os relays em segundo plano e notificação de mensagens do motorista (passageiro)

**Feature**: `026-conexao-em-segundo-plano` · **App**: `passenger/` · **Data**: 2026-10-12 · **Status**: Draft
**Contrato de eventos**: não muda (nenhum kind, tag ou formato novo). Contrapartida de arquitetura da
`025-conexao-em-segundo-plano` do motorista, mas sem mudança no motorista.
**Entrada**: "o app do passageiro precisa manter a conexão com o relay mesmo se o usuário fechar o app, para
gerar uma notificação push caso uma mensagem do app do motorista chegue e o app não esteja em primeiro plano ou
esteja efetivamente fechado".

## Problema

Hoje a conexão do passageiro com os relays vive dentro do app. Com o app em segundo plano ou fechado o Android
suspende ou encerra o processo e o WebSocket morre. Todas as mensagens de domínio são eventos efêmeros
(`kind` 20000–29999), que o relay não guarda: um orçamento (`20002`), o aviso de chegada do motorista (`20007`),
de chegada ao destino (`20009`), de cancelamento (`20012`) ou de indisponibilidade (`20006`) que chegue com o app
fechado se perde para sempre. O passageiro que solicitou uma corrida e guardou o celular fica sem saber que o
motorista chegou. O protótipo não tem backend nem serviço de push de terceiros (tese do TCC), logo o aviso tem
de ser gerado no próprio aparelho, a partir de uma conexão mantida viva.

Diferença para o motorista (025): lá só o `kind: 20001`, em claro, era notificado. Aqui **todas as mensagens
relevantes ao passageiro são cifradas (NIP-44, emenda 17)** e a chave privada não pode sair da interface.
Logo o aviso é decidido só com o que é público no evento (kind, autor, tags `p` e `e`), sem decifrar o conteúdo.

## Cenários de usuário

### US1 — Ser avisado de uma mensagem do motorista com o app fechado (P1)
O passageiro solicita uma corrida, sai do app (ou o remove dos recentes) e guarda o celular. Quando o motorista
envia um orçamento, chega, conclui o trajeto, cancela ou fica indisponível, o aparelho mostra uma notificação de
alta importância; ao tocá-la o app abre e mostra a tela/modal correspondente, como se estivesse aberto.

**Teste independente**: com uma solicitação ativa e o app removido dos recentes, publicar por outro cliente um
`kind: 20002` cifrado ao passageiro e observar a notificação e a lista de orçamentos ao tocá-la.

1. **Dado** passageiro em "aguardando orçamentos" com o app fora de primeiro plano, **quando** chega um
   orçamento (`20002`) cifrado a ele, referenciando a solicitação ativa, **então** uma notificação é exibida.
2. **Dado** corrida aceita (orçamento aceito, motorista a caminho ou em corrida) e app fora de primeiro plano,
   **quando** chega do motorista da corrida `20007` (chegada), `20009` (chegada ao destino), `20012`
   (cancelamento) ou, em "orçamento aceito", `20006` (indisponível), **então** uma notificação é exibida.
3. **Dado** a notificação exibida, **quando** o passageiro a toca, **então** o app abre e a mensagem é tratada
   como hoje (a modal ou tela aparece; o evento não se perde por ter chegado com o app fechado).
4. **Dado** o app em primeiro plano, **quando** chega qualquer dessas mensagens, **então** só a interface
   existente reage (sem notificação).

### US2 — Saber que o app está ouvindo e deixar de ser incomodado quando não há corrida (P1)
Enquanto há uma solicitação ou corrida ativa, uma notificação fixa discreta ("Acompanhando sua corrida") mostra
que o app mantém a conexão em segundo plano. Sem solicitação nem corrida ativa e com o app fechado, nada roda
em segundo plano e nada é notificado.

1. **Dado** o passageiro que solicita uma corrida e sai do app, **então** a notificação fixa aparece e a conexão
   continua.
2. **Dado** a corrida que termina, é cancelada, expira ou a solicitação é cancelada, e o app fora de primeiro
   plano, **então** a notificação fixa some e o serviço encerra.

### US3 — Conexão sobrevive a quedas de rede em segundo plano (P2)
Com o app fechado, a reconexão automática, a sonda de vivacidade e o reenvio da inscrição continuam
funcionando; trocar Wi-Fi por dados móveis não deixa o passageiro surdo.

## Casos de borda

- Evento com assinatura inválida, sem o marcador, duplicado (mesmo `id` de três relays), de kind não notificável
  (`20005` localização periódica, `20011` rota) ou sem `p` igual à chave do passageiro: **nenhuma notificação**.
- Evento cujo autor não é o motorista da corrida aceita, ou cuja tag `e` não é a solicitação/orçamento ativo
  (a tag é pública no relay): nenhuma notificação, como hoje a interface o ignora.
- Conteúdo ilegível ou forjado por quem tem a chave de assinatura do motorista: como o serviço não decifra,
  pode haver notificação; ao abrir, a interface descarta o evento em silêncio (FR-007 da 022) e nada muda. Custo
  aceito de não levar a chave ao serviço.
- Passageiro sem solicitação nem corrida ativa ("inicial") ou em "destino confirmado aguardando avaliação":
  nada é notificado.
- Várias mensagens com o app fechado: cada orçamento (`20002`) é uma notícia e gera uma notificação; os avisos da
  corrida (`20007`, `20009`, `20012`, `20006`) geram **uma notificação por corrida e tipo** — o `20007` se repete a
  cada 5 s enquanto o motorista está no raio (emenda 20 do contrato) e não pode virar uma notificação a cada 5 s.
  Nunca acumula `20005`. Ao abrir, as ainda válidas são reentregues à interface em ordem de recebimento.
- Mensagem recebida há mais de 5 minutos ao abrir: não é reentregue.
- Permissão de notificação negada: o passageiro é avisado ao solicitar uma corrida de que não será avisado com o
  app fechado; o serviço roda só com o app visível e encerra ao sair dele (sem aviso possível, manter a conexão
  seria só gasto de bateria).
- Processo morto pelo sistema ou "Forçar parada": o serviço para; ao reabrir, a interface restaura o estado da
  corrida persistido, como hoje, mas as mensagens perdidas nesse intervalo não voltam (efêmeras).
- **Fora de escopo com o app fechado**: o relógio de silêncio de 3 minutos da 021 (vive na interface) e qualquer
  publicação que exija cifrar ou assinar (`20003`, `20004`, `20008`, `20010`, `20013`) — dependem da interface e
  acontecem quando o passageiro toca a notificação e age.

## Requisitos

- **FR-001** O serviço em segundo plano MUST rodar enquanto o app está em primeiro plano **ou** existe solicitação
  ou corrida ativa (qualquer estado de corrida diferente de "inicial" e de "destino confirmado aguardando
  avaliação"), e MUST encerrar quando o app sai de primeiro plano sem nenhuma das duas. Com corrida ativa, a
  notificação fixa MUST dizer "Acompanhando sua corrida"; com o app aberto e sem corrida, o serviço segue (a
  interface usa a conexão dele) com notificação discreta de baixa importância. Sem a permissão de notificação, o
  serviço não sobrevive à saída do app.
- **FR-002** A conexão MUST permanecer ativa com o app em segundo plano e depois de removido da lista de
  recentes, mantendo reconexão automática, sonda de vivacidade e reenvio da inscrição a cada conexão.
- **FR-003** Exista uma única conexão por relay, mantida pelo serviço; a interface a usa como cliente (receber
  eventos, estado dos relays, publicar, adicionar/remover relay, reconectar). Nada que o app já faz com os
  relays pode regredir.
- **FR-004** A verificação de assinatura (com recálculo do `id`), do marcador e a deduplicação MUST ocorrer antes
  de qualquer outro processamento, também no serviço (regras 1/2/6 do contrato).
- **FR-005** Uma mensagem MUST gerar notificação se, e somente se, o app está fora de primeiro plano **e**: o
  kind é `20002`, `20006`, `20007`, `20009` ou `20012`; a tag `p` é a chave pública do passageiro; e as mesmas
  condições de estado e de origem que hoje fazem a interface agir valem (autor = motorista da corrida aceita,
  tag `e` = orçamento aceito, ou, para `20002`, solicitação ativa; kind permitido no estado atual conforme
  `PassengerRideRules`). A decisão MUST ser uma única regra compartilhada entre serviço e interface e MUST usar
  apenas dados públicos do evento. Um aviso da corrida MUST gerar no máximo uma notificação por corrida e tipo;
  cada orçamento, uma própria.
- **FR-006** A notificação MUST ter importância alta, texto fixo por tipo ("Novo orçamento de corrida", "Seu
  motorista chegou", "Você chegou ao destino", "Corrida cancelada pelo motorista", "Motorista indisponível"),
  MUST NOT conter nome, placa, endereço, coordenada nem chave de terceiros, e MUST abrir o app ao ser tocada.
- **FR-007** Mensagens notificáveis recebidas pelo serviço sem a interface à vista MUST ser entregues à interface
  quando ela abrir, por até 5 minutos desde o recebimento; a interface as trata pelo caminho normal
  (decifração, conferência de autor e tag, transição de estado). Fora do prazo são descartadas.
- **FR-008** Eventos publicados pelo app (assinados e cifrados na interface) MUST ser repassados ao serviço para
  envio; a chave privada e a semente MUST NOT atravessar o canal entre interface e serviço nem ser necessárias
  no serviço, e o serviço MUST NOT decifrar conteúdo.
- **FR-009** O app MUST pedir a permissão de notificação apenas ao solicitar uma corrida pela primeira vez,
  nunca ao abrir.
- **FR-010** O serviço MUST informar à interface o estado dos relays para que a lista de relays e as faixas de
  conexão continuem corretas.
- **FR-011** O estado necessário ao serviço (chave pública do passageiro, estado da corrida, solicitação e
  orçamento aceito ativos, motorista da corrida, app em primeiro plano) MUST ser comunicado a ele pela interface e
  persistido o bastante para sobreviver a um reinício do processo do serviço. Não inclui segredo.
- **FR-012** Ao abrir com o serviço ainda ativo, o app MUST reaproveitar a conexão existente sem perder
  mensagens retidas; a restauração do estado da corrida persistido (014) segue como hoje.

## Fora de escopo

FCM/Firebase/UnifiedPush ou qualquer servidor; decifrar no serviço; publicar com o app fechado; o relógio de
silêncio (021) com o app fechado; notificar `20005` e `20011`; iniciar o serviço no boot do aparelho; contornar
otimização de bateria de fabricantes; mudanças no motorista ou no contrato.

## Critérios de sucesso

- **SC-001** Com solicitação ativa e o app removido dos recentes, uma mensagem notificável válida gera
  notificação em até 10 s depois de publicada, com os três relays padrão ativos (medido; registrar 10 tentativas).
- **SC-002** 0 notificações para mensagens que hoje a interface ignora por autor, tag, estado ou kind
  (verificável por teste).
- **SC-003** Nenhuma notificação contém dado de terceiros ou da corrida (verificável por teste).
- **SC-004** Com a tela apagada por 10 min e uma troca de rede no meio, o passageiro continua recebendo.
- **SC-005** Nenhum teste existente regride e `flutter analyze` não tem avisos.
- **SC-006** Medir e registrar o consumo de bateria por hora com corrida ativa e tela apagada (dado para o TCC).
- **SC-007** Teste confere que a chave privada não aparece em import nem no tráfego do canal do serviço.

## Suposições

- Android apenas; serviço em primeiro plano tipado (14+) e permissão de notificação em tempo de execução (13+).
- O passageiro aceita a notificação fixa durante uma corrida como custo da conexão contínua.
- Reaproveita-se a arquitetura e as dependências da 025 do motorista (serviço em primeiro plano, notificação
  local, `RelayConnection` remota), adaptadas, não copiadas: o código das apps não é espelho. A decisão de
  dependência vai para o `research.md` (Princípio III).
- A exceção de segundo plano da constituição 2.14.0 vale só para o motorista: exige emenda **2.15.0** nas duas
  constituições (estender ao passageiro, com a condição de decidir apenas por dados públicos), commitada à parte,
  antes do código.
- A notificação por evento não decifrado pode ser disparada por mensagem forjada com a chave do motorista da
  corrida; é limitação aceita e registrada, sem efeito no estado.
- Risco: fabricantes com economia de bateria agressiva podem matar o serviço; é limitação, não defeito.

# Research — Expirar a corrida por silêncio do motorista (passageiro)

## D1 — Temporizador e prazo

**Decision**: um `Timer` de uso único no `_MapScreenState`, com o prazo vindo de um parâmetro opcional do
construtor de `MapScreen` (`driverSilenceTimeout`, padrão `Duration(minutes: 3)`). `_armarSilencio()`
cancela o timer anterior e, se o estado for `orcamentoAceito` ou `motoristaACaminho` e houver corrida
aceita, cria outro; fora disso apenas cancela.

**Rationale**: um timer de uso único rearmado a cada sinal é a forma mais simples de "tempo desde o último
sinal" e roda sobre o relógio falso do `flutter_test` (`tester.pump(Duration)`), ao contrário de comparar
`DateTime.now()`. O parâmetro permite testar com prazos curtos sem esperar 3 minutos e deixa o valor de
produção numa constante única, fácil de ajustar (risco das Assumptions).

**Alternatives**: `Timer.periodic` comparando `DateTime.now()` — rejeitado: não é controlado pelo relógio
falso e acorda sem necessidade. Prazo fixo `const` — rejeitado: obrigaria testes de 3 minutos reais ou
falsos sem controle.

## D2 — Quando armar e quando cancelar

**Decision**: chamar `_armarSilencio()` (a) ao final de `_aceitarOrcamento`, depois do `setState` que entra
em `orcamentoAceito`; (b) ao final de `_carregarEstadoCorrida`, quando o estado restaurado é
`orcamentoAceito` ou `motoristaACaminho`; (c) em `_processarLocalizacaoMotorista`, depois das
conferências de autor e de `["e", quoteId]` e do filtro de fase, a cada sinal novo (mesmo com `content`
inválido); e cancelar (via o mesmo método, que cancela quando o estado não é elegível) em
`_encerrarCorridaAceita`, em `_confirmarEncontro` (ao entrar em `emCorrida`), em `_finalizarAvaliacao`
e em `dispose`.

**Rationale**: cada ponto é uma mudança de estado já existente; `_armarSilencio` é idempotente e olha o
estado atual, então basta chamá-lo depois de qualquer mudança que possa tornar a corrida elegível ou não.
Contar a localização com `content` inválido como sinal segue a feature 009 (o sinal "motorista começou a
se deslocar" não depende de o conteúdo ser válido).

**Alternatives**: observar `_rideStatus` por um setter/ValueNotifier — rejeitado (Princípio V): reescreveria
o estado do `MapScreen` por um ganho que cinco chamadas explícitas já dão.

## D3 — O último sinal não é persistido

**Decision**: nenhum campo novo em `AcceptedRide`/`PassengerRideStateStore`. Ao restaurar a corrida na
abertura do app, a contagem recomeça do zero.

**Rationale**: persistir o instante do último sinal exigiria migração e um relógio de parede, e o ganho é
pequeno (só vale para o app fechado por menos de 3 minutos). Quem reabre o app depois de muito tempo
espera, no máximo, 3 minutos para a expiração.

**Alternatives**: persistir o instante e expirar de imediato ao reabrir — rejeitada por Princípio V; poderia
encerrar uma corrida legítima só porque o app ficou fechado.

## D4 — Efeito da expiração

**Decision**: `_expirarPorSilencio()` confere `_corridaAceita != null` e
`PassengerRideRules.canExpireBySilence(_rideStatus)` e chama
`_encerrarCorridaAceita(() => _modalMotoristaSemSinalVisivel = true)`, o mesmo encerramento da feature 020
(estado `inicial` persistido, corrida aceita, posição e rota zeradas, modais da corrida apagadas). Sem
publicação, sem avaliação.

**Rationale**: reuso integral; o encerramento no instante (não no "OK") mantém a garantia de que fechar o
app com a modal aberta não reabre a corrida (SC-004).

## D5 — Modal

**Decision**: `DriverSilentModal` (`ModalTematizado`, título "Motorista sem sinal", texto "O motorista ficou
sem sinal e a corrida foi encerrada. Você pode solicitar outra.", botão primário "OK"), em `Stack` na
árvore do `MapScreen`, com precedência sobre as demais, no padrão de `DriverUnavailableModal`.

**Rationale**: padrão estabelecido do app (T019 de `specs/008-receber-orcamentos/tasks.md`).

## D6 — Contrato

**Decision**: nenhuma alteração. `contracts/README.md` só registra que a feature é local e consome o
`kind: 20005` como já definido.

# Quickstart — Posição do motorista no mapa do passageiro

Guia de validação em `Prototipo/passenger/`. Os cenários 2–6 exigem dois aparelhos/emuladores com
relay em comum (motorista com `Prototipo/driver` na versão com a feature 016 ou anterior — o motorista
não mudou).

## Automatizado

```bash
cd Prototipo/passenger
flutter analyze        # No issues found!
flutter test           # suíte completa
flutter test test/domain/driver_location_test.dart
```

## Manual

Pré-requisito: passageiro com solicitação aceita; motorista com "Iniciar corrida" tocado (feature 010
do motorista), publicando `kind: 20005` a cada 5 s.

1. **Posição aparece (US1)** — ao entrar em "motorista a caminho" (modal "OK"), ver o marcador de
   carro no ponto do motorista; a primeira localização já conta (FR-002).
2. **Atualiza sem duplicar** — mover o motorista no emulador: o marcador acompanha, sempre um só.
3. **Enquadramento (FR-007)** — na primeira exibição motorista e passageiro cabem na tela; mover o
   passageiro (GPS) não recentraliza sozinho; "Centralizar" volta a seguir o passageiro.
4. **Símbolo (US2)** — comparar lado a lado com a posição do próprio motorista no app dele: mesmo
   círculo, mesmas cores, mesmo ícone; e distinto do marcador do passageiro.
5. **Estado (US3)** — o marcador some ao confirmar o encontro; nunca aparece em "orçamento aceito",
   "encontro confirmado" ou antes da corrida.
6. **Evento forjado** — publicar à mão um `kind: 20005` com a tag `["e", quoteId]` mas outra chave:
   o marcador não muda (`tool/` ou cliente Nostr de teste).

## Medições (SC-001, SC-004, SC-005)

| Critério | Alvo | Medido |
|---|---|---|
| SC-001: chegada da mensagem → marcador visível | ≤ 1 s | _a medir_ |
| SC-004: 5 verificações lado a lado com o app do motorista | 5 de 5 idênticas | _a verificar_ |
| SC-005: motorista visível sem mover o mapa | sim | _a verificar_ |

Resultados e cenários que falharem devem ser relatados aqui, não omitidos (Fluxo de Desenvolvimento e
Gates, item 3).

## Estado da validação (2026-09-30)

**Validação em aparelho pendente.** A sessão que implementou a feature só tinha o alvo `linux`
(desktop) em `flutter devices` — nenhum aparelho/emulador Android nem segundo dispositivo com relay em
comum. Os cenários manuais 1–6 e a tabela de Medições **não foram executados**; o que está coberto é
o comportamento no nível de widget (testes de `MapScreen` com dublês de transporte e localização).
O teste de autor foi verificado por mutação: sem a conferência de `authorPublicKey`, ele falha.

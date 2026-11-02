# Quickstart — Cancelar corrida (passageiro)

Validação em `Prototipo/passenger/`. Para o ponta a ponta completo, dois aparelhos/emuladores Android com um
relay em comum e a feature `020` do motorista (já implementada).

## Automatizados

```bash
flutter analyze        # "No issues found!"
flutter test test/domain
flutter test test/event_feed_test.dart
flutter test test/screens/cancel_ride_modal_test.dart
flutter test test/screens/map_screen_test.dart   # lento (~13 min): rodar em segundo plano
```

## Cenários manuais (referem FR/SC de `spec.md`)

### 1. Cancelar com o motorista a caminho (US1, SC-001, SC-002)

1. Passageiro aceita um orçamento; motorista toca "Iniciar corrida" (passageiro em "motorista a caminho").
2. Passageiro toca "Cancelar corrida" e confirma.
3. **Esperado**: volta ao mapa com o painel de solicitação; marcador e rota do motorista somem; no motorista,
   modal "O passageiro cancelou a corrida" e volta a "Aguardando solicitação de corrida".

### 2. Desistir do cancelamento (US1, SC-003)

1. Tocar em "Cancelar corrida" e, na modal, em "Voltar". **Esperado**: nada muda; nada é publicado.

### 3. Cancelar "em corrida" (US2)

1. Passageiro confirma o encontro e cancela. **Esperado**: mesmos efeitos; rota do motorista some; **sem**
   modal de avaliação.

### 4. Botão ausente fora das fases (FR-001)

1. Em "aguardando orçamentos", no estado inicial e em "destino confirmado": sem "Cancelar corrida".

### 5. Reinício e nova corrida (SC-004, SC-005)

1. Cancelar, fechar e reabrir o app. **Esperado**: estado inicial sem corrida aceita; nova solicitação normal.

### 6. Concorrência (FR-006)

1. Abrir a confirmação e, antes de confirmar, o motorista cancela. **Esperado**: a confirmação fecha e
   aparece "Corrida cancelada" do motorista; o passageiro não publica nada.

### 7. Sem relay (FR-007)

1. Desconectar os relays e cancelar. **Esperado**: passageiro livre; sem erro visível.

## Estado da validação

- **Automatizados** (2026-10-07): `flutter analyze` sem problemas; 466 testes passando (447 antes desta feature,
  +19: regra de transição, publicação do `20013`, modal e o grupo de cancelamento do `MapScreen`; 182 em
  `map_screen_test.dart` e 284 nos demais, em dois lotes porque a pasta `test/screens` é lenta).
- **Em aparelho**: **pendente** — cenários 1 a 7 não executados (sem aparelho/emulador na sessão); o ponta a
  ponta depende também da feature `020` do motorista, já implementada.

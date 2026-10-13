# Quickstart — Corrida cancelada pelo motorista (passageiro)

Validação em `Prototipo/passenger/`. Para o ponta a ponta completo, dois aparelhos/emuladores Android
com um relay em comum e a feature 018 do motorista (que publica o aviso).

## Automatizados

```bash
flutter analyze        # "No issues found!"
flutter test test/domain/passenger_ride_status_test.dart
flutter test test/screens/ride_cancelled_modal_test.dart
flutter test test/screens/map_screen_test.dart
flutter test           # suíte completa
```

## Cenários manuais (referem FR/SC de `spec.md`)

### 1. Cancelamento a caminho (US1, SC-001)

1. Passageiro com orçamento aceito e o motorista "a caminho" (marcador no mapa).
2. No app do motorista, "Cancelar corrida" → confirmar.
3. **Esperado**: no passageiro, modal "Corrida cancelada"; ao tocar "OK", estado inicial (painel
   "Solicitar corrida" disponível, sem marcador do motorista).

### 2. Cancelamento em corrida (US1)

1. Encontro confirmado (passageiro "em corrida", rota do motorista traçada). Motorista cancela.
2. **Esperado**: mesma modal; ao "OK", sem rota nem marcador do motorista; nenhuma modal de
   avaliação (SC-005).

### 3. Reinício com a modal aberta (US2, SC-003)

1. Receber o aviso e, sem tocar "OK", fechar e reabrir o app.
2. **Esperado**: abre no estado inicial, sem modal e sem corrida aceita.

### 4. Aviso inválido (US3, SC-002)

1. Publicar (ferramenta de teste) um `kind: 20012` assinado por outra chave, com o `["e", ...]` da
   corrida; depois outro com `["e", ...]` de outro orçamento.
2. **Esperado**: nenhuma modal, nenhuma mudança de estado.

### 5. Nova corrida depois do cancelamento (US2, SC-004)

1. Depois do cenário 1, solicitar uma nova corrida e concluí-la.
2. **Esperado**: fluxo normal, sem interferência.

## Estado da validação (2026-10-04)

- **Automatizados**: `flutter analyze` sem problemas; `flutter test` com 354 testes passando.
- **Em aparelho**: **pendente** — cenários 1 a 5 não executados (sem emulador/aparelho na sessão que
  implementou). Exigem as duas apps com relay em comum; a feature 018 do motorista, que publica o
  aviso, já está implementada.

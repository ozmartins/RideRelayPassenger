# Quickstart — Expirar a corrida por silêncio do motorista (passageiro)

Validação em `Prototipo/passenger/`. Para o ponta a ponta, duas apps (ou o motorista simulado) com relay
em comum; o prazo real é de 3 minutos.

## Automatizados

```bash
flutter analyze        # "No issues found!"
flutter test test/domain/passenger_ride_status_test.dart
flutter test test/screens/driver_silent_modal_test.dart
flutter test test/screens/map_screen_test.dart
flutter test           # suíte completa
```

## Cenários manuais (referem FR/SC de `spec.md`)

### 1. Motorista nunca aparece (US1, SC-001)

1. Passageiro aceita um orçamento (estado "orçamento aceito"); o motorista não toca "Iniciar corrida".
2. Esperar 3 minutos.
3. **Esperado**: modal "Motorista sem sinal"; ao "OK", painel "Solicitar corrida" disponível.

### 2. Motorista some a caminho (US2)

1. Motorista inicia a corrida (marcador aparece no mapa do passageiro). Fechar o app do motorista.
2. Esperar 3 minutos desde a última localização.
3. **Esperado**: mesma modal; marcador do motorista some.

### 3. Sinal contínuo não expira (SC-002)

1. Com o motorista a caminho, localizações chegando a cada 5 s, esperar mais de 3 minutos.
2. **Esperado**: nada acontece.

### 4. Em corrida não expira (US3, SC-003)

1. Confirmar o encontro e, depois, fechar o app do motorista; esperar mais de 3 minutos.
2. **Esperado**: o passageiro continua "em corrida".

### 5. Reinício (SC-004)

1. Deixar a modal de expiração aberta e fechar/reabrir o app.
2. **Esperado**: estado inicial, sem modal e sem corrida aceita.

## Estado da validação (2026-10-04)

- **Automatizados**: `flutter analyze` sem problemas; `flutter test` com 386 testes passando.
- **Em aparelho**: **pendente** — cenários 1 a 5 não executados (sem emulador/aparelho na sessão que
  implementou; o prazo real de 3 minutos só foi exercitado com prazo reduzido nos testes).

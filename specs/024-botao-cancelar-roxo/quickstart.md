# Quickstart — Botões de cancelar corrida em roxo (passageiro)

Validação em `Prototipo/passenger/`.

```bash
flutter analyze        # "No issues found!"
flutter test test/screens/cancel_ride_modal_test.dart
flutter test test/screens/received_quotes_screen_test.dart
flutter test test/screens/map_screen_test.dart --plain-name "cancelar"
flutter test           # suíte completa (a pasta test/screens é lenta; rodar em dois lotes se preciso)
```

## Cenários manuais

1. **Mapa (US1)**: com corrida aceita, em "orçamento aceito", "motorista a caminho" e "em corrida": o botão
   "Cancelar corrida" é roxo com ícone e texto brancos.
2. **Lista (US2)**: após solicitar uma corrida, a tela de orçamentos mostra "Cancelar" roxo, com ou sem
   orçamentos.
3. **Confirmação (US3)**: o botão "Cancelar corrida" da modal tem as mesmas cores do do mapa.
4. **Comportamento intacto**: cancelar continua encerrando a corrida/solicitação e avisando o motorista.

## Estado da validação

- **Automatizados** (2026-10-07): `flutter analyze` sem problemas; `flutter test` passando em dois lotes — 187
  testes de `map_screen_test.dart` e 287 nos demais (474 no total). Localizador `confirmar` do mapa ajustado para
  excluir o botão de chave `botao-cancelar-corrida`, que agora também é um `FilledButton`. **Em aparelho**: **pendente**.

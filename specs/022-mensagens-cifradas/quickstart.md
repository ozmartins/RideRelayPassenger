# Quickstart — Mensagens cifradas entre as apps (passageiro)

Validação em `Prototipo/passenger/`. O ponta a ponta exige a feature 019 do motorista.

## Automatizados

```bash
flutter analyze        # "No issues found!"
flutter test test/services/nip44_test.dart
flutter test test/services/message_cipher_test.dart
flutter test test/identity_service_test.dart test/event_feed_test.dart
flutter test test/screens/map_screen_test.dart
flutter test           # suíte completa
```

## Cenários manuais (dois aparelhos, relay em comum, as duas apps atualizadas)

1. **Solicitar e receber orçamentos (US2)**: solicitar corrida (`20001` legível no relay, esperado); o
   `20002` do motorista é base64 opaco no relay e aparece normalmente na lista.
2. **Aceitar (US1)**: o `20003`/`20004` aparecem opacos; o motorista recebe a modal de aceitação.
3. **A caminho / rota / chegada (US2)**: `20005`, `20007`, `20009`, `20011` opacos no relay; marcador,
   rota e modais iguais aos de antes.
4. **Confirmar encontro e destino (US1)**: `20008`/`20010` opacos; o fluxo conclui e abre a avaliação.
5. **Cancelamento e silêncio (US2)**: `20012` cifrado encerra a corrida; sem `20005` por 3 min o
   passageiro expira como antes; um `20005` em claro ou cifrado a outra chave **não** rearma o relógio.
6. **Orçamento antigo (edge)**: orçamentos já gravados antes da atualização continuam na lista.

## Medição (SC-004)

Registrar em `research.md` D6 o tempo do primeiro ECDH e de decifrar uma `20005` no `Pixel_6_API34_1`.

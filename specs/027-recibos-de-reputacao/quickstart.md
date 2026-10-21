# Quickstart: 027-recibos-de-reputacao

Pré-requisito: `flutter pub get`. Nenhum teste contata relay real.

## Automatizado
```bash
flutter analyze                       # "No issues found!"
flutter test                          # suíte completa, sem testes ignorados
flutter test test/domain/receipt_test.dart test/services/reputation_verifier_test.dart \
  test/services/receipt_service_test.dart test/services/receipt_store_test.dart
```

## Cenários (dois emuladores/aparelhos: passageiro e motorista, ambos com a feature equivalente)
1. **Reputação verificada (US1)**: o motorista com recibos envia orçamento; a tela de orçamentos mostra
   "verificado nos últimos N" e, menor, o declarado. Recibo adulterado ⇒ descartado e contado.
2. **Inconsistente / lacunas (US1.4–5)**: `head` divergente ⇒ "inconsistente"; `seq` pulado ⇒ "N recibos não apresentados".
3. **Emissão (US2)**: concluir uma corrida, avaliar com nota; conferir recibo `pendente`, `20014` cifrado no relay
   (conteúdo ilegível) e baixa ao chegar o `20015`. Repetir com "pular" (sem `nota`).
4. **Sobrevive a reinício (US2.5)**: desligar o motorista, concluir e avaliar, fechar e reabrir o passageiro; o
   recibo continua pendente e é reenviado; ligar o motorista ⇒ confirmado.
5. **Reputação inconsistente (US2.3)**: orçamento com `head` falso aceito ⇒ aviso de uma linha, sem recibo, nota local mantida.
6. **Recepção (US3)**: motorista avalia o passageiro; o passageiro grava, responde `20015` e o próximo `20001`
   leva `reputacao`; sem recibos, o `20001` sai sem a chave.
7. **Silêncio**: com o app em segundo plano, `20014`/`20015` não geram notificação.
8. **Não vazamento (Princípio I)**: inspecionar `adb logcat` e o tráfego dos relays: nenhuma chave privada, nenhum
   `content` de `20014/20015` em claro.
9. **Vetor compartilhado**: o mesmo `test/fixtures/receipt_vectors.json` passa no passageiro e no motorista.

## Resultado da execução (2026-10-20)

**Automatizado — executado**: `flutter analyze` sem apontamentos; `flutter test` integral: 728 testes, 0 falhas, 0
ignorados (medido com o repórter JSON do `flutter test`, contando também os ignorados como falha). O vetor
`test/fixtures/receipt_vectors.json` é idêntico ao do motorista (`diff` sem saída).

**Cenários 1–9 em dois aparelhos — NÃO executados.** Dependem do app do motorista com a feature 026 e de relays reais.
O que os testes automatizados já provam, por cenário:

| Cenário | Coberto por | Falta (manual) |
|---|---|---|
| 1 e 2 (reputação na tela) | `received_quotes_screen_test` (verificado × declarado, inconsistente, lacunas, descartados) | ver na interface real |
| 3 (emissão, `20014` cifrado, baixa no `20015`) | `receipt_service_issue_test`, `map_screen_test` (nota e "pular") | ver o `20014` ilegível no relay |
| 4 (sobrevive a reinício) | `receipt_service_issue_test` (store compartilhada) | reiniciar o app de verdade |
| 5 (head falso) | `map_screen_test` (aviso, sem recibo, nota local mantida) | — |
| 6 (recepção e `20001` com `reputacao`) | `receipt_service_receive_test`, `map_screen_test`, `event_feed_test` | ponta a ponta com o motorista |
| 7 (silêncio) | `background_notification_rule_test` | com o app em segundo plano |
| 8 (não vazamento) | `receipt_service_privacy_test` | `adb logcat` e tráfego do relay |
| 9 (vetor) | `receipt_test`, `reputation_verifier_test` | rodar o mesmo arquivo no motorista |

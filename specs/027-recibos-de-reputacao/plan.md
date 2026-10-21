# Plano de implementação: 027-recibos-de-reputacao

**Spec**: [spec.md](spec.md) · **App**: `passenger/` · **Data**: 2026-10-20 · **Referência**: `especificacao-passageiro.md`
(contrato comum idêntico ao do app do motorista; o código das apps não é espelho, exceto domínio e verificador)

## Resumo

Reputação sem backend: cada corrida concluída gera um **recibo assinado** pelo avaliador (kind `20014`, cifrado),
confirmado pelo avaliado (`20015`); os recibos formam uma cadeia por avaliado, apresentada (últimos 5) no campo
opcional `reputacao` do `20001` (em claro, passageiro) e do `20002` (cifrado, motorista). Este app emite recibos
do motorista, recebe os do motorista sobre o passageiro, verifica a `reputacao` dos orçamentos por função pura e
a exibe na tela de orçamentos. Sem dependência nova, sem relay guardando avaliação, sem backend.

## Contexto técnico

- **Linguagem/SDK**: Dart ^3.13.3, Flutter, Android apenas.
- **Dependências novas**: nenhuma ([research.md](research.md) D1; `crypto` já é direta).
- **Armazenamento**: `receipts.db` (sqflite) com três tabelas ([data-model.md](data-model.md)); `ride_ratings` permanece.
- **Testes**: `flutter_test` com dublês em memória (`ReceiptStore`, relay); assinatura/verificação com a cripto real.
- **Restrições**: chave privada só em `IdentityService`/Keystore; `20014/20015` sempre cifrados; serviço em segundo
  plano sem chave e sem notificar esses kinds; sem `since`; marcador do protótipo intocado.
- **Escala**: ≤ 5 recibos por `reputacao`; `content` < 65 535 bytes.

## Verificação da constituição (2.16.0)

| Princípio / restrição | Situação |
|---|---|
| I — segredo não vaza | OK: chave só entra em `keys.sign`; recibo/log sem chave; teste de não vazamento (log + conteúdo publicado) no quickstart 8. |
| II — assinatura nasce com teste | OK: `receipt_signature` e `reputation_verifier` nascem com testes válido/inválido (id adulterado, assinatura, autor, seq, guid repetido). |
| III — dependência registrada | Nenhuma nova ([research.md](research.md) D1); tipos de terceiros confinados a `services/`. |
| IV — contrato antes do código | [contracts/reputacao-por-recibos.md](contracts/reputacao-por-recibos.md); emenda 25 no `nostr-events.md` das **duas** apps no mesmo commit; vetor compartilhado. |
| V — simplicidade | `ReceiptStore` tem consumidor real e dublê de teste; sem camada sem uso. Reenvio com só o serviço vivo fora de escopo (D5). |
| Dado pessoal sem cifra | **Gate**: `reputacao` no `20001` em claro expõe chaves públicas de contrapartes. A seção de Segurança exige registrar a exceção **antes do código** ⇒ **emenda 2.17.0** (texto abaixo), nas duas apps, commit à parte. Justificativa em `spec.md`. |
| Segundo plano / notificação | `20014/20015` entram em `passengerConsumedKinds` mas NÃO em `notifiableKinds`; serviço continua sem chave e sem decifrar. |
| Identidade visual | Tela de orçamentos ganha linhas de reputação; seguem `identidade_visual.dart` (roxo, tipografia existente). Sem tela nova. |

**Emenda 2.17.0 (texto proposto):** na exceção do `kind: 20001`, acrescentar: "O `20001` pode incluir o campo
opcional `reputacao` (os recibos assinados mais recentes), que expõe publicamente as chaves públicas de
motoristas que avaliaram o passageiro e as notas dadas; justificado em `specs/027-recibos-de-reputacao/spec.md`
e na seção 1.9 do contrato como custo aceito do protótipo." (Texto final no commit da emenda.)

## Estrutura do código

```text
passenger/lib/
├── domain/
│   ├── receipt.dart               # novo: Receipt, canonical/computeId, fromJson estrito
│   ├── reputation.dart            # novo: Reputation, kReputacaoJanela = 5
│   ├── reputation_view.dart       # novo: resultado da verificação (verificado × declarado)
│   └── received_quote.dart        # lê `reputacao` opcional (malformada => null)
├── services/
│   ├── receipt_signature.dart     # novo: sign/verify sobre id_recibo (keys.sign/verify)
│   ├── reputation_verifier.dart   # novo: função pura, regras 1.6 (a–i)
│   ├── receipt_store.dart         # novo: ReceiptStore + SqfliteReceiptStore + dublê (test/support)
│   ├── receipt_service.dart       # novo: issueFor, onReceiptEvent, onAckEvent, retryPending (+ timer 60 s)
│   ├── event_feed.dart            # publishReceipt, publishReceiptAck, publishRideRequest(reputation:)
│   └── subscription_request.dart  # passengerConsumedKinds += 20014, 20015
├── screens/
│   ├── received_quotes_screen.dart # reputação verificada/declarada/inconsistente/lacunas
│   └── map_screen.dart             # saveDeclared ao aceitar; issueFor ao fechar a modal; myReputation no 20001
└── main.dart                       # instancia SqfliteReceiptStore + ReceiptService, injeta no _Shell

passenger/test/
├── fixtures/receipt_vectors.json  # vetor compartilhado (idêntico ao do motorista)
├── domain/{receipt,reputation,received_quote}_test.dart
├── services/{receipt_signature,reputation_verifier,receipt_store,subscription_request,event_feed}_test.dart
├── services/receipt_service_{issue,receive,privacy}_test.dart
├── domain/background_notification_rule_test.dart   # 20014/20015 não notificam
└── support/in_memory_receipt_store.dart
```

## Fases

1. **Contrato e constituição** (commits separados): emenda 2.17.0 (nas duas apps) → emenda 25 em `nostr-events.md`
   (+ vetor) nas duas apps.
2. **Domínio e criptografia**: `Receipt`, `Reputation`, `ReputationView`, `receipt_signature`, `reputation_verifier`
   — testes primeiro (Princípio II) contra o vetor compartilhado.
3. **Persistência e serviço**: `ReceiptStore` (+dublê), `ReceiptService`, publicações no `EventFeed`,
   `passengerConsumedKinds`.
4. **Integração**: `ReceivedQuote.reputation`, `main.dart`, `map_screen.dart` (aceitar, avaliar, solicitar),
   tela de orçamentos.
5. **Gates**: `flutter analyze`, `flutter test`, quickstart 1–9, não vazamento.

## Riscos
- Vetor compartilhado divergente entre apps: mitigado por copiar o mesmo JSON e rodar nos dois repositórios.
- Reenvio sem interface (D5): limite declarado.
- Corrida descartada antes de `issueFor`: `issueFor` roda antes de `_finalizarAvaliacao` (D6).

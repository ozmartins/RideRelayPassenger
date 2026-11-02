# Implementation Plan: Mensagens cifradas entre as apps (passageiro)

**Branch**: `master` (commits diretos, sem branch de feature — Padrão de Commits da constituição) | **Date**: 2026-10-06 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/022-mensagens-cifradas/spec.md`

## Summary

Contrapartida, no passageiro, de `Prototipo/driver/specs/019-mensagens-cifradas`. O passageiro cifra com
NIP-44 v2, ao motorista da tag `p`, o `content` do que publica com destinatário (`20003`, `20004`,
`20008`, `20010` — todos do marcador `{}`), e decifra o que recebe (`20002`, `20005`, `20006`, `20007`,
`20009`, `20011`, `20012`). O `20001` segue assinado e em claro (exceção). A cifra é uma cópia, adaptada
aos imports do passageiro, de `nip44.dart` do motorista, sobre `pointycastle` e `crypto`; a política
(cache de chave de conversa, marcador, conferência de `p`) mora em `services/message_cipher.dart`.
Cifrar acontece em `EventFeed._publish` (já é onde assina); decifrar acontece no consumo, em
`MapScreen` (que tem a identidade), logo na entrada de cada tratador. O contrato (emenda 17) e a
constituição (2.11.0) são **escritos pela feature do motorista nas duas apps**; aqui só se confere.

## Technical Context

**Language/Version**: Dart 3 / Flutter (versão já fixada no `pubspec.yaml`)

**Primary Dependencies**: `dart_nostr` (assinatura, chaves — sem mudança); promoção a diretas de
`pointycastle ^3.9.1` e `crypto ^3.0.7` (já transitivas) — mesma decisão D1 do motorista (Princípio III).

**Storage**: sem mudança. `SqfliteReceivedQuoteStore` já grava campos decodificados (FR-009), sem
migração; chave de conversa por par só em memória.

**Testing**: `flutter_test`; vetores oficiais do NIP-44 em `test/fixtures/nip44.vectors.json` (mesma
cópia do motorista); dublês de `test/support/` (`FakeRelayTransport`, `event_fixtures.dart`, que passa a
ter um construtor de evento do motorista **cifrado**). Nenhum teste toca rede (Princípio II).

**Target Platform**: Android (sem mudança)

**Project Type**: mobile-app (Flutter, Android apenas)

**Performance Goals**: decifrar < 100 ms por mensagem, inclusive o primeiro ECDH do par (SC-004), com a
chave de conversa em cache; localização a cada 5 s segue sem atraso; se o primeiro ECDH passar de
~100 ms, a cifra vai para um `Isolate` (decisão D4 do motorista).

**Constraints**: nunca publicar em claro como alternativa (FR-004); ordem assinatura → destinatário →
decifração (FR-005); só `20005` decifrado conta para "a caminho" e silêncio (FR-007).

**Scale/Scope**: um par passageiro-motorista por corrida; 4 kinds publicados, 7 recebidos.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio / restrição | Avaliação |
|---|---|
| I. Segredo criptográfico não vaza | PASS (obrigação). A chave privada só é lida em `IdentityService`/`EventFeed._publish` e em `MessageCipher`; a chave de conversa vive em memória, sem log nem persistência; falhas não ecoam conteúdo. |
| II. Assinatura/verificação nascem com teste | PASS (obrigação). Vetores oficiais, política de decifração e conteúdo cifrado dos quatro publicadores têm teste. |
| III. Dependência exige decisão registrada | **GATE ATIVO.** `pointycastle` e `crypto` viram diretas; `research.md` D1 cita a decisão do motorista e registra o que é específico do passageiro. |
| IV. Contrato antes do código, replicado | **GATE ATIVO.** A emenda 17 já é escrita nas duas cópias pelas tarefas de gate da feature 019 do motorista; esta feature **verifica** a cópia do passageiro e só então começa o código. |
| V. Simplicidade e medição | PASS com medição devida: SC-004 medido de fato (sonda do motorista já cobre o tempo; aqui medir a decifração no emulador). A cifra duplicada entre apps é custo aceito (D2). |
| Restrições de Segurança e Privacidade | **EMENDA 2.11.0** feita pelo gate da feature do motorista; aqui, verificar o espelho. |
| Identidade Visual e Design | N/A — sem tela nova nem alterada. |

Pós-design (Phase 1): inalterado; os gates viram os primeiros itens de `tasks.md`.

## Project Structure

### Documentation (this feature)

```text
specs/022-mensagens-cifradas/
├── plan.md  research.md  data-model.md  quickstart.md  tasks.md
└── contracts/README.md   # aponta para a emenda 17 do motorista (não a redefine)
```

### Source Code (repository root: `Prototipo/passenger/`)

```text
lib/
├── services/
│   ├── nip44.dart              # NOVO — cópia adaptada da do motorista
│   ├── message_cipher.dart     # NOVO — cache de chave de conversa + política (`{}`, `p`)
│   ├── (identity_service.dart sem mudança)
│   └── event_feed.dart         # _publish cifra; decrypted(evento, identity) decifra; falha → relatório vazio
├── domain/                     # sem mudança de entidade (ReceivedQuote, DriverLocation, RideRoute
│                               # recebem o texto já decifrado — D3)
└── screens/map_screen.dart     # tratadores de 20002/20005/20006/20007/20009/20011/20012 decifram
test/
├── fixtures/nip44.vectors.json
├── services/{nip44,message_cipher}_test.dart; test/identity_service_test.dart; test/event_feed_test.dart
├── support/event_fixtures.dart # + construtor de evento cifrado do motorista
└── screens/map_screen_test.dart
```

**Structure Decision**: mesma divisão do motorista (cifra pura + política em `services/`), mas
decifrar no consumo porque o `EventFeed` do passageiro, como o do motorista, é construído sem acesso à
identidade para receber e é usado também com `kind: 1`/`20001`.

## Complexity Tracking

Sem violações a justificar.

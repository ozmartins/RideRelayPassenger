# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projeto

App Flutter (Android apenas) do **passageiro** de um protótipo de corridas P2P sobre Nostr (TCC UFSC). Não há backend: toda comunicação com o app irmão do motorista (`../driver`) passa por relays Nostr. O README.md (em português) tem a visão do produto; documentação e comentários do código são em português do Brasil.

## Comandos

```bash
flutter pub get
flutter analyze                      # deve terminar com "No issues found!"
flutter test                         # suíte completa
flutter test test/event_feed_test.dart
flutter test --plain-name "descarta evento com assinatura adulterada"
flutter run [-d <dispositivo>]
dart run tool/check_relays.dart      # sonda relays reais (de propósito fora de test/)
```

Testes nunca contatam relay real: serviços recebem armazenamento/transporte por injeção e usam dublês de `test/support/`. A verificação de assinatura nos testes usa a criptografia real (não dublar o verificador).

## Arquitetura

- `lib/main.dart` é a **raiz de composição**: único lugar que escolhe as implementações reais (`FlutterSecureStore`, `RemoteRelayHub`, stores em SharedPreferences/sqflite, Photon, OpenRouteService). O resto depende de interfaces (`SecureStore`, `RelayTransport`, `RelayHub`, `LocationService`, `GeocodingService`, `RouteService`, `*Store`).
- `lib/domain/`: entidades com tipos próprios. Tipos de `dart_nostr` ficam confinados a `lib/services/`.
- `lib/services/`: lógica e integrações. `EventFeed` recebe, verifica (`NostrEventVerifier` recalcula o `id` antes de checar a assinatura — `isVerified()` da lib não faz isso), deduplica e publica. `nip44.dart`/`message_cipher.dart` implementam a cifra das mensagens do motorista.
- **Conexão em segundo plano (feature 026)**: a conexão com os relays vive num serviço em primeiro plano do Android (`lib/services/background/`), não na UI. A UI usa `RemoteRelayHub`, que conversa com o serviço por mensagens (`MessageChannel`/`service_messages.dart`); `RelayHostCore` roda dentro do serviço. O serviço **nunca tem a chave privada**: decide notificar só por dados públicos do evento (kind, autor, tags `p`/`e`) via `BackgroundNotificationRule`, pois o `content` é NIP-44 cifrado ao passageiro. `passengerConsumedKinds` é a lista de kinds compartilhada entre `EventFeed` e a inscrição do serviço.
- **Reputação por recibos (feature 027, emenda 25)**: cada corrida concluída gera um recibo assinado pelo avaliador (`kind` 20014, cifrado; confirmação `20015`), encadeado por hash na cadeia do avaliado. `ReceiptService` emite o recibo do motorista ao fechar a modal de avaliação, reenvia os pendentes (abertura do app, reconexão de relay, 60 s com o app aberto — nunca pelo serviço em segundo plano, que não tem a chave) e recebe os recibos do motorista; `ReceiptStore` (`receipts.db`) guarda os recibos e a reputação declarada pelo motorista no orçamento aceito; `ReputationVerifier` (função pura) separa o **verificado** do **declarado**. O `20001` leva a `reputacao` do próprio passageiro em claro (exceção da constituição 2.17.0). `20014`/`20015` estão em `passengerConsumedKinds` mas nunca notificam.
- Estado da corrida do passageiro (`PassengerRideStatus`, `PassengerRideStateStore`) e destino/corrida aceita/orçamentos/avaliações são persistidos localmente; o destino do usuário nunca é publicado em relay.
- `lib/screens/`: telas e modais; `identidade_visual.dart` concentra a identidade visual.

## Invariantes que cruzam as duas apps

O app do motorista não compartilha código; estes itens MUST ser idênticos nos dois e mudar no **mesmo commit** em ambos:
- Contratos de eventos em `specs/*/contracts/` (principalmente `specs/002-nostr-relay-connection/contracts/nostr-events.md`, com emendas numeradas)
- `lib/shared/default_relays.dart`
- `test/fixtures/receipt_vectors.json` (vetor de contrato dos recibos; gerado no motorista e copiado byte a byte — `diff` sem saída)
- Marcador `["t", "tcc-ufsc-caronas"]` em `lib/shared/prototype_marker.dart` (filtro `#t` na inscrição; não é mecanismo de segurança)

## Processo (spec-kit + constituição)

O desenvolvimento segue spec-kit: cada feature tem `specs/NNN-nome/` (spec, plan, research, data-model, tasks, quickstart); a feature ativa está em `.specify/feature.json`. Use as skills `speckit-*`. A constituição (`.specify/memory/constitution.md`, com Sync Impact Report no topo) é normativa:
- Chave privada nunca vaza (logs, `toString`, UI); código de assinatura/verificação nasce com teste.
- Dependência nova exige decisão registrada no `research.md` da feature (Princípio III); o contrato do evento vem antes do código.
- Gates de conclusão: `flutter analyze` limpo, `flutter test` integral sem testes ignorados, cenários do `quickstart.md` executados, telas novas seguem a seção Identidade Visual.
- **Commits**: português do Brasil, sem Conventional Commits nem emojis; assunto numa frase com verbo no presente, 3ª pessoa ("Adiciona", "Corrige"), sem ponto final, < 120 caracteres, nomeando alvo e efeito; corpo em prosa (~80 colunas) explicando o porquê quando muda comportamento/contrato/dependência; um commit = uma mudança lógica (emenda de constituição, código que ela autoriza e atualização do CLAUDE.md são commits separados); trailer `Co-Authored-By:` quando houver IA; commits direto na `master`, histórico linear, sem ramos de feature. Isto prevalece sobre skills genéricas de commit.

## Observações

- `assets/ors_api_key.txt` é a chave do OpenRouteService embutida no app (decisão consciente do autor); `--dart-define=ORS_API_KEY=` tem precedência.
- Desinstalar o app destrói a identidade (chave no Android Keystore).

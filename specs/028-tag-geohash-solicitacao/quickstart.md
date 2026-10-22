# Quickstart: 028-tag-geohash-solicitacao

Pré-requisitos: `flutter pub get`; motorista com `test/fixtures/geohash_vectors.json` gerado.

1. **Vetor idêntico**: `diff test/fixtures/geohash_vectors.json ../RideRelayDriver/test/fixtures/geohash_vectors.json` — sem saída.
2. **Contrato idêntico**: `diff specs/002-nostr-relay-connection/contracts/nostr-events.md ../RideRelayDriver/specs/002-nostr-relay-connection/contracts/nostr-events.md` — só o cabeçalho de procedência.
3. **Geohash**: `flutter test test/domain/geohash_test.dart test/services/geohash_contract_vectors_test.dart`.
4. **Publicação**: `flutter test test/event_feed_test.dart --plain-name "20001"` — evento com `t` + três `g` corretas, `content` igual ao anterior, assinatura verificada, transporte dublê.
5. **Coordenada inválida**: o teste correspondente confirma que nada é enviado.
6. **Gate**: `flutter analyze` ("No issues found!") e `flutter test` integral, sem testes ignorados.
7. **Ponta a ponta (opcional, com o motorista da 027)**: motorista online na região recebe a solicitação; fora do raio, não.

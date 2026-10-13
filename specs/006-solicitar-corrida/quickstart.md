# Phase 1 — Quickstart / Validação: Solicitar corrida

Comandos executados a partir de `Prototipo/passenger`. O cenário 1 é automatizado; os demais exigem
emulador/aparelho com conectividade de rede real até os relays padrão do protótipo (mesma exigência
da feature 002) e até `https://photon.komoot.io` (para escolher um destino via feature 005).

## Pré-requisitos

- Ambiente das features 001–005 funcionando (ver `README.md`)
- Dependências instaladas: `flutter pub get`
- Conectividade de internet no emulador/aparelho (relays e Photon)
- Um segundo cliente Nostr (ou o `dart run tool/check_relays.dart`/um relay explorer público) capaz
  de se inscrever em `{"kinds": [20001], "#t": ["tcc-ufsc-caronas"]}` para observar o evento
  publicado de fora do app — usado no Cenário 5 (SC-004)

## Cenário 1 — Gates automatizados

```bash
flutter analyze   # esperado: No issues found!
flutter test      # esperado: todos os testes passam
```

Cobre, com dublês de `LocationService`, `GeocodingService`, `RelayService`/transporte e `EventFeed`
(sem rede real — Princípio II): as três User Stories do `spec.md` (solicitar com tudo disponível,
tentar sem destino, tentar sem posição), a montagem do `content` JSON (D2/D3 de `research.md`,
incluindo a ordem lat/lon do GeoJSON da Photon — D4), a pré-seleção e troca de forma de pagamento
(D5), e o novo método `EventFeed.publishRideRequest` (kind, tags, sem relay conectado).

## Cenário 2 — Solicitar corrida com destino, posição e pagamento disponíveis (US1, SC-001)

```bash
flutter run
```

1. Na tela do mapa, aguarde a posição atual aparecer (ícone de "sua posição").
2. Busque e selecione um endereço de destino (fluxo da feature 005).
3. Confira a forma de pagamento pré-selecionada ("Dinheiro") e, se quiser, troque para "PIX" ou
   "Cartão".
4. Toque em "Solicitar corrida".

**Esperado**: em uma única interação (sem telas adicionais), o app confirma visivelmente que a
solicitação foi enviada, sem expor o JSON do evento na interface.

## Cenário 3 — Sem destino escolhido (US2, SC-002)

1. Na tela do mapa, com o campo de destino vazio (ou com texto digitado, sem tocar em nenhuma
   sugestão), toque em "Solicitar corrida".

**Esperado**: nenhuma solicitação é enviada; uma mensagem explica que é preciso escolher um destino
primeiro. O campo de destino mantém o texto que já estava digitado.

## Cenário 4 — Sem posição atual disponível (US3, SC-003)

1. Negue a permissão de localização (ou desligue a localização do aparelho antes de abrir o app).
2. Busque e selecione um destino (a busca funciona independentemente da posição — garantia da
   feature 005).
3. Toque em "Solicitar corrida".

**Esperado**: nenhuma solicitação é enviada; uma mensagem informa que a posição atual ainda não está
disponível.

## Cenário 5 — O evento publicado é válido para qualquer cliente NIP-01 (SC-004)

Com o segundo cliente Nostr (ou relay explorer) inscrito em
`{"kinds": [20001], "#t": ["tcc-ufsc-caronas"]}`:

1. Repita o Cenário 2.
2. No segundo cliente, localize o evento recebido.

**Esperado**: o evento tem os sete campos do envelope NIP-01 (`id`, `pubkey`, `created_at`, `kind:
20001`, `tags` com o marcador, `content`, `sig`), a assinatura verifica com sucesso no segundo
cliente (prova independente da verificação própria do app), e o `content` decodifica como o JSON
descrito em `contracts/ride-request-event.md`, com `origin`/`destination` correspondendo à posição e
ao destino usados no Cenário 2 e `payment` correspondendo à forma escolhida.

## Cenário 6 — Nenhum relay conectado (FR-010)

1. Remova todos os relays da lista (tela de relays) ou aguarde todos ficarem indisponíveis.
2. Repita os passos 1–3 do Cenário 2.
3. Toque em "Solicitar corrida".

**Esperado**: nenhuma solicitação é enviada; uma mensagem informa que não há relay conectado —
mesma mensagem já usada por `HomeScreen` para o evento de teste (FR-010).

## Verificação de não vazamento (Princípio I)

Esta feature assina um evento novo com a identidade local do passageiro. Verificação: inspecionar,
com um proxy ou os logs do transporte WebSocket, que o payload publicado (Cenário 2 ou 5) contém
apenas `id`, `pubkey`, `created_at`, `kind`, `tags`, `content`, `sig` — nunca a chave privada, nem em
`content`, nem em nenhum campo do envelope.

## Verificação de privacidade (Restrições de Segurança e Privacidade da constituição)

Confirmar, no Cenário 5, que o `content` do evento não traz nome, apelido de exibição nem qualquer
identificador além da `pubkey` do envelope — apenas `origin`, `destination` e `payment`, conforme a
justificativa de privacidade do `spec.md`.

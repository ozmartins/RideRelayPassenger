# Corridas Passageiro

Aplicativo do **passageiro** do protótipo de corridas P2P sobre Nostr, do TCC
"Nostr para Mobilidade P2P: Avaliação de Viabilidade em Aplicativos de Corridas" (UFSC — Araranguá).

O aplicativo tem uma identidade Nostr própria, conecta-se simultaneamente a vários relays públicos,
publica e recebe eventos assinados e interopera com o aplicativo do motorista — **sem backend e sem
que as duas apps se conheçam**: toda a comunicação passa por relays Nostr. O passageiro informa o
destino, solicita a corrida, recebe e aceita orçamentos, acompanha o motorista no mapa, conversa com
ele por mensagens cifradas, avalia a corrida e acumula reputação por recibos assinados.

| | |
|---|---|
| Nome de exibição | `Corridas Passageiro` |
| Identificador de aplicativo | `br.ufsc.tcc.corridas.passenger` |
| Plataforma | Android (iOS, web e desktop fora de escopo) |
| App irmã | `Corridas Motorista` — `br.ufsc.tcc.corridas.driver`, em `../driver` |

As duas apps usam o namespace comum `br.ufsc.tcc.corridas` com sufixos distintos, de modo que **podem
ser instaladas simultaneamente no mesmo aparelho** — é assim que a interoperabilidade é validada.

## O aplicativo

**O aplicativo exige acesso à internet.** Sem rede ele abre normalmente, explica a falta de conexão e
reconecta sozinho quando a rede volta.

A tela inicial é uma barra de navegação com duas abas, **Mapa** e **Mais**:

| Tela | O que faz |
|---|---|
| **Mapa** | Mapa vetorial (tiles do OpenFreeMap) centrado na posição real do passageiro. Concentra todo o fluxo da corrida: busca de endereço de destino com sugestões (Photon), rota até o destino (OpenRouteService), escolha da forma de pagamento e **Solicitar corrida**; lista de orçamentos recebidos (com a reputação do motorista, separando o **verificado** do **declarado**), aceitação, acompanhamento do motorista a caminho, confirmação de encontro e de chegada ao destino, cancelamento e avaliação ao final. Pede a permissão de localização ao abrir e mostra mensagem compreensível se ela for negada ou a localização ficar indisponível. O **destino nunca é publicado em relay**; a solicitação leva apenas a origem, por meio de tags de geohash. |
| **Mais** | Estado das conexões ("3 de 3 relays conectados") e o menu: **Meu nome** (nome/apelido de exibição, editável), **Minha identidade** (chave pública, legível e copiável — a chave privada **nunca** é exibida) e **Relays** (lista, acrescenta e remove relays, com validação de endereço, reconexão manual e opção de restaurar a lista padrão; a lista sobrevive ao fechamento do app). |

O estado da corrida (`PassengerRideStatus`), o destino, a corrida aceita, os orçamentos, as avaliações
e os recibos são persistidos localmente e sobrevivem a um reinício do app.

### Em segundo plano

A conexão com os relays vive num **serviço em primeiro plano do Android**, não na interface, e por
isso o app continua recebendo mensagens do motorista com a tela fechada e notifica o passageiro. O
serviço **nunca tem a chave privada**: decide notificar apenas por dados públicos do evento (kind,
autor, tags), pois o conteúdo das mensagens é cifrado (NIP-44) para o passageiro. A decifração
acontece só na interface, ao abrir o app.

### Serviços externos

O app consulta três serviços públicos de terceiros, além dos relays:

| Serviço | Uso |
|---|---|
| OpenFreeMap | tiles vetoriais do mapa (estilo `positron`) |
| Photon (komoot) | busca de endereço do destino |
| OpenRouteService | cálculo da rota (perfil `driving-car`) |

A chave do OpenRouteService vem embutida em `assets/ors_api_key.txt` (decisão consciente do autor);
`--dart-define=ORS_API_KEY=<chave>` tem precedência.

> **Desinstalar o aplicativo destrói a identidade.** A chave privada vive só no armazenamento
> protegido do aparelho (Android Keystore). Ao reinstalar, uma identidade nova é criada e a anterior
> não pode ser recuperada — os eventos publicados antes continuam na rede, atribuídos a uma chave que
> o aplicativo não tem mais.

## Pré-requisitos

- **Flutter 3.47.x** (canal stable) com **Dart ^3.13.3** (`environment.sdk` do `pubspec.yaml`).
- Android SDK configurado e um emulador ou aparelho Android **com acesso à internet e localização
  simulável**. O app pede as permissões de localização e de notificação.

Comece verificando o ambiente:

```bash
flutter --version
flutter doctor
```

Apenas o grupo **`[✓] Android toolchain`** precisa estar OK. Falhas nos grupos `Chrome` e
`Linux toolchain` são esperadas e **não** impedem o trabalho — web e desktop estão fora de escopo.

## Setup

```bash
flutter pub get
```

## Executar

Com um emulador aberto ou aparelho conectado (use `flutter devices` para listar):

```bash
flutter run

# escolhendo explicitamente o dispositivo
flutter run -d emulator-5554
```

Para subir o emulador antes:

```bash
flutter emulators                              # lista os emuladores disponíveis
flutter emulators --launch <id-do-emulador>
```

## Análise estática

```bash
flutter analyze
```

Deve reportar `No issues found!`. O conjunto de regras é o `flutter_lints`, incluído por
`analysis_options.yaml`.

## Testes

```bash
# suíte completa
flutter test

# apenas um arquivo de teste
flutter test test/event_feed_test.dart

# apenas um teste, pelo nome
flutter test --plain-name "descarta evento com assinatura adulterada"
```

**Nenhum teste automatizado contata relay real.** Serviços recebem armazenamento e transporte por
injeção, e os testes usam dublês em memória (`test/support/`). É uma regra do
projeto: teste que depende de relay público é lento, intermitente e falha sem rede. A verificação de
assinatura, porém, é a criptografia de verdade — dublar o verificador esvaziaria o que precisa ser
testado.

## Verificar os relays padrão

A lista padrão é volátil: relays públicos saem do ar. Para reconfirmar, sob demanda:

```bash
dart run tool/check_relays.dart
```

O script publica um evento assinado por uma identidade descartável e o recupera **por uma conexão
separada**, que é a mecânica real da interoperabilidade. Ele contata relays reais de propósito, e por
isso vive em `tool/` e não em `test/`.

`tool/publish_test_message.dart` também contata relays reais: publica uma mensagem "do motorista"
para validar a notificação em segundo plano (veja o cabeçalho do script para os argumentos).

## Medir o tempo de inicialização

```bash
flutter run --profile --trace-startup
cat build/start_up_info.json
```

`timeToFirstFrameMicros` deve ficar abaixo de 3 s. A medição de referência (74,5 ms no emulador
`Pixel_6_API34_1`) é da base inicial do app (feature 001), anterior ao mapa e ao serviço em segundo
plano; refaça-a antes de citar o número.

## Estrutura do projeto

```text
lib/
├── main.dart          # raiz de composição: único lugar que escolhe as implementações reais
├── domain/            # entidades com tipos próprios — nunca importam dart_nostr
│   ├── identity.dart, relay.dart, nostr_event.dart     # identidade, relay e evento verificado
│   ├── ride_request.dart, received_quote.dart, accepted_ride.dart   # solicitação, orçamento, corrida
│   ├── passenger_ride_status.dart                      # estado único da corrida
│   ├── receipt.dart, reputation.dart, reputation_view.dart          # recibos e reputação
│   ├── geohash.dart                                    # tags g da origem do kind 20001
│   └── ...                                             # posição, destino, rota, pagamento, avaliação
├── services/          # lógica e integrações; único lugar que importa dart_nostr
│   ├── relay_service.dart, relay_hub.dart, relay_transport.dart   # conexões e reconexão
│   ├── event_feed.dart, event_verifier.dart            # recepção, verificação, deduplicação, publicação
│   ├── nip44.dart, message_cipher.dart                 # cifra das mensagens do motorista
│   ├── receipt_service.dart, receipt_store.dart, reputation_verifier.dart   # recibos e reputação
│   ├── geocoding_service.dart, route_service.dart, location_service.dart    # Photon, ORS, GPS
│   ├── *_store.dart                                    # persistência local (SharedPreferences/sqflite)
│   └── background/                                     # serviço em primeiro plano (feature 026)
├── screens/           # telas e modais: mapa, mais, nome, identidade, relays, orçamentos, avaliação
└── shared/            # lista padrão de relays, marcador do protótipo, informações do app

specs/                 # uma pasta por feature (spec-kit): spec, plan, tasks, contratos
test/                  # testes, com dublês em test/support/ e vetores em test/fixtures/
tool/                  # sondas que contatam relays reais (check_relays, publish_test_message)
android/               # projeto Android (applicationId br.ufsc.tcc.corridas.passenger)
```

Tipos de `dart_nostr` ficam confinados a `services/`: domínio e telas usam tipos próprios. Trocar de
biblioteca não deveria tocar na interface.

## Nota de arquitetura

O protótipo **não tem backend**. As apps do motorista e do passageiro não se conhecem e não trocam
pacotes diretamente: toda a comunicação acontece publicando e assinando eventos em relays Nostr.

A consequência prática é que **não existe lugar para lógica compartilhada**. Estes itens precisam ser
idênticos nas duas apps e mudar de um lado sem o outro é defeito:

| O que | Onde, no passageiro |
|---|---|
| Contrato de eventos (com emendas numeradas) | `specs/*/contracts/`, principalmente `specs/002-nostr-relay-connection/contracts/nostr-events.md` |
| Lista padrão de relays | `lib/shared/default_relays.dart` |
| Marcador do protótipo `tcc-ufsc-caronas` | `lib/shared/prototype_marker.dart` |
| Vetor de contrato dos recibos | `test/fixtures/receipt_vectors.json` (gerado no motorista, copiado byte a byte) |
| Vetor do geohash da tag `g` | `test/fixtures/geohash_vectors.json` (gerado no motorista, copiado byte a byte) |

### Por que o marcador existe

O evento de teste da primeira etapa usava `kind: 1` (retirado do contrato de eventos), a nota de texto padrão do
Nostr — aceita por qualquer relay, mas também usada por toda a rede social. Inscrever-se em `kind: 1`
sem filtro entregava o tráfego público inteiro: medido em ~500 eventos alheios por relay no primeiro segundo. O marcador
`["t", "tcc-ufsc-caronas"]` e o filtro `#t` na inscrição isolam o tráfego do protótipo.

O marcador **não é segurança**: qualquer pessoa pode publicar com a mesma tag. A confiança vem da
verificação de assinatura e da autoria. É um achado do trabalho: **o Nostr não oferece isolamento de
aplicação** — a separação é convenção combinada entre as partes, não garantia do protocolo.

### Verificação de assinatura

`NostrEvent.isVerified()` da biblioteca `dart_nostr` confere a assinatura sobre o `id` **informado**,
sem recalcular o `id` a partir do conteúdo. Um evento com conteúdo adulterado e `id`/`sig` originais
passaria nessa checagem. `NostrEventVerifier` recalcula o identificador canônico antes de verificar, e
há teste específico para esse caso.

## Processo de desenvolvimento

O desenvolvimento segue o [spec-kit](https://github.com/github/spec-kit): cada feature tem uma pasta
`specs/NNN-nome/` (spec, plan, research, data-model, tasks, quickstart) e a feature ativa está em
`.specify/feature.json`. A constituição do projeto (`.specify/memory/constitution.md`) é normativa:
a chave privada nunca vaza, código de assinatura e verificação nasce com teste, dependência nova exige
decisão registrada e o contrato do evento vem antes do código. Orientações para o Claude Code estão em
`CLAUDE.md`.

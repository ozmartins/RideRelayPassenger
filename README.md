# Caronas Passageiro

Aplicativo do **passageiro** do protótipo de caronas P2P sobre Nostr, do TCC
"Nostr para Mobilidade P2P: Avaliação de Viabilidade em Aplicativos de Caronas" (UFSC — Araranguá).

O aplicativo tem uma identidade Nostr própria, conecta-se simultaneamente a vários relays públicos,
publica e recebe eventos assinados e interopera com o aplicativo do motorista — **sem backend e sem
que as duas apps se conheçam**: toda a comunicação passa por relays Nostr. Os eventos desta etapa são
de teste; os formatos de domínio de caronas (oferta, solicitação, mensagem) são trabalho futuro.

| | |
|---|---|
| Nome de exibição | `Caronas Passageiro` |
| Identificador de aplicativo | `br.ufsc.tcc.caronas.passenger` |
| Plataforma | Android (iOS, web e desktop fora de escopo) |
| App irmã | `Caronas Motorista` — `br.ufsc.tcc.caronas.driver`, em `../driver` |

As duas apps usam o namespace comum `br.ufsc.tcc.caronas` com sufixos distintos, de modo que **podem
ser instaladas simultaneamente no mesmo aparelho** — é assim que a interoperabilidade é validada.

## O aplicativo

**O aplicativo exige acesso à internet.** Sem rede ele abre normalmente, explica a falta de conexão e
reconecta sozinho quando a rede volta.

A tela inicial é uma barra de navegação com duas abas, **Mapa** e **Início**:

| Tela | O que faz |
|---|---|
| **Mapa** | Mapa (mosaicos do OpenStreetMap) centrado na posição real do passageiro, com um indicador de posição atualizado continuamente, e um campo de texto para informar o destino ("Para onde você quer ir?"). O destino é texto livre, existe só em memória durante a sessão, e **nunca é publicado em relay** — o widget não tem nenhuma referência a `RelayService`/`EventFeed`. Pede a permissão de localização ao abrir, e mostra mensagem compreensível se ela for negada ou a localização ficar indisponível — sem travar o resto da tela. |
| **Início** | Resumo das conexões ("3 de 3 relays conectados"), eventos recebidos do mais novo para o mais antigo, e o botão **Publicar teste**, que informa relay a relay se a publicação foi aceita, recusada ou ficou sem resposta. Eventos próprios aparecem como "eu"; os de terceiros, com a chave pública truncada do autor. As ações da barra superior levam a **Meu nome** (nome/apelido de exibição, editável), **Identidade** (chave pública, legível e copiável — a chave privada **nunca** é exibida) e **Relays** (lista, acrescenta e remove relays, com validação de endereço e opção de restaurar a lista padrão quando vazia; a lista sobrevive ao fechamento do app). |

> **Desinstalar o aplicativo destrói a identidade.** A chave privada vive só no armazenamento
> protegido do aparelho (Android Keystore). Ao reinstalar, uma identidade nova é criada e a anterior
> não pode ser recuperada — os eventos publicados antes continuam na rede, atribuídos a uma chave que
> o aplicativo não tem mais.

## Pré-requisitos

- **Flutter 3.47.4** (canal stable) com **Dart 3.13.3** — versão usada na validação.
- Android SDK configurado e um emulador ou aparelho Android **com acesso à internet e localização
  simulável** (a tela de mapa pede a permissão de localização ao abrir).

Comece verificando o ambiente:

```bash
flutter --version
flutter doctor
```

Apenas o grupo **`[✓] Android toolchain`** precisa estar OK. Falhas nos grupos `Chrome` e
`Linux toolchain` são esperadas e **não** impedem o trabalho — web e desktop estão fora de escopo.

## Setup

```bash
cd Prototipo/passenger
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

## Medir o tempo de inicialização

```bash
flutter run --profile --trace-startup
cat build/start_up_info.json
```

`timeToFirstFrameMicros` deve ficar abaixo de 3 s. Medição de referência:
**74,5 ms** (74539 µs) no emulador `Pixel_6_API34_1` (Android 14, API 34, x86_64).

## Estrutura do projeto

```text
lib/
├── main.dart          # ponto de entrada: compõe as dependências reais e o widget raiz
├── domain/            # entidades com tipos próprios — nunca importam dart_nostr
│   ├── identity.dart              # par de chaves; toString nunca expõe a chave privada
│   ├── relay.dart                 # relay e seu estado de conexão
│   ├── nostr_event.dart           # evento recebido, já verificado
│   ├── passenger_position.dart    # posição atual do passageiro (só em memória)
│   └── destination_address.dart   # destino informado como texto livre (só em memória)
├── services/          # único lugar que importa bibliotecas de terceiros
│   ├── identity_service.dart          # cria/recupera a identidade no Keystore
│   ├── relay_service.dart             # conexões, estados, reconexão automática, inscrições
│   ├── event_feed.dart                # recepção, verificação, deduplicação, publicação
│   ├── event_verifier.dart            # verificação de assinatura (recalcula o id)
│   ├── relay_repository.dart          # persistência da lista de relays
│   ├── name_service.dart              # persistência do nome/apelido de exibição
│   ├── location_service.dart          # abstração de acesso à localização (injetável)
│   └── geolocator_location_service.dart  # implementação real sobre geolocator
├── screens/           # telas: mapa, principal, nome, identidade, relays
└── shared/            # identidade visual, lista padrão de relays, marcador do protótipo

test/                  # testes, com dublês em test/support/
tool/check_relays.dart # sonda de disponibilidade dos relays padrão
android/               # projeto Android gerado (applicationId br.ufsc.tcc.caronas.passenger)
```

Tipos de `dart_nostr` ficam confinados a `services/`: domínio e telas usam tipos próprios. Trocar de
biblioteca não deveria tocar na interface.

## Nota de arquitetura

O protótipo **não tem backend**. As apps do motorista e do passageiro não se conhecem e não trocam
pacotes diretamente: toda a comunicação acontece publicando e assinando eventos em relays Nostr.

A consequência prática é que **não existe lugar para lógica compartilhada**. Três coisas precisam ser
idênticas nas duas apps, e mudar uma de um lado sem o outro é defeito:

| O que | Onde, no passageiro |
|---|---|
| Contrato de eventos | documento de contrato de eventos, mantido igual nas duas apps |
| Lista padrão de relays | `lib/shared/default_relays.dart` |
| Marcador do protótipo `tcc-ufsc-caronas` | `lib/shared/prototype_marker.dart` |

### Por que o marcador existe

O evento de teste usava `kind: 1` (retirado do contrato de eventos), a nota de texto padrão do
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

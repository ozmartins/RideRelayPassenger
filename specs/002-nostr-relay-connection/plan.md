# Implementation Plan: Conexão do Passageiro com Relays Nostr

**Branch**: `master` (feature dir `002-nostr-relay-connection`) | **Date**: 2026-09-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/002-nostr-relay-connection/spec.md`

## Summary

Dar ao aplicativo do passageiro uma identidade Nostr persistente, conexão simultânea a múltiplos relays e
a capacidade de publicar e receber eventos assinados — e, com isso, fechar a prova de conceito do TCC:
demonstrar que **as duas apps do protótipo interoperam** através de relays públicos, sem backend e sem
se conhecerem.

A abordagem usa `dart_nostr ^10.0.1` (já instalada) para assinatura, serialização e conexões WebSocket;
`flutter_secure_storage` para a chave privada no Keystore; e `shared_preferences` para a lista de relays.
Todas as decisões técnicas são **herdadas** da feature equivalente do motorista, que é anterior — ver
`research.md`. A estrutura de `lib/` ganha `domain/` e `services/` ao lado de `screens/` e `shared/`.

## Technical Context

**Language/Version**: Dart 3.13.3 (Flutter 3.47.4, stable) — inalterado desde a feature 001

**Primary Dependencies**:
- `dart_nostr ^10.0.1` — protocolo Nostr (chaves, assinatura, eventos, relays) — **já instalada**
- `flutter_secure_storage` — chave privada no Android Keystore (a adicionar)
- `shared_preferences` — persistência da lista de relays (a adicionar)
- `flutter_test` + `flutter_lints` (dev, já presentes)

**Storage**: armazenamento local em dois níveis — Keystore (chave privada) e preferências (lista de
relays). Sem banco de dados; eventos recebidos ficam apenas em memória.

**Testing**: `flutter test` com testes de unidade dos serviços (identidade, relays, deduplicação,
verificação de assinatura) usando dublês; testes de widget das telas; `flutter analyze` como gate.
Nenhum teste contata relay real (Princípio II, decisão D5).

**Target Platform**: Android apenas. `android.permission.INTERNET` passa a ser obrigatória no manifesto
**principal**, não só em debug (FR-016, D6).

**Project Type**: mobile-app

**Performance Goals**: primeiro relay conectado em ≤ 5 s (SC-001); ida e volta do próprio evento em ≤ 5 s
(SC-002); evento do motorista recebido em ≤ 10 s (SC-009); UI responsiva sob rajada de ≥ 100 eventos
(SC-006)

**Constraints**: sem backend; chave privada nunca sai do aparelho, não vai a log nem a tela
(FR-005/SC-007); falha de um relay não derruba os demais (FR-003); reconexão automática após queda de
rede (FR-014); o contrato de eventos não pode divergir do da app do motorista (FR-019)

**Scale/Scope**: 3 telas (eventos, relays, identidade), 3 serviços, 3 entidades de domínio

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Estado da constituição**: ratificada, **versão 1.0.0** (2026-09-15). Diferentemente da feature 001,
este gate é avaliado de verdade, princípio a princípio.

| Princípio | Avaliação | Evidência no design |
|---|---|---|
| I. Segredo criptográfico não vaza (NÃO NEGOCIÁVEL) | **PASS** | Chave privada só no Keystore (D2); FR-005 proíbe tela/log/relay; SC-007 é verificação explícita de não vazamento entre os critérios de aceitação, como o princípio exige; `data-model.md` marca o campo como nunca exibível |
| II. Assinatura e verificação nascem com teste (NÃO NEGOCIÁVEL) | **PASS** | D5 fixa dublês em memória e proíbe relay real nos testes; a estrutura `services/` existe justamente para tornar assinatura, verificação e descarte testáveis sem árvore de widgets; tarefas de teste para caso válido **e** inválido são obrigatórias (nota propagada ao `tasks-template.md`) |
| III. Dependência de terceiros exige decisão registrada | **PASS** | D1 traz 4 alternativas com versão e data de publicação, critérios, riscos e mitigação, regularizando a pendência aberta pela constituição; `flutter_secure_storage` e `shared_preferences` justificadas em D2/D3; tipos de terceiros confinados a `services/` |
| IV. O contrato de evento vem antes do código | **PASS** | `contracts/nostr-events.md` existe antes de qualquer código e é cópia verificada do contrato do motorista (FR-019); FR-009, FR-010 e FR-018 replicam as regras de recepção do contrato |
| V. Simplicidade proporcional e rastreabilidade | **PASS** | D8 acrescenta apenas `domain/` e `services/`, ambos com consumidor real, e rejeita `repositories/`/`usecases/`; D9 declara que SC-009 é medição manual e MUST ser relatada com o método — inclusive se falhar |

**Restrições de Segurança e Privacidade**: PASS. A permissão `INTERNET` só é declarada agora, quando
existe funcionalidade que a exige (D6) — a regra de "nada de permissão para o futuro" foi justamente o
motivo de não declará-la na feature 001. Nenhuma permissão de localização, contatos, câmera ou
armazenamento externo é solicitada. Os eventos desta etapa são públicos e sem dado pessoal: o conteúdo
é texto de teste, e a chave pública é, por desenho do protocolo, um identificador público.

**Nenhuma violação a justificar**: a seção Complexity Tracking permanece vazia.

## Project Structure

### Documentation (this feature)

```text
specs/002-nostr-relay-connection/
├── plan.md              # Este arquivo
├── research.md          # Fase 0 — decisões herdadas + próprias; D1 atende FR-017
├── data-model.md        # Fase 1
├── quickstart.md        # Fase 1
├── contracts/
│   └── nostr-events.md  # Cópia congelada do contrato do motorista (FR-019)
├── checklists/
│   └── requirements.md
└── tasks.md             # Fase 2 (/speckit-tasks)
```

Diferentemente da feature 001, **há `contracts/`**: os eventos publicados são a interface externa do
aplicativo, e é por eles que a app do motorista interopera.

### Source Code (repository root)

```text
Prototipo/passenger/
├── lib/
│   ├── main.dart                      # entrypoint + composição das dependências
│   ├── domain/                        # NOVO
│   │   ├── identity.dart              # identidade do passageiro
│   │   ├── relay.dart                 # relay + estado de conexão
│   │   └── nostr_event.dart           # evento (id, autor, horário, kind, conteúdo)
│   ├── services/                      # NOVO — único lugar que importa dart_nostr
│   │   ├── identity_service.dart      # cria/recupera identidade no armazenamento seguro
│   │   ├── relay_service.dart         # conexões, estados, reconexão, publicação
│   │   └── event_feed.dart            # assinatura, verificação e deduplicação por id
│   ├── screens/                       # já existe (feature 001)
│   │   ├── home_screen.dart           # eventos recebidos + publicar evento de teste
│   │   ├── relays_screen.dart         # listar/adicionar/remover relays
│   │   └── identity_screen.dart       # exibir chave pública
│   └── shared/                        # já existe — identidade visual do app
│       └── app_info.dart
├── test/
│   ├── identity_service_test.dart
│   ├── relay_service_test.dart
│   ├── event_feed_test.dart
│   └── screens/…_test.dart
└── android/app/src/main/AndroidManifest.xml   # + android.permission.INTERNET
```

**Structure Decision**: acrescentar `domain/` e `services/` ao que a feature 001 criou, sem reorganizar
(D8). A justificativa é concreta: o Princípio III exige que tipos de `dart_nostr` fiquem confinados aos
serviços, e o Princípio II exige que assinatura, verificação e deduplicação sejam testáveis sem árvore
de widgets — manter essa lógica dentro dos widgets tornaria SC-002, SC-003 e SC-006 verificáveis apenas
manualmente. Nenhuma camada adicional é introduzida.

**Relação com a app do motorista**: ela parte de `main.dart` plano e chega a `domain/ + services/ +
screens/`; esta parte de `main.dart + screens/ + shared/` e chega ao mesmo lugar, mantendo `shared/`. O
que **precisa** ser idêntico entre as duas apps não é o layout de pastas, e sim o contrato de eventos.

## Complexity Tracking

> Nenhuma violação de constituição a justificar (ver Constitution Check).

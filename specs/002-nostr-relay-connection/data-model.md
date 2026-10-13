# Phase 1 — Data Model: Conexão do Passageiro com Relays Nostr

Esta feature introduz as primeiras entidades de domínio do aplicativo do passageiro. Todas vivem em
`lib/domain/` com **tipos próprios**, sem expor tipos de `dart_nostr` à UI — exigência do Princípio III
da constituição e mitigação do risco de acoplamento registrado em D1.

As entidades são equivalentes às da app do motorista, por simetria deliberada (ver `research.md`).

## Identidade do passageiro (`Identity`)

| Campo | Tipo | Regras |
|-------|------|--------|
| `publicKey` | `String` (hex, 64 caracteres) | Derivada da chave privada; exibida ao usuário; identifica o passageiro na rede |
| `privateKey` | `String` (hex, 64 caracteres) | **Nunca** exibida por padrão, registrada em log ou enviada a relay (FR-005/SC-007, Princípio I); vive apenas em memória e no armazenamento seguro |

- **Identidade e unicidade**: a chave pública é o identificador do passageiro na rede. Uma única
  identidade por instalação.
- **Ciclo de vida**: criada na primeira execução → persistida no armazenamento seguro → recuperada nas
  execuções seguintes → destruída apenas com a desinstalação do aplicativo (FR-004, US2 cenário 4).
- **Validação**: ambas as chaves devem ter 64 caracteres hexadecimais; chave recuperada fora desse
  formato é tratada como armazenamento corrompido, não como identidade válida.
- **Isolamento entre as apps**: a identidade do passageiro é independente da do motorista, mesmo no
  mesmo aparelho — o armazenamento seguro é particionado por `applicationId` (US2 cenário 5, SC-010).

## Relay (`Relay`)

| Campo | Tipo | Regras |
|-------|------|--------|
| `url` | `String` | Endereço `wss://` ou `ws://`; único na lista (FR-011); é a chave da entidade |
| `status` | `RelayStatus` | `connecting` \| `connected` \| `unavailable` |
| `lastError` | `String?` | Motivo resumido quando `unavailable`, para exibição (US1 cenário 2) |
| `isDefault` | `bool` | Distingue relay da lista padrão de relay adicionado pelo passageiro |

**Transições de estado**:

```text
                  falha / timeout
        ┌──────────────────────────────┐
        ▼                              │
  [unavailable] ──── retentativa ──> [connecting] ──── handshake ok ──> [connected]
        ▲                                                                   │
        └───────────────── queda de conexão / perda de rede ────────────────┘
```

- Entrada: todo relay adicionado ou carregado da lista entra em `connecting`.
- `unavailable` não remove o relay da lista: ele permanece visível com o motivo (FR-002/FR-003).
- Retorno de rede dispara nova tentativa automática para todos em `unavailable` (FR-014).
- Remoção pelo passageiro encerra a conexão e retira a entidade da lista (FR-011).

## Evento (`NostrEvent`)

| Campo | Tipo | Regras |
|-------|------|--------|
| `id` | `String` (hex) | Hash canônico definido pelo protocolo; **chave de deduplicação** (FR-010, D4) |
| `authorPublicKey` | `String` (hex, 64) | Autor do evento; é o que distingue evento do motorista de evento próprio (FR-020) |
| `createdAt` | `DateTime` | Horário declarado pelo autor — dado de terceiro, não confiável para ordenação absoluta |
| `kind` | `int` | Tipo do evento conforme o contrato; kinds desconhecidos são ignorados sem erro (FR-018) |
| `content` | `String` | Conteúdo textual; público nesta etapa (sem criptografia entre pares) |
| `isSignatureValid` | `bool` | Resultado da verificação; eventos inválidos são **descartados**, não exibidos (FR-009) |

- **Origem**: eventos são recebidos de relays (dados de terceiros) ou criados localmente para publicação.
- **Regra de confiança**: nenhum campo de evento recebido é tratado como confiável antes da verificação
  de assinatura. Conteúdo recebido é **dado**, nunca instrução ou marcação renderizável (FR-018,
  Princípio IV).
- **Autoria**: eventos cujo `authorPublicKey` é igual à chave pública local são do próprio passageiro;
  os demais vêm de terceiros — inclusive do motorista, o que sustenta a User Story 4.
- **Retenção**: apenas em memória, durante a sessão. Não há persistência de eventos nesta feature.
- **Limite**: o conjunto exibido é limitado (janela das entradas mais recentes) para sustentar SC-006 sob
  rajada de eventos.

## Relações

```text
Identity (1) ──assina──> NostrEvent (N) ──trafega por──> Relay (N)
```

- Uma identidade assina muitos eventos.
- Um evento pode chegar por vários relays; a deduplicação por `id` garante exibição única.
- Relays são independentes entre si: o estado de um não afeta o de outro (FR-003).
- Um relay em comum entre as duas apps é o que torna a User Story 4 possível — não há canal direto.

## Persistência

| Dado | Onde | Justificativa |
|------|------|---------------|
| Chave privada e pública | Armazenamento seguro (Keystore) | Material criptográfico (D2, Princípio I) |
| Lista de relays (`url` + `isDefault`) | Preferências locais, como JSON | Dado público e de baixo volume (D3) |
| `status` / `lastError` dos relays | Apenas memória | Estado de runtime; não faz sentido restaurar "conectado" de sessão anterior |
| Eventos | Apenas memória | Escopo da feature (sem histórico offline) |

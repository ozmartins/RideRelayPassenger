# Contrato interno UI ↔ serviço (não é contrato Nostr)

Mensagens `Map<String, dynamic>` com `t` (tipo) e `v: 1`. Só primitivos. **Nenhuma carrega chave privada, semente
ou texto decifrado** (Princípio I). Mudar o formato = mudar os dois lados desta app na mesma alteração. Não afeta
o motorista nem `nostr-events.md`.

| `t` | Direção | Campos | Efeito |
|---|---|---|---|
| `ready` | S→UI | — | isolate de pé; até receber, a UI enfileira comandos |
| `hello` | UI→S | `foreground: bool` | handshake ao abrir/voltar |
| `helloAck` | S→UI | `relays: [{url,status,error?,isDefault}]`, `pending: [{relayUrl,payload}]` | estado + mensagens retidas (≤ 5 min), reentregues também como `message` |
| `state` | UI→S | `ServiceState` (ver data-model) | atualiza regra e ciclo de vida |
| `start` | UI→S | `relays: [...]` | substitui a lista e conecta (quando o serviço acabou de nascer) |
| `addRelay` / `removeRelay` | UI→S | `url` / `url` | idem `RelayService` |
| `retryUnavailable` | UI→S | — | idem `RelayService.retryUnavailable` |
| `subscribe` | UI→S | `subscriptionId`, `request` | registra e reenvia a toda conexão |
| `broadcast` | UI→S | `message` (texto do `EVENT`, já assinado/cifrado) | envia aos relays conectados |
| `relaysChanged` | S→UI | `relays: [...]` | espelho da lista (base de `connectedUrls`) |
| `message` | S→UI | `relayUrl`, `payload` (texto cru) | mensagem do relay; EVENT só após assinatura, marcador e dedupe |
| `stop` | UI→S | — | encerra |

**Regras**: (0) no `onStart` o serviço lê a lista de relays do `RelayRepository` e conecta sozinho; (1) assinatura
(id recalculado), marcador e dedupe antes de repassar ou decidir notificar; (2) `OK`, `EOSE`, `NOTICE` só são
repassados com a UI à vista; (3) versão `v` diferente ou tipo desconhecido é ignorado; (4) `pending` só contém
mensagens aprovadas por `BackgroundNotificationRule`; (5) `broadcast` sem relay conectado não é enviado — a UI já
recusa antes, com o espelho vazio.

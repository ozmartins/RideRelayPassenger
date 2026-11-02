/// Um evento Nostr, conforme o envelope descrito em
/// `specs/002-nostr-relay-connection/contracts/nostr-events.md`.
///
/// Tipo próprio do projeto: a camada de domínio não expõe tipos da biblioteca
/// `dart_nostr` (Princípio III da constituição), para que trocar de biblioteca
/// não contamine telas nem testes.
///
/// **Todo evento recebido é dado de terceiro não confiável** até que
/// [isSignatureValid] seja verdadeiro. O [content] é sempre tratado como texto
/// simples, nunca como marcação ou instrução.
class NostrEvent {
  const NostrEvent({
    required this.id,
    required this.authorPublicKey,
    required this.createdAt,
    required this.kind,
    required this.content,
    required this.isSignatureValid,
    this.tags = const [],
  });

  /// Hash canônico definido pelo protocolo. É a **chave de deduplicação**
  /// quando o mesmo evento chega por mais de um relay (FR-010).
  final String id;

  /// Chave pública de quem assinou o evento.
  final String authorPublicKey;

  /// Horário **declarado pelo autor**. Dado de terceiro: não serve como
  /// ordenação confiável nem para qualquer decisão de segurança.
  final DateTime createdAt;

  /// Tipo do evento conforme a tabela de kinds do contrato.
  final int kind;

  /// Conteúdo textual. Público nesta etapa — sem criptografia entre pares.
  final String content;

  /// Resultado da verificação de assinatura. Evento com `false` MUST ser
  /// descartado, nunca exibido (FR-009).
  final bool isSignatureValid;

  /// Tags do evento, conforme o protocolo (feature 008 — necessário para
  /// extrair referências `["e", ...]`/`["p", ...]` a outros eventos).
  final List<List<String>> tags;

  /// O valor da primeira tag `["e", "<valor>"]`, ou `null` se ausente —
  /// referência a outro evento (ex.: a solicitação respondida por um
  /// orçamento).
  String? get referencedEventId => _firstTagValue('e');

  /// O valor da primeira tag `["p", "<valor>"]`, ou `null` se ausente — o
  /// destinatário do evento (emenda 17: é com a chave dele que o `content` foi
  /// cifrado, e só ele o decifra).
  String? get recipientPublicKey => _firstTagValue('p');

  /// Cópia deste evento com [novoContent] no lugar do `content` — usada para
  /// entregar às entidades de domínio o texto já decifrado, sem tocar o
  /// restante (id, autor, tags).
  NostrEvent withContent(String novoContent) => NostrEvent(
    id: id,
    authorPublicKey: authorPublicKey,
    createdAt: createdAt,
    kind: kind,
    content: novoContent,
    isSignatureValid: isSignatureValid,
    tags: tags,
  );

  String? _firstTagValue(String key) {
    for (final tag in tags) {
      if (tag.length >= 2 && tag[0] == key) return tag[1];
    }
    return null;
  }

  /// Verdadeiro quando o evento foi assinado pela identidade local, e não por
  /// um terceiro. É o que distingue evento próprio de evento do motorista
  /// (FR-020).
  bool isAuthoredBy(String publicKey) => authorPublicKey == publicKey;

  @override
  String toString() =>
      'NostrEvent(${id.substring(0, 8)}…, kind: $kind, autor: ${authorPublicKey.substring(0, 8)}…)';

  @override
  bool operator ==(Object other) => other is NostrEvent && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

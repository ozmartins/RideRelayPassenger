import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart' as nostr;
import 'package:passenger/shared/prototype_marker.dart';

/// Gera um par de chaves descartável para os testes.
nostr.NostrKeyPairs novoPar() =>
    nostr.Nostr.instance.services.keys.generateKeyPair();

/// Constrói o payload JSON de um evento assinado, como ele chega de um relay.
///
/// Usa assinatura real: o teste de verificação só tem valor se exercitar a
/// criptografia de verdade. Nada disso toca rede.
Map<String, dynamic> eventoAssinado({
  required nostr.NostrKeyPairs autor,
  String content = 'evento de teste',
  int kind = 20002,
  bool comMarcador = true,
  List<List<String>>? tags,
  DateTime? createdAt,
}) {
  final evento = nostr.NostrEvent.fromPartialData(
    kind: kind,
    content: content,
    keyPairs: autor,
    tags: tags ?? (comMarcador ? [prototypeMarkerTag] : const <List<String>>[]),
    createdAt: createdAt,
  );
  return {
    'id': evento.id,
    'pubkey': evento.pubkey,
    'created_at': evento.createdAt!.millisecondsSinceEpoch ~/ 1000,
    'kind': evento.kind,
    'tags': evento.tags ?? const <List<String>>[],
    'content': evento.content,
    'sig': evento.sig,
  };
}

/// Empacota um payload como a mensagem `EVENT` que um relay envia.
String mensagemEvent(Map<String, dynamic> payload, {String sub = 'feed'}) =>
    jsonEncode(['EVENT', sub, payload]);

// Publica numa corrida de teste uma mensagem "do motorista" ao passageiro, para
// validar a notificação em segundo plano (feature 026, quickstart).
//
// ignore_for_file: avoid_print — script de linha de comando, stdout é a sua
// interface (mesma supressão pontual de tool/check_relays.dart).
//
// NÃO é teste automatizado: contata relays reais de propósito (Princípio II).
//
//   dart run tool/publish_test_message.dart <kind> <pubkey-do-passageiro> <tag-e> [repetições] [intervalo-ms]
//
// O `content` NÃO é cifrado de verdade: o serviço em segundo plano nunca o lê
// (decide só por kind, autor e tags), então basta um texto qualquer para provar
// a notificação. A interface, ao abrir, descartará o evento por não decifrar —
// o comportamento esperado da regra de recepção 7. O autor é uma identidade
// descartável; para o `kind` de corrida aceita, informe a mesma via `AUTOR_PRIV`.
import 'dart:async';
import 'dart:io';

import 'package:dart_nostr/dart_nostr.dart';

const relaysPadrao = [
  'wss://nos.lol',
  'wss://relay.primal.net',
  'wss://offchain.pub',
];

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    print('uso: dart run tool/publish_test_message.dart <kind> <pubkey> <tag-e> [repetições] [intervalo-ms]');
    exit(64);
  }
  final kind = int.parse(args[0]);
  final passageiro = args[1];
  final referencia = args[2];
  final repeticoes = args.length > 3 ? int.parse(args[3]) : 1;
  final intervalo = Duration(milliseconds: args.length > 4 ? int.parse(args[4]) : 5000);

  final privada = Platform.environment['AUTOR_PRIV'];
  final autor = privada == null
      ? Nostr.instance.services.keys.generateKeyPair()
      : Nostr.instance.services.keys.generateKeyPairFromExistingPrivateKey(privada);
  print('autor: ${autor.public}');

  final conexoes = <WebSocket>[];
  for (final url in relaysPadrao) {
    try {
      final c = await WebSocket.connect(url).timeout(const Duration(seconds: 10));
      c.listen((m) => print('  $url -> $m'));
      conexoes.add(c);
    } catch (e) {
      print('✗ $url não conectou');
    }
  }

  for (var i = 0; i < repeticoes; i++) {
    final evento = NostrEvent.fromPartialData(
      kind: kind,
      content: 'mensagem de teste $i ${DateTime.now().microsecondsSinceEpoch}',
      keyPairs: autor,
      tags: [
        ['t', 'tcc-ufsc-caronas'],
        ['p', passageiro],
        ['e', referencia],
      ],
    );
    for (final c in conexoes) {
      c.add(evento.serialized());
    }
    print('${DateTime.now().toIso8601String()} publicado kind $kind id ${evento.id}');
    if (i < repeticoes - 1) await Future<void>.delayed(intervalo);
  }
  await Future<void>.delayed(const Duration(seconds: 2));
  for (final c in conexoes) {
    await c.close();
  }
}

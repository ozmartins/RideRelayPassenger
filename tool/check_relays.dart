// Verificação de disponibilidade dos relays padrão do protótipo.
//
// ignore_for_file: avoid_print — este arquivo é um script de linha de comando,
// não código de produção: stdout é a sua interface. A supressão é pontual e
// restrita a este arquivo, como manda a constituição, em vez de desativar a
// regra no analysis_options.yaml.
//
// NÃO é teste automatizado: contata relays reais de propósito, o que o
// Princípio II da constituição proíbe dentro de `test/`. Rode à mão quando
// suspeitar que um relay saiu do ar — a lista padrão é volátil por natureza
// (decisão D7 de specs/002-nostr-relay-connection/research.md).
//
//   dart run tool/check_relays.dart
//
// Para cada relay, publica um evento assinado por uma identidade descartável e
// tenta recuperá-lo por uma conexão separada — a mesma mecânica da User Story 4
// (motorista publica, passageiro recebe).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dart_nostr/dart_nostr.dart';

/// Espelha `defaultRelays` de `lib/shared/default_relays.dart` e a lista
/// padrão da app do motorista. Os três MUST permanecer iguais.
const relaysPadrao = [
  'wss://nos.lol',
  'wss://relay.primal.net',
  'wss://offchain.pub',
];

Future<void> main() async {
  final autor = Nostr.instance.services.keys.generateKeyPair();
  final evento = NostrEvent.fromPartialData(
    kind: 1,
    content: 'Sonda de disponibilidade — TCC UFSC ${DateTime.now().toIso8601String()}',
    keyPairs: autor,
  );

  var falhas = 0;
  for (final url in relaysPadrao) {
    try {
      final relogio = Stopwatch()..start();

      final pub = await WebSocket.connect(url).timeout(const Duration(seconds: 10));
      final aceito = Completer<void>();
      final sPub = pub.listen((m) {
        final d = jsonDecode(m as String) as List;
        if (d.isNotEmpty && d[0] == 'OK' && !aceito.isCompleted) aceito.complete();
      });
      pub.add(evento.serialized());
      await aceito.future.timeout(const Duration(seconds: 15));
      await sPub.cancel();
      await pub.close();

      final sub = await WebSocket.connect(url).timeout(const Duration(seconds: 10));
      final volta = Completer<Map<String, dynamic>>();
      final sSub = sub.listen((m) {
        final d = jsonDecode(m as String) as List;
        if (d.isNotEmpty && d[0] == 'EVENT' && !volta.isCompleted) {
          volta.complete(d[2] as Map<String, dynamic>);
        }
      });
      sub.add(jsonEncode([
        'REQ',
        'sonda',
        {'authors': [autor.public], 'kinds': [1], 'limit': 5},
      ]));
      final recebido = await volta.future.timeout(const Duration(seconds: 15));
      await sSub.cancel();
      await sub.close();

      if (recebido['id'] != evento.id) {
        falhas++;
        print('✗ $url  evento recuperado não confere com o publicado');
      } else {
        print('✓ $url  ida e volta em ${relogio.elapsedMilliseconds}ms');
      }
    } catch (e) {
      falhas++;
      final msg = e.toString().split('\n').first;
      print('✗ $url  ${msg.length > 80 ? msg.substring(0, 80) : msg}');
    }
  }

  print(falhas == 0
      ? '\nTodos os relays padrão estão operantes.'
      : '\n$falhas de ${relaysPadrao.length} relays padrão com problema — reavaliar a decisão D7.');
}

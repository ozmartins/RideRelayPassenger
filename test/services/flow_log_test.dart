import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:passenger/services/flow_log.dart';
import 'package:passenger/services/flow_log_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:passenger/domain/address_suggestion.dart';
import 'package:passenger/domain/route_result.dart';
import 'package:passenger/services/geocoding_service.dart';
import 'package:passenger/services/route_service.dart';
import 'package:passenger/domain/identity.dart';
import 'package:passenger/domain/received_quote.dart';
import 'package:passenger/domain/relay.dart';
import 'package:passenger/services/event_feed.dart';
import 'package:passenger/services/relay_service.dart';

import '../support/event_fixtures.dart';
import '../support/fake_relay_transport.dart';
import '../support/memory_flow_log.dart';

void main() {
  final id = 'a' * 64;

  group('FlowLine', () {
    test('aceita só os campos do contrato, na forma esperada', () {
      final l = FlowLine.build(
        t: 5,
        papel: 'passageiro',
        exec: 'e1',
        iso: 'ui',
        comp: 'relay',
        op: 'evento.publicou',
        res: 'ok',
        kind: 20001,
        id: id,
        relay: 'wss://relay.damus.io',
        guid: id,
        motivo: 'raio',
        ext: 'ors',
        n: 3,
      );
      expect(l['id'], id);
      expect(l['relay'], 'wss://relay.damus.io');
      expect(l['ext'], 'ors');
      expect(l['kind'], 20001);
    });

    test(
      'omite valores plantados fora do formato (chave, texto, URL com segredo)',
      () {
        const chavePrivada =
            'nsec1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq';
        final l = FlowLine.build(
          t: 5,
          papel: 'passageiro',
          exec: 'e1',
          iso: 'ui',
          comp: 'relay',
          op: 'evento.publicou',
          res: 'ok',
          id: 'Rua das Flores, 123',
          relay: 'wss://user:senha@relay.exemplo.com/?key=SEGREDO',
          guid: chavePrivada,
          motivo: '-27.59,-48.54 raio 12',
          ext: 'chave-ors-123',
        );
        final texto = jsonEncode(l);
        for (final proibido in [
          chavePrivada,
          'Rua das Flores',
          'senha',
          'SEGREDO',
          '-27.59',
          'chave-ors',
        ]) {
          expect(texto, isNot(contains(proibido)));
        }
        expect(l.containsKey('id'), isFalse);
        expect(l.containsKey('relay'), isFalse);
        expect(l.containsKey('motivo'), isFalse);
      },
    );

    test('nome inválido de op vira "invalido" sem vazar o valor', () {
      final l = FlowLine.build(
        t: 1,
        papel: 'passageiro',
        exec: 'e',
        iso: 'ui',
        comp: 'x',
        op: 'conteúdo secreto',
        res: 'ok',
      );
      expect(l['op'], 'invalido');
    });
  });

  group('texto livre e coordenadas (erro, endereco, lat/lon)', () {
    Map<String, Object?> linha({
      String? erro,
      String? endereco,
      double? lat,
      double? lon,
    }) => FlowLine.build(
      t: 1,
      papel: 'x',
      exec: 'e',
      iso: 'ui',
      comp: 'externo',
      op: 'externo.falha',
      res: 'falha',
      erro: erro,
      endereco: endereco,
      lat: lat,
      lon: lon,
    );

    test('grava erro, endereço e coordenadas como vieram', () {
      final l = linha(
        erro: 'ClientException: HTTP 429 em photon.komoot.io',
        endereco: 'Rua das Flores, 123',
        lat: -27.59,
        lon: -48.54,
      );
      expect(l['erro'], 'ClientException: HTTP 429 em photon.komoot.io');
      expect(l['endereco'], 'Rua das Flores, 123');
      expect(l['lat'], -27.59);
      expect(l['lon'], -48.54);
    });

    test('oculta chave privada, credenciais e a chave da ORS no texto', () {
      FlowLine.segredos.add('ors-chave-super-secreta');
      addTearDown(FlowLine.segredos.clear);
      final privada = 'ab' * 32;
      final l = linha(
        erro:
            'falha em https://x/?api_key=ors-chave-super-secreta '
            'Authorization: Bearer abc $privada nsec1qqqqqqqq',
      );
      final texto = l['erro'] as String;
      expect(texto, isNot(contains('ors-chave-super-secreta')));
      expect(texto, isNot(contains('Bearer abc')));
      expect(texto, isNot(contains(privada)));
      expect(texto, isNot(contains('nsec1qqqq')));
      expect(texto, contains('[oculto]'));
    });

    test(
      'limita o texto, tira quebras de linha e ignora coordenada inválida',
      () {
        final l = linha(erro: 'a\nb' * 200, lat: 95, lon: 10);
        expect((l['erro'] as String).contains('\n'), isFalse);
        expect((l['erro'] as String).length, lessThanOrEqualTo(301));
        expect(l.containsKey('lat'), isFalse);
        expect(l.containsKey('lon'), isFalse);
      },
    );
  });

  group('EventFeed com log', () {
    late FakeTransport transport;
    late RelayService relays;
    late EventFeed feed;
    late MemoryFlowLog log;

    setUp(() async {
      log = MemoryFlowLog();
      transport = FakeTransport({});
      relays = RelayService(
        transport: transport,
        connectTimeout: const Duration(milliseconds: 50),
        livenessTimeout: const Duration(milliseconds: 50),
        log: log,
      );
      feed = EventFeed(
        relayService: relays,
        publishTimeout: const Duration(milliseconds: 100),
        log: log,
      );
      await relays.start([const Relay(url: 'wss://a.test')]);
      feed.start();
    });

    tearDown(() async {
      feed.dispose();
      await relays.dispose();
    });

    test('registra recebido e descartes sem jamais gravar o content', () async {
      const segredo = 'SEGREDO-NO-CONTENT-Rua-X';
      final autor = novoPar();
      final bom = eventoAssinado(autor: autor, content: segredo);
      final adulterado = {...eventoAssinado(autor: autor), 'content': 'x'};
      final semMarcador = eventoAssinado(
        autor: autor,
        content: segredo,
        comMarcador: false,
      );
      void entregar(Map<String, dynamic> p) =>
          transport.conexoes['wss://a.test']!.emitir(mensagemEvent(p));

      entregar(bom);
      entregar(bom);
      entregar(adulterado);
      entregar(semMarcador);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final eventos = log.linhas.where(
        (l) => (l['op'] as String).startsWith('evento.'),
      );
      expect(
        [for (final l in eventos) l['op']],
        [
          'evento.recebeu',
          'evento.descartou',
          'evento.descartou',
          'evento.descartou',
        ],
      );
      expect(
        [for (final l in eventos) l['motivo']],
        [null, 'duplicado', 'assinatura', 'marcador'],
      );
      expect(eventos.first['id'], bom['id']);
      expect(eventos.first['relay'], 'wss://a.test');
      expect(log.texto, isNot(contains(segredo)));
      expect(log.ops, contains('relay.conectou'));
    });

    test(
      'registra a publicação e o resultado por relay, sem o content',
      () async {
        final par = novoPar();
        await feed.publishQuoteAcceptance(
          ReceivedQuote(
            quoteId: 'b' * 64,
            requestId: 'c' * 64,
            driverPubkey: novoPar().public,
            driverName: 'Fulano da Silva',
            carBrand: 'Fiat',
            carModel: 'Palio',
            carYear: 2018,
            pricePerKm: 2.5,
            total: 25.0,
            etaMinutes: 6,
          ),
          Identity(publicKey: par.public, privateKey: par.private),
        );
        expect(log.ops, containsAllInOrder(['evento.publicou', 'relay.ok']));
        final pub = log.linhas.firstWhere((l) => l['op'] == 'evento.publicou');
        expect(pub['kind'], 20003);
        expect(log.texto, isNot(contains(par.private)));
      },
    );
  });

  group('FileFlowLog', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('flowlog'));
    tearDown(() => dir.deleteSync(recursive: true));

    test(
      'grava JSON Lines, inclusive o que veio antes de o diretório abrir',
      () async {
        final log = FileFlowLog(
          papel: 'passageiro',
          iso: 'servico',
          exec: 'e1',
          diretorio: () async => dir.path,
          now: () => DateTime.utc(2026, 11, 3),
        );
        log.registrar(comp: 'app', op: 'app.inicio');
        await log.gravado;
        log.registrar(comp: 'relay', op: 'relay.conectou', res: FlowLog.ok);

        final linhas = File('${dir.path}/fluxo-servico.jsonl')
            .readAsLinesSync();
        expect(linhas, hasLength(2));
        final primeira = jsonDecode(linhas.first) as Map<String, dynamic>;
        expect(primeira['op'], 'app.inicio');
        expect(primeira['exec'], 'e1');
        expect(primeira['iso'], 'servico');
        expect(primeira['t'], DateTime.utc(2026, 11, 3).millisecondsSinceEpoch);
      },
    );

    test('rotaciona ao passar do teto e registra a rotação', () async {
      final log = FileFlowLog(
        papel: 'passageiro',
        iso: 'ui',
        diretorio: () async => dir.path,
        maxBytes: 300,
      );
      await log.gravado;
      for (var i = 0; i < 20; i++) {
        log.registrar(comp: 'relay', op: 'relay.conectou');
      }
      expect(File('${dir.path}/fluxo-ui.jsonl.1').existsSync(), isTrue);
      final atual = File('${dir.path}/fluxo-ui.jsonl').readAsLinesSync();
      expect(
        atual.any((l) => (jsonDecode(l) as Map)['op'] == 'log.rotacao'),
        isTrue,
      );
    });

    test('falha de diretório não lança nem afeta o chamador', () async {
      final log = FileFlowLog(
        papel: 'passageiro',
        iso: 'ui',
        diretorio: () async => throw StateError('sem disco'),
      );
      log.registrar(comp: 'app', op: 'app.inicio');
      await log.gravado;
      log.registrar(comp: 'app', op: 'app.inicio');
    });
  });

  group('falha de serviço externo', () {
    test('motivoExterno classifica sem copiar o texto do erro', () {
      expect(motivoExterno(Exception('HTTP 429 Too Many Requests')), 'http429');
      expect(motivoExterno(TimeoutException('x')), 'timeout');
      expect(motivoExterno(Exception('Rua das Flores 123')), 'erro');
    });

    test('busca com sucesso também é registrada, com a contagem', () async {
      final log = MemoryFlowLog();
      final r = await LoggingGeocodingService(_FotonOk(), log).search('Rua X');
      expect(r, isEmpty);
      expect(log.ops, ['externo.chamada']);
      expect(log.linhas.single['res'], 'ok');
      expect(log.linhas.single['endereco'], 'Rua X');
      expect(log.linhas.single['n'], 0);
    });

    test('registra externo.falha com o texto do erro, o endereço e as coordenadas, e relança', () async {
      final log = MemoryFlowLog();
      final rota = LoggingRouteService(_RotaQueFalha(), log);
      await expectLater(
        rota.route(
          origin: const LatLng(-27.5, -48.5),
          destination: const LatLng(-27.6, -48.6),
        ),
        throwsA(isA<RouteFailure>()),
      );
      final foto = LoggingGeocodingService(_FotonQueFalha(), log);
      await expectLater(
        foto.search('Rua das Flores 123'),
        throwsA(isA<GeocodingFailure>()),
      );
      expect(log.ops, [
        'externo.chamada',
        'externo.falha',
        'externo.chamada',
        'externo.falha',
      ]);
      expect(
        [for (final l in log.linhas) l['ext']],
        ['ors', 'ors', 'photon', 'photon'],
      );
      expect(log.linhas.first['ms'], isA<int>());
      expect(log.linhas.first['motivo'], 'http429');
      expect(log.linhas.first['erro'], contains('HTTP 429'));
      expect(log.linhas.first['lat'], -27.5);
      expect(log.linhas.first['lon2'], -48.6);
      expect(log.linhas.last['endereco'], 'Rua das Flores 123');
      expect(log.linhas.last['erro'], contains('timeout'));
    });
  });
}

class _RotaQueFalha implements RouteService {
  @override
  Future<RouteResult> route({
    required LatLng origin,
    required LatLng destination,
  }) async => throw const RouteFailure('HTTP 429');
}

class _FotonQueFalha implements GeocodingService {
  @override
  Future<List<AddressSuggestion>> search(String text) async =>
      throw const GeocodingFailure('timeout');
}

class _FotonOk implements GeocodingService {
  @override
  Future<List<AddressSuggestion>> search(String text) async => [];
}

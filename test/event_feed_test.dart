import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart' as nostr;
import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/destination_address.dart';
import 'package:passenger/domain/identity.dart';
import 'package:passenger/domain/nostr_event.dart';
import 'package:passenger/domain/passenger_position.dart';
import 'package:passenger/domain/payment_method.dart';
import 'package:passenger/domain/received_quote.dart';
import 'package:passenger/domain/relay.dart';
import 'package:passenger/domain/ride_request.dart';
import 'package:passenger/services/event_feed.dart';
import 'package:passenger/services/event_verifier.dart';
import 'package:passenger/services/message_cipher.dart';
import 'package:passenger/services/relay_service.dart';
import 'package:passenger/shared/prototype_marker.dart';

import 'support/event_fixtures.dart';
import 'support/fake_relay_transport.dart';

/// Monta um feed ligado a relays falsos. Verificação criptográfica é a real:
/// dublar o verificador esvaziaria justamente o que o Princípio II manda testar.
class Cenario {
  Cenario({
    int windowSize = 100,
    Duration publishTimeout = const Duration(milliseconds: 200),
    Set<int>? acceptedKinds,
  }) {
    transport = FakeTransport({});
    relayService = RelayService(
      transport: transport,
      connectTimeout: const Duration(milliseconds: 50),
      livenessTimeout: const Duration(milliseconds: 50),
    );
    feed = EventFeed(
      relayService: relayService,
      verifier: const NostrEventVerifier(),
      windowSize: windowSize,
      publishTimeout: publishTimeout,
      acceptedKinds: acceptedKinds,
    );
  }

  late final FakeTransport transport;
  late final RelayService relayService;
  late final EventFeed feed;

  Future<void> iniciar([List<String> urls = const ['wss://a.test']]) async {
    await relayService.start([for (final u in urls) Relay(url: u)]);
    feed.start();
  }

  /// Simula o relay [url] entregando [payload].
  void entregar(Map<String, dynamic> payload, {String url = 'wss://a.test'}) {
    transport.conexoes[url]!.emitir(mensagemEvent(payload));
  }

  Future<void> assentar() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  Future<void> fechar() async {
    feed.dispose();
    await relayService.dispose();
  }
}

/// Publica uma solicitação de carona qualquer: os testes de publicação só
/// precisam de um evento de domínio assinado e em claro.
Future<PublishReport> publicarTeste(EventFeed feed, Identity identity) =>
    feed.publishRideRequest(
      RideRequest(
        origin: PassengerPosition(
          latitude: -28.9298,
          longitude: -49.4753,
          capturedAt: DateTime(2026, 9, 20),
        ),
        destination: const DestinationAddress(
          'Rua Exemplo, 123',
          latitude: -28.6721,
          longitude: -49.3671,
        ),
        payment: PaymentMethod.pix,
      ),
      identity,
    );

void main() {
  group('EventFeed — verificação de assinatura (Princípio II)', () {
    test('aceita evento com assinatura válida', () async {
      final c = Cenario();
      await c.iniciar();

      c.entregar(eventoAssinado(autor: novoPar(), content: 'olá'));
      await c.assentar();

      expect(c.feed.current, hasLength(1));
      expect(c.feed.current.single.content, 'olá');
      expect(c.feed.current.single.isSignatureValid, isTrue);
      await c.fechar();
    });

    test('descarta evento com assinatura adulterada', () async {
      final c = Cenario();
      await c.iniciar();

      final payload = eventoAssinado(autor: novoPar())..['sig'] = 'f' * 128;
      c.entregar(payload);
      await c.assentar();

      expect(c.feed.current, isEmpty);
      await c.fechar();
    });

    test('descarta evento com conteúdo adulterado mantendo id e assinatura '
        'originais', () async {
      final c = Cenario();
      await c.iniciar();

      // Este é o caso que `NostrEvent.isVerified()` da biblioteca NÃO pega:
      // ele confere a assinatura sobre o id informado, sem recalcular o id a
      // partir do conteúdo. Sem recalcular, um evento adulterado passaria.
      final payload = eventoAssinado(autor: novoPar(), content: 'original')
        ..['content'] = 'adulterado';
      c.entregar(payload);
      await c.assentar();

      expect(
        c.feed.current,
        isEmpty,
        reason: 'conteúdo adulterado deve ser descartado',
      );
      await c.fechar();
    });

    test('descarta evento cujo autor foi trocado', () async {
      final c = Cenario();
      await c.iniciar();

      final outro = novoPar();
      final payload = eventoAssinado(autor: novoPar())
        ..['pubkey'] = outro.public;
      c.entregar(payload);
      await c.assentar();

      expect(c.feed.current, isEmpty);
      await c.fechar();
    });

    test('descarta evento com campo obrigatório ausente', () async {
      final c = Cenario();
      await c.iniciar();

      for (final campo in [
        'id',
        'pubkey',
        'sig',
        'kind',
        'content',
        'created_at',
      ]) {
        final payload = eventoAssinado(autor: novoPar())..remove(campo);
        c.entregar(payload);
      }
      await c.assentar();

      expect(c.feed.current, isEmpty);
      await c.fechar();
    });

    test('mensagem malformada do relay não derruba o feed', () async {
      final c = Cenario();
      await c.iniciar();

      c.transport.conexoes['wss://a.test']!.emitir('isto não é json');
      c.transport.conexoes['wss://a.test']!.emitir('["EVENT"]');
      c.transport.conexoes['wss://a.test']!.emitir('["EVENT","f",42]');
      c.entregar(eventoAssinado(autor: novoPar(), content: 'sobrevivi'));
      await c.assentar();

      expect(c.feed.current.map((e) => e.content), ['sobrevivi']);
      await c.fechar();
    });
  });

  group('EventFeed — exibição', () {
    test('mesmo evento vindo de dois relays aparece uma única vez', () async {
      final c = Cenario();
      await c.iniciar(['wss://a.test', 'wss://b.test']);

      final payload = eventoAssinado(autor: novoPar(), content: 'duplicado');
      c.entregar(payload);
      c.entregar(payload, url: 'wss://b.test');
      await c.assentar();

      expect(c.feed.current, hasLength(1));
      await c.fechar();
    });

    test('evento sem o marcador do protótipo é descartado', () async {
      final c = Cenario();
      await c.iniciar();

      // Regra 6 de recepção: um relay pode ignorar o filtro #t da inscrição, e
      // a app não deve depender do bom comportamento dele.
      c.entregar(eventoAssinado(autor: novoPar(), comMarcador: false));
      await c.assentar();

      expect(c.feed.current, isEmpty);
      await c.fechar();
    });

    test('kind desconhecido é ignorado sem erro', () async {
      final c = Cenario();
      await c.iniciar();

      c.entregar(eventoAssinado(autor: novoPar(), kind: 7));
      c.entregar(eventoAssinado(autor: novoPar(), content: 'válido'));
      await c.assentar();

      expect(c.feed.current.map((e) => e.content), ['válido']);
      await c.fechar();
    });

    test(
      'conteúdo com marcação é preservado como texto, nunca interpretado',
      () async {
        final c = Cenario();
        await c.iniciar();

        const hostil = '<script>alert(1)</script> **negrito** {{injeção}}';
        c.entregar(eventoAssinado(autor: novoPar(), content: hostil));
        await c.assentar();

        expect(
          c.feed.current.single.content,
          hostil,
          reason:
              'o conteúdo é dado, não marcação — chega intacto à camada '
              'de exibição, que o renderiza como texto simples',
        );
        await c.fechar();
      },
    );

    test('evento de autor diferente do local traz o autor correto', () async {
      final c = Cenario();
      await c.iniciar();
      final motorista = novoPar();

      c.entregar(eventoAssinado(autor: motorista, content: 'oferta'));
      await c.assentar();

      final recebido = c.feed.current.single;
      expect(recebido.authorPublicKey, motorista.public);
      expect(recebido.isAuthoredBy(motorista.public), isTrue);
      expect(recebido.isAuthoredBy('a' * 64), isFalse);
      await c.fechar();
    });
  });

  group('EventFeed — janela de memória (SC-006)', () {
    test('rajada de 100 eventos mantém apenas a janela configurada, na ordem '
        'mais recente primeiro', () async {
      final c = Cenario(windowSize: 10);
      await c.iniciar();
      final autor = novoPar();

      for (var i = 0; i < 100; i++) {
        c.entregar(eventoAssinado(autor: autor, content: 'evento $i'));
      }
      await c.assentar();

      expect(
        c.feed.current,
        hasLength(10),
        reason: 'a janela limita o que é mantido em memória',
      );
      expect(c.feed.current.first.content, 'evento 99');
      await c.fechar();
    });

    test('a lista exposta é imodificável', () async {
      final c = Cenario();
      await c.iniciar();
      c.entregar(eventoAssinado(autor: novoPar()));
      await c.assentar();

      expect(() => c.feed.current.clear(), throwsUnsupportedError);
      await c.fechar();
    });
  });

  group('EventFeed — inscrição', () {
    test('a inscrição filtra pelo marcador, não só pelo kind', () async {
      final c = Cenario();
      await c.iniciar();

      final enviadas = c.transport.conexoes['wss://a.test']!.enviadas;
      final req = enviadas.firstWhere((m) => m.contains('"kinds"'));
      expect(req, contains('"#t"'));
      expect(
        req,
        contains(prototypeMarker),
        reason:
            'sem o filtro #t a inscrição traz o tráfego social da rede '
            'inteira (emenda 01 do contrato)',
      );
      await c.fechar();
    });

    test(
      'a inscrição limita o histórico entregue (emenda 02 do contrato)',
      () async {
        final c = Cenario();
        await c.iniciar();

        final enviadas = c.transport.conexoes['wss://a.test']!.enviadas;
        final req = enviadas.firstWhere((m) => m.contains('"kinds"'));
        expect(req, contains('"limit":50'));
        expect(
          req,
          isNot(contains('"since"')),
          reason:
              'a mesma inscrição é reenviada a cada reconexão; um since '
              'fixo ficaria cada vez mais velho',
        );
        await c.fechar();
      },
    );
  });
  group('EventFeed — publicação (FR-007)', () {
    Identity identidadeDe(nostr.NostrKeyPairs par) =>
        Identity(publicKey: par.public, privateKey: par.private);

    test('reporta aceitação por relay', () async {
      final c = Cenario();
      await c.iniciar(['wss://a.test', 'wss://b.test']);

      final relato = await publicarTeste(c.feed, identidadeDe(novoPar()));

      expect(relato.byRelay, hasLength(2));
      expect(relato.byRelay['wss://a.test'], PublishStatus.accepted);
      expect(relato.byRelay['wss://b.test'], PublishStatus.accepted);
      expect(relato.anyAccepted, isTrue);
      await c.fechar();
    });

    test('reporta recusa de um relay sem contaminar os demais', () async {
      final c = Cenario();
      await c.iniciar(['wss://a.test', 'wss://b.test']);
      c.transport.conexoes['wss://b.test']!.aceitaPublicacao = false;

      final relato = await publicarTeste(c.feed, identidadeDe(novoPar()));

      expect(relato.byRelay['wss://a.test'], PublishStatus.accepted);
      expect(relato.byRelay['wss://b.test'], PublishStatus.rejected);
      expect(
        relato.anyAccepted,
        isTrue,
        reason: 'recusa de um relay não invalida a publicação nos outros',
      );
      await c.fechar();
    });

    test(
      'relay que não confirma vira noAnswer, sem travar a publicação',
      () async {
        final c = Cenario(publishTimeout: const Duration(milliseconds: 150));
        await c.iniciar(['wss://a.test', 'wss://b.test']);
        c.transport.conexoes['wss://b.test']!.confirmaPublicacao = false;

        final relato = await publicarTeste(c.feed, identidadeDe(novoPar()));

        expect(relato.byRelay['wss://a.test'], PublishStatus.accepted);
        expect(relato.byRelay['wss://b.test'], PublishStatus.noAnswer);
        await c.fechar();
      },
    );

    test(
      'sem relay conectado, o relato sai vazio e nada é perdido em silêncio',
      () async {
        final c = Cenario();
        c.transport.comportamentos['wss://a.test'] =
            FakeBehavior.refuseConnection;
        await c.iniciar();

        final relato = await publicarTeste(c.feed, identidadeDe(novoPar()));

        expect(relato.byRelay, isEmpty);
        expect(relato.anyAccepted, isFalse);
        await c.fechar();
      },
    );

    test(
      'OK duplicado de um relay não derruba a espera pelos demais',
      () async {
        final c = Cenario(publishTimeout: const Duration(milliseconds: 300));
        await c.iniciar(['wss://a.test', 'wss://b.test']);
        // b.test nunca confirma: a espera continua aberta quando a duplicata
        // de a.test chega, e é aí que o Completer já concluído seria completado
        // de novo.
        c.transport.conexoes['wss://b.test']!.confirmaPublicacao = false;

        final publicacao = publicarTeste(c.feed, identidadeDe(novoPar()));
        await pumpEventQueue();
        final id =
            c.transport.conexoes['wss://a.test']!.enviadas
                    .map((m) => jsonDecode(m) as List)
                    .firstWhere((m) => m[0] == 'EVENT')[1]['id']
                as String;

        // Um relay defeituoso, ou um bug de reconexão, pode confirmar o mesmo
        // evento duas vezes. A segunda confirmação não pode ser um erro que
        // sobe ao chamador nem impedir o relato final.
        c.transport.conexoes['wss://a.test']!.emitir(
          jsonEncode(['OK', id, true, '']),
        );

        final relato = await publicacao;
        expect(relato.byRelay['wss://a.test'], PublishStatus.accepted);
        expect(relato.byRelay['wss://b.test'], PublishStatus.noAnswer);
        await c.fechar();
      },
    );

    test('o evento publicado leva o marcador do protótipo', () async {
      final c = Cenario();
      await c.iniciar();

      await publicarTeste(c.feed, identidadeDe(novoPar()));

      final enviado = c.transport.conexoes['wss://a.test']!.enviadas.firstWhere(
        (m) => m.startsWith('["EVENT"'),
      );
      expect(enviado, contains(prototypeMarker));
      await c.fechar();
    });

    test(
      'o próprio evento publicado é aceito de volta pela inscrição',
      () async {
        final c = Cenario(acceptedKinds: const {rideRequestKind});
        await c.iniciar();
        final par = novoPar();

        final relato = await publicarTeste(c.feed, identidadeDe(par));
        // O relay ecoa o evento para quem está inscrito.
        final enviado = c.transport.conexoes['wss://a.test']!.enviadas
            .firstWhere((m) => m.startsWith('["EVENT"'));
        final payload =
            (jsonDecode(enviado) as List)[1] as Map<String, dynamic>;
        c.entregar(payload);
        await c.assentar();

        expect(c.feed.current.single.id, relato.eventId);
        expect(c.feed.current.single.kind, rideRequestKind);
        await c.fechar();
      },
    );
  });

  group('EventFeed — publishRideRequest (FR-006, FR-007, feature 006)', () {
    Identity identidadeDe(nostr.NostrKeyPairs par) =>
        Identity(publicKey: par.public, privateKey: par.private);

    final origem = PassengerPosition(
      latitude: -28.9298,
      longitude: -49.4753,
      capturedAt: DateTime(2026, 9, 20),
    );
    const destino = DestinationAddress(
      'Rua Exemplo, 123',
      latitude: -28.6721,
      longitude: -49.3671,
    );

    test('publica com kind 20001 e tag de marcador', () async {
      final c = Cenario();
      await c.iniciar();

      await c.feed.publishRideRequest(
        RideRequest(
          origin: origem,
          destination: destino,
          payment: PaymentMethod.pix,
        ),
        identidadeDe(novoPar()),
      );

      final enviado = c.transport.conexoes['wss://a.test']!.enviadas
          .firstWhere((m) => m.startsWith('["EVENT"'));
      final payload = (jsonDecode(enviado) as List)[1] as Map<String, dynamic>;

      expect(payload['kind'], 20001);
      expect(payload['tags'], [
        ['t', prototypeMarker],
      ]);
      await c.fechar();
    });

    test('content traz origin, destination e payment no formato do '
        'contrato', () async {
      final c = Cenario();
      await c.iniciar();

      await c.feed.publishRideRequest(
        RideRequest(
          origin: origem,
          destination: destino,
          payment: PaymentMethod.card,
        ),
        identidadeDe(novoPar()),
      );

      final enviado = c.transport.conexoes['wss://a.test']!.enviadas
          .firstWhere((m) => m.startsWith('["EVENT"'));
      final payload = (jsonDecode(enviado) as List)[1] as Map<String, dynamic>;
      final content = jsonDecode(payload['content'] as String) as Map;

      expect(content['origin'], {'lat': -28.9298, 'lon': -49.4753});
      expect(content['destination'], {'lat': -28.6721, 'lon': -49.3671});
      expect(content['payment'], 'cartao');
      await c.fechar();
    });

    test('traduz cada PaymentMethod para o valor de contrato correto', () async {
      final c = Cenario();
      await c.iniciar();

      for (final par in [
        (PaymentMethod.cash, 'dinheiro'),
        (PaymentMethod.pix, 'pix'),
        (PaymentMethod.card, 'cartao'),
      ]) {
        await c.feed.publishRideRequest(
          RideRequest(origin: origem, destination: destino, payment: par.$1),
          identidadeDe(novoPar()),
        );
        final enviado = c.transport.conexoes['wss://a.test']!.enviadas
            .lastWhere((m) => m.startsWith('["EVENT"'));
        final payload =
            (jsonDecode(enviado) as List)[1] as Map<String, dynamic>;
        final content = jsonDecode(payload['content'] as String) as Map;
        expect(content['payment'], par.$2);
      }
      await c.fechar();
    });

    test('sem relay conectado, o relato sai vazio', () async {
      final c = Cenario();
      c.transport.comportamentos['wss://a.test'] =
          FakeBehavior.refuseConnection;
      await c.iniciar();

      final relato = await c.feed.publishRideRequest(
        RideRequest(
          origin: origem,
          destination: destino,
          payment: PaymentMethod.cash,
        ),
        identidadeDe(novoPar()),
      );

      expect(relato.byRelay, isEmpty);
      await c.fechar();
    });
  });

  group('EventFeed — inscrição sobrevive a mudanças de conexão', () {
    // Defeito encontrado na validação cross-app (cenário X5, controle
    // positivo): a inscrição era enviada uma única vez, no start(). Um relay
    // acrescentado depois, ou reconectado após queda de rede, ficava
    // "Conectado" mas nunca recebia o REQ — conectado e surdo. O teste de
    // reconexão da fase 4 não pegou porque verificava só o status.

    test('relay acrescentado depois do start recebe a inscrição e entrega '
        'eventos', () async {
      final c = Cenario();
      await c.iniciar(['wss://a.test']);

      await c.relayService.add(const Relay(url: 'wss://b.test'));
      await c.assentar();

      final enviadasB = c.transport.conexoes['wss://b.test']!.enviadas;
      expect(
        enviadasB.any((m) => m.contains('"#t"')),
        isTrue,
        reason: 'o relay novo precisa receber a inscrição',
      );

      c.entregar(
        eventoAssinado(autor: novoPar(), content: 'via b'),
        url: 'wss://b.test',
      );
      await c.assentar();
      expect(c.feed.current.map((e) => e.content), contains('via b'));
      await c.fechar();
    });

    test('após queda e reconexão, a inscrição é reenviada e os eventos '
        'voltam a chegar', () async {
      final c = Cenario();
      await c.iniciar(['wss://a.test']);

      // Cai a conexão.
      c.transport.conexoes['wss://a.test']!.derrubar();
      await c.assentar();
      expect(c.relayService.current.single.status, RelayStatus.unavailable);

      // A rede volta e o relay reconecta — numa conexão NOVA.
      await c.relayService.retryUnavailable();
      await c.assentar();
      expect(c.relayService.current.single.status, RelayStatus.connected);

      final novaConexao = c.transport.conexoes['wss://a.test']!;
      expect(
        novaConexao.enviadas.any((m) => m.contains('"#t"')),
        isTrue,
        reason: 'sem reinscrição, o relay reconectado fica surdo',
      );

      c.entregar(eventoAssinado(autor: novoPar(), content: 'depois da queda'));
      await c.assentar();
      expect(c.feed.current.map((e) => e.content), contains('depois da queda'));
      await c.fechar();
    });

    test('a inscrição não é duplicada na mesma conexão', () async {
      final c = Cenario();
      await c.iniciar(['wss://a.test']);
      c.feed.start(); // start repetido não deve reenviar

      final reqs = c.transport.conexoes['wss://a.test']!.enviadas.where(
        (m) => m.contains('"#t"'),
      );
      expect(reqs, hasLength(1));
      await c.fechar();
    });
  });
  group('EventFeed — ordem de exibição', () {
    // Defeito encontrado na validação cross-app: os eventos eram inseridos no
    // topo por ordem de CHEGADA. Um relay entrega o histórico do mais novo
    // para o mais velho, então inserir cada um no topo invertia a lista — o
    // evento mais antigo aparecia primeiro e o recém-publicado ficava no fim,
    // fora da tela.

    test('histórico entregue do mais novo para o mais velho é exibido com o '
        'mais novo primeiro', () async {
      final c = Cenario();
      await c.iniciar();
      final autor = novoPar();
      final agora = DateTime.now();

      // Ordem em que um relay real entrega o histórico: decrescente.
      for (final minutos in [0, 10, 20, 30]) {
        c.entregar(
          eventoAssinado(
            autor: autor,
            content: 'há $minutos min',
            createdAt: agora.subtract(Duration(minutes: minutos)),
          ),
        );
      }
      await c.assentar();

      expect(c.feed.current.map((e) => e.content), [
        'há 0 min',
        'há 10 min',
        'há 20 min',
        'há 30 min',
      ]);
      await c.fechar();
    });

    test(
      'evento recém-chegado mais novo que o histórico vai para o topo',
      () async {
        final c = Cenario();
        await c.iniciar();
        final autor = novoPar();
        final agora = DateTime.now();

        c.entregar(
          eventoAssinado(
            autor: autor,
            content: 'antigo',
            createdAt: agora.subtract(const Duration(hours: 1)),
          ),
        );
        await c.assentar();
        c.entregar(
          eventoAssinado(autor: autor, content: 'novo', createdAt: agora),
        );
        await c.assentar();

        expect(c.feed.current.first.content, 'novo');
        await c.fechar();
      },
    );

    test(
      'evento com data no futuro não fica preso no topo para sempre',
      () async {
        final c = Cenario();
        await c.iniciar();
        final autor = novoPar();
        final agora = DateTime.now();

        // created_at é declarado pelo autor e não é confiável (regra 5 do
        // contrato). Sem limitar, um evento datado para daqui a um ano nunca
        // sairia do topo nem seria descartado pela janela.
        c.entregar(
          eventoAssinado(
            autor: autor,
            content: 'datado no futuro',
            createdAt: agora.add(const Duration(days: 365)),
          ),
        );
        await c.assentar();
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        c.entregar(eventoAssinado(autor: autor, content: 'legítimo e recente'));
        await c.assentar();

        expect(
          c.feed.current.first.content,
          'legítimo e recente',
          reason: 'data futura é tratada como o instante de chegada',
        );
        await c.fechar();
      },
    );
  });

  group('EventFeed — acceptedKinds configurável (feature 008)', () {
    test(
      'kind fora de acceptedKinds é ignorado, mesmo que válido',
      () async {
        final c = Cenario(acceptedKinds: {rideQuoteKind});
        await c.iniciar();

        c.entregar(eventoAssinado(autor: novoPar(), kind: 20099));
        c.entregar(
          eventoAssinado(autor: novoPar(), kind: rideQuoteKind, content: '{}'),
        );
        await c.assentar();

        expect(c.feed.current, hasLength(1));
        expect(c.feed.current.single.kind, rideQuoteKind);
        await c.fechar();
      },
    );

    test('subscriptionRequest lista os acceptedKinds configurados', () {
      final c = Cenario(acceptedKinds: {rideQuoteKind});
      final request = jsonDecode(c.feed.subscriptionRequest()) as List;
      final filtro = request[2] as Map<String, dynamic>;

      expect(filtro['kinds'], unorderedEquals([rideQuoteKind]));
    });

    test('evento aceito carrega as tags originais', () async {
      final c = Cenario(acceptedKinds: {rideQuoteKind});
      await c.iniciar();

      c.entregar(
        eventoAssinado(
          autor: novoPar(),
          kind: rideQuoteKind,
          content: '{}',
          tags: [prototypeMarkerTag, [
            'e',
            'id-da-solicitacao',
          ]],
        ),
      );
      await c.assentar();

      expect(
        c.feed.current.single.referencedEventId,
        'id-da-solicitacao',
      );
      await c.fechar();
    });
  });

  group('EventFeed — rota da corrida (feature 018)', () {
    test('kind 20011 chega ao feed quando está em acceptedKinds', () async {
      final c = Cenario(acceptedKinds: {rideRouteKind});
      await c.iniciar();

      c.entregar(
        eventoAssinado(
          autor: novoPar(),
          kind: rideRouteKind,
          content: '{"points":[[-28.9,-49.4],[-28.8,-49.3]]}',
          tags: [prototypeMarkerTag, ['e', 'orcamento'], ['p', 'passageiro']],
        ),
      );
      await c.assentar();

      expect(c.feed.current, hasLength(1));
      expect(c.feed.current.single.kind, 20011);
      expect(c.feed.current.single.referencedEventId, 'orcamento');
      await c.fechar();
    });

    test('kind 20011 é ignorado quando fora de acceptedKinds (regra 4)', () async {
      final c = Cenario(acceptedKinds: {rideQuoteKind});
      await c.iniciar();

      c.entregar(
        eventoAssinado(
          autor: novoPar(),
          kind: rideRouteKind,
          content: '{"points":[[-28.9,-49.4],[-28.8,-49.3]]}',
        ),
      );
      await c.assentar();

      expect(c.feed.current, isEmpty);
      await c.fechar();
    });

    test('a inscrição lista o kind 20011 quando aceito', () {
      final c = Cenario(acceptedKinds: {rideRouteKind});
      final request = jsonDecode(c.feed.subscriptionRequest()) as List;
      final filtro = request[2] as Map<String, dynamic>;

      expect(filtro['kinds'], contains(20011));
    });
  });

  group('EventFeed — corrida cancelada pelo motorista (feature 019)', () {
    test('kind 20012 chega ao feed quando está em acceptedKinds', () async {
      final c = Cenario(acceptedKinds: {rideCancelledKind});
      await c.iniciar();

      c.entregar(
        eventoAssinado(
          autor: novoPar(),
          kind: rideCancelledKind,
          content: '',
          tags: [prototypeMarkerTag, ['e', 'orcamento'], ['p', 'passageiro']],
        ),
      );
      await c.assentar();

      expect(c.feed.current, hasLength(1));
      expect(c.feed.current.single.kind, 20012);
      expect(c.feed.current.single.referencedEventId, 'orcamento');
      await c.fechar();
    });

    test('kind 20012 é ignorado quando fora de acceptedKinds (regra 4)', () async {
      final c = Cenario(acceptedKinds: {rideQuoteKind});
      await c.iniciar();

      c.entregar(
        eventoAssinado(autor: novoPar(), kind: rideCancelledKind, content: ''),
      );
      await c.assentar();

      expect(c.feed.current, isEmpty);
      await c.fechar();
    });

    test('a inscrição lista o kind 20012 quando aceito', () {
      final c = Cenario(acceptedKinds: {rideCancelledKind});
      final request = jsonDecode(c.feed.subscriptionRequest()) as List;
      final filtro = request[2] as Map<String, dynamic>;

      expect(filtro['kinds'], contains(20012));
    });
  });

  group('EventFeed — corrida não pode mais ser atendida (feature 020)', () {
    test('kind 20006 chega ao feed quando está em acceptedKinds', () async {
      final c = Cenario(acceptedKinds: {rideUnavailableKind});
      await c.iniciar();

      c.entregar(
        eventoAssinado(
          autor: novoPar(),
          kind: rideUnavailableKind,
          content: '',
          tags: [prototypeMarkerTag, ['e', 'orcamento'], ['p', 'passageiro']],
        ),
      );
      await c.assentar();

      expect(c.feed.current, hasLength(1));
      expect(c.feed.current.single.kind, 20006);
      expect(c.feed.current.single.referencedEventId, 'orcamento');
      await c.fechar();
    });

    test('kind 20006 é ignorado quando fora de acceptedKinds (regra 4)', () async {
      final c = Cenario(acceptedKinds: {rideQuoteKind});
      await c.iniciar();

      c.entregar(
        eventoAssinado(autor: novoPar(), kind: rideUnavailableKind, content: ''),
      );
      await c.assentar();

      expect(c.feed.current, isEmpty);
      await c.fechar();
    });

    test('a inscrição lista o kind 20006 quando aceito', () {
      final c = Cenario(acceptedKinds: {rideUnavailableKind});
      final request = jsonDecode(c.feed.subscriptionRequest()) as List;
      final filtro = request[2] as Map<String, dynamic>;

      expect(filtro['kinds'], contains(20006));
    });
  });

  group('EventFeed — publicações com destinatário (features 008 e 010, '
      'cifradas pela feature 022)', () {
    // Motorista de teste com par de chaves de verdade: o `content` é cifrado à
    // chave pública dele (emenda 17), então só a privada o decifra.
    late Identity motorista;
    late Identity passageiro;

    setUp(() {
      motorista = _identidadeDe(novoPar());
      passageiro = _identidadeDe(novoPar());
    });

    Future<Map<String, dynamic>> publicadoPor(
      Cenario c,
      Future<PublishReport> Function(EventFeed feed) publicar,
    ) async {
      await publicar(c.feed);
      final enviado = c.transport.conexoes['wss://a.test']!.enviadas.firstWhere(
        (m) => m.startsWith('["EVENT"'),
      );
      return (jsonDecode(enviado) as List)[1] as Map<String, dynamic>;
    }

    List<List<String>> tagsDe(Map<String, dynamic> payload) =>
        (payload['tags'] as List<dynamic>)
            .map((t) => (t as List<dynamic>).map((e) => e.toString()).toList())
            .toList();

    String? decifradoPeloMotorista(Map<String, dynamic> payload) =>
        MessageCipher().decryptFrom(
          motorista,
          passageiro.publicKey,
          payload['content'] as String,
          emptyMarker: true,
        );

    test('publishQuoteAcceptance publica kind 20003 com tags e (orçamento) e '
        'p (motorista) e content cifrado', () async {
      final c = Cenario();
      await c.iniciar();
      final quote = _orcamentoDeTeste(motorista.publicKey);

      final payload = await publicadoPor(
        c,
        (f) => f.publishQuoteAcceptance(quote, passageiro),
      );

      expect(payload['kind'], quoteAcceptedKind);
      expect(payload['content'], isNot(''));
      expect(decifradoPeloMotorista(payload), '{}');
      final tags = tagsDe(payload);
      expect(tags, anyElement(equals(['e', quote.quoteId])));
      expect(tags, anyElement(equals(['p', quote.driverPubkey])));
      await c.fechar();
    });

    test('publishQuoteRejection publica kind 20004 cifrado ao motorista '
        'recusado, com as mesmas tags', () async {
      final c = Cenario();
      await c.iniciar();
      final quote = _orcamentoDeTeste(motorista.publicKey);

      final payload = await publicadoPor(
        c,
        (f) => f.publishQuoteRejection(quote, passageiro),
      );

      expect(payload['kind'], quoteRejectedKind);
      expect(decifradoPeloMotorista(payload), '{}');
      expect(tagsDe(payload), anyElement(equals(['p', motorista.publicKey])));
      await c.fechar();
    });

    test('publishMeetingConfirmation publica kind 20008 cifrado, com tags e '
        '(orçamento) e p (motorista)', () async {
      final c = Cenario();
      await c.iniciar();

      final payload = await publicadoPor(
        c,
        (f) => f.publishMeetingConfirmation(
          'id-do-orcamento',
          motorista.publicKey,
          passageiro,
        ),
      );

      expect(payload['kind'], meetingConfirmedKind);
      expect(decifradoPeloMotorista(payload), '{}');
      final tags = tagsDe(payload);
      expect(tags, anyElement(equals(['e', 'id-do-orcamento'])));
      expect(tags, anyElement(equals(['p', motorista.publicKey])));
      await c.fechar();
    });

    test('publishDestinationConfirmation publica kind 20010 cifrado, com as '
        'mesmas tags', () async {
      final c = Cenario();
      await c.iniciar();

      final payload = await publicadoPor(
        c,
        (f) => f.publishDestinationConfirmation(
          'id-do-orcamento',
          motorista.publicKey,
          passageiro,
        ),
      );

      expect(payload['kind'], destinationConfirmedKind);
      expect(decifradoPeloMotorista(payload), '{}');
      final tags = tagsDe(payload);
      expect(tags, anyElement(equals(['e', 'id-do-orcamento'])));
      expect(tags, anyElement(equals(['p', motorista.publicKey])));
      await c.fechar();
    });

    test('publishRideCancellation publica kind 20013 cifrado, com tags e '
        '(orçamento) e p (motorista)', () async {
      final c = Cenario();
      await c.iniciar();

      final payload = await publicadoPor(
        c,
        (f) => f.publishRideCancellation(
          'id-do-orcamento',
          motorista.publicKey,
          passageiro,
        ),
      );

      expect(payload['kind'], rideCancelledByPassengerKind);
      expect(payload['kind'], 20013);
      expect(decifradoPeloMotorista(payload), '{}');
      final tags = tagsDe(payload);
      expect(tags, anyElement(equals(['t', prototypeMarker])));
      expect(tags, anyElement(equals(['e', 'id-do-orcamento'])));
      expect(tags, anyElement(equals(['p', motorista.publicKey])));
      expect(const NostrEventVerifier().isValid(payload), isTrue);
      await c.fechar();
    });

    test('publishRideCancellation com destinatário inválido: nada é '
        'transmitido, nunca em claro', () async {
      final c = Cenario();
      await c.iniciar();

      final relato = await c.feed.publishRideCancellation(
        'q',
        'pubkey-invalida',
        passageiro,
      );

      expect(relato.anyAccepted, isFalse);
      expect(
        c.transport.conexoes['wss://a.test']!.enviadas.where(
          (m) => m.startsWith('["EVENT"'),
        ),
        isEmpty,
      );
      await c.fechar();
    });

    test('só o motorista destinatário decifra; um terceiro não', () async {
      final c = Cenario();
      await c.iniciar();
      final terceiro = _identidadeDe(novoPar());

      final payload = await publicadoPor(
        c,
        (f) =>
            f.publishMeetingConfirmation('q', motorista.publicKey, passageiro),
      );

      expect(
        MessageCipher().decryptFrom(
          terceiro,
          passageiro.publicKey,
          payload['content'] as String,
        ),
        isNull,
      );
      await c.fechar();
    });

    test('a assinatura vale sobre o content cifrado', () async {
      final c = Cenario();
      await c.iniciar();

      final payload = await publicadoPor(
        c,
        (f) =>
            f.publishMeetingConfirmation('q', motorista.publicKey, passageiro),
      );

      expect(const NostrEventVerifier().isValid(payload), isTrue);
      await c.fechar();
    });

    test(
      'o kind 20001 continua em claro e assinado (exceção da emenda 17)',
      () async {
        final c = Cenario();
        await c.iniciar();

        final payload = await publicadoPor(
          c,
          (f) => f.publishRideRequest(_solicitacaoDeTeste(), passageiro),
        );

        expect(payload['kind'], rideRequestKind);
        expect(jsonDecode(payload['content'] as String), isA<Map>());
        expect(const NostrEventVerifier().isValid(payload), isTrue);
        await c.fechar();
      },
    );

    test('falha ao cifrar (destinatário inválido): nada é transmitido e o '
        'relatório não tem relay aceito (FR-004)', () async {
      final c = Cenario();
      await c.iniciar();

      final relato = await c.feed.publishMeetingConfirmation(
        'q',
        'pubkey-invalida',
        passageiro,
      );

      expect(relato.anyAccepted, isFalse);
      expect(relato.byRelay, isEmpty);
      final enviadas = c.transport.conexoes['wss://a.test']!.enviadas;
      expect(enviadas.where((m) => m.startsWith('["EVENT"')), isEmpty);
      await c.fechar();
    });
  });

  group('EventFeed.decrypted (feature 022, emenda 17)', () {
    late Identity passageiro;
    late Identity motorista;
    late EventFeed feed;
    final cifra = MessageCipher();

    setUp(() {
      passageiro = _identidadeDe(novoPar());
      motorista = _identidadeDe(novoPar());
      feed = Cenario().feed;
    });

    NostrEvent recebido({required String content, String? p, Identity? autor}) =>
        NostrEvent(
          id: 'id',
          authorPublicKey: (autor ?? motorista).publicKey,
          createdAt: DateTime(2026, 10, 6),
          kind: rideQuoteKind,
          content: content,
          isSignatureValid: true,
          tags: [
            ['t', 'tcc-ufsc-caronas'],
            ['e', 'q'],
            ['p', p ?? passageiro.publicKey],
          ],
        );

    String cifrado(String texto, {Identity? para}) => cifra.encryptFor(
      motorista,
      (para ?? passageiro).publicKey,
      texto,
    );

    test('cifrado ao passageiro: devolve o evento com o texto decifrado', () {
      final claro = feed.decrypted(
        recebido(content: cifrado('{"a":1}')),
        passageiro,
      );

      expect(claro, isNotNull);
      expect(claro!.content, '{"a":1}');
      expect(claro.id, 'id');
      expect(claro.authorPublicKey, motorista.publicKey);
      expect(claro.referencedEventId, 'q');
    });

    test('kind sem dado próprio: aceita só o marcador {}', () {
      expect(
        feed.decrypted(
          recebido(content: cifrado('')),
          passageiro,
          emptyMarker: true,
        ),
        isNotNull,
      );
      expect(
        feed.decrypted(
          recebido(content: cifrado('{"a":1}')),
          passageiro,
          emptyMarker: true,
        ),
        isNull,
      );
    });

    test('tag p de outro destinatário: null', () {
      final outro = _identidadeDe(novoPar());

      expect(
        feed.decrypted(
          recebido(content: cifrado('{}', para: outro), p: outro.publicKey),
          passageiro,
        ),
        isNull,
      );
    });

    test('tag p é a do passageiro mas cifrado a outra chave: null', () {
      expect(
        feed.decrypted(
          recebido(content: cifrado('{}', para: _identidadeDe(novoPar()))),
          passageiro,
        ),
        isNull,
      );
    });

    test('conteúdo em claro: null', () {
      expect(feed.decrypted(recebido(content: '{}'), passageiro), isNull);
    });

    test('MAC adulterado: null', () {
      final bytes = base64.decode(cifrado('{}'))..[60] ^= 0x01;

      expect(
        feed.decrypted(recebido(content: base64.encode(bytes)), passageiro),
        isNull,
      );
    });
  });
}

Identity _identidadeDe(nostr.NostrKeyPairs par) =>
    Identity(publicKey: par.public, privateKey: par.private);

ReceivedQuote _orcamentoDeTeste(String driverPubkey) => ReceivedQuote(
  quoteId: 'id-do-orcamento',
  requestId: 'id-da-solicitacao',
  driverPubkey: driverPubkey,
  driverName: 'Fulano da Silva',
  carBrand: 'Fiat',
  carModel: 'Palio',
  carYear: 2018,
  pricePerKm: 2.5,
  total: 25.0,
  etaMinutes: 6,
);

RideRequest _solicitacaoDeTeste() => RideRequest(
  origin: PassengerPosition(
    latitude: -28.9298,
    longitude: -49.4753,
    capturedAt: DateTime(2026, 9, 20),
  ),
  destination: const DestinationAddress(
    'Rua Exemplo, 123',
    latitude: -28.6721,
    longitude: -49.3671,
  ),
  payment: PaymentMethod.pix,
);

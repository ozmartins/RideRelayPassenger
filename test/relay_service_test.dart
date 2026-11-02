import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/relay.dart';
import 'package:passenger/services/relay_service.dart';

import 'support/fake_relay_transport.dart';

const relaysDeTeste = ['wss://a.test', 'wss://b.test', 'wss://c.test'];

RelayService criarService(FakeTransport transport) => RelayService(
  transport: transport,
  connectTimeout: const Duration(milliseconds: 100),
  livenessTimeout: const Duration(milliseconds: 100),
);

void main() {
  group('RelayService', () {
    test('relay saudável vai de connecting a connected', () async {
      final transport = FakeTransport({});
      final service = criarService(transport);

      final estados = <List<RelayStatus>>[];
      final sub = service.relays.listen(
        (lista) => estados.add(lista.map((r) => r.status).toList()),
      );

      await service.start(
        relaysDeTeste.map((u) => Relay(url: u, isDefault: true)).toList(),
      );

      expect(
        estados.first.every((s) => s == RelayStatus.connecting),
        isTrue,
        reason: 'todo relay entra em connecting',
      );
      expect(
        service.current.every((r) => r.status == RelayStatus.connected),
        isTrue,
      );
      await sub.cancel();
      await service.dispose();
    });

    test('falha em um relay não impede o funcionamento dos demais', () async {
      final transport = FakeTransport({
        'wss://b.test': FakeBehavior.refuseConnection,
      });
      final service = criarService(transport);

      await service.start(relaysDeTeste.map((u) => Relay(url: u)).toList());

      final porUrl = {for (final r in service.current) r.url: r};
      expect(porUrl['wss://b.test']!.status, RelayStatus.unavailable);
      expect(porUrl['wss://b.test']!.lastError, isNotNull);
      expect(porUrl['wss://a.test']!.status, RelayStatus.connected);
      expect(porUrl['wss://c.test']!.status, RelayStatus.connected);
      expect(service.hasAnyConnected, isTrue);

      await service.dispose();
    });

    test('relay que aceita a conexão mas nunca responde vira indisponível '
        'por limite de espera', () async {
      final transport = FakeTransport({'wss://a.test': FakeBehavior.silent});
      final service = criarService(transport);

      await service.start(relaysDeTeste.map((u) => Relay(url: u)).toList());

      final mudo = service.current.firstWhere((r) => r.url == 'wss://a.test');
      expect(mudo.status, RelayStatus.unavailable);
      expect(mudo.lastError, contains('resposta'));

      await service.dispose();
    });

    test('relay permanece na lista quando fica indisponível', () async {
      final transport = FakeTransport({
        'wss://b.test': FakeBehavior.refuseConnection,
      });
      final service = criarService(transport);

      await service.start(relaysDeTeste.map((u) => Relay(url: u)).toList());

      expect(
        service.current.length,
        3,
        reason: 'indisponível não remove o relay da lista',
      );
      await service.dispose();
    });

    test('queda de conexão marca o relay como indisponível', () async {
      final transport = FakeTransport({});
      final service = criarService(transport);
      await service.start([const Relay(url: 'wss://a.test')]);
      expect(service.current.single.status, RelayStatus.connected);

      transport.conexoes['wss://a.test']!.derrubar();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(service.current.single.status, RelayStatus.unavailable);
      await service.dispose();
    });

    test('mensagem que chega depois da queda não é tratada como do relay '
        'disponível', () async {
      // addError não fecha o stream: se a assinatura antiga não for
      // cancelada ao marcar o relay indisponível, uma mensagem que ainda
      // chegar por ela seria tratada como legítima, com o relay já dado como
      // fora do ar.
      final transport = FakeTransport({});
      final service = criarService(transport);
      await service.start([const Relay(url: 'wss://a.test')]);
      final mensagens = <RelayMessage>[];
      final sub = service.messages.listen(mensagens.add);

      transport.conexoes['wss://a.test']!.derrubar();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      transport.conexoes['wss://a.test']!.emitir('["EVENT","corridas",{}]');
      await pumpEventQueue();

      expect(
        mensagens,
        isEmpty,
        reason: 'a assinatura da conexão caída deveria estar cancelada',
      );
      await sub.cancel();
      await service.dispose();
    });

    test('retorno de rede tenta reconectar apenas os indisponíveis', () async {
      final transport = FakeTransport({
        'wss://b.test': FakeBehavior.refuseConnection,
      });
      final service = criarService(transport);
      await service.start(relaysDeTeste.map((u) => Relay(url: u)).toList());
      final tentativasIniciais = transport.tentativas;

      // O relay volta a funcionar e a rede retorna.
      transport.comportamentos.remove('wss://b.test');
      await service.retryUnavailable();

      expect(
        transport.tentativas,
        tentativasIniciais + 1,
        reason: 'só o relay indisponível deve ser retentado',
      );
      expect(
        service.current.firstWhere((r) => r.url == 'wss://b.test').status,
        RelayStatus.connected,
      );
      await service.dispose();
    });

    test('sem nenhum relay conectado, hasAnyConnected é falso', () async {
      final transport = FakeTransport({
        for (final u in relaysDeTeste) u: FakeBehavior.refuseConnection,
      });
      final service = criarService(transport);

      await service.start(relaysDeTeste.map((u) => Relay(url: u)).toList());

      expect(service.hasAnyConnected, isFalse);
      await service.dispose();
    });

    test('relay removido durante o handshake não deixa conexão órfã', () async {
      final transport = FakeTransport({});
      final portao = transport.portoes['wss://a.test'] = Completer<void>();
      final service = criarService(transport);
      final mensagens = <RelayMessage>[];
      final sub = service.messages.listen(mensagens.add);

      final conectando = service.start([const Relay(url: 'wss://a.test')]);
      await pumpEventQueue();
      await service.remove('wss://a.test');

      // O handshake termina depois da remoção.
      portao.complete();
      await conectando;
      transport.conexoes['wss://a.test']!.emitir('["EVENT","corridas",{}]');
      await pumpEventQueue();

      expect(
        transport.conexoes['wss://a.test']!.fechada,
        isTrue,
        reason: 'conexão que termina após a remoção deve ser fechada',
      );
      expect(
        mensagens,
        isEmpty,
        reason: 'relay removido não pode continuar entregando eventos',
      );
      expect(service.current, isEmpty);
      await sub.cancel();
      await service.dispose();
    });

    test(
      'relay removido e acrescentado de novo fica só com a conexão nova',
      () async {
        final transport = FakeTransport({});
        final portao = transport.portoes['wss://a.test'] = Completer<void>();
        final service = criarService(transport);

        final antiga = service.start([const Relay(url: 'wss://a.test')]);
        await pumpEventQueue();
        await service.remove('wss://a.test');
        transport.portoes.remove('wss://a.test');
        await service.add(const Relay(url: 'wss://a.test'));
        final nova = transport.conexoes['wss://a.test']!;

        portao.complete();
        await antiga;
        await pumpEventQueue();
        final atrasada = transport.conexoes['wss://a.test']!;
        service.broadcast('["CLOSE","x"]');

        expect(identical(atrasada, nova), isFalse);
        expect(
          atrasada.fechada,
          isTrue,
          reason: 'a tentativa atrasada não pode substituir a conexão nova',
        );
        expect(nova.fechada, isFalse);
        expect(nova.enviadas.last, '["CLOSE","x"]');
        expect(service.current.single.status, RelayStatus.connected);
        await service.dispose();
      },
    );

    test('remover um relay encerra a conexão e o retira da lista', () async {
      final transport = FakeTransport({});
      final service = criarService(transport);
      await service.start(relaysDeTeste.map((u) => Relay(url: u)).toList());

      await service.remove('wss://a.test');

      expect(transport.conexoes['wss://a.test']!.fechada, isTrue);
      expect(service.current.any((r) => r.url == 'wss://a.test'), isFalse);
      await service.dispose();
    });

    test('a sonda de vivacidade não pressupõe o formato de assinatura da '
        'aplicação', () async {
      final transport = FakeTransport({});
      final service = criarService(transport);
      await service.start([const Relay(url: 'wss://a.test')]);

      final enviadas = transport.conexoes['wss://a.test']!.enviadas;
      expect(enviadas, hasLength(1));
      // A sonda filtra por um id inexistente: não depende de kind nem de tag,
      // portanto sobrevive a emendas no contrato de eventos.
      expect(enviadas.single, contains('"ids"'));
      expect(enviadas.single, isNot(contains('"kinds"')));

      await service.dispose();
    });
    test('reconecta sozinho quando a rede volta, sem intervenção manual', () async {
      final transport = FakeTransport({
        'wss://a.test': FakeBehavior.refuseConnection,
      });
      final service = RelayService(
        transport: transport,
        connectTimeout: const Duration(milliseconds: 50),
        livenessTimeout: const Duration(milliseconds: 50),
        retryInterval: const Duration(milliseconds: 60),
      );

      await service.start([const Relay(url: 'wss://a.test')]);
      service.enableAutoRetry();
      expect(service.current.single.status, RelayStatus.unavailable);

      // A rede volta. Ninguém toca em nada: FR-014 exige reconexão automática.
      transport.comportamentos.remove('wss://a.test');
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(
        service.current.single.status,
        RelayStatus.connected,
        reason: 'o ciclo de retentativas deve reconectar sem ação do usuário',
      );
      await service.dispose();
    });

    test('o ciclo de retentativas para ao descartar o serviço', () async {
      final transport = FakeTransport({
        'wss://a.test': FakeBehavior.refuseConnection,
      });
      final service = RelayService(
        transport: transport,
        connectTimeout: const Duration(milliseconds: 50),
        livenessTimeout: const Duration(milliseconds: 50),
        retryInterval: const Duration(milliseconds: 60),
      );
      await service.start([const Relay(url: 'wss://a.test')]);
      service.enableAutoRetry();
      await service.dispose();
      final tentativasAoDescartar = transport.tentativas;

      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(
        transport.tentativas,
        tentativasAoDescartar,
        reason: 'timer vazado continuaria tentando conectar após o dispose',
      );
    });
  });
}

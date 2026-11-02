import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart' as nostr;
import 'package:passenger/domain/identity.dart';
import 'package:passenger/domain/receipt.dart';
import 'package:passenger/domain/relay.dart';
import 'package:passenger/services/event_feed.dart';
import 'package:passenger/services/message_cipher.dart';
import 'package:passenger/services/receipt_service.dart';
import 'package:passenger/services/relay_service.dart';
import 'package:passenger/shared/prototype_marker.dart';

import 'event_fixtures.dart';
import 'fake_relay_transport.dart';
import 'in_memory_receipt_store.dart';
import 'receipt_builders.dart';

/// Monta o `ReceiptService` sobre relays falsos, `EventFeed` e store em
/// memória. A verificação criptográfica (eventos, recibos, cifra) é a real.
class RecibosCenario {
  RecibosCenario({
    this.retryInterval = const Duration(seconds: 60),
    DateTime Function()? clock,
  }) {
    transport = FakeTransport({});
    relayService = RelayService(
      transport: transport,
      connectTimeout: const Duration(milliseconds: 50),
      livenessTimeout: const Duration(milliseconds: 50),
    );
    feed = EventFeed(
      relayService: relayService,
      publishTimeout: const Duration(milliseconds: 100),
      acceptedKinds: {rideQuoteKind, receiptKind, receiptAckKind},
    );
    service = ReceiptService(
      store: store,
      feed: feed,
      identity: eu,
      isKnownRide: (guid, avaliador) async => conhecidas[guid] == avaliador,
      retryInterval: retryInterval,
      clock: clock,
    );
  }

  final Duration retryInterval;
  final Identity eu = identidadeNova();
  final Identity motorista = identidadeNova();
  final InMemoryReceiptStore store = InMemoryReceiptStore();

  /// Corridas que este passageiro conhece (orçamento recebido), por `guid`, com
  /// a chave do motorista que o enviou — o que `ReceivedQuoteStore` guarda de
  /// verdade (emenda 26). Um recibo só vale se a corrida estiver aqui.
  final Map<String, String> conhecidas = {};

  /// Registra que recebi o orçamento [guid] de [de] (o motorista por padrão).
  void conhecer(String guid, [Identity? de]) =>
      conhecidas[guid] = (de ?? motorista).publicKey;
  late final FakeTransport transport;
  late final RelayService relayService;
  late final EventFeed feed;
  late final ReceiptService service;

  Future<void> iniciar([List<String> urls = const ['wss://a.test']]) async {
    await relayService.start([for (final u in urls) Relay(url: u)]);
    feed.start();
    service.start();
    await assentar();
  }

  Future<void> assentar() =>
      Future<void>.delayed(const Duration(milliseconds: 30));

  /// Entrega [payload] como se viesse do relay [url].
  void entregar(Map<String, dynamic> payload, {String url = 'wss://a.test'}) {
    transport.conexoes[url]!.emitir(mensagemEvent(payload));
  }

  /// Eventos que o app publicou no relay [url], já decodificados.
  List<Map<String, dynamic>> publicados({String url = 'wss://a.test'}) => [
    for (final m in transport.conexoes[url]!.enviadas)
      if (m.startsWith('["EVENT"'))
        (jsonDecode(m) as List)[1] as Map<String, dynamic>,
  ];

  /// Os publicados de um [kind].
  List<Map<String, dynamic>> publicadosDe(int kind) => [
    for (final p in publicados())
      if (p['kind'] == kind) p,
  ];

  /// Decifra, como o motorista, o `content` de um evento publicado por mim.
  String? decifradoPeloMotorista(Map<String, dynamic> payload) =>
      MessageCipher().decryptFrom(
        motorista,
        eu.publicKey,
        payload['content'] as String,
      );

  /// Evento `20014` do motorista ([de]) para mim, com o recibo [recibo].
  Map<String, dynamic> eventoDeRecibo(
    Receipt recibo, {
    Identity? de,
    String? guidNaTag,
    String? paraNaTag,
    bool emClaro = false,
  }) {
    final autor = de ?? motorista;
    final json = jsonEncode(recibo.toJson());
    return eventoAssinado(
      autor: _par(autor),
      kind: receiptKind,
      content: emClaro
          ? json
          : MessageCipher().encryptFor(autor, eu.publicKey, json),
      tags: [
        prototypeMarkerTag,
        ['e', guidNaTag ?? recibo.guidCorrida],
        ['p', paraNaTag ?? eu.publicKey],
      ],
    );
  }

  /// Evento `20015` do motorista ([de]) para mim, confirmando [idRecibo].
  Map<String, dynamic> eventoDeConfirmacao({
    required String guid,
    required String idRecibo,
    Identity? de,
  }) {
    final autor = de ?? motorista;
    return eventoAssinado(
      autor: _par(autor),
      kind: receiptAckKind,
      content: MessageCipher().encryptFor(
        autor,
        eu.publicKey,
        jsonEncode({'id_recibo': idRecibo}),
      ),
      tags: [
        prototypeMarkerTag,
        ['e', guid],
        ['p', eu.publicKey],
      ],
    );
  }

  Future<void> fechar() async {
    await service.dispose();
    feed.dispose();
    await relayService.dispose();
  }
}

nostr.NostrKeyPairs _par(Identity i) =>
    nostr.NostrKeyPairs(private: i.privateKey);

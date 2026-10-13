import 'dart:async';
import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart' as nostr;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passenger/domain/accepted_ride.dart';
import 'package:latlong2/latlong.dart';
import 'package:passenger/domain/address_suggestion.dart';
import 'package:passenger/domain/identity.dart';
import 'package:passenger/domain/passenger_ride_status.dart';
import 'package:passenger/domain/payment_method.dart';
import 'package:passenger/domain/relay.dart';
import 'package:passenger/domain/received_quote.dart';
import 'package:passenger/domain/ride_rating.dart';
import 'package:passenger/screens/identidade_visual.dart';
import 'package:passenger/domain/service_state.dart';
import 'package:passenger/screens/map_screen.dart';
import 'package:passenger/services/background/background_service.dart';
import 'package:passenger/services/background/message_channel.dart';
import 'package:passenger/services/background/service_controller.dart';
import 'package:passenger/services/remote_relay_hub.dart';
import 'package:passenger/domain/destination_address.dart';
import 'package:passenger/services/accepted_ride_store.dart';
import 'package:passenger/services/destination_store.dart';
import 'package:passenger/services/event_feed.dart';
import 'package:passenger/services/location_service.dart';
import 'package:passenger/services/message_cipher.dart';
import 'package:passenger/services/nip44.dart';
import 'package:passenger/services/passenger_ride_state_store.dart';
import 'package:passenger/services/received_quote_store.dart';
import 'package:passenger/services/relay_service.dart';
import 'package:passenger/services/ride_rating_store.dart';
import 'package:passenger/services/route_service.dart';
import 'package:passenger/shared/prototype_marker.dart';

import '../support/event_fixtures.dart';
import '../support/fake_geocoding_service.dart';
import '../support/fake_location_service.dart';
import '../support/fake_relay_transport.dart';
import '../support/fake_route_service.dart';
import '../support/memory_channel.dart';

/// Dublê em memória: nenhum teste toca SQLite real (Princípio II por
/// analogia).
class FakeReceivedQuoteStore implements ReceivedQuoteStore {
  final salvos = <ReceivedQuote>[];

  @override
  Future<void> save(ReceivedQuote quote) async => salvos.add(quote);

  @override
  Future<List<ReceivedQuote>> byRequest(String requestId) async =>
      salvos.where((q) => q.requestId == requestId).toList();
}

/// Dublê em memória: nenhum teste toca SQLite real (feature 011).
class FakeRideRatingStore implements RideRatingStore {
  final salvos = <RideRating>[];

  @override
  Future<void> save(RideRating rating, Identity identity) async =>
      salvos.add(rating);

  @override
  Future<RideRating?> forRide(String rideId, Identity identity) async {
    for (final rating in salvos.reversed) {
      if (rating.rideId == rideId) return rating;
    }
    return null;
  }
}

/// Dublê em memória de `AcceptedRideStore` (feature 009) — `initial` permite
/// pré-carregar uma corrida já aceita, simulando um reinício do app.
class InMemoryAcceptedRideStore implements AcceptedRideStore {
  InMemoryAcceptedRideStore({this.initial});

  AcceptedRide? initial;
  int saveCount = 0;

  @override
  Future<AcceptedRide?> load() async => initial;

  @override
  Future<void> save(AcceptedRide ride) async {
    saveCount++;
    initial = ride;
  }
}

/// Dublê em memória de `DestinationStore` — `destino` permite pré-carregar um
/// destino salvo, simulando um reinício do app.
class InMemoryDestinationStore implements DestinationStore {
  InMemoryDestinationStore({this.destino});

  DestinationAddress? destino;
  int saveCount = 0;

  @override
  Future<DestinationAddress?> load() async => destino;

  @override
  Future<void> save(DestinationAddress? novo) async {
    saveCount++;
    destino = novo;
  }
}

/// Dublê em memória de `PassengerRideStateStore` (feature 014) — `status`/
/// `solicitacaoId` permitem pré-carregar um estado já em andamento,
/// simulando um reinício do app.
class InMemoryPassengerRideStateStore implements PassengerRideStateStore {
  InMemoryPassengerRideStateStore({
    this.status = PassengerRideStatus.inicial,
    this.solicitacaoId,
  });

  PassengerRideStatus status;
  String? solicitacaoId;
  int saveCount = 0;

  @override
  Future<(PassengerRideStatus, String?)> load() async =>
      (status, solicitacaoId);

  @override
  Future<void> save(PassengerRideStatus status, String? solicitacaoId) async {
    saveCount++;
    this.status = status;
    this.solicitacaoId = solicitacaoId;
  }
}

const _sugestaoLisboa = AddressSuggestion(
  id: 'R1',
  displayText: 'Lisboa, Portugal',
  latitude: 38.7077507,
  longitude: -9.1365919,
);
const _sugestaoAraranguaCentro = AddressSuggestion(
  id: 'W1',
  displayText: 'Rua das Flores, 123, Araranguá, Santa Catarina, Brasil',
  latitude: -28.9298,
  longitude: -49.4753,
);
const _sugestaoAraranguaBairro = AddressSuggestion(
  id: 'W2',
  displayText: 'Rua das Flores, 123, Araranguá, Santa Catarina, Brasil',
  latitude: -28.9350,
  longitude: -49.4800,
);

/// Digita [texto] e avança o tempo além do debounce (D3 de
/// `specs/005-busca-endereco-photon/research.md`), deixando a busca
/// correspondente concluir.
Future<void> _digitarEBuscar(WidgetTester tester, String texto) async {
  await tester.enterText(find.byType(TextField), texto);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

void main() {
  late FakeTransport transport;
  late RelayService relayService;
  late EventFeed eventFeed;
  late Identity identidade;

  setUp(() {
    transport = FakeTransport({});
    relayService = RelayService(
      transport: transport,
      connectTimeout: const Duration(milliseconds: 100),
      livenessTimeout: const Duration(milliseconds: 100),
    );
    eventFeed = EventFeed(
      relayService: relayService,
      acceptedKinds: const {
        1,
        rideQuoteKind,
        driverLocationKind,
        driverArrivalKind,
        meetingConfirmedKind,
        destinationArrivalKind,
        destinationConfirmedKind,
        rideRouteKind,
        rideCancelledKind,
        rideUnavailableKind,
      },
    );
    // Sem isto, EventFeed nunca ouve `relayService.messages` e as
    // confirmações OK da publicação nunca chegam (mesmo padrão de
    // `_iniciarRelays` em main.dart e de `Cenario.iniciar` em
    // test/event_feed_test.dart).
    eventFeed.start();
    final par = novoPar();
    identidade = Identity(publicKey: par.public, privateKey: par.private);
  });

  tearDown(() {
    eventFeed.dispose();
    return relayService.dispose();
  });

  /// Evento que o motorista publicaria ao passageiro (emenda 17): o `content`
  /// chega cifrado a [identidade] e a tag `p` do marcador de teste
  /// `pubkey-do-passageiro` vira a chave dele. [cifrarPara] e [emClaro] geram
  /// as variantes inválidas da regra de recepção 7.
  Map<String, dynamic> eventoDoMotorista({
    required nostr.NostrKeyPairs autor,
    String content = '',
    int kind = 20005,
    List<List<String>>? tags,
    DateTime? createdAt,
    String? cifrarPara,
    bool emClaro = false,
  }) => eventoAssinado(
    autor: autor,
    kind: kind,
    createdAt: createdAt,
    tags: tags == null
        ? null
        : [
            for (final t in tags)
              if (t.length >= 2 && t[0] == 'p' && t[1] == 'pubkey-do-passageiro')
                ['p', identidade.publicKey]
              else
                t,
          ],
    content: emClaro
        ? content
        : MessageCipher().encryptFor(
            Identity(publicKey: autor.public, privateKey: autor.private),
            cifrarPara ?? identidade.publicKey,
            content,
          ),
  );

  /// Monta `MapScreen` com os dublês da suíte, permitindo sobrescrever
  /// qualquer colaborador quando o cenário precisa de um trio
  /// relay/feed/identidade próprio (ex.: US1, que precisa de um relay
  /// conectado).
  Future<void> montar(
    WidgetTester tester, {
    LocationService? locationService,
    FakeGeocodingService? geocodingService,
    FakeRouteService? routeService,
    FakeReceivedQuoteStore? receivedQuoteStore,
    InMemoryAcceptedRideStore? acceptedRideStore,
    InMemoryDestinationStore? destinationStore,
    InMemoryPassengerRideStateStore? rideStateStore,
    FakeRideRatingStore? rideRatingStore,
    ServiceController? serviceController,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          serviceController: serviceController,
          locationService: locationService ?? FakeLocationService(),
          geocodingService: geocodingService ?? FakeGeocodingService(),
          eventFeed: eventFeed,
          identity: identidade,
          relayService: relayService,
          routeService: routeService ?? FakeRouteService(),
          receivedQuoteStore: receivedQuoteStore ?? FakeReceivedQuoteStore(),
          acceptedRideStore: acceptedRideStore ?? InMemoryAcceptedRideStore(),
          destinationStore: destinationStore ?? InMemoryDestinationStore(),
          rideStateStore:
              rideStateStore ?? InMemoryPassengerRideStateStore(),
          rideRatingStore: rideRatingStore ?? FakeRideRatingStore(),
        ),
      ),
    );
    await tester.pump();
  }

  /// Troca a árvore e monta uma `MapScreen` nova sobre as mesmas stores,
  /// simulando o reinício do app.
  Future<void> aoMontarNovamente(
    WidgetTester tester, {
    required InMemoryPassengerRideStateStore estado,
    required InMemoryAcceptedRideStore aceita,
  }) async {
    await tester.pumpWidget(const SizedBox());
    await montar(tester, rideStateStore: estado, acceptedRideStore: aceita);
    await tester.pump();
  }

  /// Aguarda a entrega de um evento injetado via
  /// `transport.conexoes[...].emitir(...)` até o `MapScreen`.
  ///
  /// `pumpAndSettle()` sozinho não basta aqui: a entrega atravessa três
  /// `StreamController` em cadeia (conexão → `RelayService` →
  /// `EventFeed`), e o `FlutterMap` desta tela mantém, ao mesmo tempo, um
  /// `TileLayer` buscando tiles por HTTP real — o relógio falso do
  /// `flutter_test` nunca avança o suficiente para os dois terminarem
  /// enquanto ainda há requisições HTTP em voo. `runAsync` sai do relógio
  /// falso e deixa o event loop real da VM processar tudo isso antes de
  /// medir o resultado.
  Future<void> esperarEntregaDoEvento(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();
  }

  /// Monta a tela, solicita uma corrida com sucesso e devolve o `id` do
  /// evento publicado — a solicitação "ativa" para os orçamentos.
  Future<String> montarComSolicitacaoAtiva(
    WidgetTester tester, {
    FakeRouteService? routeService,
    FakeReceivedQuoteStore? receivedQuoteStore,
    InMemoryDestinationStore? destinationStore,
    InMemoryAcceptedRideStore? acceptedRideStore,
    InMemoryPassengerRideStateStore? rideStateStore,
    FakeRideRatingStore? rideRatingStore,
    FakeLocationService? localizacao,
  }) async {
    await relayService.start([const Relay(url: 'wss://a.test')]);
    final locationService = localizacao ?? FakeLocationService();
    final geocoding = FakeGeocodingService(
      respostas: {
        'Lis': [_sugestaoLisboa],
      },
    );
    await montar(
      tester,
      locationService: locationService,
      geocodingService: geocoding,
      routeService: routeService,
      receivedQuoteStore: receivedQuoteStore,
      destinationStore: destinationStore,
      acceptedRideStore: acceptedRideStore,
      rideStateStore: rideStateStore,
      rideRatingStore: rideRatingStore,
    );

    locationService.emitir(posicaoDeTeste());
    await tester.pump();
    await _digitarEBuscar(tester, 'Lis');
    await tester.tap(find.text('Lisboa, Portugal'));
    await tester.pump();

    await tester.tap(find.text('Solicitar corrida'));
    await tester.pumpAndSettle();

    final enviada = transport.conexoes['wss://a.test']!.enviadas.firstWhere(
      (m) => m.startsWith('["EVENT"'),
    );
    final payload = (jsonDecode(enviada) as List)[1] as Map<String, dynamic>;
    return payload['id'] as String;
  }

  Map<String, dynamic> orcamentoDeTeste({
    required String requestId,
    nostr.NostrKeyPairs? autor,
    double total = 25.0,
    int? etaMinutes = 6,
  }) => eventoDoMotorista(
    autor: autor ?? novoPar(),
    kind: rideQuoteKind,
    content: jsonEncode({
      'pricePerKm': 2.5,
      'total': total,
      'driverName': 'Fulano da Silva',
      'carBrand': 'Fiat',
      'carModel': 'Palio',
      'carYear': 2018,
      'etaMinutes': ?etaMinutes,
    }),
    tags: [
      prototypeMarkerTag,
      ['e', requestId],
      ['p', 'pubkey-do-passageiro'],
    ],
  );

  /// Monta um payload de `kind: 20005` já assinado — a mesma localização
  /// que o motorista publicaria (emenda 08/10 do contrato), sob o mesmo
  /// [autor] de um orçamento já enviado, para que `driverPubkey` bata.
  Map<String, dynamic> localizacaoDeTeste({
    required nostr.NostrKeyPairs autor,
    required String quoteId,
    String passengerPubkey = 'pubkey-do-passageiro',
    double lat = -28.9312,
    double lon = -49.4889,
    String? content,
    DateTime? createdAt,
  }) => eventoDoMotorista(
    autor: autor,
    kind: driverLocationKind,
    createdAt: createdAt,
    content: content ?? jsonEncode({'lat': lat, 'lon': lon}),
    tags: [
      prototypeMarkerTag,
      ['e', quoteId],
      ['p', passengerPubkey],
    ],
  );

  /// Monta a tela, solicita uma corrida, recebe um orçamento de [autor] e o
  /// aceita — devolve o `id` do orçamento (`quoteId`) e o [autor], para que
  /// os testes da feature 009 possam publicar uma localização com a mesma
  /// assinatura.
  Future<({String quoteId, nostr.NostrKeyPairs autor})> montarComCorridaAceita(
    WidgetTester tester, {
    FakeRouteService? routeService,
    InMemoryDestinationStore? destinationStore,
    InMemoryAcceptedRideStore? acceptedRideStore,
    InMemoryPassengerRideStateStore? rideStateStore,
    FakeRideRatingStore? rideRatingStore,
    FakeLocationService? localizacao,
  }) async {
    final autor = novoPar();
    final requestId = await montarComSolicitacaoAtiva(
      tester,
      routeService: routeService,
      destinationStore: destinationStore,
      acceptedRideStore: acceptedRideStore,
      rideStateStore: rideStateStore,
      rideRatingStore: rideRatingStore,
      localizacao: localizacao,
    );
    final orcamento = orcamentoDeTeste(requestId: requestId, autor: autor);
    transport.conexoes['wss://a.test']!.emitir(mensagemEvent(orcamento));
    await esperarEntregaDoEvento(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Aceitar').first);
    await tester.pumpAndSettle();

    return (quoteId: orcamento['id'] as String, autor: autor);
  }

  /// Monta um payload de `kind: 20007` já assinado — a chegada do motorista
  /// ao ponto de encontro (emenda 09/11 do contrato, feature 010).
  Map<String, dynamic> chegadaMotoristaDeTeste({
    required nostr.NostrKeyPairs autor,
    required String quoteId,
    String passengerPubkey = 'pubkey-do-passageiro',
  }) => eventoDoMotorista(
    autor: autor,
    kind: driverArrivalKind,
    content: '',
    tags: [
      prototypeMarkerTag,
      ['e', quoteId],
      ['p', passengerPubkey],
    ],
  );

  /// Monta um payload de `kind: 20009` já assinado — a chegada ao destino
  /// (emenda 11 do contrato, feature 010).
  Map<String, dynamic> chegadaDestinoDeTeste({
    required nostr.NostrKeyPairs autor,
    required String quoteId,
    String passengerPubkey = 'pubkey-do-passageiro',
  }) => eventoDoMotorista(
    autor: autor,
    kind: destinationArrivalKind,
    content: '',
    tags: [
      prototypeMarkerTag,
      ['e', quoteId],
      ['p', passengerPubkey],
    ],
  );

  /// Faz a corrida aceita [resultado] avançar para `motoristaACaminho`
  /// (`kind: 20005`, feature 014) e fecha a modal "motorista a caminho"
  /// (feature 009) — pré-requisito real de `emCorrida`, que a
  /// chegada do motorista ao ponto de encontro (`kind: 20007`) exige desde
  /// a feature 014.
  Future<void> avisarMotoristaACaminho(
    WidgetTester tester,
    ({String quoteId, nostr.NostrKeyPairs autor}) resultado,
  ) async {
    transport.conexoes['wss://a.test']!.emitir(
      mensagemEvent(
        localizacaoDeTeste(autor: resultado.autor, quoteId: resultado.quoteId),
      ),
    );
    await esperarEntregaDoEvento(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();
  }

  /// Monta a tela com uma corrida aceita, entrega a localização do
  /// motorista (`kind: 20005`, via [avisarMotoristaACaminho]) e a chegada
  /// dele ao ponto de encontro (`kind: 20007`), e confirma o encontro pelo
  /// botão — deixa a corrida no estado esperado pelos testes de US2
  /// (`emCorrida`).
  Future<({String quoteId, nostr.NostrKeyPairs autor})>
  montarComEncontroConfirmado(
    WidgetTester tester, {
    FakeRouteService? routeService,
    FakeLocationService? localizacao,
    InMemoryDestinationStore? destinationStore,
    InMemoryAcceptedRideStore? acceptedRideStore,
    InMemoryPassengerRideStateStore? rideStateStore,
    FakeRideRatingStore? rideRatingStore,
  }) async {
    final resultado = await montarComCorridaAceita(
      tester,
      routeService: routeService,
      localizacao: localizacao,
      destinationStore: destinationStore,
      acceptedRideStore: acceptedRideStore,
      rideStateStore: rideStateStore,
      rideRatingStore: rideRatingStore,
    );
    await avisarMotoristaACaminho(tester, resultado);

    transport.conexoes['wss://a.test']!.emitir(
      mensagemEvent(
        chegadaMotoristaDeTeste(
          autor: resultado.autor,
          quoteId: resultado.quoteId,
        ),
      ),
    );
    await esperarEntregaDoEvento(tester);

    await tester.tap(
      find.widgetWithText(
        FilledButton,
        'Confirmo que encontrei o motorista',
      ),
    );
    await tester.pumpAndSettle();

    return resultado;
  }

  /// Botão "Confirmar chegada ao destino" (substituto da antiga modal).
  final botaoConfirmarDestino = find.byKey(
    const Key('botao-confirmar-destino'),
  );

  /// Move o GPS do passageiro para o destino pedido nos testes (Lisboa) ou
  /// para [deslocamentoLat] graus ao norte dele — 0,01° ≈ 1,1 km.
  Future<void> irParaODestino(
    WidgetTester tester,
    FakeLocationService gps, {
    double deslocamentoLat = 0,
  }) async {
    gps.emitir(
      posicaoDeTeste(
        lat: _sugestaoLisboa.latitude + deslocamentoLat,
        lng: _sugestaoLisboa.longitude,
      ),
    );
    // A entrega pelo stream broadcast leva um ciclo a mais que o `pump`.
    await tester.pump();
    await tester.pump();
  }

  /// Monta a tela com o encontro já confirmado, leva o passageiro ao raio do
  /// destino e confirma a chegada pelo botão — deixa a corrida no estado
  /// esperado pelos testes da feature 011 (modal de avaliação aberta).
  Future<({String quoteId, nostr.NostrKeyPairs autor})>
  montarComDestinoConfirmado(
    WidgetTester tester, {
    InMemoryAcceptedRideStore? acceptedRideStore,
    InMemoryPassengerRideStateStore? rideStateStore,
    FakeRideRatingStore? rideRatingStore,
  }) async {
    final gps = FakeLocationService();
    final resultado = await montarComEncontroConfirmado(
      tester,
      localizacao: gps,
      acceptedRideStore: acceptedRideStore,
      rideStateStore: rideStateStore,
      rideRatingStore: rideRatingStore,
    );
    await irParaODestino(tester, gps);

    await tester.tap(botaoConfirmarDestino);
    await tester.pumpAndSettle();

    return resultado;
  }

  group('MapScreen — posição e indisponibilidade (US1 da feature 004)', () {
    testWidgets('exibe o indicador de posição quando uma posição chega', (
      tester,
    ) async {
      final service = FakeLocationService();
      await montar(tester, locationService: service);

      expect(find.byIcon(Icons.person_pin_circle), findsNothing);

      service.emitir(posicaoDeTeste());
      await tester.pump();

      expect(find.byIcon(Icons.person_pin_circle), findsOneWidget);
    });

    testWidgets('posição recebida com o mapa nunca renderizado não lança', (
      tester,
    ) async {
      final service = FakeLocationService();
      // Reinício com solicitação ativa: a lista de orçamentos ocupa o lugar
      // do FlutterMap desde a primeira tela, e `MapController.camera` lança
      // enquanto ele não foi renderizado nenhuma vez.
      await montar(
        tester,
        locationService: service,
        rideStateStore: InMemoryPassengerRideStateStore(
          status: PassengerRideStatus.aguardandoOrcamentos,
          solicitacaoId: 'a' * 64,
        ),
      );

      service.emitir(posicaoDeTeste());
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'exibe mensagem compreensível quando a permissão é negada, sem travar',
      (tester) async {
        final service = FakeLocationService(
          permissionError: const LocationPermissionDenied(),
        );
        await montar(tester, locationService: service);
        await tester.pump();

        expect(
          find.textContaining('permitir o acesso à localização'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.person_pin_circle), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('exibe mensagem diferente quando a permissão foi negada '
        'permanentemente', (tester) async {
      final service = FakeLocationService(
        permissionError: const LocationPermissionDenied(permanently: true),
      );
      await montar(tester, locationService: service);
      await tester.pump();

      expect(find.textContaining('configurações do aparelho'), findsOneWidget);
    });

    testWidgets('exibe mensagem compreensível quando a localização se torna '
        'indisponível, sem travar', (tester) async {
      final service = FakeLocationService();
      await montar(tester, locationService: service);

      service.emitirErro(const LocationUnavailable('sinal perdido'));
      await tester.pump();

      expect(
        find.textContaining('Não foi possível obter sua localização'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('MapScreen — sugestões ao digitar (US1 da feature 005)', () {
    testWidgets(
      'sugestões aparecem depois do debounce, a partir de 3 caracteres',
      (tester) async {
        final geocoding = FakeGeocodingService(
          respostas: {
            'Lis': [_sugestaoLisboa],
          },
        );
        await montar(tester, geocodingService: geocoding);

        await tester.enterText(find.byType(TextField), 'Lis');
        // Antes do debounce expirar, nenhuma busca ainda ocorreu.
        await tester.pump(const Duration(milliseconds: 100));
        expect(geocoding.buscas, isEmpty);
        expect(find.text('Lisboa, Portugal'), findsNothing);

        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();

        expect(geocoding.buscas, ['Lis']);
        expect(find.text('Lisboa, Portugal'), findsOneWidget);
      },
    );

    testWidgets('menos de 3 caracteres não dispara busca', (tester) async {
      final geocoding = FakeGeocodingService();
      await montar(tester, geocodingService: geocoding);

      await _digitarEBuscar(tester, 'Li');

      expect(geocoding.buscas, isEmpty);
    });

    testWidgets('lista atualiza ao continuar digitando ou apagar parte do '
        'texto', (tester) async {
      final geocoding = FakeGeocodingService(
        respostas: {
          'Ara': [_sugestaoAraranguaCentro],
          'Araranguá': [_sugestaoAraranguaCentro, _sugestaoAraranguaBairro],
        },
      );
      await montar(tester, geocodingService: geocoding);

      await _digitarEBuscar(tester, 'Ara');
      expect(geocoding.buscas, ['Ara']);

      await _digitarEBuscar(tester, 'Araranguá');
      expect(geocoding.buscas, ['Ara', 'Araranguá']);
      // Duas sugestões distintas (ids diferentes), mesmo texto exibido
      // (Edge Case do spec.md — endereços homônimos).
      expect(
        find.text('Rua das Flores, 123, Araranguá, Santa Catarina, Brasil'),
        findsNWidgets(2),
      );
    });

    testWidgets('campo vazio não exibe nenhuma sugestão', (tester) async {
      final geocoding = FakeGeocodingService();
      await montar(tester, geocodingService: geocoding);

      await _digitarEBuscar(tester, '');

      expect(geocoding.buscas, isEmpty);
      expect(find.byType(ListTile), findsNothing);
    });
  });

  group('MapScreen — seleção define o destino (US2 da feature 005)', () {
    testWidgets(
      'tocar uma sugestão define o destino com o displayText exato dela e '
      'fecha a lista',
      (tester) async {
        final geocoding = FakeGeocodingService(
          respostas: {
            'Lis': [_sugestaoLisboa],
          },
        );
        await montar(tester, geocodingService: geocoding);

        await _digitarEBuscar(tester, 'Lis');
        expect(find.text('Lisboa, Portugal'), findsOneWidget);

        await tester.tap(find.text('Lisboa, Portugal'));
        await tester.pump();

        // O texto do campo passa a ser exatamente o displayText da
        // sugestão, mesmo diferindo do texto digitado ('Lis').
        expect(
          find.widgetWithText(TextField, 'Lisboa, Portugal'),
          findsOneWidget,
        );
        expect(find.byType(ListTile), findsNothing);
      },
    );

    testWidgets(
      'destino permanece o da última seleção ao editar o texto sem tocar '
      'outra sugestão; nova seleção substitui o destino anterior',
      (tester) async {
        final geocoding = FakeGeocodingService(
          respostas: {
            'Lis': [_sugestaoLisboa],
            'Ara': [_sugestaoAraranguaCentro],
          },
        );
        await montar(tester, geocodingService: geocoding);

        await _digitarEBuscar(tester, 'Lis');
        await tester.tap(find.text('Lisboa, Portugal'));
        await tester.pump();

        // Edita o texto de novo, sem ainda tocar em outra sugestão.
        await _digitarEBuscar(tester, 'Ara');
        expect(
          find.text('Rua das Flores, 123, Araranguá, Santa Catarina, Brasil'),
          findsOneWidget,
        );

        await tester.tap(
          find.text('Rua das Flores, 123, Araranguá, Santa Catarina, Brasil'),
        );
        await tester.pump();

        expect(
          find.widgetWithText(
            TextField,
            'Rua das Flores, 123, Araranguá, Santa Catarina, Brasil',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('digitar sem tocar nenhuma sugestão nunca registra destino '
        '(sem crash ao sair do campo)', (tester) async {
      final geocoding = FakeGeocodingService(
        respostas: {
          'Lis': [_sugestaoLisboa],
        },
      );
      await montar(tester, geocodingService: geocoding);

      await _digitarEBuscar(tester, 'Lis');
      expect(find.text('Lisboa, Portugal'), findsOneWidget);

      // O texto do campo continua sendo o digitado — não o da sugestão —
      // porque nada foi tocado.
      expect(find.widgetWithText(TextField, 'Lis'), findsOneWidget);
    });
  });

  group('MapScreen — sem resultado ou falha na busca (US3 da feature 005)', () {
    testWidgets('busca sem resultado mostra mensagem de "nenhum endereço '
        'encontrado"', (tester) async {
      final geocoding = FakeGeocodingService(respostas: {'xyzxyz': const []});
      await montar(tester, geocodingService: geocoding);

      await _digitarEBuscar(tester, 'xyzxyz');

      expect(find.textContaining('Nenhum endereço encontrado'), findsOneWidget);
    });

    testWidgets(
      'falha da busca mostra mensagem de falha sem travar a tela, e uma '
      'nova tentativa depois de editar o texto funciona',
      (tester) async {
        final geocoding = FakeGeocodingService(
          erros: {'sem rede': Exception('falha de rede')},
          respostas: {
            'com rede': [_sugestaoLisboa],
          },
        );
        await montar(tester, geocodingService: geocoding);

        await _digitarEBuscar(tester, 'sem rede');

        expect(
          find.textContaining('Não foi possível buscar endereços'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await _digitarEBuscar(tester, 'com rede');

        expect(find.text('Lisboa, Portugal'), findsOneWidget);
      },
    );
  });

  group('MapScreen — Edge Case: apagar o texto desfaz o destino (FR-012 da '
      'feature 005)', () {
    testWidgets(
      'apagar todo o texto depois de uma seleção volta ao estado "sem '
      'destino definido", sem nenhuma sugestão visível',
      (tester) async {
        final geocoding = FakeGeocodingService(
          respostas: {
            'Lis': [_sugestaoLisboa],
          },
        );
        await montar(tester, geocodingService: geocoding);

        await _digitarEBuscar(tester, 'Lis');
        await tester.tap(find.text('Lisboa, Portugal'));
        await tester.pump();

        await _digitarEBuscar(tester, '');

        expect(find.text('Para onde você quer ir?'), findsOneWidget);
        expect(find.byType(ListTile), findsNothing);
      },
    );
  });

  group('MapScreen — seletor de forma de pagamento (feature 006)', () {
    testWidgets('"Dinheiro" vem pré-selecionado', (tester) async {
      await montar(tester);

      final segmentado = tester.widget<SegmentedButton<PaymentMethod>>(
        find.byType(SegmentedButton<PaymentMethod>),
      );
      expect(segmentado.selected, {PaymentMethod.cash});
    });

    testWidgets('permite trocar para PIX', (tester) async {
      await montar(tester);

      await tester.tap(find.text('PIX'));
      await tester.pump();

      final segmentado = tester.widget<SegmentedButton<PaymentMethod>>(
        find.byType(SegmentedButton<PaymentMethod>),
      );
      expect(segmentado.selected, {PaymentMethod.pix});
    });
  });

  group(
    'MapScreen — Solicitar corrida com tudo disponível (US1 da feature 006)',
    () {
      testWidgets(
        'toca em "Solicitar corrida" publica a solicitação e confirma',
        (tester) async {
          await relayService.start([const Relay(url: 'wss://a.test')]);

          final locationService = FakeLocationService();
          final geocoding = FakeGeocodingService(
            respostas: {
              'Lis': [_sugestaoLisboa],
            },
          );
          await montar(
            tester,
            locationService: locationService,
            geocodingService: geocoding,
          );

          locationService.emitir(posicaoDeTeste());
          await tester.pump();

          await _digitarEBuscar(tester, 'Lis');
          await tester.tap(find.text('Lisboa, Portugal'));
          await tester.pump();

          await tester.tap(find.text('Solicitar corrida'));
          await tester.pumpAndSettle();

          expect(
            find.textContaining('Solicitação de corrida enviada'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'sem nenhum relay conectado, não publica nada e explica o motivo '
        '(FR-010)',
        (tester) async {
          // relayService nunca chama start(): nenhum relay é conectado.
          final locationService = FakeLocationService();
          final geocoding = FakeGeocodingService(
            respostas: {
              'Lis': [_sugestaoLisboa],
            },
          );
          await montar(
            tester,
            locationService: locationService,
            geocodingService: geocoding,
          );

          locationService.emitir(posicaoDeTeste());
          await tester.pump();

          await _digitarEBuscar(tester, 'Lis');
          await tester.tap(find.text('Lisboa, Portugal'));
          await tester.pump();

          await tester.tap(find.text('Solicitar corrida'));
          await tester.pump();

          expect(find.textContaining('Nenhum relay conectado'), findsOneWidget);
        },
      );
    },
  );

  group(
    'MapScreen — Tentar solicitar corrida sem destino (US2 da feature 006)',
    () {
      testWidgets(
        'campo de destino vazio: não publica nada e orienta a escolher '
        'destino',
        (tester) async {
          await relayService.start([const Relay(url: 'wss://a.test')]);
          final locationService = FakeLocationService();
          await montar(tester, locationService: locationService);

          locationService.emitir(posicaoDeTeste());
          await tester.pump();

          await tester.tap(find.text('Solicitar corrida'));
          await tester.pump();

          expect(find.textContaining('Escolha um destino'), findsOneWidget);
        },
      );

      testWidgets(
        'texto digitado sem seleção: mesmo efeito de destino ausente',
        (tester) async {
          await relayService.start([const Relay(url: 'wss://a.test')]);
          final locationService = FakeLocationService();
          final geocoding = FakeGeocodingService(
            respostas: {
              'Lis': [_sugestaoLisboa],
            },
          );
          await montar(
            tester,
            locationService: locationService,
            geocodingService: geocoding,
          );

          locationService.emitir(posicaoDeTeste());
          await tester.pump();

          await _digitarEBuscar(tester, 'Lis');

          await tester.tap(find.text('Solicitar corrida'));
          await tester.pump();

          expect(find.textContaining('Escolha um destino'), findsOneWidget);
        },
      );

      testWidgets(
        'selecionar e depois apagar o campo volta a se comportar como sem '
        'destino escolhido (Edge Case)',
        (tester) async {
          await relayService.start([const Relay(url: 'wss://a.test')]);
          final locationService = FakeLocationService();
          final geocoding = FakeGeocodingService(
            respostas: {
              'Lis': [_sugestaoLisboa],
            },
          );
          await montar(
            tester,
            locationService: locationService,
            geocodingService: geocoding,
          );

          locationService.emitir(posicaoDeTeste());
          await tester.pump();

          await _digitarEBuscar(tester, 'Lis');
          await tester.tap(find.text('Lisboa, Portugal'));
          await tester.pump();
          await _digitarEBuscar(tester, '');

          await tester.tap(find.text('Solicitar corrida'));
          await tester.pump();

          expect(find.textContaining('Escolha um destino'), findsOneWidget);
        },
      );
    },
  );

  group(
    'MapScreen — Tentar solicitar corrida sem posição atual (US3 da feature '
    '006)',
    () {
      testWidgets('sem nenhuma posição lida: não publica nada e explica a '
          'indisponibilidade', (tester) async {
        await relayService.start([const Relay(url: 'wss://a.test')]);
        final geocoding = FakeGeocodingService(
          respostas: {
            'Lis': [_sugestaoLisboa],
          },
        );
        // FakeLocationService que nunca emite posição.
        await montar(tester, geocodingService: geocoding);

        await _digitarEBuscar(tester, 'Lis');
        await tester.tap(find.text('Lisboa, Portugal'));
        await tester.pump();

        await tester.tap(find.text('Solicitar corrida'));
        await tester.pump();

        expect(
          find.textContaining('posição atual ainda não está disponível'),
          findsOneWidget,
        );
      });
    },
  );

  group('MapScreen — distância real até o destino (US1 da feature 007)', () {
    testWidgets(
      'exibe a distância quando destino e posição estão disponíveis',
      (tester) async {
        final locationService = FakeLocationService();
        final geocoding = FakeGeocodingService(
          respostas: {
            'Lis': [_sugestaoLisboa],
          },
        );
        final routeService = FakeRouteService();
        await montar(
          tester,
          locationService: locationService,
          geocodingService: geocoding,
          routeService: routeService,
        );

        locationService.emitir(posicaoDeTeste());
        await tester.pump();

        await _digitarEBuscar(tester, 'Lis');
        await tester.tap(find.text('Lisboa, Portugal'));
        await tester.pump();
        await tester.pump();

        expect(routeService.chamadas, hasLength(1));
        expect(find.textContaining('Distância:'), findsOneWidget);
      },
    );

    testWidgets(
      'trocar de destino dispara novo cálculo e substitui a distância '
      'exibida',
      (tester) async {
        final locationService = FakeLocationService();
        final geocoding = FakeGeocodingService(
          respostas: {
            'Lis': [_sugestaoLisboa],
            'Ara': [_sugestaoAraranguaCentro],
          },
        );
        final routeService = FakeRouteService();
        await montar(
          tester,
          locationService: locationService,
          geocodingService: geocoding,
          routeService: routeService,
        );

        locationService.emitir(posicaoDeTeste());
        await tester.pump();

        await _digitarEBuscar(tester, 'Lis');
        await tester.tap(find.text('Lisboa, Portugal'));
        await tester.pump();
        await tester.pump();
        expect(routeService.chamadas, hasLength(1));

        await _digitarEBuscar(tester, 'Ara');
        await tester.tap(
          find.text('Rua das Flores, 123, Araranguá, Santa Catarina, Brasil'),
        );
        await tester.pump();
        await tester.pump();

        expect(routeService.chamadas, hasLength(2));
        expect(
          routeService.chamadas.last.destination.latitude,
          closeTo(-28.9298, 1e-6),
        );
      },
    );

    testWidgets(
      'limpar o destino remove a distância exibida e o traçado no mapa '
      '(FR-005)',
      (tester) async {
        final locationService = FakeLocationService();
        final geocoding = FakeGeocodingService(
          respostas: {
            'Lis': [_sugestaoLisboa],
          },
        );
        await montar(
          tester,
          locationService: locationService,
          geocodingService: geocoding,
        );

        locationService.emitir(posicaoDeTeste());
        await tester.pump();
        await _digitarEBuscar(tester, 'Lis');
        await tester.tap(find.text('Lisboa, Portugal'));
        await tester.pump();
        await tester.pump();
        expect(find.textContaining('Distância:'), findsOneWidget);
        expect(find.byType(PolylineLayer), findsOneWidget);

        await _digitarEBuscar(tester, '');

        expect(find.textContaining('Distância:'), findsNothing);
        expect(find.byType(PolylineLayer), findsNothing);
        expect(find.textContaining('Calculando'), findsNothing);
      },
    );

    testWidgets(
      'recálculo só ocorre após deslocamento maior que 50 m da origem usada '
      'no último cálculo',
      (tester) async {
        final locationService = FakeLocationService();
        final geocoding = FakeGeocodingService(
          respostas: {
            'Lis': [_sugestaoLisboa],
          },
        );
        final routeService = FakeRouteService();
        await montar(
          tester,
          locationService: locationService,
          geocodingService: geocoding,
          routeService: routeService,
        );

        locationService.emitir(posicaoDeTeste());
        await tester.pump();
        await _digitarEBuscar(tester, 'Lis');
        await tester.tap(find.text('Lisboa, Portugal'));
        await tester.pump();
        await tester.pump();
        expect(routeService.chamadas, hasLength(1));

        // Deslocamento de ~0,1 m: abaixo do limiar, não recalcula.
        locationService.emitir(posicaoDeTeste(lat: -28.935001));
        await tester.pump();
        await tester.pump();
        expect(routeService.chamadas, hasLength(1));

        // Deslocamento de ~55 m (0,0005° de latitude): acima do limiar.
        locationService.emitir(posicaoDeTeste(lat: -28.9355));
        await tester.pump();
        await tester.pump();
        expect(routeService.chamadas, hasLength(2));
      },
    );
  });

  group('MapScreen — trajeto no mapa (US2 da feature 007)', () {
    testWidgets('desenha um Polyline com os pontos da rota calculada', (
      tester,
    ) async {
      final locationService = FakeLocationService();
      final geocoding = FakeGeocodingService(
        respostas: {
          'Lis': [_sugestaoLisboa],
        },
      );
      final routeService = FakeRouteService();
      await montar(
        tester,
        locationService: locationService,
        geocodingService: geocoding,
        routeService: routeService,
      );

      expect(find.byType(PolylineLayer), findsNothing);

      locationService.emitir(posicaoDeTeste());
      await tester.pump();
      await _digitarEBuscar(tester, 'Lis');
      await tester.tap(find.text('Lisboa, Portugal'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(PolylineLayer), findsOneWidget);
    });

    testWidgets(
      'trocar de destino substitui o Polyline anterior, sem acumular linhas',
      (tester) async {
        final locationService = FakeLocationService();
        final geocoding = FakeGeocodingService(
          respostas: {
            'Lis': [_sugestaoLisboa],
            'Ara': [_sugestaoAraranguaCentro],
          },
        );
        final routeService = FakeRouteService();
        await montar(
          tester,
          locationService: locationService,
          geocodingService: geocoding,
          routeService: routeService,
        );

        locationService.emitir(posicaoDeTeste());
        await tester.pump();
        await _digitarEBuscar(tester, 'Lis');
        await tester.tap(find.text('Lisboa, Portugal'));
        await tester.pump();
        await tester.pump();
        final antes = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
        expect(antes.polylines, hasLength(1));

        await _digitarEBuscar(tester, 'Ara');
        await tester.tap(
          find.text('Rua das Flores, 123, Araranguá, Santa Catarina, Brasil'),
        );
        await tester.pump();
        await tester.pump();
        final depois = tester.widget<PolylineLayer>(find.byType(PolylineLayer));

        expect(depois.polylines, hasLength(1));
        expect(
          depois.polylines.first.points,
          isNot(equals(antes.polylines.first.points)),
        );
      },
    );
  });

  group('MapScreen — falha no cálculo de rota (US3 da feature 007)', () {
    testWidgets(
      'falha no cálculo exibe indicação não bloqueante, sem exceção',
      (tester) async {
        final locationService = FakeLocationService();
        final geocoding = FakeGeocodingService(
          respostas: {
            'Lis': [_sugestaoLisboa],
          },
        );
        final routeService = FakeRouteService(
          erro: const RouteFailure('falha simulada'),
        );
        await montar(
          tester,
          locationService: locationService,
          geocodingService: geocoding,
          routeService: routeService,
        );

        locationService.emitir(posicaoDeTeste());
        await tester.pump();
        await _digitarEBuscar(tester, 'Lis');
        await tester.tap(find.text('Lisboa, Portugal'));
        await tester.pump();
        await tester.pump();

        expect(
          find.textContaining('Não foi possível calcular a distância'),
          findsOneWidget,
        );
        expect(find.byType(PolylineLayer), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('com falha no cálculo de rota, "Solicitar corrida" continua '
        'disponível e publica normalmente', (tester) async {
      await relayService.start([const Relay(url: 'wss://a.test')]);
      final locationService = FakeLocationService();
      final geocoding = FakeGeocodingService(
        respostas: {
          'Lis': [_sugestaoLisboa],
        },
      );
      final routeService = FakeRouteService(
        erro: const RouteFailure('falha simulada'),
      );
      await montar(
        tester,
        locationService: locationService,
        geocodingService: geocoding,
        routeService: routeService,
      );

      locationService.emitir(posicaoDeTeste());
      await tester.pump();
      await _digitarEBuscar(tester, 'Lis');
      await tester.tap(find.text('Lisboa, Portugal'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Solicitar corrida'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Solicitação de corrida enviada'),
        findsOneWidget,
      );
    });
  });

  group('MapScreen — receber orçamentos (US1/US2 da feature 008)', () {
    testWidgets(
      'orçamento referenciando a solicitação ativa aparece na tela de '
      'orçamentos com os dados esperados (feature 015: tela substitui a '
      'modal)',
      (tester) async {
        final requestId = await montarComSolicitacaoAtiva(tester);

        transport.conexoes['wss://a.test']!.emitir(
          mensagemEvent(orcamentoDeTeste(requestId: requestId)),
        );
        await esperarEntregaDoEvento(tester);

        expect(find.text('Orçamentos recebidos'), findsOneWidget);
        expect(
          find.textContaining('Fulano da Silva — Fiat Palio 2018'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Total: R\$ 25.00 · 6 min estimados'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'segundo orçamento da mesma solicitação é adicionado à lista já '
      'exibida, sem substituir o primeiro',
      (tester) async {
        final requestId = await montarComSolicitacaoAtiva(tester);

        transport.conexoes['wss://a.test']!.emitir(
          mensagemEvent(orcamentoDeTeste(requestId: requestId, total: 25.0)),
        );
        await esperarEntregaDoEvento(tester);
        transport.conexoes['wss://a.test']!.emitir(
          mensagemEvent(orcamentoDeTeste(requestId: requestId, total: 30.0)),
        );
        await esperarEntregaDoEvento(tester);

        expect(find.textContaining('Total: R\$ 25.00'), findsOneWidget);
        expect(find.textContaining('Total: R\$ 30.00'), findsOneWidget);
      },
    );

    testWidgets(
      'orçamento de outra solicitação não é persistido nem adicionado à '
      'lista (a tela de orçamentos em si já está visível desde a '
      'solicitação, feature 015)',
      (tester) async {
        final store = FakeReceivedQuoteStore();
        await montarComSolicitacaoAtiva(tester, receivedQuoteStore: store);

        transport.conexoes['wss://a.test']!.emitir(
          mensagemEvent(orcamentoDeTeste(requestId: 'outra-solicitacao')),
        );
        await esperarEntregaDoEvento(tester);

        expect(find.textContaining('Aguardando orçamentos'), findsOneWidget);
        expect(store.salvos, isEmpty);
      },
    );

    testWidgets(
      'aceitar publica aceitação para o escolhido e recusa para os demais, '
      'e fecha a modal',
      (tester) async {
        final requestId = await montarComSolicitacaoAtiva(tester);

        final orcamento1 = orcamentoDeTeste(requestId: requestId, total: 25.0);
        final orcamento2 = orcamentoDeTeste(requestId: requestId, total: 30.0);
        transport.conexoes['wss://a.test']!.emitir(mensagemEvent(orcamento1));
        await esperarEntregaDoEvento(tester);
        transport.conexoes['wss://a.test']!.emitir(mensagemEvent(orcamento2));
        await esperarEntregaDoEvento(tester);

        await tester.tap(find.widgetWithText(FilledButton, 'Aceitar').first);
        await tester.pumpAndSettle();

        final publicados = transport.conexoes['wss://a.test']!.enviadas
            .where((m) => m.startsWith('["EVENT"'))
            .map((m) => (jsonDecode(m) as List)[1] as Map<String, dynamic>)
            .where(
              (p) =>
                  p['kind'] == quoteAcceptedKind ||
                  p['kind'] == quoteRejectedKind,
            )
            .toList();

        expect(
          publicados.where((p) => p['kind'] == quoteAcceptedKind),
          hasLength(1),
        );
        expect(
          publicados.where((p) => p['kind'] == quoteRejectedKind),
          hasLength(1),
        );
        expect(find.text('Orçamentos recebidos'), findsNothing);
      },
    );

    testWidgets(
      'sem relay conectado ao aceitar, informa a falha sem fechar a modal',
      (tester) async {
        final requestId = await montarComSolicitacaoAtiva(tester);
        transport.conexoes['wss://a.test']!.emitir(
          mensagemEvent(orcamentoDeTeste(requestId: requestId)),
        );
        await esperarEntregaDoEvento(tester);

        // `dispose()` não marca o relay como indisponível (só desliga a
        // conexão, sem efeito em `hasAnyConnected`); simula a queda pelo
        // mesmo caminho real de uma desconexão de rede.
        transport.conexoes['wss://a.test']!.derrubar();
        await tester.pump(const Duration(milliseconds: 20));

        await tester.tap(find.widgetWithText(FilledButton, 'Aceitar').first);
        await tester.pumpAndSettle();

        expect(find.text('Orçamentos recebidos'), findsOneWidget);
        expect(find.textContaining('Nenhum relay conectado'), findsOneWidget);
      },
    );

    testWidgets(
      'depois de aceito, um orçamento novo da mesma solicitação é '
      'persistido mas não reabre a modal nem gera recusa automática',
      (tester) async {
        final store = FakeReceivedQuoteStore();
        final requestId = await montarComSolicitacaoAtiva(
          tester,
          receivedQuoteStore: store,
        );

        transport.conexoes['wss://a.test']!.emitir(
          mensagemEvent(orcamentoDeTeste(requestId: requestId)),
        );
        await esperarEntregaDoEvento(tester);

        await tester.tap(find.widgetWithText(FilledButton, 'Aceitar').first);
        await tester.pumpAndSettle();
        expect(find.text('Orçamentos recebidos'), findsNothing);

        final antesDoNovo = transport.conexoes['wss://a.test']!.enviadas
            .length;
        transport.conexoes['wss://a.test']!.emitir(
          mensagemEvent(orcamentoDeTeste(requestId: requestId, total: 99.0)),
        );
        await esperarEntregaDoEvento(tester);

        expect(
          find.text('Orçamentos recebidos'),
          findsNothing,
          reason: 'não reabre a modal depois da decisão',
        );
        expect(store.salvos, hasLength(2), reason: 'ainda é persistido');
        expect(
          transport.conexoes['wss://a.test']!.enviadas.length,
          antesDoNovo,
          reason: 'nenhuma recusa automática nova é publicada',
        );
      },
    );
  });

  group(
    'MapScreen — notificar que o motorista está a caminho (US1 da feature '
    '009)',
    () {
      testWidgets(
        'aceitar um orçamento grava AcceptedRide (quoteId, driverPubkey) e '
        'transiciona o estado para orcamentoAceito (FR-006 da feature 009; '
        'FR-004 da feature 014)',
        (tester) async {
          final acceptedRideStore = InMemoryAcceptedRideStore();
          final rideStateStore = InMemoryPassengerRideStateStore();
          final resultado = await montarComCorridaAceita(
            tester,
            acceptedRideStore: acceptedRideStore,
            rideStateStore: rideStateStore,
          );

          final aceita = await acceptedRideStore.load();
          expect(aceita, isNotNull);
          expect(aceita!.quoteId, resultado.quoteId);
          expect(aceita.driverPubkey, resultado.autor.public);
          expect(rideStateStore.status, PassengerRideStatus.orcamentoAceito);
        },
      );

      testWidgets(
        'localização do motorista aceito exibe a modal "Motorista a '
        'caminho" (FR-001, FR-002)',
        (tester) async {
          final resultado = await montarComCorridaAceita(tester);

          transport.conexoes['wss://a.test']!.emitir(
            mensagemEvent(
              localizacaoDeTeste(
                autor: resultado.autor,
                quoteId: resultado.quoteId,
              ),
            ),
          );
          await esperarEntregaDoEvento(tester);

          expect(find.text('Motorista a caminho'), findsOneWidget);
          expect(find.text('OK'), findsOneWidget);
        },
      );

      testWidgets('tocar "OK" fecha a modal (FR-003)', (tester) async {
        final resultado = await montarComCorridaAceita(tester);
        transport.conexoes['wss://a.test']!.emitir(
          mensagemEvent(
            localizacaoDeTeste(
              autor: resultado.autor,
              quoteId: resultado.quoteId,
            ),
          ),
        );
        await esperarEntregaDoEvento(tester);
        expect(find.text('Motorista a caminho'), findsOneWidget);

        await tester.tap(find.widgetWithText(FilledButton, 'OK'));
        await tester.pumpAndSettle();

        expect(find.text('Motorista a caminho'), findsNothing);
      });

      testWidgets(
        'uma segunda localização do mesmo motorista não reabre a modal '
        '(FR-004)',
        (tester) async {
          final resultado = await montarComCorridaAceita(tester);
          transport.conexoes['wss://a.test']!.emitir(
            mensagemEvent(
              localizacaoDeTeste(
                autor: resultado.autor,
                quoteId: resultado.quoteId,
              ),
            ),
          );
          await esperarEntregaDoEvento(tester);
          await tester.tap(find.widgetWithText(FilledButton, 'OK'));
          await tester.pumpAndSettle();

          transport.conexoes['wss://a.test']!.emitir(
            mensagemEvent(
              localizacaoDeTeste(
                autor: resultado.autor,
                quoteId: resultado.quoteId,
              ),
            ),
          );
          await esperarEntregaDoEvento(tester);

          expect(find.text('Motorista a caminho'), findsNothing);
        },
      );

      testWidgets(
        'localização de um motorista diferente do aceito (quoteId de um '
        'orçamento que não foi o escolhido) não exibe modal (FR-005, '
        'SC-003)',
        (tester) async {
          await montarComCorridaAceita(tester);

          // Mesmo edge case do spec.md: um motorista que já tinha enviado
          // orçamento antes da decisão — quoteId próprio, diferente do
          // aceito, por ser um evento kind 20002 distinto.
          transport.conexoes['wss://a.test']!.emitir(
            mensagemEvent(
              localizacaoDeTeste(
                autor: novoPar(),
                quoteId: 'quote-nao-escolhido',
              ),
            ),
          );
          await esperarEntregaDoEvento(tester);

          expect(find.text('Motorista a caminho'), findsNothing);
        },
      );

      testWidgets(
        'localização recebida sem nenhuma corrida aceita não exibe modal '
        '(FR-005)',
        (tester) async {
          await relayService.start([const Relay(url: 'wss://a.test')]);
          await montar(tester);

          transport.conexoes['wss://a.test']!.emitir(
            mensagemEvent(
              localizacaoDeTeste(autor: novoPar(), quoteId: 'quote-qualquer'),
            ),
          );
          await esperarEntregaDoEvento(tester);

          expect(find.text('Motorista a caminho'), findsNothing);
        },
      );

      testWidgets(
        'com o estado pré-carregado em motoristaACaminho (reinício após já '
        'ter avisado), uma nova localização não reabre a modal (FR-007 da '
        'feature 009; FR-010 da feature 014)',
        (tester) async {
          final autor = novoPar();
          const quoteId = 'quote-de-antes-do-reinicio';
          final acceptedRideStore = InMemoryAcceptedRideStore(
            initial: AcceptedRide(quoteId: quoteId, driverPubkey: autor.public),
          );
          final rideStateStore = InMemoryPassengerRideStateStore(
            status: PassengerRideStatus.motoristaACaminho,
          );
          await relayService.start([const Relay(url: 'wss://a.test')]);
          await montar(
            tester,
            acceptedRideStore: acceptedRideStore,
            rideStateStore: rideStateStore,
          );

          transport.conexoes['wss://a.test']!.emitir(
            mensagemEvent(
              localizacaoDeTeste(autor: autor, quoteId: quoteId),
            ),
          );
          await esperarEntregaDoEvento(tester);

          expect(find.text('Motorista a caminho'), findsNothing);
        },
      );
    },
  );

  group(
    'MapScreen — confirmar encontro com o motorista (US1 da feature 010)',
    () {
      testWidgets(
        'chegada do motorista da corrida aceita exibe "Motorista chegou" '
        '(FR-001, FR-002)',
        (tester) async {
          final resultado = await montarComCorridaAceita(tester);
          await avisarMotoristaACaminho(tester, resultado);

          transport.conexoes['wss://a.test']!.emitir(
            mensagemEvent(
              chegadaMotoristaDeTeste(
                autor: resultado.autor,
                quoteId: resultado.quoteId,
              ),
            ),
          );
          await esperarEntregaDoEvento(tester);

          expect(find.text('Motorista chegou'), findsOneWidget);
          expect(
            find.text('Confirmo que encontrei o motorista'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'tocar o botão publica kind 20008 com as tags corretas e fecha a '
        'modal (FR-003)',
        (tester) async {
          final resultado = await montarComCorridaAceita(tester);
          await avisarMotoristaACaminho(tester, resultado);
          transport.conexoes['wss://a.test']!.emitir(
            mensagemEvent(
              chegadaMotoristaDeTeste(
                autor: resultado.autor,
                quoteId: resultado.quoteId,
              ),
            ),
          );
          await esperarEntregaDoEvento(tester);

          await tester.tap(
            find.widgetWithText(
              FilledButton,
              'Confirmo que encontrei o motorista',
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Motorista chegou'), findsNothing);
          final publicado = transport.conexoes['wss://a.test']!.enviadas
              .map((m) => jsonDecode(m) as List)
              .where((d) => d.first == 'EVENT')
              .map((d) => d[1] as Map<String, dynamic>)
              .firstWhere((p) => p['kind'] == meetingConfirmedKind);
          final tags = (publicado['tags'] as List<dynamic>)
              .map(
                (t) => (t as List<dynamic>).map((e) => e.toString()).toList(),
              )
              .toList();
          expect(tags, anyElement(equals(['e', resultado.quoteId])));
          expect(tags, anyElement(equals(['p', resultado.autor.public])));
        },
      );

      testWidgets(
        'chegadas repetidas (emenda 20) abrem uma única tela; depois de '
        'confirmar, as seguintes não a reabrem',
        (tester) async {
          final resultado = await montarComCorridaAceita(tester);
          await avisarMotoristaACaminho(tester, resultado);

          for (var i = 0; i < 3; i++) {
            transport.conexoes['wss://a.test']!.emitir(
              mensagemEvent(
                chegadaMotoristaDeTeste(
                  autor: resultado.autor,
                  quoteId: resultado.quoteId,
                ),
              ),
            );
            await esperarEntregaDoEvento(tester);
          }
          expect(find.text('Motorista chegou'), findsOneWidget);

          await tester.tap(
            find.widgetWithText(
              FilledButton,
              'Confirmo que encontrei o motorista',
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Motorista chegou'), findsNothing);

          transport.conexoes['wss://a.test']!.emitir(
            mensagemEvent(
              chegadaMotoristaDeTeste(
                autor: resultado.autor,
                quoteId: resultado.quoteId,
              ),
            ),
          );
          await esperarEntregaDoEvento(tester);

          expect(find.text('Motorista chegou'), findsNothing);
        },
      );

      testWidgets(
        'falha ao cifrar: nenhum kind 20008 é transmitido e a modal segue '
        'aberta, sem sair de "motorista chegou" (FR-004 da feature 022)',
        (tester) async {
          final cifra = _CifraQueFalhaQuandoPedido();
          eventFeed.dispose();
          eventFeed = EventFeed(
            relayService: relayService,
            acceptedKinds: const {
              1,
              rideQuoteKind,
              driverLocationKind,
              driverArrivalKind,
              meetingConfirmedKind,
              destinationArrivalKind,
              destinationConfirmedKind,
              rideRouteKind,
              rideCancelledKind,
              rideUnavailableKind,
            },
            cipher: cifra,
          )..start();
          final resultado = await montarComCorridaAceita(tester);
          await avisarMotoristaACaminho(tester, resultado);
          transport.conexoes['wss://a.test']!.emitir(
            mensagemEvent(
              chegadaMotoristaDeTeste(
                autor: resultado.autor,
                quoteId: resultado.quoteId,
              ),
            ),
          );
          await esperarEntregaDoEvento(tester);

          cifra.falha = true; // a aceitação já foi enviada; só a próxima falha
          await tester.tap(
            find.widgetWithText(
              FilledButton,
              'Confirmo que encontrei o motorista',
            ),
          );
          await tester.pumpAndSettle();

          final enviados = transport.conexoes['wss://a.test']!.enviadas
              .map((m) => jsonDecode(m) as List)
              .where((d) => d.first == 'EVENT')
              .map((d) => d[1] as Map<String, dynamic>);
          expect(enviados.where((p) => p['kind'] == meetingConfirmedKind),
              isEmpty);
          expect(find.text('Motorista chegou'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'uma segunda chegada do motorista (reentrega), com a modal já '
        'exibida, não reabre (FR-004)',
        (tester) async {
          final resultado = await montarComCorridaAceita(tester);
          await avisarMotoristaACaminho(tester, resultado);
          transport.conexoes['wss://a.test']!.emitir(
            mensagemEvent(
              chegadaMotoristaDeTeste(
                autor: resultado.autor,
                quoteId: resultado.quoteId,
              ),
            ),
          );
          await esperarEntregaDoEvento(tester);
          await tester.tap(
            find.widgetWithText(
              FilledButton,
              'Confirmo que encontrei o motorista',
            ),
          );
          await tester.pumpAndSettle();

          transport.conexoes['wss://a.test']!.emitir(
            mensagemEvent(
              chegadaMotoristaDeTeste(
                autor: resultado.autor,
                quoteId: resultado.quoteId,
              ),
            ),
          );
          await esperarEntregaDoEvento(tester);

          expect(find.text('Motorista chegou'), findsNothing);
        },
      );

      testWidgets(
        'chegada de um motorista diferente do aceito não exibe modal '
        '(FR-009)',
        (tester) async {
          await montarComCorridaAceita(tester);

          transport.conexoes['wss://a.test']!.emitir(
            mensagemEvent(
              chegadaMotoristaDeTeste(
                autor: novoPar(),
                quoteId: 'quote-nao-escolhido',
              ),
            ),
          );
          await esperarEntregaDoEvento(tester);

          expect(find.text('Motorista chegou'), findsNothing);
        },
      );

      testWidgets(
        'sem relay conectado ao tocar o botão, a modal permanece aberta com '
        'mensagem de falha',
        (tester) async {
          final resultado = await montarComCorridaAceita(tester);
          await avisarMotoristaACaminho(tester, resultado);
          transport.conexoes['wss://a.test']!.emitir(
            mensagemEvent(
              chegadaMotoristaDeTeste(
                autor: resultado.autor,
                quoteId: resultado.quoteId,
              ),
            ),
          );
          await esperarEntregaDoEvento(tester);

          transport.conexoes['wss://a.test']!.derrubar();
          await tester.pump(const Duration(milliseconds: 20));

          await tester.tap(
            find.widgetWithText(
              FilledButton,
              'Confirmo que encontrei o motorista',
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Motorista chegou'), findsOneWidget);
          expect(
            find.textContaining('Nenhum relay conectado'),
            findsOneWidget,
          );
        },
      );
    },
  );

  group(
    'MapScreen — confirmar chegada ao destino por botão (US2 da feature 010)',
    () {
      testWidgets('em corrida, com o passageiro a mais de 1 km do destino, não '
          'há botão', (tester) async {
        final gps = FakeLocationService();
        await montarComEncontroConfirmado(tester, localizacao: gps);
        await irParaODestino(tester, gps, deslocamentoLat: 0.012);

        expect(botaoConfirmarDestino, findsNothing);
      });

      testWidgets('em corrida, com o passageiro a 1 km ou menos do destino, o '
          'botão aparece e não há modal', (tester) async {
        final gps = FakeLocationService();
        await montarComEncontroConfirmado(tester, localizacao: gps);
        await irParaODestino(tester, gps, deslocamentoLat: 0.008);

        expect(botaoConfirmarDestino, findsOneWidget);
        expect(find.text('Confirmar chegada ao destino'), findsOneWidget);
        expect(find.text('Chegamos ao destino'), findsNothing);
      });

      testWidgets('o botão some quando o passageiro volta a sair do raio', (
        tester,
      ) async {
        final gps = FakeLocationService();
        await montarComEncontroConfirmado(tester, localizacao: gps);
        await irParaODestino(tester, gps);
        expect(botaoConfirmarDestino, findsOneWidget);

        await irParaODestino(tester, gps, deslocamentoLat: 0.02);

        expect(botaoConfirmarDestino, findsNothing);
      });

      testWidgets('antes do encontro confirmado não há botão, mesmo no raio', (
        tester,
      ) async {
        final gps = FakeLocationService();
        await montarComCorridaAceita(tester, localizacao: gps);
        await irParaODestino(tester, gps);

        expect(botaoConfirmarDestino, findsNothing);
      });

      testWidgets('tocar o botão publica kind 20010 com as tags corretas e '
          'abre a avaliação (FR-007)', (tester) async {
        final resultado = await montarComDestinoConfirmado(tester);

        expect(botaoConfirmarDestino, findsNothing);
        expect(find.text('Avalie a corrida'), findsOneWidget);
        final publicado = transport.conexoes['wss://a.test']!.enviadas
            .map((m) => jsonDecode(m) as List)
            .where((d) => d.first == 'EVENT')
            .map((d) => d[1] as Map<String, dynamic>)
            .firstWhere((p) => p['kind'] == destinationConfirmedKind);
        final tags = (publicado['tags'] as List<dynamic>)
            .map((t) => (t as List<dynamic>).map((e) => e.toString()).toList())
            .toList();
        expect(tags, anyElement(equals(['e', resultado.quoteId])));
        expect(tags, anyElement(equals(['p', resultado.autor.public])));
      });

      testWidgets('o aviso de chegada do motorista (kind 20009) não abre modal '
          'nem mostra o botão fora do raio', (tester) async {
        final resultado = await montarComEncontroConfirmado(tester);

        transport.conexoes['wss://a.test']!.emitir(
          mensagemEvent(
            chegadaDestinoDeTeste(
              autor: resultado.autor,
              quoteId: resultado.quoteId,
            ),
          ),
        );
        await esperarEntregaDoEvento(tester);

        expect(find.text('Chegamos ao destino'), findsNothing);
        expect(botaoConfirmarDestino, findsNothing);
      });
    },
  );

  group('MapScreen — destino persistido (constituição 2.16.0)', () {
    testWidgets('selecionar uma sugestão grava o destino no armazenamento', (
      tester,
    ) async {
      final store = InMemoryDestinationStore();
      await montar(
        tester,
        destinationStore: store,
        geocodingService: FakeGeocodingService(
          respostas: {
            'Lis': [_sugestaoLisboa],
          },
        ),
      );
      await _digitarEBuscar(tester, 'Lis');
      await tester.tap(find.text('Lisboa, Portugal'));
      await tester.pump();

      expect(store.destino?.text, 'Lisboa, Portugal');
      expect(store.destino?.latitude, _sugestaoLisboa.latitude);
      expect(store.destino?.longitude, _sugestaoLisboa.longitude);
    });

    testWidgets('apagar o campo de destino apaga o destino salvo', (
      tester,
    ) async {
      final store = InMemoryDestinationStore(
        destino: DestinationAddress(
          'Lisboa, Portugal',
          latitude: _sugestaoLisboa.latitude,
          longitude: _sugestaoLisboa.longitude,
        ),
      );
      await montar(tester, destinationStore: store);
      await tester.pump();

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      expect(store.destino, isNull);
    });

    testWidgets('ao abrir o app, o destino salvo volta ao campo', (
      tester,
    ) async {
      final store = InMemoryDestinationStore(
        destino: DestinationAddress(
          'Lisboa, Portugal',
          latitude: _sugestaoLisboa.latitude,
          longitude: _sugestaoLisboa.longitude,
        ),
      );
      await montar(tester, destinationStore: store);
      await tester.pump();

      final campo = tester.widget<TextField>(find.byType(TextField));
      expect(campo.controller?.text, 'Lisboa, Portugal');
    });

    testWidgets('sem destino salvo, o campo abre vazio', (tester) async {
      await montar(tester);
      await tester.pump();

      final campo = tester.widget<TextField>(find.byType(TextField));
      expect(campo.controller?.text, isEmpty);
    });

    testWidgets('reiniciar o app em "Em corrida" mantém o botão de chegada '
        'ao destino, pelo destino salvo', (tester) async {
      final destino = InMemoryDestinationStore();
      final aceita = InMemoryAcceptedRideStore();
      final estado = InMemoryPassengerRideStateStore();
      await montarComEncontroConfirmado(
        tester,
        destinationStore: destino,
        acceptedRideStore: aceita,
        rideStateStore: estado,
      );
      expect(destino.destino, isNotNull);

      final gps = FakeLocationService();
      await tester.pumpWidget(const SizedBox());
      await montar(
        tester,
        locationService: gps,
        destinationStore: destino,
        acceptedRideStore: aceita,
        rideStateStore: estado,
      );
      await tester.pump();
      await irParaODestino(tester, gps);

      expect(botaoConfirmarDestino, findsOneWidget);
    });
  });

  group('MapScreen — avaliar corrida (US1 da feature 011)', () {
    testWidgets(
      'confirmar a chegada ao destino exibe a tela de avaliação, com cinco '
      'estrelas e nenhuma pré-selecionada (FR-001, FR-002)',
      (tester) async {
        await montarComDestinoConfirmado(tester);

        expect(find.text('Avalie a corrida'), findsOneWidget);
        expect(find.byIcon(Icons.star), findsNothing);
        expect(find.byIcon(Icons.star_border), findsNWidgets(5));
      },
    );

    testWidgets(
      'tocar na estrela de posição N seleciona as estrelas 1..N e nenhuma '
      'das demais (FR-003)',
      (tester) async {
        await montarComDestinoConfirmado(tester);

        await tester.tap(find.byIcon(Icons.star_border).at(2));
        await tester.pump();

        expect(find.byIcon(Icons.star), findsNWidgets(3));
        expect(find.byIcon(Icons.star_border), findsNWidgets(2));
      },
    );

    testWidgets(
      'selecionar uma nota e confirmar persiste a avaliação associada ao '
      'quoteId da corrida e fecha a tela (FR-004, FR-005)',
      (tester) async {
        final store = FakeRideRatingStore();
        final resultado = await montarComDestinoConfirmado(
          tester,
          rideRatingStore: store,
        );

        await tester.tap(find.byIcon(Icons.star_border).at(2));
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
        await tester.pumpAndSettle();

        expect(find.text('Avalie a corrida'), findsNothing);
        expect(store.salvos, hasLength(1));
        expect(store.salvos.single.rideId, resultado.quoteId);
        expect(store.salvos.single.stars, 3);
      },
    );

    testWidgets(
      'pular a avaliação fecha a tela sem persistir nenhuma nota (FR-008)',
      (tester) async {
        final store = FakeRideRatingStore();
        await montarComDestinoConfirmado(tester, rideRatingStore: store);

        await tester.tap(find.widgetWithText(TextButton, 'Pular'));
        await tester.pumpAndSettle();

        expect(find.text('Avalie a corrida'), findsNothing);
        expect(store.salvos, isEmpty);
      },
    );
  });

  group('MapScreen — estado único de corrida do passageiro (feature 014)', () {
    testWidgets(
      'ao abrir sem nada persistido, o estado é inicial e nenhuma modal de '
      'corrida aparece (FR-002, US1 cenário 1-2)',
      (tester) async {
        final rideStateStore = InMemoryPassengerRideStateStore();
        await montar(tester, rideStateStore: rideStateStore);

        expect(rideStateStore.status, PassengerRideStatus.inicial);
        expect(find.text('Orçamentos recebidos'), findsNothing);
        expect(find.text('Motorista a caminho'), findsNothing);
        expect(find.text('Motorista chegou'), findsNothing);
        expect(find.text('Chegamos ao destino'), findsNothing);
        expect(find.text('Avalie a corrida'), findsNothing);
      },
    );

    testWidgets(
      'com o estado persistido em orcamentoAceito mas sem AcceptedRide '
      'correspondente, o app trata como corrompido e volta a inicial (D5 de '
      'research.md, FR-009)',
      (tester) async {
        final rideStateStore = InMemoryPassengerRideStateStore(
          status: PassengerRideStatus.orcamentoAceito,
        );
        await relayService.start([const Relay(url: 'wss://a.test')]);
        final locationService = FakeLocationService();
        final geocoding = FakeGeocodingService(
          respostas: {
            'Lis': [_sugestaoLisboa],
          },
        );
        await montar(
          tester,
          locationService: locationService,
          geocodingService: geocoding,
          rideStateStore: rideStateStore,
        );
        await tester.pump();

        expect(rideStateStore.status, PassengerRideStatus.inicial);

        // A reconciliação libera "Solicitar corrida" normalmente — se o
        // app tivesse ficado em orcamentoAceito, a guarda de
        // PassengerRideRules.canRequestRide bloquearia com outra mensagem.
        locationService.emitir(posicaoDeTeste());
        await tester.pump();
        await _digitarEBuscar(tester, 'Lis');
        await tester.tap(find.text('Lisboa, Portugal'));
        await tester.pump();
        await tester.tap(find.text('Solicitar corrida'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Solicitação de corrida enviada'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'solicitar corrida com sucesso transiciona para aguardandoOrcamentos, '
      'persistindo (status, solicitacaoId) (FR-003)',
      (tester) async {
        final rideStateStore = InMemoryPassengerRideStateStore();
        await relayService.start([const Relay(url: 'wss://a.test')]);
        final locationService = FakeLocationService();
        final geocoding = FakeGeocodingService(
          respostas: {
            'Lis': [_sugestaoLisboa],
          },
        );
        await montar(
          tester,
          locationService: locationService,
          geocodingService: geocoding,
          rideStateStore: rideStateStore,
        );

        locationService.emitir(posicaoDeTeste());
        await tester.pump();
        await _digitarEBuscar(tester, 'Lis');
        await tester.tap(find.text('Lisboa, Portugal'));
        await tester.pump();
        await tester.tap(find.text('Solicitar corrida'));
        await tester.pumpAndSettle();

        expect(rideStateStore.status, PassengerRideStatus.aguardandoOrcamentos);
        expect(rideStateStore.solicitacaoId, isNotNull);
      },
    );

    // O teste que existia aqui ("tentar solicitar uma segunda corrida com
    // uma já em andamento é impedido") ficou impossível de exercitar pela
    // UI depois da feature 015: o painel de solicitação (com o botão
    // "Solicitar corrida") passou a ficar oculto em qualquer fase além de
    // `inicial` (FR-001/FR-002 daquela feature), então não há mais como
    // tocar o botão estando em `aguardandoOrcamentos` para provocar a
    // mensagem "Já existe uma corrida em andamento". A guarda
    // `PassengerRideRules.canRequestRide` continua coberta por
    // `test/domain/passenger_ride_status_test.dart`; a garantia de
    // visibilidade do painel é testada no grupo "feature 015" abaixo.

    testWidgets(
      'a primeira localização do motorista transiciona o estado para '
      'motoristaACaminho (FR-005)',
      (tester) async {
        final rideStateStore = InMemoryPassengerRideStateStore();
        final resultado = await montarComCorridaAceita(
          tester,
          rideStateStore: rideStateStore,
        );

        transport.conexoes['wss://a.test']!.emitir(
          mensagemEvent(
            localizacaoDeTeste(
              autor: resultado.autor,
              quoteId: resultado.quoteId,
            ),
          ),
        );
        await esperarEntregaDoEvento(tester);

        expect(rideStateStore.status, PassengerRideStatus.motoristaACaminho);
      },
    );

    testWidgets(
      'confirmar o encontro transiciona o estado para emCorrida '
      '(FR-006)',
      (tester) async {
        final rideStateStore = InMemoryPassengerRideStateStore();
        await montarComEncontroConfirmado(
          tester,
          rideStateStore: rideStateStore,
        );

        expect(rideStateStore.status, PassengerRideStatus.emCorrida);
      },
    );

    testWidgets(
      'confirmar o destino transiciona o estado para '
      'destinoConfirmadoAguardandoAvaliacao (FR-007)',
      (tester) async {
        final rideStateStore = InMemoryPassengerRideStateStore();
        await montarComDestinoConfirmado(
          tester,
          rideStateStore: rideStateStore,
        );

        expect(
          rideStateStore.status,
          PassengerRideStatus.destinoConfirmadoAguardandoAvaliacao,
        );
      },
    );

    testWidgets(
      'um orçamento (kind: 20002) recebido depois que a solicitação já foi '
      'decidida não altera o estado corrente (FR-010, Edge Case 2)',
      (tester) async {
        final rideStateStore = InMemoryPassengerRideStateStore();
        final requestId = await montarComSolicitacaoAtiva(
          tester,
          rideStateStore: rideStateStore,
        );
        transport.conexoes['wss://a.test']!.emitir(
          mensagemEvent(orcamentoDeTeste(requestId: requestId)),
        );
        await esperarEntregaDoEvento(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Aceitar').first);
        await tester.pumpAndSettle();
        expect(rideStateStore.status, PassengerRideStatus.orcamentoAceito);

        transport.conexoes['wss://a.test']!.emitir(
          mensagemEvent(orcamentoDeTeste(requestId: requestId, total: 99.0)),
        );
        await esperarEntregaDoEvento(tester);

        expect(rideStateStore.status, PassengerRideStatus.orcamentoAceito);
      },
    );

    testWidgets(
      'confirmar a avaliação a partir de '
      'destinoConfirmadoAguardandoAvaliacao volta o estado a inicial '
      '(FR-008, US3 cenário 1)',
      (tester) async {
        final rideStateStore = InMemoryPassengerRideStateStore();
        await montarComDestinoConfirmado(tester, rideStateStore: rideStateStore);

        await tester.tap(find.byIcon(Icons.star_border).at(2));
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
        await tester.pumpAndSettle();

        expect(rideStateStore.status, PassengerRideStatus.inicial);
      },
    );

    testWidgets(
      'pular a avaliação a partir de destinoConfirmadoAguardandoAvaliacao '
      'volta o estado a inicial (FR-008, US3 cenário 2)',
      (tester) async {
        final rideStateStore = InMemoryPassengerRideStateStore();
        await montarComDestinoConfirmado(tester, rideStateStore: rideStateStore);

        await tester.tap(find.widgetWithText(TextButton, 'Pular'));
        await tester.pumpAndSettle();

        expect(rideStateStore.status, PassengerRideStatus.inicial);
      },
    );

    testWidgets(
      'depois do retorno a inicial, solicitar uma nova corrida funciona '
      'normalmente, sem resquício da corrida anterior (SC-003)',
      (tester) async {
        final rideStateStore = InMemoryPassengerRideStateStore();
        await montarComDestinoConfirmado(tester, rideStateStore: rideStateStore);
        await tester.tap(find.widgetWithText(TextButton, 'Pular'));
        await tester.pumpAndSettle();
        // Dissipa a SnackBar da solicitação original ("Solicitação de
        // corrida enviada…", 6 s) — senão ela absorve o toque no botão,
        // que fica na mesma região da tela.
        await tester.pump(const Duration(seconds: 7));
        await tester.pumpAndSettle();

        // Mesma tela ainda montada: posição, relay e o destino escolhido em
        // `montarComSolicitacaoAtiva` seguem disponíveis — nenhum resquício
        // do estado anterior impede uma nova solicitação completa.
        await tester.tap(find.text('Solicitar corrida'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Já existe uma corrida em andamento'),
          findsNothing,
        );
        expect(
          find.textContaining('Solicitação de corrida enviada'),
          findsOneWidget,
        );
        expect(
          rideStateStore.status,
          PassengerRideStatus.aguardandoOrcamentos,
        );
      },
    );
  });

  group(
    'MapScreen — tela de orçamentos recebidos e cancelamento (feature 015)',
    () {
      testWidgets(
        'painel de solicitação some assim que a corrida sai da fase '
        'inicial (US1, FR-001, FR-002)',
        (tester) async {
          await montarComSolicitacaoAtiva(tester);

          expect(find.text('Solicitar corrida'), findsNothing);
        },
      );

      testWidgets(
        'painel de solicitação continua ausente em orcamentoAceito (US1, '
        'FR-002)',
        (tester) async {
          await montarComCorridaAceita(tester);

          expect(find.text('Solicitar corrida'), findsNothing);
        },
      );

      testWidgets(
        'solicitar corrida exibe a tela de orçamentos vazia, com '
        '"Cancelar" visível (US2, FR-003)',
        (tester) async {
          await montarComSolicitacaoAtiva(tester);

          expect(find.text('Orçamentos recebidos'), findsOneWidget);
          expect(find.textContaining('Aguardando orçamentos'), findsOneWidget);
          expect(find.widgetWithText(FilledButton, 'Cancelar'), findsOneWidget);
        },
      );

      testWidgets(
        'reiniciar o app com aguardandoOrcamentos persistido restaura os '
        'orçamentos já recebidos, em vez de mostrar a lista vazia (US2, '
        'FR-012)',
        (tester) async {
          final store = FakeReceivedQuoteStore();
          final requestId = await montarComSolicitacaoAtiva(
            tester,
            receivedQuoteStore: store,
          );
          transport.conexoes['wss://a.test']!.emitir(
            mensagemEvent(orcamentoDeTeste(requestId: requestId)),
          );
          await esperarEntregaDoEvento(tester);
          expect(
            find.textContaining('Fulano da Silva — Fiat Palio 2018'),
            findsOneWidget,
          );

          // Simula o reinício: remonta a tela com o mesmo store (já
          // persistiu o orçamento) e o mesmo status/solicitacaoId.
          final rideStateStore = InMemoryPassengerRideStateStore(
            status: PassengerRideStatus.aguardandoOrcamentos,
            solicitacaoId: requestId,
          );
          await montar(
            tester,
            receivedQuoteStore: store,
            rideStateStore: rideStateStore,
          );

          expect(find.text('Orçamentos recebidos'), findsOneWidget);
          expect(
            find.textContaining('Fulano da Silva — Fiat Palio 2018'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'cancelar com a lista vazia volta à fase inicial, sem publicar '
        'nenhuma recusa (US3, FR-009, cenário 3 do spec.md)',
        (tester) async {
          final rideStateStore = InMemoryPassengerRideStateStore();
          await montarComSolicitacaoAtiva(
            tester,
            rideStateStore: rideStateStore,
          );
          final publicadasAntes =
              transport.conexoes['wss://a.test']!.enviadas.length;
          // Dissipa a SnackBar da solicitação ("Solicitação de corrida
          // enviada…", 6 s) — senão ela absorve o toque em "Cancelar", que
          // fica na mesma região da tela (mesmo motivo já registrado na
          // feature 014).
          await tester.pump(const Duration(seconds: 7));
          await tester.pumpAndSettle();

          await tester.tap(find.widgetWithText(FilledButton, 'Cancelar'));
          await tester.pumpAndSettle();

          expect(find.text('Orçamentos recebidos'), findsNothing);
          expect(find.text('Solicitar corrida'), findsOneWidget);
          expect(rideStateStore.status, PassengerRideStatus.inicial);
          expect(
            transport.conexoes['wss://a.test']!.enviadas.length,
            publicadasAntes,
          );
        },
      );

      testWidgets(
        'cancelar com orçamentos recebidos publica uma recusa para cada '
        'um e volta à fase inicial (US3, FR-010, SC-003)',
        (tester) async {
          final rideStateStore = InMemoryPassengerRideStateStore();
          final requestId = await montarComSolicitacaoAtiva(
            tester,
            rideStateStore: rideStateStore,
          );
          transport.conexoes['wss://a.test']!.emitir(
            mensagemEvent(orcamentoDeTeste(requestId: requestId, total: 25.0)),
          );
          await esperarEntregaDoEvento(tester);
          transport.conexoes['wss://a.test']!.emitir(
            mensagemEvent(orcamentoDeTeste(requestId: requestId, total: 30.0)),
          );
          await esperarEntregaDoEvento(tester);
          // Dissipa a SnackBar da solicitação, mesmo motivo do teste
          // anterior.
          await tester.pump(const Duration(seconds: 7));
          await tester.pumpAndSettle();

          await tester.tap(find.widgetWithText(FilledButton, 'Cancelar'));
          await tester.pumpAndSettle();

          final recusas = transport.conexoes['wss://a.test']!.enviadas
              .where((m) => m.startsWith('["EVENT"'))
              .map((m) => (jsonDecode(m) as List)[1] as Map<String, dynamic>)
              .where((p) => p['kind'] == quoteRejectedKind)
              .toList();
          expect(recusas, hasLength(2));
          expect(find.text('Orçamentos recebidos'), findsNothing);
          expect(rideStateStore.status, PassengerRideStatus.inicial);
        },
      );

      testWidgets(
        'depois de cancelar, uma nova solicitação funciona normalmente '
        '(US3, SC-004)',
        (tester) async {
          final rideStateStore = InMemoryPassengerRideStateStore();
          await montarComSolicitacaoAtiva(
            tester,
            rideStateStore: rideStateStore,
          );
          // Dissipa a SnackBar da solicitação original, mesmo motivo já
          // registrado no teste de retorno a inicial da feature 014 —
          // senão ela absorve o toque em "Cancelar" logo abaixo.
          await tester.pump(const Duration(seconds: 7));
          await tester.pumpAndSettle();

          await tester.tap(find.widgetWithText(FilledButton, 'Cancelar'));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Solicitar corrida'));
          await tester.pumpAndSettle();

          expect(
            find.textContaining('Solicitação de corrida enviada'),
            findsOneWidget,
          );
          expect(
            rideStateStore.status,
            PassengerRideStatus.aguardandoOrcamentos,
          );
        },
      );
    },
  );

  group('MapScreen — posição do motorista no mapa (feature 016)', () {
    const passageiro = LatLng(-28.935, -49.49); // posicaoDeTeste()
    const motorista = LatLng(-28.9312, -49.4889); // localizacaoDeTeste()
    final t0 = DateTime.utc(2026, 9, 30, 12);

    final carro = find.byIcon(Icons.directions_car);

    Iterable<Marker> marcadores(WidgetTester tester) => tester
        .widgetList<MarkerLayer>(find.byType(MarkerLayer))
        .expand((camada) => camada.markers);

    bool temMarcadorEm(WidgetTester tester, LatLng ponto) =>
        marcadores(tester).any((m) => m.point == ponto);

    LatLng centro(WidgetTester tester) => tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .camera
        .center;

    Future<void> entregar(
      WidgetTester tester,
      Map<String, dynamic> payload,
    ) async {
      transport.conexoes['wss://a.test']!.emitir(mensagemEvent(payload));
      await esperarEntregaDoEvento(tester);
    }

    Future<void> fecharAvisoDoMotorista(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();
    }

    group('exibição (US1)', () {
      testWidgets(
        'a localização que leva a "motorista a caminho" já mostra o marcador '
        'no ponto recebido (FR-001, FR-002)',
        (tester) async {
          final r = await montarComCorridaAceita(tester);
          expect(carro, findsNothing);

          await entregar(
            tester,
            localizacaoDeTeste(autor: r.autor, quoteId: r.quoteId),
          );

          expect(find.text('Motorista a caminho'), findsOneWidget);
          expect(carro, findsOneWidget);
          expect(temMarcadorEm(tester, motorista), isTrue);
        },
      );

      testWidgets(
        'uma localização mais nova move o marcador sem duplicá-lo; mais '
        'antiga, igual ou repetida não o move (FR-003, FR-008)',
        (tester) async {
          final r = await montarComCorridaAceita(tester);
          await entregar(
            tester,
            localizacaoDeTeste(
              autor: r.autor,
              quoteId: r.quoteId,
              createdAt: t0,
            ),
          );
          await fecharAvisoDoMotorista(tester);

          const novo = LatLng(-28.9300, -49.4880);
          await entregar(
            tester,
            localizacaoDeTeste(
              autor: r.autor,
              quoteId: r.quoteId,
              lat: novo.latitude,
              lon: novo.longitude,
              createdAt: t0.add(const Duration(seconds: 5)),
            ),
          );
          expect(carro, findsOneWidget);
          expect(temMarcadorEm(tester, novo), isTrue);
          expect(temMarcadorEm(tester, motorista), isFalse);

          // Mais antiga (t0 + 1 s) e igual (t0 + 5 s): ignoradas.
          for (final instante in [1, 5]) {
            await entregar(
              tester,
              localizacaoDeTeste(
                autor: r.autor,
                quoteId: r.quoteId,
                lat: -28.9,
                lon: -49.4,
                createdAt: t0.add(Duration(seconds: instante)),
              ),
            );
            expect(temMarcadorEm(tester, novo), isTrue);
          }

          // O mesmo evento entregue de novo: tratado uma vez.
          final repetida = localizacaoDeTeste(
            autor: r.autor,
            quoteId: r.quoteId,
            lat: -28.8,
            lon: -49.3,
            createdAt: t0.add(const Duration(seconds: 10)),
          );
          await entregar(tester, repetida);
          expect(temMarcadorEm(tester, const LatLng(-28.8, -49.3)), isTrue);
          await entregar(tester, repetida);
          // Sempre um só marcador do motorista (+ o do passageiro); o
          // widget do carro pode estar fora da área visível, por isso a
          // contagem é feita nos dados da camada.
          expect(marcadores(tester), hasLength(2));
        },
      );

      testWidgets(
        'após reinício em "motorista a caminho" não há marcador até a '
        'próxima localização (FR-009)',
        (tester) async {
          final autor = novoPar();
          const quoteId = 'quote-de-antes-do-reinicio';
          await relayService.start([const Relay(url: 'wss://a.test')]);
          await montar(
            tester,
            acceptedRideStore: InMemoryAcceptedRideStore(
              initial: AcceptedRide(
                quoteId: quoteId,
                driverPubkey: autor.public,
              ),
            ),
            rideStateStore: InMemoryPassengerRideStateStore(
              status: PassengerRideStatus.motoristaACaminho,
            ),
          );
          expect(carro, findsNothing);

          await entregar(
            tester,
            localizacaoDeTeste(autor: autor, quoteId: quoteId),
          );

          expect(carro, findsOneWidget);
          expect(find.text('Motorista a caminho'), findsNothing);
        },
      );

      testWidgets(
        'conteúdo malformado não cria marcador nem erro, mas ainda é o '
        'sinal de que o motorista saiu (FR-008, FR-011)',
        (tester) async {
          final r = await montarComCorridaAceita(tester);

          for (final content in [
            'não é json',
            '{"lat": -28.9}',
            '{"lat": 91, "lon": -49.4}',
            '{"lat": "x", "lon": -49.4}',
          ]) {
            await entregar(
              tester,
              localizacaoDeTeste(
                autor: r.autor,
                quoteId: r.quoteId,
                content: content,
              ),
            );
            expect(carro, findsNothing, reason: content);
            expect(tester.takeException(), isNull);
          }

          expect(
            find.text('Motorista a caminho'),
            findsOneWidget,
            reason: 'a primeira, mesmo malformada, causou a transição',
          );
        },
      );

      testWidgets(
        'o aviso "motorista a caminho" aparece uma vez por corrida e o "OK" '
        'funciona com o marcador na tela (FR-011)',
        (tester) async {
          final r = await montarComCorridaAceita(tester);
          await entregar(
            tester,
            localizacaoDeTeste(
              autor: r.autor,
              quoteId: r.quoteId,
              createdAt: t0,
            ),
          );
          expect(find.text('Motorista a caminho'), findsOneWidget);

          await fecharAvisoDoMotorista(tester);
          expect(find.text('Motorista a caminho'), findsNothing);
          expect(carro, findsOneWidget);

          await entregar(
            tester,
            localizacaoDeTeste(
              autor: r.autor,
              quoteId: r.quoteId,
              lat: -28.93,
              lon: -49.48,
              createdAt: t0.add(const Duration(seconds: 5)),
            ),
          );
          expect(find.text('Motorista a caminho'), findsNothing);
        },
      );
    });

    group('seguir o motorista (feature 017)', () {
      Future<void> posicao(
        WidgetTester tester,
        ({String quoteId, nostr.NostrKeyPairs autor}) r,
        LatLng ponto,
        int segundos,
      ) => entregar(
        tester,
        localizacaoDeTeste(
          autor: r.autor,
          quoteId: r.quoteId,
          lat: ponto.latitude,
          lon: ponto.longitude,
          createdAt: t0.add(Duration(seconds: segundos)),
        ),
      );

      testWidgets(
        'centraliza no motorista a cada posição nova, mantém o zoom e o GPS '
        'do passageiro não move a câmera (US1, FR-001 a FR-003)',
        (tester) async {
          final gps = FakeLocationService();
          final r = await montarComCorridaAceita(tester, localizacao: gps);
          expect(centro(tester), passageiro);

          await posicao(tester, r, motorista, 0);
          await fecharAvisoDoMotorista(tester);
          expect(centro(tester), motorista);

          final zoom = tester
              .widget<FlutterMap>(find.byType(FlutterMap))
              .mapController!
              .camera
              .zoom;

          gps.emitir(posicaoDeTeste(lat: -28.9351));
          await tester.pump();
          await tester.pump();
          expect(centro(tester), motorista);

          const novo = LatLng(-28.9300, -49.4880);
          await posicao(tester, r, novo, 5);
          expect(centro(tester), novo);
          expect(
            tester
                .widget<FlutterMap>(find.byType(FlutterMap))
                .mapController!
                .camera
                .zoom,
            zoom,
          );
        },
      );

      testWidgets(
        'posição inválida, repetida ou mais antiga não move a câmera (FR-001)',
        (tester) async {
          final r = await montarComCorridaAceita(tester);
          await posicao(tester, r, motorista, 10);
          await fecharAvisoDoMotorista(tester);

          await posicao(tester, r, const LatLng(-28.9, -49.4), 1); // antiga
          expect(centro(tester), motorista);
          await posicao(tester, r, const LatLng(-28.9, -49.4), 10); // igual
          expect(centro(tester), motorista);
          await entregar(
            tester,
            localizacaoDeTeste(
              autor: r.autor,
              quoteId: r.quoteId,
              content: 'não é json',
              createdAt: t0.add(const Duration(seconds: 20)),
            ),
          );
          expect(centro(tester), motorista);
        },
      );

      testWidgets(
        '10 posições consecutivas, sem gesto algum no mapa, terminam com o '
        'centro na décima (SC-004)',
        (tester) async {
          final r = await montarComCorridaAceita(tester);
          await posicao(tester, r, motorista, 0);
          await fecharAvisoDoMotorista(tester);

          var ultimo = motorista;
          for (var i = 1; i <= 9; i++) {
            ultimo = LatLng(motorista.latitude + i * 0.0005, motorista.longitude);
            await posicao(tester, r, ultimo, i * 5);
            expect(centro(tester), ultimo);
          }
        },
      );

      testWidgets(
        'em "motorista a caminho" sem posição válida do motorista o GPS '
        'ainda move o mapa (FR-005)',
        (tester) async {
          final gps = FakeLocationService();
          final r = await montarComCorridaAceita(tester, localizacao: gps);
          // Conteúdo malformado: dispara "motorista a caminho" sem posição.
          await entregar(
            tester,
            localizacaoDeTeste(
              autor: r.autor,
              quoteId: r.quoteId,
              content: 'não é json',
            ),
          );
          await fecharAvisoDoMotorista(tester);
          expect(carro, findsNothing);

          gps.emitir(posicaoDeTeste(lat: -28.9351));
          await tester.pump();
          await tester.pump();
          expect(centro(tester), const LatLng(-28.9351, -49.49));
        },
      );

      testWidgets(
        'reaberto já em "motorista a caminho", a primeira posição do '
        'motorista centraliza o mapa nele',
        (tester) async {
          final autor = novoPar();
          const quoteId = 'quote-de-antes-do-reinicio';
          await relayService.start([const Relay(url: 'wss://a.test')]);
          await montar(
            tester,
            acceptedRideStore: InMemoryAcceptedRideStore(
              initial: AcceptedRide(
                quoteId: quoteId,
                driverPubkey: autor.public,
              ),
            ),
            rideStateStore: InMemoryPassengerRideStateStore(
              status: PassengerRideStatus.motoristaACaminho,
            ),
          );

          await entregar(
            tester,
            localizacaoDeTeste(autor: autor, quoteId: quoteId, createdAt: t0),
          );
          expect(centro(tester), motorista);
        },
      );

      testWidgets(
        'o botão "Centralizar" não existe em "motorista a caminho", nem '
        'depois de arrastar o mapa; a próxima posição devolve a câmera ao '
        'motorista (US2, FR-004)',
        (tester) async {
          final r = await montarComCorridaAceita(tester);
          expect(find.byIcon(Icons.my_location), findsNothing);

          await posicao(tester, r, motorista, 0);
          await fecharAvisoDoMotorista(tester);
          expect(find.byIcon(Icons.my_location), findsNothing);

          await tester.drag(find.byType(FlutterMap), const Offset(200, 0));
          await tester.pump();
          expect(centro(tester), isNot(motorista));
          expect(find.byIcon(Icons.my_location), findsNothing);

          const novo = LatLng(-28.9300, -49.4880);
          await posicao(tester, r, novo, 5);
          expect(centro(tester), novo);
          expect(find.byIcon(Icons.my_location), findsNothing);
        },
      );
    });

    group('mesmo símbolo do app do motorista (US2)', () {
      testWidgets(
        'círculo de 44 px, fundo, borda branca de 2 px e ícone de carro em '
        'destaque; distinto do marcador do passageiro (FR-004, FR-012)',
        (tester) async {
          final r = await montarComCorridaAceita(tester);
          await entregar(
            tester,
            localizacaoDeTeste(autor: r.autor, quoteId: r.quoteId),
          );

          final marcador = marcadores(tester)
              .singleWhere((m) => m.point == motorista);
          expect(marcador.width, 44);
          expect(marcador.height, 44);

          final container = tester.widget<Container>(
            find.ancestor(of: carro, matching: find.byType(Container)).first,
          );
          final decoracao = container.decoration! as BoxDecoration;
          expect(decoracao.shape, BoxShape.circle);
          expect(decoracao.color, IdentidadeVisual.fundo);
          final borda = decoracao.border! as Border;
          expect(borda.top.color, Colors.white);
          expect(borda.top.width, 2);

          final icone = tester.widget<Icon>(carro);
          expect(icone.color, IdentidadeVisual.destaque);
          expect(icone.size, 24);

          // O marcador do próprio passageiro segue sendo outro.
          expect(find.byIcon(Icons.person_pin_circle), findsOneWidget);
          expect(temMarcadorEm(tester, passageiro), isTrue);
        },
      );
    });

    group('só o motorista certo, só no momento certo (US3)', () {
      testWidgets(
        'localização assinada por outra chave, mesmo referenciando a corrida, '
        'não cria marcador nem causa a transição (FR-005)',
        (tester) async {
          final r = await montarComCorridaAceita(tester);

          await entregar(
            tester,
            localizacaoDeTeste(autor: novoPar(), quoteId: r.quoteId),
          );

          expect(carro, findsNothing);
          expect(find.text('Motorista a caminho'), findsNothing);
          expect(find.byIcon(Icons.my_location), findsNothing);
        },
      );

      testWidgets('localização de outra corrida é ignorada', (tester) async {
        final r = await montarComCorridaAceita(tester);

        await entregar(
          tester,
          localizacaoDeTeste(autor: r.autor, quoteId: 'outra-corrida'),
        );

        expect(carro, findsNothing);
        expect(find.text('Motorista a caminho'), findsNothing);
      });

      testWidgets(
        'em "motorista a caminho" uma localização de outra chave não move o '
        'marcador',
        (tester) async {
          final r = await montarComCorridaAceita(tester);
          await entregar(
            tester,
            localizacaoDeTeste(
              autor: r.autor,
              quoteId: r.quoteId,
              createdAt: t0,
            ),
          );
          await fecharAvisoDoMotorista(tester);

          await entregar(
            tester,
            localizacaoDeTeste(
              autor: novoPar(),
              quoteId: r.quoteId,
              lat: -28.9,
              lon: -49.4,
              createdAt: t0.add(const Duration(seconds: 10)),
            ),
          );

          expect(temMarcadorEm(tester, motorista), isTrue);
          expect(temMarcadorEm(tester, const LatLng(-28.9, -49.4)), isFalse);
        },
      );

      testWidgets(
        'o marcador some ao confirmar o encontro, não volta com novas '
        'localizações, e o mapa volta a seguir o passageiro (FR-006)',
        (tester) async {
          final gps = FakeLocationService();
          final r = await montarComCorridaAceita(tester, localizacao: gps);
          await entregar(
            tester,
            localizacaoDeTeste(
              autor: r.autor,
              quoteId: r.quoteId,
              createdAt: t0,
            ),
          );
          await fecharAvisoDoMotorista(tester);
          expect(carro, findsOneWidget);

          await entregar(
            tester,
            chegadaMotoristaDeTeste(autor: r.autor, quoteId: r.quoteId),
          );
          await tester.tap(
            find.widgetWithText(
              FilledButton,
              'Confirmo que encontrei o motorista',
            ),
          );
          await tester.pumpAndSettle();

          expect(carro, findsNothing);
          expect(find.byIcon(Icons.my_location), findsNothing);

          await entregar(
            tester,
            localizacaoDeTeste(
              autor: r.autor,
              quoteId: r.quoteId,
              createdAt: t0.add(const Duration(seconds: 10)),
            ),
          );
          expect(carro, findsNothing);

          gps.emitir(posicaoDeTeste(lat: -28.9355));
          await tester.pump();
          await tester.pump();
          expect(centro(tester), const LatLng(-28.9355, -49.49));
        },
      );

      testWidgets(
        'em orçamento aceito (antes de qualquer localização) não há marcador',
        (tester) async {
          await montarComCorridaAceita(tester);
          expect(carro, findsNothing);
        },
      );
    });
  });

  group('MapScreen — rota do motorista no mapa (feature 018)', () {
    const rotaRecebida = [
      LatLng(-28.9312, -49.4889),
      LatLng(-28.9200, -49.4800),
      LatLng(-28.9000, -49.4600),
    ];
    final t0 = DateTime.utc(2026, 10, 3, 12);

    Iterable<Polyline> linhas(WidgetTester tester) => tester
        .widgetList<PolylineLayer>(find.byType(PolylineLayer))
        .expand((camada) => camada.polylines);

    bool temLinha(WidgetTester tester, List<LatLng> pontos) =>
        linhas(tester).any((l) => listEquals(l.points, pontos));

    Map<String, dynamic> rotaDeTeste({
      required nostr.NostrKeyPairs autor,
      required String quoteId,
      List<LatLng> pontos = rotaRecebida,
      String? content,
      DateTime? createdAt,
    }) => eventoDoMotorista(
      autor: autor,
      kind: rideRouteKind,
      createdAt: createdAt,
      content:
          content ??
          jsonEncode({
            'points': [
              for (final p in pontos) [p.latitude, p.longitude],
            ],
          }),
      tags: [
        prototypeMarkerTag,
        ['e', quoteId],
        ['p', 'pubkey-do-passageiro'],
      ],
    );

    Future<void> entregar(
      WidgetTester tester,
      Map<String, dynamic> payload,
    ) async {
      transport.conexoes['wss://a.test']!.emitir(mensagemEvent(payload));
      await esperarEntregaDoEvento(tester);
    }

    /// Entrega a chegada do motorista e confirma o encontro — leva de
    /// "motorista a caminho" a `emCorrida`.
    Future<void> confirmarEncontro(
      WidgetTester tester,
      ({String quoteId, nostr.NostrKeyPairs autor}) r,
    ) async {
      await entregar(
        tester,
        chegadaMotoristaDeTeste(autor: r.autor, quoteId: r.quoteId),
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Confirmo que encontrei o motorista'),
      );
      await tester.pumpAndSettle();
    }

    group('traçar a rota recebida (US1)', () {
      testWidgets(
        'em emCorrida traça a rota do motorista, roxa de 5 px (FR-002, FR-009)',
        (tester) async {
          final r = await montarComEncontroConfirmado(tester);
          expect(linhas(tester), isEmpty);

          await entregar(
            tester,
            rotaDeTeste(autor: r.autor, quoteId: r.quoteId),
          );

          final unica = linhas(tester).single;
          expect(unica.points, rotaRecebida);
          expect(unica.strokeWidth, 5);
          expect(unica.color, IdentidadeVisual.roxo);
        },
      );

      testWidgets(
        'uma rota mais nova substitui a anterior; mais antiga, igual ou '
        'repetida não a trocam (FR-004)',
        (tester) async {
          final r = await montarComEncontroConfirmado(tester);
          await entregar(
            tester,
            rotaDeTeste(autor: r.autor, quoteId: r.quoteId, createdAt: t0),
          );

          const nova = [LatLng(-28.9, -49.4), LatLng(-28.8, -49.3)];
          final maisNova = rotaDeTeste(
            autor: r.autor,
            quoteId: r.quoteId,
            pontos: nova,
            createdAt: t0.add(const Duration(seconds: 5)),
          );
          await entregar(tester, maisNova);
          expect(linhas(tester), hasLength(1));
          expect(temLinha(tester, nova), isTrue);

          for (final instante in [1, 5]) {
            await entregar(
              tester,
              rotaDeTeste(
                autor: r.autor,
                quoteId: r.quoteId,
                pontos: const [LatLng(-28.1, -49.1), LatLng(-28.2, -49.2)],
                createdAt: t0.add(Duration(seconds: instante)),
              ),
            );
            expect(temLinha(tester, nova), isTrue, reason: '+${instante}s');
          }

          await entregar(tester, maisNova);
          expect(linhas(tester), hasLength(1));
          expect(temLinha(tester, nova), isTrue);
        },
      );

      testWidgets(
        'depois de um reinício em emCorrida começa sem rota (FR-007) e traça '
        'a próxima que chegar',
        (tester) async {
          final autor = novoPar();
          await relayService.start([const Relay(url: 'wss://a.test')]);
          final aceita = InMemoryAcceptedRideStore(
            initial: AcceptedRide(
              quoteId: 'orcamento-1',
              driverPubkey: autor.public,
            ),
          );
          final estado = InMemoryPassengerRideStateStore(
            status: PassengerRideStatus.emCorrida,
          );
          await montar(
            tester,
            acceptedRideStore: aceita,
            rideStateStore: estado,
          );
          await tester.pumpAndSettle();
          expect(linhas(tester), isEmpty);

          await entregar(
            tester,
            rotaDeTeste(autor: autor, quoteId: 'orcamento-1'),
          );

          expect(temLinha(tester, rotaRecebida), isTrue);
          expect(estado.saveCount, 0, reason: 'a rota nunca é persistida');
        },
      );
    });

    group('o passageiro não calcula a rota (US2)', () {
      testWidgets(
        'a linha local some ao entrar em emCorrida e a posição não dispara '
        'nenhuma consulta (FR-008, SC-004)',
        (tester) async {
          final rotas = FakeRouteService();
          final gps = FakeLocationService();
          final r = await montarComCorridaAceita(
            tester,
            routeService: rotas,
            localizacao: gps,
          );
          await avisarMotoristaACaminho(tester, r);
          expect(linhas(tester), hasLength(1), reason: 'rota local (007)');
          expect(rotas.chamadas, isNotEmpty);

          await confirmarEncontro(tester, r);
          expect(find.text('Motorista a caminho'), findsNothing);
          expect(linhas(tester), isEmpty);

          final antes = rotas.chamadas.length;
          gps.emitir(posicaoDeTeste(lat: -28.930));
          await tester.pump();
          await tester.pump();

          expect(rotas.chamadas, hasLength(antes));
          expect(linhas(tester), isEmpty);
        },
      );

      testWidgets(
        'um cálculo local em voo que termina depois da entrada em emCorrida '
        'não desenha nada',
        (tester) async {
          final rotas = FakeRouteService();
          final gps = FakeLocationService();
          final r = await montarComCorridaAceita(
            tester,
            routeService: rotas,
            localizacao: gps,
          );
          await avisarMotoristaACaminho(tester, r);

          final bloqueio = Completer<void>();
          rotas.bloqueio = bloqueio;
          gps.emitir(posicaoDeTeste(lat: -28.930));
          await tester.pump();

          await confirmarEncontro(tester, r);
          bloqueio.complete();
          await tester.pump();
          await tester.pump();

          expect(linhas(tester), isEmpty);
        },
      );
    });

    group('só rota legítima e só durante a corrida (US3)', () {
      testWidgets(
        'autor errado, orçamento diferente e conteúdo inválido não mudam o '
        'traçado (FR-003, FR-005)',
        (tester) async {
          final r = await montarComEncontroConfirmado(tester);
          await entregar(
            tester,
            rotaDeTeste(autor: r.autor, quoteId: r.quoteId, createdAt: t0),
          );
          expect(temLinha(tester, rotaRecebida), isTrue);

          var segundos = 10;
          Future<void> ilegitima(Map<String, dynamic> payload) async {
            await entregar(tester, payload);
            expect(linhas(tester), hasLength(1));
            expect(temLinha(tester, rotaRecebida), isTrue);
          }

          DateTime depois() => t0.add(Duration(seconds: segundos++));

          await ilegitima(
            rotaDeTeste(
              autor: novoPar(),
              quoteId: r.quoteId,
              createdAt: depois(),
            ),
          );
          await ilegitima(
            rotaDeTeste(
              autor: r.autor,
              quoteId: 'outro-orcamento',
              createdAt: depois(),
            ),
          );
          for (final conteudo in [
            'não é json',
            '{"points":[[-28.9,-49.4]]}',
            '{"points":[[-28.9,-49.4],[200,-49.3]]}',
            jsonEncode({
              'points': [
                for (var i = 0; i < 1001; i++) [-28.9, -49.4],
              ],
            }),
          ]) {
            await ilegitima(
              rotaDeTeste(
                autor: r.autor,
                quoteId: r.quoteId,
                content: conteudo,
                createdAt: depois(),
              ),
            );
          }
        },
      );

      testWidgets(
        'fora de emCorrida a rota é ignorada e não reaparece depois '
        '(FR-002, FR-005)',
        (tester) async {
          final r = await montarComCorridaAceita(tester);
          await avisarMotoristaACaminho(tester, r);

          await entregar(
            tester,
            rotaDeTeste(autor: r.autor, quoteId: r.quoteId),
          );
          expect(temLinha(tester, rotaRecebida), isFalse);

          await confirmarEncontro(tester, r);
          expect(temLinha(tester, rotaRecebida), isFalse);
        },
      );

      testWidgets(
        'ao confirmar o destino o traçado some, e uma rota tardia não o faz '
        'reaparecer (FR-006)',
        (tester) async {
          final gps = FakeLocationService();
          final r = await montarComEncontroConfirmado(tester, localizacao: gps);
          await entregar(
            tester,
            rotaDeTeste(autor: r.autor, quoteId: r.quoteId, createdAt: t0),
          );
          expect(temLinha(tester, rotaRecebida), isTrue);

          await irParaODestino(tester, gps);
          await tester.tap(botaoConfirmarDestino);
          await tester.pumpAndSettle();
          expect(linhas(tester), isEmpty);

          await entregar(
            tester,
            rotaDeTeste(
              autor: r.autor,
              quoteId: r.quoteId,
              createdAt: t0.add(const Duration(seconds: 30)),
            ),
          );
          expect(linhas(tester), isEmpty);
        },
      );
    });
  });

  group('MapScreen — corrida cancelada pelo motorista (feature 019)', () {
    Map<String, dynamic> cancelamentoDeTeste({
      required nostr.NostrKeyPairs autor,
      required String quoteId,
      String passengerPubkey = 'pubkey-do-passageiro',
    }) => eventoDoMotorista(
      autor: autor,
      kind: rideCancelledKind,
      content: '',
      tags: [
        prototypeMarkerTag,
        ['e', quoteId],
        ['p', passengerPubkey],
      ],
    );

    Future<void> entregarCancelamento(
      WidgetTester tester,
      Map<String, dynamic> evento,
    ) async {
      transport.conexoes['wss://a.test']!.emitir(mensagemEvent(evento));
      await esperarEntregaDoEvento(tester);
    }

    Map<String, dynamic> rotaDeTeste({
      required nostr.NostrKeyPairs autor,
      required String quoteId,
      required DateTime createdAt,
    }) => eventoDoMotorista(
      autor: autor,
      kind: rideRouteKind,
      createdAt: createdAt,
      content: jsonEncode({
        'points': [
          [-28.93, -49.48],
          [-28.92, -49.47],
        ],
      }),
      tags: [
        prototypeMarkerTag,
        ['e', quoteId],
        ['p', 'pubkey-do-passageiro'],
      ],
    );

    final modalDeCancelamento = find.text('Corrida cancelada');
    final botaoOk = find.widgetWithText(FilledButton, 'OK');
    final modalDeAvaliacao = find.text('Avalie a corrida');
    final marcadorDoMotorista = find.byIcon(Icons.directions_car);
    final painelDeSolicitacao = find.widgetWithText(
      FilledButton,
      'Solicitar corrida',
    );

    int eventosPublicados() => transport.conexoes['wss://a.test']!.enviadas
        .where((m) => m.startsWith('["EVENT"'))
        .length;

    Future<void> aoMontar(
      WidgetTester tester, {
      required InMemoryPassengerRideStateStore estado,
      required InMemoryAcceptedRideStore aceita,
    }) async {
      // Troca a árvore por outra antes, para a nova `MapScreen` ter um
      // `State` novo (simula o reinício do app) em vez de reaproveitar o
      // anterior.
      await tester.pumpWidget(const SizedBox());
      await montar(tester, rideStateStore: estado, acceptedRideStore: aceita);
      await tester.pump();
    }

    group('três fases canceláveis (US1)', () {
      for (final fase in [
        'orçamento aceito',
        'motorista a caminho',
        'em corrida',
      ]) {
        testWidgets('em "$fase": modal aparece, o estado já é inicial antes de '
            'tocar "OK", nada é publicado e sem avaliação '
            '(FR-003, FR-004, FR-005, FR-007, FR-010)', (tester) async {
          final estado = InMemoryPassengerRideStateStore();
          final aceita = InMemoryAcceptedRideStore();
          final ({String quoteId, nostr.NostrKeyPairs autor}) r;
          if (fase == 'orçamento aceito') {
            r = await montarComCorridaAceita(
              tester,
              rideStateStore: estado,
              acceptedRideStore: aceita,
            );
            expect(estado.status, PassengerRideStatus.orcamentoAceito);
          } else if (fase == 'motorista a caminho') {
            r = await montarComCorridaAceita(
              tester,
              rideStateStore: estado,
              acceptedRideStore: aceita,
            );
            await avisarMotoristaACaminho(tester, r);
            expect(estado.status, PassengerRideStatus.motoristaACaminho);
          } else {
            r = await montarComEncontroConfirmado(
              tester,
              rideStateStore: estado,
              acceptedRideStore: aceita,
            );
            expect(estado.status, PassengerRideStatus.emCorrida);
          }
          final antes = eventosPublicados();

          await entregarCancelamento(
            tester,
            cancelamentoDeTeste(autor: r.autor, quoteId: r.quoteId),
          );

          expect(modalDeCancelamento, findsOneWidget);
          expect(
            estado.status,
            PassengerRideStatus.inicial,
            reason: 'encerrada no recebimento, não ao tocar "OK" (FR-005)',
          );
          expect(modalDeAvaliacao, findsNothing);
          expect(eventosPublicados(), antes);

          await tester.tap(botaoOk);
          await tester.pumpAndSettle();

          expect(modalDeCancelamento, findsNothing);
          expect(painelDeSolicitacao, findsOneWidget);
        });
      }
    });

    group('nada sobra no app (US2)', () {
      testWidgets('o marcador do motorista some e localizações tardias da '
          'corrida cancelada não o trazem de volta (FR-006)', (tester) async {
        final r = await montarComCorridaAceita(tester);
        await avisarMotoristaACaminho(tester, r);
        expect(marcadorDoMotorista, findsOneWidget);

        await entregarCancelamento(
          tester,
          cancelamentoDeTeste(autor: r.autor, quoteId: r.quoteId),
        );
        await tester.tap(botaoOk);
        await tester.pumpAndSettle();
        expect(marcadorDoMotorista, findsNothing);

        transport.conexoes['wss://a.test']!.emitir(
          mensagemEvent(
            localizacaoDeTeste(
              autor: r.autor,
              quoteId: r.quoteId,
              createdAt: DateTime.now().add(const Duration(minutes: 1)),
            ),
          ),
        );
        await esperarEntregaDoEvento(tester);

        expect(marcadorDoMotorista, findsNothing);
        expect(find.text('Motorista a caminho'), findsNothing);
      });

      testWidgets('a rota do motorista some e rotas tardias não a trazem de '
          'volta (FR-006)', (tester) async {
        final r = await montarComEncontroConfirmado(tester);
        final linhas = find.byWidgetPredicate((w) => w is PolylineLayer);
        transport.conexoes['wss://a.test']!.emitir(
          mensagemEvent(
            rotaDeTeste(
              autor: r.autor,
              quoteId: r.quoteId,
              createdAt: DateTime.now(),
            ),
          ),
        );
        await esperarEntregaDoEvento(tester);
        bool temLinha() => tester
            .widgetList<PolylineLayer>(linhas)
            .any((l) => l.polylines.isNotEmpty);
        expect(temLinha(), isTrue);

        await entregarCancelamento(
          tester,
          cancelamentoDeTeste(autor: r.autor, quoteId: r.quoteId),
        );
        await tester.tap(botaoOk);
        await tester.pumpAndSettle();
        expect(temLinha(), isFalse);

        transport.conexoes['wss://a.test']!.emitir(
          mensagemEvent(
            rotaDeTeste(
              autor: r.autor,
              quoteId: r.quoteId,
              createdAt: DateTime.now().add(const Duration(minutes: 1)),
            ),
          ),
        );
        await esperarEntregaDoEvento(tester);
        expect(temLinha(), isFalse);
      });

      testWidgets('o aviso tira o botão de chegada ao destino que estava '
          'visível (Edge Cases)', (tester) async {
        final gps = FakeLocationService();
        final r = await montarComEncontroConfirmado(tester, localizacao: gps);
        await irParaODestino(tester, gps);
        expect(botaoConfirmarDestino, findsOneWidget);

        await entregarCancelamento(
          tester,
          cancelamentoDeTeste(autor: r.autor, quoteId: r.quoteId),
        );

        expect(modalDeCancelamento, findsOneWidget);
        expect(botaoConfirmarDestino, findsNothing);
      });

      testWidgets('reabrir o app com a modal ainda aberta mostra o estado '
          'inicial, sem modal e sem corrida aceita (FR-004, SC-003)', (
        tester,
      ) async {
        final estado = InMemoryPassengerRideStateStore();
        final aceita = InMemoryAcceptedRideStore();
        final r = await montarComEncontroConfirmado(
          tester,
          rideStateStore: estado,
          acceptedRideStore: aceita,
        );
        await entregarCancelamento(
          tester,
          cancelamentoDeTeste(autor: r.autor, quoteId: r.quoteId),
        );
        expect(modalDeCancelamento, findsOneWidget);

        await aoMontar(tester, estado: estado, aceita: aceita);

        expect(modalDeCancelamento, findsNothing);
        expect(painelDeSolicitacao, findsOneWidget);
        expect(estado.status, PassengerRideStatus.inicial);
      });

      testWidgets('eventos da corrida cancelada (chegada, destino) depois do '
          'cancelamento não abrem modal nem mudam o estado (FR-006)', (
        tester,
      ) async {
        final estado = InMemoryPassengerRideStateStore();
        final r = await montarComEncontroConfirmado(
          tester,
          rideStateStore: estado,
        );
        await entregarCancelamento(
          tester,
          cancelamentoDeTeste(autor: r.autor, quoteId: r.quoteId),
        );
        await tester.tap(botaoOk);
        await tester.pumpAndSettle();

        transport.conexoes['wss://a.test']!.emitir(
          mensagemEvent(
            chegadaMotoristaDeTeste(autor: r.autor, quoteId: r.quoteId),
          ),
        );
        await esperarEntregaDoEvento(tester);
        transport.conexoes['wss://a.test']!.emitir(
          mensagemEvent(
            chegadaDestinoDeTeste(autor: r.autor, quoteId: r.quoteId),
          ),
        );
        await esperarEntregaDoEvento(tester);

        expect(find.text('Motorista chegou'), findsNothing);
        expect(find.text('Chegamos ao destino'), findsNothing);
        expect(estado.status, PassengerRideStatus.inicial);
      });
    });

    group('só avisos legítimos (US3)', () {
      testWidgets('aviso assinado por outra chave que não a do motorista da '
          'corrida é ignorado (FR-002)', (tester) async {
        final estado = InMemoryPassengerRideStateStore();
        final r = await montarComEncontroConfirmado(
          tester,
          rideStateStore: estado,
        );

        await entregarCancelamento(
          tester,
          cancelamentoDeTeste(autor: novoPar(), quoteId: r.quoteId),
        );

        expect(modalDeCancelamento, findsNothing);
        expect(estado.status, PassengerRideStatus.emCorrida);
      });

      testWidgets('aviso referenciando outro orçamento é ignorado (FR-002)', (
        tester,
      ) async {
        final estado = InMemoryPassengerRideStateStore();
        final r = await montarComEncontroConfirmado(
          tester,
          rideStateStore: estado,
        );

        await entregarCancelamento(
          tester,
          cancelamentoDeTeste(autor: r.autor, quoteId: 'outra-corrida'),
        );

        expect(modalDeCancelamento, findsNothing);
        expect(estado.status, PassengerRideStatus.emCorrida);
      });

      testWidgets('aviso sem corrida aceita (inicial) é ignorado (FR-002)', (
        tester,
      ) async {
        final estado = InMemoryPassengerRideStateStore();
        await relayService.start([const Relay(url: 'wss://a.test')]);
        await montar(tester, rideStateStore: estado);

        await entregarCancelamento(
          tester,
          cancelamentoDeTeste(autor: novoPar(), quoteId: 'qualquer'),
        );

        expect(modalDeCancelamento, findsNothing);
        expect(estado.status, PassengerRideStatus.inicial);
      });

      testWidgets('aviso em aguardandoOrcamentos é ignorado (FR-002)', (
        tester,
      ) async {
        final estado = InMemoryPassengerRideStateStore();
        final requestId = await montarComSolicitacaoAtiva(
          tester,
          rideStateStore: estado,
        );
        expect(estado.status, PassengerRideStatus.aguardandoOrcamentos);

        await entregarCancelamento(
          tester,
          cancelamentoDeTeste(autor: novoPar(), quoteId: requestId),
        );

        expect(modalDeCancelamento, findsNothing);
        expect(estado.status, PassengerRideStatus.aguardandoOrcamentos);
      });

      testWidgets('aviso em destinoConfirmadoAguardandoAvaliacao é ignorado e '
          'a avaliação segue (FR-002, Edge Cases)', (tester) async {
        final estado = InMemoryPassengerRideStateStore();
        final r = await montarComDestinoConfirmado(
          tester,
          rideStateStore: estado,
        );
        expect(modalDeAvaliacao, findsOneWidget);

        await entregarCancelamento(
          tester,
          cancelamentoDeTeste(autor: r.autor, quoteId: r.quoteId),
        );

        expect(modalDeCancelamento, findsNothing);
        expect(modalDeAvaliacao, findsOneWidget);
        expect(
          estado.status,
          PassengerRideStatus.destinoConfirmadoAguardandoAvaliacao,
        );
      });

      testWidgets('o mesmo aviso reentregue depois de tratado não reabre a '
          'modal (FR-008)', (tester) async {
        final r = await montarComEncontroConfirmado(tester);
        final evento = cancelamentoDeTeste(autor: r.autor, quoteId: r.quoteId);
        await entregarCancelamento(tester, evento);
        await tester.tap(botaoOk);
        await tester.pumpAndSettle();
        expect(modalDeCancelamento, findsNothing);

        await entregarCancelamento(tester, evento);

        expect(modalDeCancelamento, findsNothing);
      });
    });
  });

  group('MapScreen — motorista não pode atender a corrida (feature 020)', () {
    Map<String, dynamic> indisponibilidadeDeTeste({
      required nostr.NostrKeyPairs autor,
      required String quoteId,
    }) => eventoDoMotorista(
      autor: autor,
      kind: rideUnavailableKind,
      content: '',
      tags: [
        prototypeMarkerTag,
        ['e', quoteId],
        ['p', 'pubkey-do-passageiro'],
      ],
    );

    Future<void> entregar(
      WidgetTester tester,
      Map<String, dynamic> evento,
    ) async {
      transport.conexoes['wss://a.test']!.emitir(mensagemEvent(evento));
      await esperarEntregaDoEvento(tester);
    }

    final modal = find.text('Motorista indisponível');
    final botaoOk = find.widgetWithText(FilledButton, 'OK');
    final painelDeSolicitacao = find.widgetWithText(
      FilledButton,
      'Solicitar corrida',
    );

    int eventosPublicados() => transport.conexoes['wss://a.test']!.enviadas
        .where((m) => m.startsWith('["EVENT"'))
        .length;

    testWidgets('em orçamento aceito: modal aparece, o estado já é inicial '
        'antes de tocar "OK" e nada é publicado (FR-002 a FR-005)', (
      tester,
    ) async {
      final estado = InMemoryPassengerRideStateStore();
      final r = await montarComCorridaAceita(tester, rideStateStore: estado);
      expect(estado.status, PassengerRideStatus.orcamentoAceito);
      final antes = eventosPublicados();

      await entregar(
        tester,
        indisponibilidadeDeTeste(autor: r.autor, quoteId: r.quoteId),
      );

      expect(modal, findsOneWidget);
      expect(
        estado.status,
        PassengerRideStatus.inicial,
        reason: 'encerrada no recebimento, não ao tocar "OK"',
      );
      expect(eventosPublicados(), antes);

      await tester.tap(botaoOk);
      await tester.pumpAndSettle();

      expect(modal, findsNothing);
      expect(painelDeSolicitacao, findsOneWidget);
    });

    testWidgets('reabrir o app com a modal ainda aberta mostra o estado '
        'inicial, sem modal e sem corrida aceita (FR-005)', (tester) async {
      final estado = InMemoryPassengerRideStateStore();
      final aceita = InMemoryAcceptedRideStore();
      final r = await montarComCorridaAceita(
        tester,
        rideStateStore: estado,
        acceptedRideStore: aceita,
      );
      await entregar(
        tester,
        indisponibilidadeDeTeste(autor: r.autor, quoteId: r.quoteId),
      );
      expect(modal, findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await montar(tester, rideStateStore: estado, acceptedRideStore: aceita);
      await tester.pump();

      expect(modal, findsNothing);
      expect(painelDeSolicitacao, findsOneWidget);
      expect(estado.status, PassengerRideStatus.inicial);
    });

    testWidgets('aviso assinado por outra chave que não a do motorista é '
        'ignorado (FR-002)', (tester) async {
      final estado = InMemoryPassengerRideStateStore();
      final r = await montarComCorridaAceita(tester, rideStateStore: estado);

      await entregar(
        tester,
        indisponibilidadeDeTeste(autor: novoPar(), quoteId: r.quoteId),
      );

      expect(modal, findsNothing);
      expect(estado.status, PassengerRideStatus.orcamentoAceito);
    });

    testWidgets('aviso referenciando outro orçamento é ignorado (FR-002)', (
      tester,
    ) async {
      final estado = InMemoryPassengerRideStateStore();
      final r = await montarComCorridaAceita(tester, rideStateStore: estado);

      await entregar(
        tester,
        indisponibilidadeDeTeste(autor: r.autor, quoteId: 'outra-corrida'),
      );

      expect(modal, findsNothing);
      expect(estado.status, PassengerRideStatus.orcamentoAceito);
    });

    testWidgets('aviso em motorista a caminho é ignorado: a corrida já '
        'começou (FR-002)', (tester) async {
      final estado = InMemoryPassengerRideStateStore();
      final r = await montarComCorridaAceita(tester, rideStateStore: estado);
      await avisarMotoristaACaminho(tester, r);
      expect(estado.status, PassengerRideStatus.motoristaACaminho);

      await entregar(
        tester,
        indisponibilidadeDeTeste(autor: r.autor, quoteId: r.quoteId),
      );

      expect(modal, findsNothing);
      expect(estado.status, PassengerRideStatus.motoristaACaminho);
    });

    testWidgets('aviso sem corrida aceita (inicial) é ignorado (FR-002)', (
      tester,
    ) async {
      final estado = InMemoryPassengerRideStateStore();
      await relayService.start([const Relay(url: 'wss://a.test')]);
      await montar(tester, rideStateStore: estado);

      await entregar(
        tester,
        indisponibilidadeDeTeste(autor: novoPar(), quoteId: 'qualquer'),
      );

      expect(modal, findsNothing);
      expect(estado.status, PassengerRideStatus.inicial);
    });

    testWidgets('o mesmo aviso reentregue depois de tratado não reabre a '
        'modal (FR-007)', (tester) async {
      final r = await montarComCorridaAceita(tester);
      final evento = indisponibilidadeDeTeste(
        autor: r.autor,
        quoteId: r.quoteId,
      );
      await entregar(tester, evento);
      await tester.tap(botaoOk);
      await tester.pumpAndSettle();

      await entregar(tester, evento);

      expect(modal, findsNothing);
    });

    testWidgets('depois do aviso, uma nova solicitação segue normal (FR-008)', (
      tester,
    ) async {
      final r = await montarComCorridaAceita(tester);
      await entregar(
        tester,
        indisponibilidadeDeTeste(autor: r.autor, quoteId: r.quoteId),
      );
      await tester.tap(botaoOk);
      await tester.pumpAndSettle();

      expect(painelDeSolicitacao, findsOneWidget);
    });
  });

  group('MapScreen — recepção cifrada (feature 022, emenda 17)', () {
    // Cada variante é um jeito de o evento chegar assinado e bem-formado, mas
    // inválido pela regra de recepção 7: tem de ser descartado em silêncio.
    Map<String, Map<String, dynamic> Function(_Base)> variantes({
      required bool semDadoProprio,
    }) => {
      'em claro': (b) => b.monta(emClaro: true),
      'cifrado a outra chave': (b) => b.monta(cifrarPara: novoPar().public),
      'tag p de outro destinatário': (b) {
        final outro = novoPar().public;
        return b.monta(pTag: outro, cifrarPara: outro);
      },
      'MAC adulterado': (b) {
        final bytes = base64.decode(
          b.cifradoValido(),
        )..[60] ^= 0x01;
        return b.monta(emClaro: true, conteudoBruto: base64.encode(bytes));
      },
      if (semDadoProprio)
        'texto diferente de {}': (b) => b.monta(conteudo: '{"a":1}'),
    };

    _Base base(
      nostr.NostrKeyPairs autor,
      int kind,
      String ref,
      String conteudo,
    ) => _Base(
      autor: autor,
      kind: kind,
      ref: ref,
      conteudo: conteudo,
      identidade: identidade,
      assinar: eventoDoMotorista,
    );

    Future<void> entregar(WidgetTester tester, Map<String, dynamic> p) async {
      transport.conexoes['wss://a.test']!.emitir(mensagemEvent(p));
      await esperarEntregaDoEvento(tester);
    }

    testWidgets('20002 válido e cifrado: o orçamento é salvo com os campos '
        'decodificados, não com o content cifrado (FR-009)', (tester) async {
      final store = FakeReceivedQuoteStore();
      final requestId = await montarComSolicitacaoAtiva(
        tester,
        receivedQuoteStore: store,
      );
      final autor = novoPar();

      await entregar(
        tester,
        orcamentoDeTeste(requestId: requestId, autor: autor),
      );

      final salvo = store.salvos.single;
      expect(salvo.driverName, 'Fulano da Silva');
      expect(salvo.driverPubkey, autor.public);
      expect(salvo.total, 25.0);
    });

    for (final nome in variantes(semDadoProprio: false).keys) {
      testWidgets('20002 $nome: o orçamento não é salvo nem exibido '
          '(FR-006)', (tester) async {
        final store = FakeReceivedQuoteStore();
        final requestId = await montarComSolicitacaoAtiva(
          tester,
          receivedQuoteStore: store,
        );
        final autor = novoPar();
        final b = base(
          autor,
          rideQuoteKind,
          requestId,
          jsonEncode({
            'pricePerKm': 2.5,
            'total': 25.0,
            'driverName': 'Fulano da Silva',
            'carBrand': 'Fiat',
            'carModel': 'Palio',
            'carYear': 2018,
          }),
        );

        await entregar(tester, variantes(semDadoProprio: false)[nome]!(b));

        expect(store.salvos, isEmpty);
        expect(find.text('Fulano da Silva'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('20005 $nome: não dispara "a caminho" (FR-006, FR-007)', (tester) async {
        final estado = InMemoryPassengerRideStateStore();
        final r = await montarComCorridaAceita(
          tester,
          rideStateStore: estado,
        );

        final b = base(
          r.autor,
          driverLocationKind,
          r.quoteId,
          jsonEncode({'lat': -28.93, 'lon': -49.48}),
        );
        await entregar(tester, variantes(semDadoProprio: false)[nome]!(b));

        expect(find.text('Motorista a caminho'), findsNothing);
        expect(estado.status, PassengerRideStatus.orcamentoAceito);
      });
    }

    for (final nome in variantes(semDadoProprio: true).keys) {
      testWidgets('20006 $nome: nada acontece (FR-006)', (tester) async {
        final estado = InMemoryPassengerRideStateStore();
        final r = await montarComCorridaAceita(tester, rideStateStore: estado);
        final b = base(r.autor, rideUnavailableKind, r.quoteId, '');

        await entregar(tester, variantes(semDadoProprio: true)[nome]!(b));

        expect(find.text('Motorista indisponível'), findsNothing);
        expect(estado.status, PassengerRideStatus.orcamentoAceito);
      });

      testWidgets('20012 $nome: nada acontece (FR-006)', (tester) async {
        final estado = InMemoryPassengerRideStateStore();
        final r = await montarComCorridaAceita(tester, rideStateStore: estado);
        final b = base(r.autor, rideCancelledKind, r.quoteId, '');

        await entregar(tester, variantes(semDadoProprio: true)[nome]!(b));

        expect(find.text('Corrida cancelada'), findsNothing);
        expect(estado.status, PassengerRideStatus.orcamentoAceito);
      });

      testWidgets('20007 $nome: a modal de chegada não abre (FR-006)', (
        tester,
      ) async {
        final r = await montarComCorridaAceita(tester);
        await avisarMotoristaACaminho(tester, r);
        final b = base(r.autor, driverArrivalKind, r.quoteId, '');

        await entregar(tester, variantes(semDadoProprio: true)[nome]!(b));

        expect(find.text('Motorista chegou'), findsNothing);
      });

      testWidgets('20009 $nome: a modal de destino não abre (FR-006)', (
        tester,
      ) async {
        final r = await montarComEncontroConfirmado(tester);
        final b = base(r.autor, destinationArrivalKind, r.quoteId, '');

        await entregar(tester, variantes(semDadoProprio: true)[nome]!(b));

        expect(
          find.text('Vocês chegaram ao destino da corrida.'),
          findsNothing,
        );
      });
    }

    for (final nome in variantes(semDadoProprio: false).keys) {
      testWidgets('20011 $nome: a rota não é traçada (FR-006)', (tester) async {
        final r = await montarComEncontroConfirmado(tester);
        final b = base(
          r.autor,
          rideRouteKind,
          r.quoteId,
          jsonEncode({
            'points': [
              [-28.93, -49.48],
              [-28.92, -49.47],
            ],
          }),
        );

        await entregar(tester, variantes(semDadoProprio: false)[nome]!(b));

        final linhas = tester
            .widgetList<PolylineLayer>(find.byType(PolylineLayer))
            .expand((c) => c.polylines);
        expect(linhas, isEmpty);
      });
    }
  });

  group('MapScreen — cancelar corrida (feature 023)', () {
    final botao = find.byKey(const Key('botao-cancelar-corrida'));
    // O botão do mapa também é um FilledButton "Cancelar corrida" (feature
    // 024), mas tem a chave `botao-cancelar-corrida`; o da confirmação, não.
    final confirmar = find.byWidgetPredicate(
      (w) =>
          w is FilledButton &&
          w.key == null &&
          w.child is Text &&
          (w.child! as Text).data == 'Cancelar corrida',
    );
    final voltar = find.widgetWithText(TextButton, 'Voltar');
    final confirmacao = find.text('Cancelar corrida?');
    final painelDeSolicitacao = find.widgetWithText(
      FilledButton,
      'Solicitar corrida',
    );
    final marcadorDoMotorista = find.byIcon(Icons.directions_car);
    final modalDeAvaliacao = find.text('Avalie a corrida');
    final modalDoMotorista = find.text('Corrida cancelada');

    /// `kind: 20013` publicados pelo passageiro, já decodificados.
    List<Map<String, dynamic>> avisos() => transport
        .conexoes['wss://a.test']!
        .enviadas
        .where((m) => m.startsWith('["EVENT"'))
        .map((m) => (jsonDecode(m) as List)[1] as Map<String, dynamic>)
        .where((p) => p['kind'] == rideCancelledByPassengerKind)
        .toList();

    String? decifradoPeloMotorista(
      Map<String, dynamic> payload,
      nostr.NostrKeyPairs motorista,
    ) => MessageCipher().decryptFrom(
      Identity(publicKey: motorista.public, privateKey: motorista.private),
      identidade.publicKey,
      payload['content'] as String,
    );

    /// Espera o SnackBar da solicitação (que cobre a parte de baixo do mapa
    /// por alguns segundos) sumir e toca no botão.
    Future<void> abrirConfirmacao(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      await tester.tap(botao);
      await tester.pumpAndSettle();
    }

    Future<void> cancelar(WidgetTester tester) async {
      await abrirConfirmacao(tester);
      await tester.tap(confirmar);
      await tester.pumpAndSettle();
    }

    Map<String, dynamic> cancelamentoDoMotorista(
      ({String quoteId, nostr.NostrKeyPairs autor}) r,
    ) => eventoDoMotorista(
      autor: r.autor,
      kind: rideCancelledKind,
      content: '',
      tags: [
        prototypeMarkerTag,
        ['e', r.quoteId],
        ['p', 'pubkey-do-passageiro'],
      ],
    );

    Future<({String quoteId, nostr.NostrKeyPairs autor})> montarEm(
      WidgetTester tester,
      String fase, {
      InMemoryPassengerRideStateStore? estado,
      InMemoryAcceptedRideStore? aceita,
    }) async {
      if (fase == 'orçamento aceito') {
        return montarComCorridaAceita(
          tester,
          rideStateStore: estado,
          acceptedRideStore: aceita,
        );
      }
      if (fase == 'motorista a caminho') {
        final r = await montarComCorridaAceita(
          tester,
          rideStateStore: estado,
          acceptedRideStore: aceita,
        );
        await avisarMotoristaACaminho(tester, r);
        return r;
      }
      return montarComEncontroConfirmado(
        tester,
        rideStateStore: estado,
        acceptedRideStore: aceita,
      );
    }

    ButtonStyle estiloDe(WidgetTester tester, Finder f) =>
        tester.widget<FilledButton>(f).style!;
    Color fundoDe(ButtonStyle e) => e.backgroundColor!.resolve({})!;
    Color textoDe(ButtonStyle e) => e.foregroundColor!.resolve({})!;
    double razaoDeContraste(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final claro = la > lb ? la : lb;
      final escuro = la > lb ? lb : la;
      return (claro + 0.05) / (escuro + 0.05);
    }

    for (final fase in [
      'orçamento aceito',
      'motorista a caminho',
      'em corrida',
    ]) {
      testWidgets('em "$fase": o botão do mapa é roxo com texto branco e '
          'contraste >= 4,5:1 (feature 024: FR-001, FR-003, FR-006, SC-001, '
          'SC-002)', (tester) async {
        await montarEm(tester, fase);

        final e = estiloDe(tester, botao);
        expect(fundoDe(e), IdentidadeVisual.roxo);
        expect(textoDe(e), Colors.white);
        expect(
          razaoDeContraste(fundoDe(e), textoDe(e)),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          find.descendant(of: botao, matching: find.text('Cancelar corrida')),
          findsOneWidget,
        );
        expect(tester.getSize(botao).height, 48);
      });
    }

    testWidgets('o botão do mapa e o da confirmação têm as mesmas cores '
        '(feature 024: FR-004, SC-003)', (tester) async {
      await montarEm(tester, 'orçamento aceito');

      final doMapa = estiloDe(tester, botao);
      await abrirConfirmacao(tester);
      final daConfirmacao = estiloDe(tester, confirmar);

      expect(fundoDe(daConfirmacao), fundoDe(doMapa));
      expect(textoDe(daConfirmacao), textoDe(doMapa));
    });

    for (final fase in [
      'orçamento aceito',
      'motorista a caminho',
      'em corrida',
    ]) {
      testWidgets('em "$fase": confirmar volta a inicial, persiste, publica '
          'um único 20013 ao motorista e não abre avaliação '
          '(FR-001, FR-003, FR-004, FR-005)', (tester) async {
        final estado = InMemoryPassengerRideStateStore();
        final r = await montarEm(tester, fase, estado: estado);
        expect(botao, findsOneWidget);

        await cancelar(tester);

        expect(estado.status, PassengerRideStatus.inicial);
        expect(painelDeSolicitacao, findsOneWidget);
        expect(botao, findsNothing);
        expect(modalDeAvaliacao, findsNothing);
        expect(marcadorDoMotorista, findsNothing);
        final publicados = avisos();
        expect(publicados, hasLength(1));
        final tags = (publicados.single['tags'] as List)
            .map((t) => (t as List).map((e) => e.toString()).toList())
            .toList();
        expect(tags, anyElement(equals(['e', r.quoteId])));
        expect(tags, anyElement(equals(['p', r.autor.public])));
        expect(tags, anyElement(equals(['t', prototypeMarker])));
        expect(decifradoPeloMotorista(publicados.single, r.autor), '{}');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('tocar no botão abre a confirmação; "Voltar" desiste sem '
        'efeito e nada é publicado (FR-002, SC-003)', (tester) async {
      final estado = InMemoryPassengerRideStateStore();
      await montarEm(tester, 'orçamento aceito', estado: estado);

      await abrirConfirmacao(tester);
      expect(confirmacao, findsOneWidget);

      await tester.tap(voltar);
      await tester.pumpAndSettle();

      expect(confirmacao, findsNothing);
      expect(estado.status, PassengerRideStatus.orcamentoAceito);
      expect(avisos(), isEmpty);
      expect(botao, findsOneWidget);
    });

    testWidgets('duplo toque em "Cancelar corrida" publica um único aviso '
        '(FR-004)', (tester) async {
      await montarEm(tester, 'motorista a caminho');
      await abrirConfirmacao(tester);

      await tester.tap(confirmar);
      await tester.tap(confirmar, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(avisos(), hasLength(1));
    });

    testWidgets('o botão não existe no estado inicial (FR-001)', (
      tester,
    ) async {
      await montar(tester);

      expect(botao, findsNothing);
    });

    testWidgets('o botão não existe em aguardando orçamentos (FR-001)', (
      tester,
    ) async {
      await montarComSolicitacaoAtiva(tester);

      expect(botao, findsNothing);
    });

    testWidgets('o botão não existe com o destino confirmado aguardando '
        'avaliação (FR-001)', (tester) async {
      await montarComDestinoConfirmado(tester);

      expect(modalDeAvaliacao, findsOneWidget);
      expect(botao, findsNothing);
    });

    testWidgets('um reinício depois do cancelamento reabre no estado inicial, '
        'sem corrida aceita (SC-004)', (tester) async {
      final estado = InMemoryPassengerRideStateStore();
      final aceita = InMemoryAcceptedRideStore();
      await montarEm(tester, 'em corrida', estado: estado, aceita: aceita);
      await cancelar(tester);

      await aoMontarNovamente(tester, estado: estado, aceita: aceita);

      expect(painelDeSolicitacao, findsOneWidget);
      expect(botao, findsNothing);
      expect(marcadorDoMotorista, findsNothing);
    });

    testWidgets('eventos do motorista depois do cancelamento são ignorados, '
        'sem modal (FR-008)', (tester) async {
      final r = await montarEm(tester, 'motorista a caminho');
      await cancelar(tester);

      transport.conexoes['wss://a.test']!.emitir(
        mensagemEvent(
          localizacaoDeTeste(
            autor: r.autor,
            quoteId: r.quoteId,
            createdAt: DateTime.now().add(const Duration(minutes: 1)),
          ),
        ),
      );
      await esperarEntregaDoEvento(tester);
      transport.conexoes['wss://a.test']!.emitir(
        mensagemEvent(cancelamentoDoMotorista(r)),
      );
      await esperarEntregaDoEvento(tester);

      expect(marcadorDoMotorista, findsNothing);
      expect(modalDoMotorista, findsNothing);
      expect(find.text('Motorista a caminho'), findsNothing);
    });

    testWidgets('com a confirmação aberta, o cancelamento do motorista a '
        'fecha, mostra o desfecho dele e nada é publicado (FR-006)', (
      tester,
    ) async {
      final estado = InMemoryPassengerRideStateStore();
      final r = await montarEm(tester, 'motorista a caminho', estado: estado);
      await abrirConfirmacao(tester);
      expect(confirmacao, findsOneWidget);

      transport.conexoes['wss://a.test']!.emitir(
        mensagemEvent(cancelamentoDoMotorista(r)),
      );
      await esperarEntregaDoEvento(tester);

      expect(confirmacao, findsNothing);
      expect(modalDoMotorista, findsOneWidget);
      expect(estado.status, PassengerRideStatus.inicial);
      expect(avisos(), isEmpty);
    });

    testWidgets('sem relay conectado o cancelamento local acontece, sem '
        'erro e sem aviso (FR-007)', (tester) async {
      final estado = InMemoryPassengerRideStateStore();
      await montarEm(tester, 'orçamento aceito', estado: estado);
      transport.conexoes['wss://a.test']!.derrubar();
      await tester.pump(const Duration(milliseconds: 20));

      await cancelar(tester);

      expect(estado.status, PassengerRideStatus.inicial);
      expect(painelDeSolicitacao, findsOneWidget);
      expect(avisos(), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('relay que recusa a publicação: o cancelamento local '
        'prevalece, sem erro (FR-007)', (tester) async {
      final estado = InMemoryPassengerRideStateStore();
      await montarEm(tester, 'em corrida', estado: estado);
      transport.conexoes['wss://a.test']!.aceitaPublicacao = false;

      await cancelar(tester);

      expect(estado.status, PassengerRideStatus.inicial);
      expect(painelDeSolicitacao, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('MapScreen — serviço em segundo plano (feature 026)', () {
    late _ControladorGravador controlador;

    setUp(() => controlador = _ControladorGravador());

    testWidgets('informa o estado só depois de restaurar o persistido, '
        'com a chave pública e sem corrida (FR-011)', (tester) async {
      await montar(tester, serviceController: controlador);

      expect(controlador.estados, isNotEmpty);
      final primeiro = controlador.estados.first;
      expect(primeiro.passengerPubkey, identidade.publicKey);
      expect(primeiro.rideStatus, PassengerRideStatus.inicial);
      expect(primeiro.requestId, isNull);
    });

    testWidgets('restaurada uma corrida, o primeiro estado já é o dela — '
        'nunca "sem corrida" no lugar', (tester) async {
      await montar(
        tester,
        serviceController: controlador,
        rideStateStore: InMemoryPassengerRideStateStore(
          status: PassengerRideStatus.motoristaACaminho,
        ),
        acceptedRideStore: InMemoryAcceptedRideStore(
          initial: const AcceptedRide(quoteId: 'q1', driverPubkey: 'd1'),
        ),
      );
      await tester.pump();

      expect(controlador.estados.first.rideStatus,
          PassengerRideStatus.motoristaACaminho);
      expect(controlador.estados.first.quoteId, 'q1');
      expect(controlador.estados.first.driverPubkey, 'd1');
      expect(controlador.estados.first.hasActiveRide, isTrue);
    });

    testWidgets('ao solicitar, pede a permissão de notificação e informa a '
        'solicitação ativa', (tester) async {
      await relayService.start([const Relay(url: 'wss://a.test')]);
      final localizacao = FakeLocationService();
      await montar(
        tester,
        locationService: localizacao,
        geocodingService: FakeGeocodingService(
          respostas: {
            'Lis': [_sugestaoLisboa],
          },
        ),
        serviceController: controlador,
      );
      // Abrir o app não pede a permissão.
      expect(controlador.permissoesPedidas, 0);

      localizacao.emitir(posicaoDeTeste());
      await tester.pump();
      await _digitarEBuscar(tester, 'Lis');
      await tester.tap(find.text('Lisboa, Portugal'));
      await tester.pump();
      await tester.tap(find.text('Solicitar corrida'));
      await tester.pumpAndSettle();

      expect(controlador.permissoesPedidas, 1);
      final enviada = transport.conexoes['wss://a.test']!.enviadas.firstWhere(
        (m) => m.startsWith('["EVENT"'),
      );
      final id = ((jsonDecode(enviada) as List)[1]
          as Map<String, dynamic>)['id'] as String;
      final ativo = controlador.estados.lastWhere(
        (e) => e.rideStatus == PassengerRideStatus.aguardandoOrcamentos,
      );
      expect(ativo.requestId, id);
    });

    testWidgets('permissão negada: avisa que só haverá aviso com o app '
        'aberto, e a solicitação segue (FR-009)', (tester) async {
      controlador.permissaoConcedida = false;
      await relayService.start([const Relay(url: 'wss://a.test')]);
      final localizacao = FakeLocationService();
      await montar(
        tester,
        locationService: localizacao,
        geocodingService: FakeGeocodingService(
          respostas: {
            'Lis': [_sugestaoLisboa],
          },
        ),
        serviceController: controlador,
      );
      localizacao.emitir(posicaoDeTeste());
      await tester.pump();
      await _digitarEBuscar(tester, 'Lis');
      await tester.tap(find.text('Lisboa, Portugal'));
      await tester.pump();
      await tester.tap(find.text('Solicitar corrida'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Notificações desativadas'), findsOneWidget);
      expect(
        transport.conexoes['wss://a.test']!.enviadas.where(
          (m) => m.startsWith('["EVENT"'),
        ),
        isNotEmpty,
      );
    });

    testWidgets('a visibilidade do app vai ao controlador: pausado = fora, '
        'inactive e resumed = à vista', (tester) async {
      await montar(tester, serviceController: controlador);

      for (final estado in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(estado);
      }

      expect(controlador.visibilidade, [true, false, false, false, true, true]);
    });

    testWidgets('sem controlador (testes e demais usos) nada muda',
        (tester) async {
      await montar(tester);
      for (final estado in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(estado);
      }
      expect(tester.takeException(), isNull);
    });
  });
}

/// Cifra que passa a falhar quando o teste manda, para verificar que nada é
/// publicado em claro.
class _CifraQueFalhaQuandoPedido extends MessageCipher {
  bool falha = false;

  @override
  String encryptFor(Identity identity, String peerPubkey, String plaintext) {
    if (falha) throw const Nip44Exception('falha simulada');
    return super.encryptFor(identity, peerPubkey, plaintext);
  }
}

/// Monta, para um tipo de evento do motorista, as variantes de entrega
/// (válida e inválidas) usadas pela recepção cifrada.
class _Base {
  _Base({
    required this.autor,
    required this.kind,
    required this.ref,
    required this.conteudo,
    required this.identidade,
    required this.assinar,
  });

  final nostr.NostrKeyPairs autor;
  final int kind;
  final String ref;
  final String conteudo;
  final Identity identidade;
  final Map<String, dynamic> Function({
    required nostr.NostrKeyPairs autor,
    String content,
    int kind,
    List<List<String>>? tags,
    DateTime? createdAt,
    String? cifrarPara,
    bool emClaro,
  })
  assinar;

  String cifradoValido() => MessageCipher().encryptFor(
    Identity(publicKey: autor.public, privateKey: autor.private),
    identidade.publicKey,
    conteudo,
  );

  Map<String, dynamic> monta({
    String? pTag,
    String? cifrarPara,
    bool emClaro = false,
    String? conteudoBruto,
    String? conteudo,
  }) => assinar(
    autor: autor,
    kind: kind,
    content: conteudoBruto ?? conteudo ?? this.conteudo,
    emClaro: emClaro,
    cifrarPara: cifrarPara,
    tags: [
      prototypeMarkerTag,
      ['e', ref],
      ['p', pTag ?? 'pubkey-do-passageiro'],
    ],
  );
}

/// Controlador que só grava o que a tela lhe diz (feature 026).
class _ControladorGravador extends ServiceController {
  _ControladorGravador._(MemoryChannelPair canal)
    : super(
        service: _ServicoNulo(canal.ui),
        hub: RemoteRelayHub(canal.ui, helloRetry: const Duration(hours: 1)),
      );

  factory _ControladorGravador() => _ControladorGravador._(MemoryChannelPair());

  final estados = <ServiceState>[];
  final visibilidade = <bool>[];
  var permissoesPedidas = 0;
  var permissaoConcedida = true;

  @override
  void update(ServiceState state) => estados.add(state);

  @override
  Future<void> onForeground(bool foreground) async =>
      visibilidade.add(foreground);

  @override
  Future<bool> ensureNotificationPermission() async {
    permissoesPedidas++;
    return permissaoConcedida;
  }
}

class _ServicoNulo implements BackgroundService {
  _ServicoNulo(this.channel);

  @override
  final MessageChannel channel;

  @override
  Future<bool> get isRunning async => false;
  @override
  Future<void> start({required String text}) async {}
  @override
  Future<void> updateText(String text) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<bool> hasNotificationPermission() async => true;
  @override
  Future<bool> requestNotificationPermission() async => true;
}

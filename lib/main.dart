import 'dart:async';

import 'package:flutter/material.dart';

import 'package:passenger/domain/identity.dart';
import 'package:passenger/screens/home_screen.dart';
import 'package:passenger/screens/map_screen.dart';
import 'package:passenger/screens/name_screen.dart';
import 'package:passenger/services/accepted_ride_store.dart';
import 'package:passenger/services/destination_store.dart';
import 'package:passenger/services/background/background_service.dart';
import 'package:passenger/services/background/foreground_task_channels.dart';
import 'package:passenger/services/background/service_controller.dart';
import 'package:passenger/services/event_feed.dart';
import 'package:passenger/services/flutter_secure_store.dart';
import 'package:passenger/services/geocoding_service.dart';
import 'package:passenger/services/geolocator_location_service.dart';
import 'package:passenger/services/identity_service.dart';
import 'package:passenger/services/location_service.dart';
import 'package:passenger/services/name_service.dart';
import 'package:passenger/services/passenger_ride_state_store.dart';
import 'package:passenger/services/prefs_key_value_store.dart';
import 'package:passenger/services/received_quote_store.dart';
import 'package:passenger/services/relay_hub.dart';
import 'package:passenger/services/remote_relay_hub.dart';
import 'package:passenger/services/relay_repository.dart';
import 'package:passenger/services/ride_rating_store.dart';
import 'package:passenger/services/route_service.dart';
import 'package:passenger/services/secure_store.dart';
import 'package:passenger/services/subscription_request.dart';
import 'package:passenger/shared/app_info.dart';
import 'package:passenger/screens/identidade_visual.dart';
import 'package:passenger/services/ors_api_key.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OrsApiKey.load();
  // Canal entre a interface e o serviço em segundo plano (feature 026).
  ForegroundTaskBackgroundService.initCommunicationPort();
  runApp(const CaronasPassengerApp());
}

/// Widget raiz do aplicativo do passageiro.
///
/// É aqui, e só aqui, que as implementações reais de armazenamento protegido e
/// de transporte de relay são escolhidas. Todo o resto do código depende dos
/// contratos `SecureStore` e `RelayTransport`, o que permite aos testes rodar
/// com dublês em memória (decisão D5, Princípio II da constituição).
class CaronasPassengerApp extends StatelessWidget {
  const CaronasPassengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appDisplayName,
      themeMode: ThemeMode.system,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: const _Bootstrap(),
    );
  }
}

/// Cria a identidade e inicia as conexões antes de entregar a tela principal.
///
/// Falha de armazenamento protegido é reportada ao usuário, nunca contornada
/// gerando uma identidade nova em silêncio.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late final Future<Identity> _identidade;
  // A conexão com os relays vive no serviço em primeiro plano do Android
  // (feature 026); a interface a vê por mensagens. Constituição 2.15.0.
  late final UiMessageChannel _canal = UiMessageChannel();
  late final RemoteRelayHub _relayService = RemoteRelayHub(_canal);
  late final ServiceController _serviceController = ServiceController(
    service: ForegroundTaskBackgroundService(channel: _canal),
    hub: _relayService,
  );
  final RelayRepository _relayRepository = RelayRepository(
    const PrefsKeyValueStore(),
  );
  late final EventFeed _eventFeed = EventFeed(
    relayService: _relayService,
    // FR-001 da feature 008: sem isto, todo orçamento recebido chega como
    // kind não aceito e é ignorado sem erro (contrato, regra 4). Emenda 10 /
    // feature 009: acrescenta driverLocationKind, para reconhecer o início
    // do deslocamento do motorista aceito. Emenda 11 / feature 010:
    // acrescenta driverArrivalKind e destinationArrivalKind, consumidos pela
    // primeira vez por esta feature; meetingConfirmedKind e
    // destinationConfirmedKind também, por simetria com o T005 dela — são
    // publicados pelo próprio passageiro e voltam pela inscrição (mesmo eco
    // já observado com os demais kinds), sem processamento associado.
    // Emenda 13 / feature 018: acrescenta rideRouteKind, a rota até o destino
    // publicada pelo motorista em "Em corrida".
    // Emenda 14 / feature 019: acrescenta rideCancelledKind, o cancelamento da
    // corrida pelo motorista.
    // Emenda 16 / feature 020: acrescenta rideUnavailableKind, o aviso de que o
    // motorista não pode atender a corrida.
    // Mesma lista que o serviço em segundo plano usa na inscrição (feature 026).
    acceptedKinds: passengerConsumedKinds,
  );
  final NameService _nameService = NameService(const PrefsKeyValueStore());
  final LocationService _locationService = const GeolocatorLocationService();
  final GeocodingService _geocodingService = PhotonGeocodingService();
  final RouteService _routeService = OrsRouteService();
  final ReceivedQuoteStore _receivedQuoteStore = SqfliteReceivedQuoteStore();
  final AcceptedRideStore _acceptedRideStore = PreferencesAcceptedRideStore(
    const PrefsKeyValueStore(),
  );
  final DestinationStore _destinationStore = PreferencesDestinationStore(
    const PrefsKeyValueStore(),
  );
  final PassengerRideStateStore _rideStateStore =
      PreferencesPassengerRideStateStore(const PrefsKeyValueStore());
  final RideRatingStore _rideRatingStore = SqfliteRideRatingStore();
  String? _nomeAtual;
  var _nomeCarregado = false;

  @override
  void initState() {
    super.initState();
    _identidade = IdentityService(const FlutterSecureStore()).loadOrCreate();
    _iniciarRelays();
    _carregarNome();
  }

  /// Carrega o nome salvo — ou `null` na primeira execução (FR-001).
  Future<void> _carregarNome() async {
    final nome = await _nameService.loadName();
    if (!mounted) return;
    setState(() {
      _nomeAtual = nome;
      _nomeCarregado = true;
    });
  }

  /// Persiste o nome e atualiza o estado, o que troca a `NameScreen` pela
  /// `HomeScreen` na primeira execução (FR-004), ou reflete o novo valor na
  /// tela principal depois de uma edição (FR-007).
  Future<void> _salvarNome(String nome) async {
    await _nameService.saveName(nome);
    if (!mounted) return;
    setState(() => _nomeAtual = nome);
  }

  /// Carrega a lista que o passageiro guardou — ou a padrão, na primeira
  /// execução — e só então conecta (FR-012).
  Future<void> _iniciarRelays() async {
    final relays = await _relayRepository.load();
    await _relayService.start(relays);
    // Inicia o serviço e se apresenta a ele; os comandos acima esperam na fila
    // até o serviço responder.
    await _serviceController.start();
    // A inscrição filtra pelo marcador do protótipo (emenda 01 do contrato):
    // sem ela, chegaria o tráfego social público da rede inteira.
    _eventFeed.start();
    // FR-014: daqui em diante o ciclo automático reconecta quando a rede
    // voltar, sem intervenção do usuário.
    _relayService.enableAutoRetry();
  }

  @override
  void dispose() {
    _eventFeed.dispose();
    unawaited(_serviceController.dispose());
    _relayService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Identity>(
      future: _identidade,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _FalhaDeIdentidade(erro: snapshot.error!);
        }
        if (!snapshot.hasData || !_nomeCarregado) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (_nomeAtual == null) {
          // Primeira execução: pede o nome antes de qualquer outra tela
          // (FR-002).
          return NameScreen(onSave: _salvarNome);
        }
        return _Shell(
          locationService: _locationService,
          geocodingService: _geocodingService,
          relayService: _relayService,
          serviceController: _serviceController,
          eventFeed: _eventFeed,
          relayRepository: _relayRepository,
          routeService: _routeService,
          receivedQuoteStore: _receivedQuoteStore,
          acceptedRideStore: _acceptedRideStore,
          destinationStore: _destinationStore,
          rideStateStore: _rideStateStore,
          rideRatingStore: _rideRatingStore,
          identity: snapshot.data!,
          displayName: _nomeAtual!,
          onSaveName: _salvarNome,
        );
      },
    );
  }
}

/// Casca com a navegação entre o mapa (tela inicial) e a tela principal
/// existente (Structure Decision do `plan.md` da feature 004).
class _Shell extends StatefulWidget {
  const _Shell({
    required this.locationService,
    required this.geocodingService,
    required this.relayService,
    required this.serviceController,
    required this.eventFeed,
    required this.relayRepository,
    required this.routeService,
    required this.receivedQuoteStore,
    required this.acceptedRideStore,
    required this.destinationStore,
    required this.rideStateStore,
    required this.rideRatingStore,
    required this.identity,
    required this.displayName,
    required this.onSaveName,
  });

  final LocationService locationService;
  final GeocodingService geocodingService;
  final RelayHub relayService;
  final ServiceController serviceController;
  final EventFeed eventFeed;
  final RelayRepository relayRepository;
  final RouteService routeService;
  final ReceivedQuoteStore receivedQuoteStore;
  final AcceptedRideStore acceptedRideStore;
  final DestinationStore destinationStore;
  final PassengerRideStateStore rideStateStore;
  final RideRatingStore rideRatingStore;
  final Identity identity;
  final String displayName;
  final Future<void> Function(String) onSaveName;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final telas = [
      MapScreen(
        locationService: widget.locationService,
        geocodingService: widget.geocodingService,
        eventFeed: widget.eventFeed,
        identity: widget.identity,
        relayService: widget.relayService,
        serviceController: widget.serviceController,
        routeService: widget.routeService,
        receivedQuoteStore: widget.receivedQuoteStore,
        acceptedRideStore: widget.acceptedRideStore,
        destinationStore: widget.destinationStore,
        rideStateStore: widget.rideStateStore,
        rideRatingStore: widget.rideRatingStore,
      ),
      HomeScreen(
        relayService: widget.relayService,
        relayRepository: widget.relayRepository,
        identity: widget.identity,
        displayName: widget.displayName,
        onSaveName: widget.onSaveName,
      ),
    ];

    return Scaffold(
      // IndexedStack, não `telas[_index]`: mantém as duas telas montadas o
      // tempo todo, para que trocar de aba não desmonte e remonte
      // MapScreen — mesmo achado documentado no motorista (investigação de
      // 22/09/2026, sessão de teste manual em aparelho).
      body: IndexedStack(index: _index, children: telas),
      bottomNavigationBar: NavigationBarTheme(
        // Identidade visual (constituição 2.8.0): barra `fundo-profundo`,
        // destino selecionado em pílula `roxo`, demais em branco a 70%.
        data: NavigationBarThemeData(
          backgroundColor: IdentidadeVisual.fundoProfundo,
          indicatorColor: IdentidadeVisual.roxo,
          height: 68,
          iconTheme: WidgetStateProperty.resolveWith(
            (estados) => IconThemeData(
              color: estados.contains(WidgetState.selected)
                  ? Colors.white
                  : const Color(0xB3FFFFFF),
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (estados) => TextStyle(
              fontSize: 11,
              fontWeight: estados.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: estados.contains(WidgetState.selected)
                  ? Colors.white
                  : const Color(0xB3FFFFFF),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Mapa',
            ),
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              label: 'Mais',
            ),
          ],
        ),
      ),
    );
  }
}

/// A identidade não pôde ser criada nem recuperada.
class _FalhaDeIdentidade extends StatelessWidget {
  const _FalhaDeIdentidade({required this.erro});

  final Object erro;

  @override
  Widget build(BuildContext context) {
    final indisponivel = erro is SecureStoreUnavailable;
    return TelaDeConteudo(
      tituloBarra: appDisplayName,
      titulo: 'Identidade indisponível',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              indisponivel
                  ? 'Não foi possível acessar o armazenamento protegido'
                  : 'A identidade guardada neste aparelho está inválida',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: IdentidadeVisual.texto,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'A sua identidade Nostr precisa ser guardada em segurança para '
              'que os seus eventos sejam sempre atribuídos a você. O aplicativo '
              'não vai criar uma identidade nova, para não descartar a atual '
              'sem o seu conhecimento.',
              textAlign: TextAlign.center,
              style: TextStyle(color: IdentidadeVisual.texto),
            ),
          ],
        ),
      ),
    );
  }
}

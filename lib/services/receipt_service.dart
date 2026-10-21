import 'dart:async';
import 'dart:convert';

import '../domain/accepted_ride.dart';
import '../domain/identity.dart';
import '../domain/nostr_event.dart';
import '../domain/receipt.dart';
import '../domain/relay.dart';
import '../domain/reputation.dart';
import 'event_feed.dart';
import 'receipt_signature.dart';
import 'receipt_store.dart';
import 'reputation_verifier.dart';

/// Desfecho de [ReceiptService.issueFor].
enum ReceiptIssueOutcome {
  /// Recibo assinado, gravado como pendente; a publicação segue em segundo
  /// plano.
  issued,

  /// A reputação que o motorista declarou nesta corrida é inconsistente: nenhum
  /// recibo é emitido (contrato, 1.7 passo 2). A nota local continua gravada.
  skippedInconsistent,

  /// Já existe recibo emitido para a corrida: nada novo é emitido.
  alreadyIssued,
}

/// Emite, entrega e recebe os recibos de reputação (feature 027, emenda 25;
/// seções 1.7 e 1.8 do contrato).
///
/// Papéis neste app: **avaliador** do motorista (emite `20014` ao fim da
/// corrida e reenvia até chegar o `20015`) e **avaliado** pelo motorista
/// (recebe `20014`, grava e responde `20015`). Nada aqui lança para a
/// interface: falha de publicação nunca bloqueia a UI e os recibos pendentes
/// sobrevivem a reinício. A chave privada só é usada pelo `EventFeed` e por
/// [ReceiptSignature] (Princípio I); nada é registrado em log.
class ReceiptService {
  ReceiptService({
    required this.store,
    required this.feed,
    required this.identity,
    this.retryInterval = const Duration(seconds: 60),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ReceiptStore store;
  final EventFeed feed;
  final Identity identity;

  /// Intervalo do reenvio dos pendentes com o app aberto (contrato, 1.7).
  final Duration retryInterval;

  final DateTime Function() _clock;

  StreamSubscription<List<NostrEvent>>? _eventsSub;
  StreamSubscription<List<Relay>>? _relaysSub;
  Timer? _timer;
  var _connected = <String>{};
  final _processed = <String>{};
  var _fila = Future<void>.value();
  var _retrying = false;
  var _disposed = false;

  /// Começa a ouvir recibos e confirmações do [EventFeed], a reconexão dos
  /// relays e o relógio de [retryInterval], e já tenta reenviar os pendentes
  /// (abertura do app). Idempotente.
  void start() {
    if (_eventsSub != null || _disposed) return;
    _eventsSub = feed.events.listen(_onEvents);
    _onEvents(feed.current);
    _connected = {
      for (final r in feed.relayService.current)
        if (r.status == RelayStatus.connected) r.url,
    };
    _relaysSub = feed.relayService.relays.listen(_onRelays);
    _timer = Timer.periodic(retryInterval, (_) => unawaited(retryPending()));
    unawaited(retryPending());
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    await _eventsSub?.cancel();
    await _relaysSub?.cancel();
    _eventsSub = null;
    _relaysSub = null;
  }

  // ---------------------------------------------------------------- emissão

  /// Emite o recibo do motorista da [ride] ao fim da corrida (1.7), com [stars]
  /// (1..5) ou sem nota (`null`, "pular").
  ///
  /// Verifica a reputação que o motorista declarou nesta corrida; se ela é
  /// inconsistente, não emite. Grava o recibo como pendente **antes** de
  /// publicar. A publicação roda em segundo plano: este método volta assim que
  /// o recibo está gravado, e nenhuma falha chega ao chamador.
  Future<ReceiptIssueOutcome> issueFor(AcceptedRide ride, int? stars) async {
    if (await store.issuedFor(ride.quoteId) != null) {
      return ReceiptIssueOutcome.alreadyIssued;
    }
    final declarada =
        await store.declaredFor(ride.quoteId) ?? const Reputation.empty();
    final visao = ReputationVerifier.verify(declarada, ride.driverPubkey);
    if (visao.inconsistent) return ReceiptIssueOutcome.skippedInconsistent;

    final recibo = ReceiptSignature.issue(
      identity: identity,
      guidCorrida: ride.quoteId,
      pubkeyAvaliado: ride.driverPubkey,
      nota: stars,
      criadoEm: _clock().millisecondsSinceEpoch ~/ 1000,
      seq: declarada.seqProximo,
      hashAnterior: declarada.head,
    );
    await store.saveIssued(recibo);
    unawaited(_publish(recibo));
    return ReceiptIssueOutcome.issued;
  }

  /// Reenvia os recibos emitidos que ainda não foram confirmados. Chamado ao
  /// abrir o app, a cada reconexão de relay e a cada [retryInterval]. Não
  /// roda duas vezes ao mesmo tempo e nunca lança.
  Future<void> retryPending() async {
    if (_retrying || _disposed) return;
    _retrying = true;
    try {
      for (final recibo in await store.pendingIssued()) {
        if (_disposed) break;
        await _publish(recibo);
      }
    } on Object {
      // Nada a fazer: o próximo gatilho tenta de novo.
    } finally {
      _retrying = false;
    }
  }

  Future<void> _publish(Receipt recibo) async {
    try {
      if (!feed.relayService.hasAnyConnected) return;
      await feed.publishReceipt(recibo, identity);
    } on Object {
      // Publicação falha em silêncio: o recibo segue pendente (1.7 passo 5).
    }
  }

  // ---------------------------------------------------------------- recepção

  /// Trata a confirmação (`20015`) do avaliado: só vale se for do avaliado do
  /// recibo emitido para a corrida e trouxer o `id_recibo` dele.
  Future<void> onAckEvent(NostrEvent evento) async {
    try {
      final claro = feed.decrypted(evento, identity);
      if (claro == null) return;
      final guid = claro.referencedEventId;
      if (guid == null) return;
      final dados = jsonDecode(claro.content);
      if (dados is! Map || dados['id_recibo'] is! String) return;
      final emitido = await store.issuedFor(guid);
      if (emitido == null) return;
      if (claro.authorPublicKey != emitido.pubkeyAvaliado) return;
      if (dados['id_recibo'] != emitido.idRecibo) return;
      await store.markAcked(emitido.idRecibo);
    } on Object {
      // content é dado: o que não se entende é ignorado.
    }
  }

  /// Trata um recibo (`20014`) em que este usuário é o avaliado (1.8): valida,
  /// grava (imutável) e responde `20015`. Recibo inválido é ignorado em
  /// silêncio; recibo repetido idêntico só reenvia a confirmação.
  Future<void> onReceiptEvent(NostrEvent evento) async {
    try {
      final claro = feed.decrypted(evento, identity);
      if (claro == null) return;
      final guid = claro.referencedEventId;
      if (guid == null) return;
      final recibo = Receipt.fromJson(jsonDecode(claro.content));

      final valido =
          recibo.hasValidFields && // (d)
          recibo.pubkeyAvaliado == identity.publicKey && // (c)
          recibo.pubkeyAvaliador == claro.authorPublicKey &&
          recibo.pubkeyAvaliador != recibo.pubkeyAvaliado && // (g)
          recibo.guidCorrida == guid &&
          recibo.hasValidId && // (a)
          ReceiptSignature.verify(recibo); // (b)
      if (!valido) return;

      if (!await store.saveReceived(recibo)) {
        final existente = await store.receivedFor(guid);
        if (existente == null || existente.idRecibo != recibo.idRecibo) return;
      }
      await _ack(recibo);
    } on Object {
      // content é dado: o que não se entende é ignorado.
    }
  }

  Future<void> _ack(Receipt recibo) async {
    try {
      if (!feed.relayService.hasAnyConnected) return;
      await feed.publishReceiptAck(
        recibo.guidCorrida,
        recibo.idRecibo,
        recibo.pubkeyAvaliador,
        identity,
      );
    } on Object {
      // O avaliador reenvia o recibo e a confirmação sai na próxima vez.
    }
  }

  // ---------------------------------------------------------------- gatilhos

  void _onEvents(List<NostrEvent> eventos) {
    for (final e in eventos) {
      if (e.kind != receiptKind && e.kind != receiptAckKind) continue;
      if (!_processed.add(e.id)) continue;
      _fila = _fila.then(
        (_) => e.kind == receiptKind ? onReceiptEvent(e) : onAckEvent(e),
      );
    }
  }

  void _onRelays(List<Relay> relays) {
    final agora = {
      for (final r in relays)
        if (r.status == RelayStatus.connected) r.url,
    };
    final novoConectado = agora.difference(_connected).isNotEmpty;
    _connected = agora;
    if (novoConectado) unawaited(retryPending());
  }

  /// Espera o tratamento dos eventos já recebidos (para os testes).
  Future<void> settled() => _fila;
}

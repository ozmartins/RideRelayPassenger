import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;

import '../domain/received_quote.dart';
import '../domain/reputation.dart';

/// Persistência dos orçamentos recebidos.
///
/// Abstração do projeto (Princípio III): a implementação real usa `sqflite`
/// (D1 de `specs/008-receber-orcamentos/research.md`, mesma biblioteca já
/// usada pelo motorista); os testes usam um dublê em memória — nenhum teste
/// toca SQLite real.
abstract class ReceivedQuoteStore {
  /// Persiste [quote]. Chamado uma vez por orçamento recebido (FR-002).
  Future<void> save(ReceivedQuote quote);

  /// Todos os orçamentos já persistidos para [requestId], em qualquer ordem.
  Future<List<ReceivedQuote>> byRequest(String requestId);
}

/// Implementação real: uma tabela SQLite, `received_quotes` (D2 de
/// `research.md`).
///
/// Único tipo do aplicativo, além do teste deste arquivo, que importa
/// `package:sqflite` (Princípio III).
class SqfliteReceivedQuoteStore implements ReceivedQuoteStore {
  SqfliteReceivedQuoteStore({this.databaseName = 'received_quotes.db'});

  final String databaseName;

  sqflite.Database? _db;

  Future<sqflite.Database> _open() async {
    final aberto = _db;
    if (aberto != null) return aberto;
    final caminho = p.join(await sqflite.getDatabasesPath(), databaseName);
    final db = await sqflite.openDatabase(
      caminho,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE received_quotes (
            id             TEXT PRIMARY KEY,
            request_id     TEXT NOT NULL,
            driver_pubkey  TEXT NOT NULL,
            driver_name    TEXT NOT NULL,
            car_brand      TEXT NOT NULL,
            car_model      TEXT NOT NULL,
            car_year       INTEGER NOT NULL,
            price_per_km   REAL NOT NULL,
            total          REAL NOT NULL,
            eta_minutes    INTEGER,
            reputation_json TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_received_quotes_request_id '
          'ON received_quotes (request_id)',
        );
      },
      // v2 (feature 027): a reputação declarada pelo motorista no orçamento,
      // para sobreviver a um reinício enquanto o passageiro escolhe.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE received_quotes ADD COLUMN reputation_json TEXT',
          );
        }
      },
    );
    _db = db;
    return db;
  }

  @override
  Future<void> save(ReceivedQuote quote) async {
    final db = await _open();
    await db.insert('received_quotes', {
      'id': quote.quoteId,
      'request_id': quote.requestId,
      'driver_pubkey': quote.driverPubkey,
      'driver_name': quote.driverName,
      'car_brand': quote.carBrand,
      'car_model': quote.carModel,
      'car_year': quote.carYear,
      'price_per_km': quote.pricePerKm,
      'total': quote.total,
      'eta_minutes': quote.etaMinutes,
      'reputation_json': quote.reputation == null
          ? null
          : jsonEncode(quote.reputation!.toJson()),
    }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  @override
  Future<List<ReceivedQuote>> byRequest(String requestId) async {
    final db = await _open();
    final linhas = await db.query(
      'received_quotes',
      where: 'request_id = ?',
      whereArgs: [requestId],
    );
    return linhas.map(_fromRow).toList();
  }

  static ReceivedQuote _fromRow(Map<String, Object?> linha) => ReceivedQuote(
    quoteId: linha['id'] as String,
    requestId: linha['request_id'] as String,
    driverPubkey: linha['driver_pubkey'] as String,
    driverName: linha['driver_name'] as String,
    carBrand: linha['car_brand'] as String,
    carModel: linha['car_model'] as String,
    carYear: linha['car_year'] as int,
    pricePerKm: (linha['price_per_km'] as num).toDouble(),
    total: (linha['total'] as num).toDouble(),
    etaMinutes: linha['eta_minutes'] as int?,
    reputation: _reputationFromRow(linha['reputation_json']),
  );

  /// Reputação gravada; ausente ou ilegível vira `null` (nunca lança).
  static Reputation? _reputationFromRow(Object? json) {
    if (json is! String) return null;
    try {
      return Reputation.fromJson(jsonDecode(json));
    } on Object {
      return null;
    }
  }
}

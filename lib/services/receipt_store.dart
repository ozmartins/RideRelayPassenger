import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;

import '../domain/receipt.dart';
import '../domain/reputation.dart';
import 'receipt_signature.dart';

/// Persistência dos recibos de reputação (feature 027, emenda 25).
///
/// Abstração do projeto (Princípio III): a implementação real usa `sqflite`;
/// os testes usam um dublê em memória (`test/support/in_memory_receipt_store.dart`)
/// — nenhum teste toca SQLite real. Mesmas três tabelas e mesmos métodos do
/// app do motorista.
abstract class ReceiptStore {
  /// Grava um recibo em que este usuário é o avaliado. Imutável: devolve
  /// `false`, sem alterar nada, se já existe recibo para a corrida.
  Future<bool> saveReceived(Receipt receipt);

  /// O recibo recebido para [guidCorrida], ou `null` se não existe ou se não
  /// confere mais (id ou assinatura, revalidados a cada leitura).
  Future<Receipt?> receivedFor(String guidCorrida);

  /// A reputação deste usuário, recalculada sobre os recibos recebidos que
  /// ainda conferem. Vazia ([Reputation.isEmpty]) sem recibos.
  Future<Reputation> myReputation();

  /// Grava um recibo emitido como pendente, **antes** de publicar (sobrevive a
  /// reinício). Mantém o que já existe para a corrida.
  Future<void> saveIssued(Receipt receipt);

  /// O recibo emitido para [guidCorrida] (pendente ou confirmado), ou `null`.
  Future<Receipt?> issuedFor(String guidCorrida);

  /// Recibos emitidos ainda sem confirmação, em ordem de gravação.
  Future<List<Receipt>> pendingIssued();

  /// Marca como confirmado o recibo emitido com [idRecibo].
  Future<void> markAcked(String idRecibo);

  /// Guarda a reputação que o [avaliado] declarou no orçamento [quoteId].
  Future<void> saveDeclared(
    String quoteId,
    String avaliado,
    Reputation reputation,
  );

  /// A reputação declarada para [quoteId], ou `null` se não há registro.
  Future<Reputation?> declaredFor(String quoteId);
}

/// Verdadeiro se [receipt] ainda confere: `id_recibo` recalculado e assinatura
/// válida para o avaliador. Usado em cada leitura de recibo recebido.
bool isIntactReceipt(Receipt receipt) =>
    receipt.hasValidId && ReceiptSignature.verify(receipt);

/// Calcula a [Reputation] a partir dos recibos [recebidos] (contrato, 1.8):
/// `corridas`, `avaliacoes`, `media`, `seq_proximo = max(seq)+1`, `head` = id
/// do recibo de maior `seq` e os [kReputacaoJanela] mais recentes por `seq`.
///
/// Ramos (mesmo `seq`) desempatam pelo `id_recibo`, nunca por `criado_em`
/// (declarado, não confiável).
Reputation reputationFromReceipts(Iterable<Receipt> recebidos) {
  final lista = recebidos.toList()
    ..sort((a, b) {
      final porSeq = b.seq.compareTo(a.seq);
      return porSeq != 0 ? porSeq : a.idRecibo.compareTo(b.idRecibo);
    });
  if (lista.isEmpty) return const Reputation.empty();
  final notas = [
    for (final r in lista)
      if (r.nota != null) r.nota!,
  ];
  return Reputation(
    corridas: lista.length,
    avaliacoes: notas.length,
    media: notas.isEmpty ? null : notas.reduce((a, b) => a + b) / notas.length,
    seqProximo: lista.first.seq + 1,
    head: lista.first.idRecibo,
    recibos: lista.take(kReputacaoJanela).toList(),
  );
}

/// Implementação real: `receipts.db` (v1) com `recibos_recebidos`,
/// `recibos_emitidos` e `reputacao_declarada` (D7 de
/// `specs/027-recibos-de-reputacao/research.md`).
///
/// Único tipo do aplicativo, além de `ReceivedQuoteStore` e
/// `RideRatingStore`, que importa `package:sqflite` (Princípio III).
class SqfliteReceiptStore implements ReceiptStore {
  SqfliteReceiptStore({this.databaseName = 'receipts.db'});

  final String databaseName;

  sqflite.Database? _db;

  Future<sqflite.Database> _open() async {
    final aberto = _db;
    if (aberto != null) return aberto;
    final caminho = p.join(await sqflite.getDatabasesPath(), databaseName);
    final db = await sqflite.openDatabase(
      caminho,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE recibos_recebidos (
            guid_corrida TEXT PRIMARY KEY,
            id_recibo    TEXT UNIQUE NOT NULL,
            seq          INTEGER NOT NULL,
            avaliador    TEXT NOT NULL,
            nota         INTEGER CHECK (nota BETWEEN 1 AND 5),
            json         TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE recibos_emitidos (
            guid_corrida TEXT PRIMARY KEY,
            id_recibo    TEXT NOT NULL,
            avaliado     TEXT NOT NULL,
            json         TEXT NOT NULL,
            pendente     INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE reputacao_declarada (
            quote_id TEXT PRIMARY KEY,
            avaliado TEXT NOT NULL,
            json     TEXT NOT NULL
          )
        ''');
      },
    );
    _db = db;
    return db;
  }

  /// Lê o recibo de [json]; `null` se não decodifica.
  static Receipt? _decode(Object? json) {
    try {
      return Receipt.fromJson(jsonDecode(json as String));
    } on Object {
      return null;
    }
  }

  @override
  Future<bool> saveReceived(Receipt receipt) async {
    final db = await _open();
    final id = await db.insert('recibos_recebidos', {
      'guid_corrida': receipt.guidCorrida,
      'id_recibo': receipt.idRecibo,
      'seq': receipt.seq,
      'avaliador': receipt.pubkeyAvaliador,
      'nota': receipt.nota,
      'json': jsonEncode(receipt.toJson()),
    }, conflictAlgorithm: sqflite.ConflictAlgorithm.ignore);
    return id > 0; // ignorado por conflito: 0 ou -1
  }

  @override
  Future<Receipt?> receivedFor(String guidCorrida) async {
    final db = await _open();
    final linhas = await db.query(
      'recibos_recebidos',
      where: 'guid_corrida = ?',
      whereArgs: [guidCorrida],
    );
    if (linhas.isEmpty) return null;
    final recibo = _decode(linhas.first['json']);
    return recibo != null && isIntactReceipt(recibo) ? recibo : null;
  }

  @override
  Future<Reputation> myReputation() async {
    final db = await _open();
    final linhas = await db.query('recibos_recebidos');
    final intactos = <Receipt>[];
    for (final linha in linhas) {
      final recibo = _decode(linha['json']);
      if (recibo != null && isIntactReceipt(recibo)) intactos.add(recibo);
    }
    return reputationFromReceipts(intactos);
  }

  @override
  Future<void> saveIssued(Receipt receipt) async {
    final db = await _open();
    await db.insert('recibos_emitidos', {
      'guid_corrida': receipt.guidCorrida,
      'id_recibo': receipt.idRecibo,
      'avaliado': receipt.pubkeyAvaliado,
      'json': jsonEncode(receipt.toJson()),
      'pendente': 1,
    }, conflictAlgorithm: sqflite.ConflictAlgorithm.ignore);
  }

  @override
  Future<Receipt?> issuedFor(String guidCorrida) async {
    final db = await _open();
    final linhas = await db.query(
      'recibos_emitidos',
      where: 'guid_corrida = ?',
      whereArgs: [guidCorrida],
    );
    return linhas.isEmpty ? null : _decode(linhas.first['json']);
  }

  @override
  Future<List<Receipt>> pendingIssued() async {
    final db = await _open();
    final linhas = await db.query(
      'recibos_emitidos',
      where: 'pendente = 1',
      orderBy: 'rowid',
    );
    return [
      for (final linha in linhas)
        if (_decode(linha['json']) case final Receipt r) r,
    ];
  }

  @override
  Future<void> markAcked(String idRecibo) async {
    final db = await _open();
    await db.update(
      'recibos_emitidos',
      {'pendente': 0},
      where: 'id_recibo = ?',
      whereArgs: [idRecibo],
    );
  }

  @override
  Future<void> saveDeclared(
    String quoteId,
    String avaliado,
    Reputation reputation,
  ) async {
    final db = await _open();
    await db.insert('reputacao_declarada', {
      'quote_id': quoteId,
      'avaliado': avaliado,
      'json': jsonEncode(reputation.toJson()),
    }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  @override
  Future<Reputation?> declaredFor(String quoteId) async {
    final db = await _open();
    final linhas = await db.query(
      'reputacao_declarada',
      where: 'quote_id = ?',
      whereArgs: [quoteId],
    );
    if (linhas.isEmpty) return null;
    try {
      return Reputation.fromJson(jsonDecode(linhas.first['json'] as String));
    } on Object {
      return null;
    }
  }
}

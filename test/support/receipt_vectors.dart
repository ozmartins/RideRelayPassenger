import 'dart:convert';
import 'dart:io';

/// Lê o vetor de contrato compartilhado da reputação por recibos
/// (`test/fixtures/receipt_vectors.json`, **idêntico nas duas apps**; gerado
/// no app do motorista e copiado byte a byte — nunca editar aqui).
Map<String, dynamic> carregarVetoresDeRecibo() =>
    jsonDecode(File('test/fixtures/receipt_vectors.json').readAsStringSync())
        as Map<String, dynamic>;

/// Os vetores individuais (`vetores`) do arquivo.
List<Map<String, dynamic>> vetoresDeRecibo() =>
    (carregarVetoresDeRecibo()['vetores'] as List).cast<Map<String, dynamic>>();

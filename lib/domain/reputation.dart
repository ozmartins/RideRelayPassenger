import 'receipt.dart';

/// Quantos recibos mais recentes uma reputação apresenta (contrato, 1.5).
const int kReputacaoJanela = 5;

/// Reputação declarada por um usuário: resumo + os [kReputacaoJanela] recibos
/// mais recentes, do mais novo para o mais antigo (feature 027, emenda 25).
///
/// `corridas`, `avaliacoes` e `media` são **declarados**: só [recibos] são
/// verificáveis (limites conhecidos, 1.9 do contrato).
class Reputation {
  const Reputation({
    required this.corridas,
    required this.avaliacoes,
    this.media,
    required this.seqProximo,
    this.head,
    required this.recibos,
    this.ilegiveis = 0,
  });

  /// Sem histórico: a reputação de quem ainda não tem recibos.
  const Reputation.empty()
    : corridas = 0,
      avaliacoes = 0,
      media = null,
      seqProximo = 0,
      head = null,
      recibos = const [],
      ilegiveis = 0;

  /// Nº de recibos guardados.
  final int corridas;

  /// Nº de recibos com nota.
  final int avaliacoes;

  /// Média das notas; `null` quando [avaliacoes] é 0.
  final double? media;

  /// Próximo `seq` a ser usado na cadeia.
  final int seqProximo;

  /// `id_recibo` do recibo `seqProximo − 1`; `null` quando [seqProximo] é 0.
  final String? head;

  final List<Receipt> recibos;

  /// Entradas de `recibos` que não puderam ser lidas (estrutura inválida) ou
  /// passaram da janela: descartadas e contadas, nunca invalidam o resto.
  /// Só existe depois de [Reputation.fromJson]; não é serializado.
  final int ilegiveis;

  /// Sem nenhum recibo guardado — o `20001` sai sem a chave `reputacao`.
  bool get isEmpty => corridas == 0 && recibos.isEmpty;

  Map<String, dynamic> toJson() => {
    'corridas': corridas,
    'avaliacoes': avaliacoes,
    if (media != null) 'media': media,
    'seq_proximo': seqProximo,
    if (head != null) 'head': head,
    'recibos': [for (final r in recibos) r.toJson()],
  };

  /// Leitura estrita do resumo: [FormatException] para qualquer campo ausente
  /// ou inválido (quem chama trata a reputação como ausente). Já um recibo de
  /// `recibos` que não se lê, ou que passa da janela de [kReputacaoJanela],
  /// é descartado e contado em [ilegiveis], sem invalidar o objeto (1.6).
  factory Reputation.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Reputação não é um objeto');
    int inteiro(String chave) {
      final valor = json[chave];
      if (valor is! int || valor < 0) {
        throw FormatException('Reputação com "$chave" inválido');
      }
      return valor;
    }

    double? media;
    if (json.containsKey('media')) {
      final valor = json['media'];
      if (valor is! num) throw const FormatException('Reputação com "media"');
      media = valor.toDouble();
    }
    String? head;
    if (json.containsKey('head')) {
      final valor = json['head'];
      if (valor is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(valor)) {
        throw const FormatException('Reputação com "head" inválido');
      }
      head = valor;
    }
    final lista = json['recibos'];
    if (lista is! List) {
      throw const FormatException('Reputação sem "recibos"');
    }
    final recibos = <Receipt>[];
    var ilegiveis = 0;
    for (final (i, entrada) in lista.indexed) {
      if (i >= kReputacaoJanela) {
        ilegiveis++;
        continue;
      }
      try {
        recibos.add(Receipt.fromJson(entrada));
      } on FormatException {
        ilegiveis++;
      }
    }
    return Reputation(
      corridas: inteiro('corridas'),
      avaliacoes: inteiro('avaliacoes'),
      media: media,
      seqProximo: inteiro('seq_proximo'),
      head: head,
      recibos: recibos,
      ilegiveis: ilegiveis,
    );
  }
}

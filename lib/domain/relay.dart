/// Estado de conexão de um relay.
enum RelayStatus {
  /// Tentando estabelecer a conexão. Estado inicial de todo relay.
  connecting,

  /// Conectado e apto a publicar e receber.
  connected,

  /// Inalcançável ou com falha. O relay **permanece na lista**, visível com o
  /// motivo, porque a falha de um não pode derrubar os demais (FR-003).
  unavailable,
}

/// Um relay Nostr da lista do passageiro.
///
/// A [url] é a chave da entidade: não há duas entradas com o mesmo endereço.
class Relay {
  const Relay({
    required this.url,
    this.status = RelayStatus.connecting,
    this.lastError,
    this.isDefault = false,
  });

  /// Endereço `wss://` ou `ws://` do relay.
  final String url;

  /// Estado corrente da conexão. Existe apenas em memória: não faz sentido
  /// restaurar "conectado" de uma sessão anterior.
  final RelayStatus status;

  /// Motivo resumido da indisponibilidade, para exibição. Nulo quando o relay
  /// não está em [RelayStatus.unavailable].
  final String? lastError;

  /// Verdadeiro para relay da lista padrão embutida; falso para relay que o
  /// passageiro acrescentou.
  final bool isDefault;

  /// Aceita apenas endereços WebSocket com host não vazio.
  static bool isValidUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty) return false;
    return uri.scheme == 'wss' || uri.scheme == 'ws';
  }

  /// Normaliza o endereço para comparação e deduplicação da lista, removendo
  /// espaços, uniformizando a caixa e descartando a barra final.
  static String normalizeUrl(String value) {
    final limpo = value.trim().toLowerCase();
    return limpo.endsWith('/') ? limpo.substring(0, limpo.length - 1) : limpo;
  }

  Relay copyWith({
    RelayStatus? status,
    String? lastError,
    bool clearError = false,
  }) {
    return Relay(
      url: url,
      status: status ?? this.status,
      lastError: clearError ? null : (lastError ?? this.lastError),
      isDefault: isDefault,
    );
  }

  @override
  String toString() =>
      'Relay($url, $status${lastError == null ? '' : ', $lastError'})';

  @override
  bool operator ==(Object other) => other is Relay && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

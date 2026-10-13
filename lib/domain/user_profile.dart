/// Perfil local do usuário do app do passageiro — o nome/apelido de exibição
/// escolhido pela pessoa.
///
/// Não se confunde com [Identity] (`domain/identity.dart`), a identidade
/// criptográfica Nostr: é um dado complementar, só de exibição local, sem
/// relação com o contrato de eventos (ver specs/003-nome-usuario/spec.md).
class UserProfile {
  const UserProfile({required this.displayName});

  /// Tamanho máximo aceito para o nome (FR-006).
  static const maxDisplayNameLength = 60;

  final String displayName;

  /// Valida e normaliza um nome digitado: remove espaços das extremidades e
  /// recusa vazio ou acima do limite (FR-003, FR-006).
  ///
  /// Lança [ArgumentError] quando o valor é inválido.
  factory UserProfile.fromInput(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('O nome é obrigatório');
    }
    if (trimmed.length > maxDisplayNameLength) {
      throw ArgumentError(
        'O nome deve ter no máximo $maxDisplayNameLength caracteres',
      );
    }
    return UserProfile(displayName: trimmed);
  }
}

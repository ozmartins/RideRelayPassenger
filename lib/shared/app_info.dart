/// Constantes de identidade do aplicativo do passageiro.
///
/// Centraliza os textos que identificam esta app para que o nome de exibição
/// não fique duplicado entre o [MaterialApp], a [AppBar] e os testes.
library;

/// Nome de exibição do aplicativo, coerente com `android:label` no manifesto
/// Android e com o `applicationId` `br.ufsc.tcc.corridas.passenger`.
const String appDisplayName = 'Corridas Passageiro';

/// Texto exibido no corpo da tela inicial enquanto não há funcionalidade de
/// corridas implementada.
const String homePlaceholderMessage =
    'Aplicativo do passageiro do protótipo de corridas P2P sobre Nostr.';

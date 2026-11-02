/// Chave de API do openrouteservice (feature de rotas).
///
/// Vem do build: `--dart-define=ORS_API_KEY=...`. A chave não é versionada;
/// sem ela o valor é vazio e a rota cai no fallback.
class OrsApiKey {
  const OrsApiKey._();

  static const value = String.fromEnvironment('ORS_API_KEY');
}

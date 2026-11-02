/// Lista padrão de relays do protótipo.
///
/// **MUST ser idêntica à lista da app do motorista**
/// (`Prototipo/driver/lib/services/default_relays.dart`). É o relay em comum
/// que permite o passageiro receber o que o motorista publica — não existe
/// canal direto entre as duas apps. Alterar aqui exige alterar lá na mesma
/// mudança.
///
/// Fixada na decisão D7 de `specs/002-nostr-relay-connection/research.md` e
/// verificada em 16/09/2026 publicando um evento assinado e recuperando-o por
/// uma conexão separada: os três completaram a ida e volta abaixo de 1,4 s.
///
/// `wss://relay.damus.io`, que constava da lista do motorista, foi removido:
/// falhou a conexão em 1 de 3 tentativas consecutivas. Reserva já verificada,
/// caso algum dos três caia: `wss://nostr.mom`.
///
/// A lista é volátil por natureza. Reconfirme com `dart run tool/check_relays.dart`,
/// que espelha esta constante.
const List<String> defaultRelays = [
  'wss://nos.lol',
  'wss://relay.primal.net',
  'wss://offchain.pub',
];

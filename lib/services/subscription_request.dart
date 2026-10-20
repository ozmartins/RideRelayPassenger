import 'dart:convert';

import 'package:passenger/shared/prototype_marker.dart';

/// Identificador da inscrição do app nos relays.
const String eventSubscriptionId = 'corridas';

/// Os `kind` que o passageiro consome (a lista da inscrição), em um arquivo
/// sem dependências para o serviço em segundo plano poder usá-la sem importar
/// o `EventFeed` (que traz identidade e cifra). Os valores são os mesmos das
/// constantes de `event_feed.dart`; um teste confere a igualdade.
const Set<int> passengerConsumedKinds = {
  20002, // orçamento (emendas 05/06)
  20005, // localização do motorista (emenda 08)
  20007, // chegada do motorista (emenda 09)
  20008, // encontro confirmado (emenda 11, eco da própria publicação)
  20009, // chegada ao destino (emenda 11)
  20010, // destino confirmado (emenda 11, eco)
  20011, // rota da corrida (emenda 13)
  20012, // corrida cancelada pelo motorista (emenda 14)
  20006, // motorista indisponível (emenda 16)
};

/// A inscrição, conforme o contrato (emendas 01 e 02): filtra por `kind` e pelo
/// marcador, e limita o histórico entregue ao estabelecer a inscrição.
///
/// MUST NOT usar `since`: a inscrição é reenviada a cada conexão, e um `since`
/// calculado uma vez ficaria cada vez mais velho.
String buildSubscriptionRequest(Set<int> kinds) => jsonEncode([
  'REQ',
  eventSubscriptionId,
  {
    'kinds': kinds.toList(),
    '#t': [prototypeMarker],
    'limit': 50,
  },
]);

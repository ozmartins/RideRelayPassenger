# Phase 0 — Research: Rota real até o destino

## D1 — Cliente de roteamento: `open_route_service` (atende FR-001, FR-004; exceção da constituição
2.3.0)

**Decision**: adotar **`open_route_service` versão `^1.2.9`** como dependência direta em
`pubspec.yaml`, confinada a `lib/services/route_service.dart`. Consultar a API pública
openrouteservice (`https://api.openrouteservice.org`) pelo endpoint de Directions, perfil
`driving-car`.

**Contexto da decisão**: o pedido de feature já nomeia a biblioteca; a decisão registrada aqui é
sobre confirmar que ela cobre o caso de uso sem superfície não usada, e sobre *como* usá-la dentro
dos limites da constituição, não sobre *se* usá-la.

### Alternativas avaliadas

| Opção | Versão consultada | Observação |
|-------|--------------------|------------|
| `open_route_service` (escolhida) | `1.2.9`, publicada no pub.dev (`Dhi13man/open_route_service`) | Cliente tipado para a API openrouteservice completa (directions, matrix, geocode, elevation, isochrones, POIs, optimization). Só o endpoint de directions é usado nesta feature; o restante da superfície não é chamado, mas o pacote não impõe custo por isso — é uma única dependência com uma API de alto nível (`directionsRouteCoordsGet`) que já devolve `List<ORSCoordinate>`, sem exigir montar a URL/JSON da API à mão. |
| Chamar a API openrouteservice diretamente via `http` (já usado no passenger para a Photon, feature 005) | N/A — seria código do projeto, não pacote | Evitaria uma dependência de terceiros nova, mas exigiria reimplementar manualmente a montagem do corpo JSON, a decodificação da resposta GeoJSON de directions e o tratamento dos códigos de erro específicos da API (limite excedido, coordenada fora de alcance) — exatamente o que `open_route_service` já resolve testado. Descartada por Princípio V: a superfície evitada (uma dependência) é menor que a superfície criada (um parser de resposta GeoJSON próprio, sem uso em nenhuma outra feature). |
| Calcular só distância em linha reta (fórmula de Haversine, sem dependência) | N/A | É exatamente o que a Feature Description e a User Story 1 rejeitam explicitamente — a distância em linha reta já está disponível hoje (as duas coordenadas existem) e não responde à pergunta "quão longe a corrida realmente vai ser" no trajeto rodoviário. Descartada por não atender ao requisito, não por custo. |

### Critérios aplicados

1. **Cobertura do caso de uso com a menor superfície adicional** — a feature precisa de um trajeto
   rodoviário e sua distância entre dois pontos; `directionsRouteCoordsGet` devolve exatamente
   `List<ORSCoordinate>`, suficiente para desenhar o `Polyline` e somar a distância.
2. **Confinamento de tipos (Princípio III)** — `OpenRouteService`, `ORSCoordinate` e qualquer
   exceção do pacote ficam inteiramente dentro de `lib/services/route_service.dart`; `domain/` e
   `screens/` só veem `RouteResult`, tipo próprio do projeto (`data-model.md`).
3. **Cumprimento da exceção da constituição 2.3.0** — a chamada usa HTTPS (endpoint
   `https://api.openrouteservice.org`, fixo no pacote); não inclui `pubkey`, nome ou apelido de
   exibição, só as coordenadas de origem e destino; a resposta (`RouteResult`) não é persistida além
   da sessão em curso (Key Entities do `spec.md`).

### Riscos assumidos e mitigação

- **Risco de indisponibilidade do serviço ou limite de requisições excedido**: mitigado tratando
  toda exceção do pacote (rede, timeout, HTTP 429/erro de rota) como falha de cálculo de rota,
  absorvida sem bloquear a tela (US3, FR-006/FR-007) — mesmo padrão já usado para a Photon (D1/D2 da
  feature 005).
- **Risco de a API exigir chave própria por requisição (ver D3)**: mitigado documentando a
  configuração local da chave sem committá-la (D3).

## D2 — Throttle de recálculo por deslocamento: 50 metros (atende FR-003; Clarifications, sessão
2026-09-20)

**Decision**: recalcular a rota quando o destino mudar **e** quando a posição atual do passageiro se
afastar mais de 50 metros do ponto de origem usado no último cálculo bem-sucedido ou em andamento —
nunca a cada atualização de posição recebida do `LocationService`.

**Contexto da decisão**: resolvida na sessão de clarificação de 2026-09-20 (ver `spec.md`,
Clarifications). O nível gratuito da API openrouteservice tem limite de requisições por minuto;
recalcular a cada atualização de GPS (tipicamente a cada 1–5 s) esgotaria esse limite em poucos
minutos de uso contínuo.

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| 50 m de deslocamento (escolhida) | Padrão comum em apps de navegação para throttle de recálculo; suficientemente pequeno para a rota não ficar visivelmente desatualizada num trajeto urbano, suficientemente grande para reduzir drasticamente a frequência de chamadas em relação a cada atualização de GPS. |
| Recalcular a cada atualização de posição | Rejeitada explicitamente na clarificação — risca esgotar o limite de requisições do nível gratuito em poucos minutos de uso. |
| Intervalo de tempo fixo (ex.: 30 s) | Rejeitada na clarificação em favor do critério por distância: um passageiro parado não gera nenhuma chamada extra (compatível com Princípio V — não gastar requisição sem mudança real de contexto), e um passageiro em movimento rápido tem a rota atualizada antes de um intervalo de tempo fixo generoso permitiria. |

### Riscos assumidos e mitigação

- **Risco de a rota ficar desatualizada entre dois recálculos**: aceito como risco de protótipo — o
  traçado é um complemento visual (User Story 2, prioridade P2), não a informação de maior peso da
  feature (a distância, User Story 1).

## D3 — Configuração da chave de API do openrouteservice (suporta D1; não altera FR)

**Decision**: a chave de API exigida pelo `OpenRouteService(apiKey: ...)` (ver
`open_route_service`, seção Prerequisites do README) é lida em tempo de build via
`String.fromEnvironment('ORS_API_KEY')` (`--dart-define=ORS_API_KEY=...` no `flutter run`/`flutter
test`), nunca hardcoded no código-fonte nem commitada no repositório.

**Contexto da decisão**: diferente da Photon (feature 005), que não exige chave, a API
openrouteservice exige cadastro e uma chave pessoal por consumidor. Essa chave não é o "segredo
criptográfico" do Princípio I (não identifica nem autentica o usuário do app perante outros usuários
Nostr), mas é uma credencial de acesso ao serviço de terceiros e por isso não deve ser versionada.

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| `--dart-define` em tempo de build (escolhida) | Padrão nativo do Flutter para valores de configuração que não devem ir ao controle de versão; sem dependência nova; documentado no `quickstart.md` para quem for rodar/testar o app localmente. |
| Hardcode da chave no código-fonte | Rejeitada: a chave ficaria no histórico do git permanentemente, visível a qualquer leitor do repositório público do TCC. |
| Armazenamento seguro no aparelho (`flutter_secure_storage`, já usado para a identidade Nostr) | Rejeitada por desproporcional (Princípio V): resolve persistência entre execuções, que não é o problema aqui — a chave é a mesma em toda execução de desenvolvimento/teste, e não há fluxo de usuário final para digitá-la (o protótipo não distribui build assinado a terceiros). |

### Riscos assumidos e mitigação

- **Risco de rodar o app sem a chave configurada**: tratado como falha de cálculo de rota
  (US3/FR-007) — a ausência de chave produz erro de autenticação do serviço, absorvido pelo mesmo
  caminho de tratamento de falha de qualquer outra indisponibilidade do serviço.

## D4 — Header `Authorization` manual sobre `OpenRouteService` (corrige bug do pacote, atende FR-007)

**Decision**: `OrsRouteService` passa a construir o `OpenRouteService` com um `client:` próprio —
`_AuthorizingHttpClient`, um `http.BaseClient` que acrescenta o header `Authorization: <chave>` a
toda requisição antes de delegar a um `http.Client` interno. Sem mudança de `pubspec.yaml` — `http`
já é dependência de produção aqui (D1 de `specs/005-busca-endereco-photon/research.md`).

**Contexto da decisão**: validação manual em aparelho (dois emuladores, motorista e passageiro)
encontrou toda chamada de rota falhando com `401 Authorization field missing`. Diagnóstico por
`curl` direto contra `api.openrouteservice.org`: `open_route_service` 1.2.9 monta a URL da chamada
GET de directions com a chave como query param `api_key=...`
(`ORSDirections.directionsRouteGeoJsonGet`, em `open_route_service_base.dart`), formato que a API
atual do openrouteservice.org rejeita — só aceita a chave no header HTTP `Authorization`. Bug do
pacote vendorizado, não do código deste projeto; sem correção anunciada no `CHANGELOG.md` da versão
instalada. Mesmo diagnóstico e mesma correção aplicados no motorista (D7 de
`specs/007-receber-solicitacao-corrida/research.md` dele), por coincidência de terem usado o mesmo
pacote — não é um caso do Princípio IV (contrato de evento), então não precisou ser a mesma
alteração na mesma mudança.

Sem tocar no pacote (fora do controle do projeto, mudança se perderia em qualquer
`flutter pub get`/`pub cache repair`/outra máquina): `OpenRouteService` já aceita um `client:`
(`http.Client?`) opcional no construtor, usado internamente para toda chamada — ponto de extensão
correto para acrescentar o header sem depender do formato de autenticação que o pacote decidiu usar
por conta própria.

**Risco assumido**: se uma versão futura do pacote corrigir o bug e passar a mandar o header por
conta própria, o header fica duplicado (mesmo valor duas vezes) — inofensivo, mas a decisão deve
ser revisitada ao atualizar a versão de `open_route_service`.

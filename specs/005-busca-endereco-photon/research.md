# Phase 0 — Research: Busca de Endereço via Photon

## D1 — Cliente HTTP (atende FR-002 a FR-004, FR-008, FR-009)

**Decision**: adotar **`http` versão `^1.6.0`** como dependência direta em `pubspec.yaml`, confinada a
`lib/services/geocoding_service.dart`.

**Contexto da decisão**: `http` já é resolvida como dependência transitiva do projeto (via
`dart_nostr`), na versão `1.6.0`, publicada pelo publisher verificado `dart.dev` no pub.dev. Promovê-la
a dependência direta, em vez de acrescentar um cliente HTTP novo, evita duplicar a mesma
responsabilidade com duas bibliotecas diferentes no mesmo projeto.

### Alternativas avaliadas

| Opção | Versão mais recente (pub.dev, consultado em 2026-09-17) | Observação |
|-------|-----------------------------------------------------------|------------|
| `http` (escolhida) | `1.6.0`, publicada ~10 meses antes da consulta, publisher verificado `dart.dev` | Já resolvida transitivamente; API mínima (`get`, decodificação manual do corpo); sem dependências de terceiros além de `http_parser`. |
| `dio` | `5.11.1`, publicada ~13 dias antes da consulta | Resolve o mesmo problema com mais recursos (interceptors, transformers, cancelamento) que esta feature não precisa — uma única requisição GET por busca. Depende de 7 pacotes (`async`, `collection`, `dio_web_adapter`, `http_parser`, `meta`, `mime`, `path`) contra a superfície bem menor de `http`. |
| `dart:io HttpClient` direto | parte do SDK, sem versão própria | Evita qualquer dependência de terceiros, mas não é multiplataforma da mesma forma (`dart:io` não roda em Web) e exige mais código manual para decodificação JSON, timeout e tratamento de erro que `package:http` já oferece pronto. Como `http` já está no grafo de dependências do projeto, não há redução real de superfície em evitá-la. |

### Critérios aplicados

1. **Cobertura do caso de uso com a menor superfície** — a feature faz uma única requisição GET por
   busca, decodifica um JSON e trata timeout/erro de rede; `http` cobre isso sem recurso não usado.
2. **Já presente no grafo de dependências** — promover uma dependência transitiva já resolvida e
   auditada (via `dart_nostr`) para direta não aumenta a superfície de terceiros do projeto, ao
   contrário de introduzir `dio`.
3. **Confinamento de tipos (Princípio III)** — `http.Client`, `http.Response` e o parsing do JSON da
   Photon ficam inteiramente dentro de `lib/services/geocoding_service.dart`; `domain/` e `screens/`
   só veem o tipo próprio `AddressSuggestion`.

### Riscos assumidos e mitigação

- **Risco de indisponibilidade da rede ou do serviço**: mitigado tratando toda exceção de
  `http.Client.get` (incluindo timeout, configurado em 5 s) como falha de busca, reportada ao usuário
  sem travar a tela (FR-009, US3).
- **Risco de resposta malformada**: mitigado tratando falha de decodificação do JSON da mesma forma
  que falha de rede — nunca deixando uma exceção não tratada chegar à UI.

## D2 — Serviço de geocodificação: instância pública da Photon (atende FR-002, exceção da
constituição 2.2.0)

**Decision**: consultar a instância pública `https://photon.komoot.io/api/`, sem hospedar instância
própria, usando apenas os parâmetros `q` (texto de busca), `lang=pt` (idioma dos resultados) e `limit`
(quantidade de sugestões, fixado em 5). Nenhum parâmetro de geolocalização (`lat`, `lon`, `zoom`,
`location_bias_scale`) é enviado — não há priorização geográfica dos resultados (Assumptions do
`spec.md`), e enviá-los exigiria a posição atual do passageiro, que a exceção da constituição 2.2.0
proíbe anexar à chamada.

**Contexto da decisão**: o próprio pedido de feature já nomeia a Photon como o serviço a integrar; a
decisão registrada aqui é sobre *como* usá-la dentro dos limites da constituição, não sobre *se*
usá-la.

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| Instância pública `photon.komoot.io` (escolhida) | Documentada pelo projeto como disponível para "uso razoável" ("as long as the number of requests stay in a reasonable limit"), sem garantia de disponibilidade e sujeita a limitação de tráfego em uso extensivo — aceitável para um protótipo acadêmico de avaliação, não para produção. |
| Hospedar instância própria da Photon | Exigiria infraestrutura própria (servidor, importação do dump do OpenStreetMap) fora do escopo de um protótipo sem backend; desproporcional ao Princípio V para provar a viabilidade de uma busca de endereço. |

### Critérios aplicados

1. **Simplicidade proporcional (Princípio V)** — o protótipo existe para responder se a arquitetura
   Nostr sem backend sustenta o app; hospedar geocodificador próprio não testa essa pergunta.
2. **Cumprimento da exceção da constituição** — a chamada não inclui `pubkey`, nome de exibição nem
   posição atual; usa HTTPS (`https://photon.komoot.io/api/`); nada da resposta é persistido além da
   sessão (mesma garantia de `DestinationAddress` na feature 004).
3. **Mitigação de uso excessivo do serviço público** — o agrupamento de digitações (debounce) de D3
   reduz o número de requisições por busca, respeitando o "uso razoável" pedido pelo mantenedor.

### Riscos assumidos e mitigação

- **Risco de throttling/banimento pelo mantenedor da instância pública**: mitigado pelo debounce e
  pelo tamanho mínimo de busca de D3, e aceito como risco de protótipo — não de produção — coerente
  com o Princípio V.
- **Risco de resultados em outro idioma**: mitigado com `lang=pt` na consulta.

## D3 — Disparo da busca: debounce e tamanho mínimo de texto (atende FR-003, Edge Cases do `spec.md`)

**Decision**: disparar uma nova busca 400 ms depois da última tecla digitada (debounce via
`Timer` de `dart:async`, sem biblioteca adicional), e só a partir de 3 caracteres digitados.

**Contexto da decisão**: o `spec.md` já assume, nas Assumptions, que "um agrupamento razoável de
digitações próximas no tempo antes de disparar a busca é suficiente", sem fixar um número. Um valor
concreto precisa existir para implementar e testar a US1; 400 ms e 3 caracteres são os valores comuns
usados por campos de busca com sugestões (equilíbrio entre resposta percebida como instantânea e
volume de requisições ao serviço público de D2).

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| 400 ms / 3 caracteres (escolhida) | Reduz drasticamente requisições por texto muito curto (que a Photon geralmente não consegue distinguir de qualquer forma) sem atraso perceptível para o usuário. |
| Buscar a cada tecla, sem debounce nem mínimo | Mais simples de implementar, mas gera uma requisição HTTP por tecla digitada — descumpre o "uso razoável" da instância pública de D2 e não é medida usual para busca com sugestões. |
| Exigir botão explícito de "buscar" | Contradiz FR-003 (a lista deve atualizar sem ação explícita além de digitar) e a User Story 1, que descreve sugestões aparecendo *enquanto* o usuário digita. |

### Riscos assumidos e mitigação

- **Risco de o debounce atrasar percepção de resposta**: 400 ms está abaixo do limiar comumente citado
  para "resposta instantânea" em interação de texto; validado de fato no `quickstart.md` (SC-003), não
  estimado.

## D4 — Correções encontradas na validação contra a rede real (T026, 2026-09-18)

**Contexto**: D1–D3 foram decididas antes de qualquer chamada real à Photon. A validação em aparelho
(T026 do `tasks.md`) expôs duas premissas erradas, ambas causando falha de busca em 100% das
tentativas — sintoma indistinguível de indisponibilidade de rede até a inspeção do corpo da resposta.

**Decision 1 — `lang=default`, não `lang=pt`**: a Photon pública só aceita `default`, `de`, `en` ou
`fr` em `lang`; `pt` é rejeitado com HTTP 400 (`"Language is not supported"`). `lang=default` devolve
o nome do lugar como está no OpenStreetMap (idioma local do lugar, não necessariamente português) —
alternativa mais próxima disponível, já que nenhum dos quatro idiomas suportados é português.

**Decision 2 — `User-Agent` próprio é obrigatório, e precisa ser ASCII puro**: a Photon pública
responde HTTP 403 a toda requisição com o `User-Agent` padrão do `package:http`
(`"Dart/<versão> (dart:io)"`), antes mesmo de avaliar os parâmetros — comportamento típico de
bloqueio automático de tráfego não identificado ("bot"), confirmado comparando `curl` com e sem esse
`User-Agent` contra o mesmo endpoint. A primeira tentativa de corrigir, com um `User-Agent` em
português (`"...protótipo acadêmico TCC UFSC)"`), falhou de um jeito diferente: o próprio
`package:http` rejeita o valor com `FormatException: Invalid HTTP header field value`, porque
cabeçalhos HTTP não aceitam caracteres fora de ASCII/latin-1 sem *encoding* — o erro nem chega a sair
para a rede. A `PhotonGeocodingService` passa a enviar
`User-Agent: CaronasPassageiro/1.0 (br.ufsc.tcc.caronas.passenger; academic prototype, UFSC)`, em
inglês simples e ASCII puro — identifica o aplicativo, sem incluir `pubkey`, nome de exibição nem
posição (continua dentro da exceção da constituição 2.2.0).

### Riscos assumidos e mitigação

- **Risco de o bloqueio por `User-Agent` mudar de critério no futuro**: aceito como risco de
  protótipo — se a Photon pública passar a bloquear também `User-Agent`s identificados, a busca volta
  a falhar (US3 trata esse caminho); não há mitigação adicional proporcional ao escopo acadêmico
  (Princípio V).

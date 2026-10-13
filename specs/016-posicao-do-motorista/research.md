# Research — Posição do motorista no mapa do passageiro

## D1 — Contrato: emenda 12, sem mudança de formato

O `kind: 20005` já traz `{ "lat": ..., "lon": ... }` (emenda 08) e o passageiro já se inscreve
(emenda 10). O que muda é só o uso: a nota "Consumo pelo passageiro (emenda 10) … não decodifica nem
exibe `lat`/`lon`" deixa de ser verdade. Emenda 12: linha na tabela de histórico e nota de consumo
reescrita ("exibe a posição do motorista como marcador, só enquanto 'motorista a caminho'; em
memória"). A cópia do passageiro é atualizada junto, com o cabeçalho de procedência (Princípio IV).
O motorista não muda de código.

## D2 — `DriverLocation` no domínio, por analogia a `ReceivedQuote`

`DriverLocation.fromNostrEvent(NostrEvent)` lê `content` como JSON, exige `lat`/`lon` numéricos,
finitos e dentro de faixa (−90..90, −180..180), e guarda `reportedAt` = `createdAt` do evento.
Falha → `FormatException`; o chamador descarta o evento (dado de terceiro nunca vira instrução).
Alternativa descartada: tratar o JSON direto em `MapScreen` — sem teste de unidade e com mais ruído
na tela já longa.

## D3 — Autor e corrida conferidos (FR-005), também no gatilho existente

`_processarLocalizacaoMotorista` hoje confere só a tag `["e", quoteId]` — que é pública no relay —,
então qualquer um poderia forjar o sinal de "motorista a caminho". Passa a exigir também
`evento.authorPublicKey == corridaAceita.driverPubkey`. Isso aperta o comportamento da feature
009/014 (não só o desta); os testes existentes já assinam a localização com a chave do motorista
(`localizacaoDeTeste(autor: ...)`), então não quebram. Localização malformada do motorista certo
**ainda** conta como sinal de movimento (comportamento atual preservado); só não move o marcador.

## D4 — Quando atualizar e quando ignorar

O evento é processado (o `id` entra no conjunto de já vistos, como hoje) e a posição só é guardada
se: o estado for `orcamentoAceito` (e a transição ocorre, FR-002) ou `motoristaACaminho`; `content`
válido; e `reportedAt` **estritamente** mais novo que o da posição exibida (FR-008, eventos fora de
ordem). `created_at` é declarado pelo autor — serve só para não deixar um ponto velho sobrescrever um
novo, não é decisão de segurança. Dois eventos no mesmo segundo: vale o primeiro (o motorista publica
a cada 5 s).

## D5 — Ciclo de vida da posição

`_posicaoMotorista` (em memória) é limpa quando `_corridaAceita` muda: ao aceitar outro orçamento, ao
finalizar a avaliação e na restauração. O marcador é desenhado só com
`_rideStatus == motoristaACaminho` (FR-006), então sai sozinho ao confirmar o encontro, sem
depender de um passo de limpeza. Reinício: nada persistido (FR-009).

## D6 — Câmera: o mesmo problema da feature 016 do motorista

`_aoReceberPosicao` faz `_mapController.move(ponto, zoom)` a cada GPS e o mapa do passageiro não tem
`fitCamera` nem botão de recentralizar. Um enquadramento feito uma vez seria desfeito na posição
seguinte. Solução, a mesma já validada no motorista: `_seguindoPassageiro` (padrão `true`);
`_aoReceberPosicao` só move a câmera se for `true`; na **primeira** exibição do marcador por corrida
(`_motoristaEnquadrado`), `fitCamera` com `CameraFit.coordinates([passageiro?, motorista])`,
padding 48/96/48/170 e `maxZoom: 17`, e `_seguindoPassageiro = false`. Sem posição do passageiro,
centraliza no motorista. O botão "Centralizar" (círculo branco de 48 px, ícone `roxo` — componente
já descrito na constituição) aparece só enquanto `motoristaACaminho && !_seguindoPassageiro`, move
para a posição do passageiro (zoom 16) e liga `_seguindoPassageiro`. Ao sair de `motoristaACaminho`
ou finalizar a corrida, volta a `true`. Atualizações seguintes do motorista só movem o marcador.

## D7 — Aparência do marcador (FR-004, FR-012)

Marcador do motorista no app do motorista: `Container` circular 44 px, `IdentidadeVisual.fundo`,
borda branca 2 px, sombra `0x33000000`/6/(0,2), `Icons.directions_car` 24 px em `destaque`. O
passageiro ganha um widget privado equivalente (`_MarcadorCircular`) com o mesmo desenho; o marcador
do próprio passageiro (ícone `person_pin_circle`, 26 px) continua como está, o que os distingue.
"Imagem" = esse símbolo: nenhuma das apps usa arquivo de imagem, então não há asset a compartilhar.

## D8 — Testes

Lógica pura em `test/domain/driver_location_test.dart`. `MapScreen` com os dublês de
`test/support/`: marcador na posição certa, atualização, primeira localização que causa a transição,
autor errado, corrida errada, outros estados, malformada, fora de ordem, duplicada, enquadramento sem
ser desfeito, "Centralizar", aparência igual à do motorista (decoração do `Container` e ícone). O
FlutterMap busca tiles por HTTP real em teste; reaproveitar o padrão já usado em `map_screen_test.dart`
(`NetworkTileProvider` sem cache, T019 da feature 008).

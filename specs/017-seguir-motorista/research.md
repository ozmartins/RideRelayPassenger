# Research — Seguir o motorista no mapa do passageiro

## D1 — O "modo de acompanhamento" é derivado, não armazenado

**Decision**: seguir o motorista ⇔ `_rideStatus == motoristaACaminho && _posicaoMotorista != null`.
Nenhuma flag nova; `_seguindoPassageiro` e `_motoristaEnquadrado` são removidas.

**Rationale**: a 016 precisou de duas flags só porque o usuário podia "soltar" o seguimento e
retomá-lo pelo botão. Sem botão, o estado é função de duas variáveis que já existem e que já são
zeradas nos mesmos pontos (D5 da 016), o que cobre FR-007 e FR-008 (sair do estado / trocar de
corrida) sem código extra.

**Alternatives**: manter `_seguindoPassageiro` e fixá-lo em `false` — deixa estado morto.

## D2 — Como a câmera vai ao motorista

**Decision**: a cada posição aceita (válida e mais nova) chamar `_mapController.move(ponto,
camera.zoom)`, se o mapa já estiver montado. Se não estiver (`_carregando`), o `MapOptions.initialCenter`
passa a ser a posição do motorista quando ela existe, de modo que o mapa nasce já nele (Edge Case do
spec).

**Rationale**: `move` com o zoom corrente cumpre FR-003; a 016 já usava o mesmo guarda
`camera.zoom.isNaN` para "mapa ainda não montado". `initialCenter` evita a perda da primeira posição
sem precisar de estado pendente.

**Alternatives**: `fitCamera` nos dois (comportamento da 016) — rejeitado pelo pedido ("focar e
seguir o motorista"); `AnimatedMapController` — dependência nova sem ganho exigido.

## D3 — GPS do passageiro

**Decision**: `_aoReceberPosicao` continua atualizando `_posicao` (marcador, rota, painel) mas só
move a câmera se **não** estiver seguindo o motorista (D1).

**Rationale**: FR-002/FR-005; o marcador do passageiro continua visível (FR-009) porque a camada de
marcadores é independente da câmera.

## D4 — Arrasto manual

**Decision**: sem tratamento especial; a próxima posição do motorista recentraliza a visão.

**Rationale**: sem botão, qualquer "soltar" deixaria o passageiro sem como retomar (FR-004). Aceito
no spec (Assumptions). Posições chegam a cada 50 m percorridos pelo motorista, então o arrasto
dura até o próximo movimento dele.

## D5 — Testes

**Decision**: reescrever o grupo `enquadramento e "Centralizar" (FR-007)` da 016 com os cenários
das US1–US3 (centro no motorista, GPS não move, sem `Icons.my_location` em nenhum momento, volta a
seguir o passageiro ao sair do estado, sem posição segue o passageiro).

**Rationale**: o teste atual afirma exatamente o comportamento revogado (FR-006 deste spec).

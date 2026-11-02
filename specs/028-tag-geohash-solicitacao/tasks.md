# Tarefas: 028-tag-geohash-solicitacao

**Entrada**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/emenda-27-tag-g.md](contracts/emenda-27-tag-g.md), [quickstart.md](quickstart.md)
**Testes**: exigidos (constituição, Princípio II; spec FR-006/FR-008). Escrever o teste antes do código.
**Formato**: `- [ ] ID [P?] [Story] descrição com caminho`

## Fase 1: Preparação

- [x] T001 Conferir (**pré-requisito externo**: se o motorista ainda não tiver o vetor ou o contrato com a emenda 27, parar aqui e concluir/gerar lá primeiro; T002, T003 e T008 só prosseguem depois) em `../RideRelayDriver` que `specs/027-filtro-geografico-solicitacoes/contracts/emenda-27-tag-g.md` é igual a `contracts/emenda-27-tag-g.md` (`diff` sem saída) e que `test/fixtures/geohash_vectors.json` e `tool/gen_geohash_vectors.dart` existem no motorista; se o vetor ainda não existir, aguardar/gerar lá (bloqueia T008)

## Fase 2: Fundação (bloqueia as histórias)

- [x] T002 Aplicar a emenda 27 (linha na tabela de emendas, célula do `20001`, seção *Tag `g` do `20001`*, *Forma da inscrição*, regra de recepção 8) em `specs/002-nostr-relay-connection/contracts/nostr-events.md`, literalmente como em `contracts/emenda-27-tag-g.md`, e acrescentar a emenda 27 ao cabeçalho de procedência
- [x] T003 Conferir com `diff` que o contrato do passageiro e `../RideRelayDriver/specs/002-nostr-relay-connection/contracts/nostr-events.md` diferem só no cabeçalho de procedência (mesma alteração nos dois repositórios)

## Fase 3: US1 — A solicitação leva as tags `g` (P1) 🎯 MVP

**Meta**: todo `20001` publicado leva `t` + três `g` (5, 4, 3) da origem; `content` intacto.
**Teste independente**: `flutter test test/event_feed_test.dart --plain-name "20001"`.

- [x] T004 [P] [US1] Escrever `test/domain/geohash_test.dart`: âncoras públicas (`42.605,-5.603 → ezs42`; `57.64911,10.40744 → u4pruydqqvj`), hemisfério sul/oeste, antimeridiano e polos (±90, ±180), prefixos (4 e 3 são prefixos do 5), `ArgumentError` para lat/lon/precisão inválidas
- [x] T005 [US1] Criar `lib/domain/geohash.dart` com `kPrecisoesDaTag = [5, 4, 3]` e `Geohash.encode(lat, lon, precisao)` (algoritmo idêntico ao do motorista, Dart puro, sem `neighbors`/`bounds`); fazer T004 passar
- [x] T006 [US1] Ampliar `test/event_feed_test.dart` com `20001`: tags exatamente `[t, g5, g4, g3]` com valores de uma origem conhecida; `content` igual ao de antes (com e sem `reputacao`); assinatura verificada com a cripto real; coordenada inválida ⇒ nada transmitido (`PublishReport` vazio); só transporte dublê
- [x] T007 [US1] Em `lib/services/event_feed.dart`, `publishRideRequest` calcula as tags `g` de `request.origin` para cada precisão de `kPrecisoesDaTag` e as passa em `extraTags`; sem nenhum raio ou filtro por `g` no passageiro (FR-004); captura `ArgumentError` e devolve `PublishReport(eventId: '', byRelay: {})`; atualizar o dartdoc citando a emenda 27; fazer T006 passar

## Fase 4: US2 — Vetor idêntico nas duas apps (P1)

**Meta**: o cálculo reproduz o vetor compartilhado.
**Teste independente**: `flutter test test/services/geohash_contract_vectors_test.dart` e `diff` do fixture.

- [x] T008 [US2] Copiar `../RideRelayDriver/test/fixtures/geohash_vectors.json` para `test/fixtures/geohash_vectors.json` e conferir `diff` sem saída
- [x] T009 [US2] Escrever `test/services/geohash_contract_vectors_test.dart` (no estilo de `test/support/receipt_vectors.dart`): para cada ponto do vetor, `Geohash.encode` nas três precisões é igual ao esperado; o teste falha se o arquivo estiver ausente ou vazio

## Fase 5: US3 — Contrato e documentação (P2)

- [x] T010 [US3] Atualizar `CLAUDE.md`: acrescentar `test/fixtures/geohash_vectors.json` (gerado no motorista, copiado byte a byte) e a tag `g` do `20001` à seção de invariantes entre as duas apps; commit separado do código

## Fase 6: Acabamento

- [x] T011 `flutter analyze` ("No issues found!") e `flutter test` integral, sem testes ignorados
- [x] T012 Executar os cenários 1–6 de [quickstart.md](quickstart.md) e relatar o resultado (o 7, ponta a ponta, só com a 027 do motorista pronta)

## Dependências

- T001 → T002/T008 (bloqueio externo: contrato e vetor do motorista); T002 → T003 (o motorista também precisa ter a emenda 27 aplicada).
- US1: T004 → T005 → T006 → T007. US2 depende de T005 (T009) e T001 (T008). US3 depois de T007.
- Entrega: T002/T003 (contrato) vão na mesma alteração do motorista; commits separados por mudança lógica, em português, conforme o `CLAUDE.md`: (1) contrato, (2) geohash + publicação + testes + vetor, (3) `CLAUDE.md`.

## Paralelismo

- T004 pode ser escrita enquanto T002/T003 acontecem. T008 é independente de T004–T007 (só depende do motorista).

## Estratégia

MVP = US1 (T004–T007). US2 trava o contrato contra divergência. Nenhuma tarefa mexe em tela, serviço em segundo plano ou persistência.

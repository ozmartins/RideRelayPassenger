# Feature 013 — Aba "Início" (hoje "Mais") do passageiro como menu

**Escopo**: só o `passenger/`; não toca o contrato de eventos.

- **FR-001** A aba "Início" não exibe a lista de eventos recebidos nem o botão "Publicar teste".
- **FR-002** A aba mostra a faixa de estado das conexões e cartões de menu: Meu nome (só com nome
  definido), Minha identidade, Relays e Tentar reconectar, com os mesmos tooltips de antes.
- **FR-003** Nada do funcionamento do app depende da lista: o `EventFeed` segue assinando os relays,
  verificando assinaturas e alimentando o `MapScreen` (orçamentos e avisos da corrida).

## Consequências

- Saem `_listaEventos`, `_LinhaEvento`, `_Vazio`, `_publicar` e o botão flutuante; `HomeScreen` deixa de
  receber `eventFeed`.
- Ficam `EventFeed.publish`, o `kind: 1` e o marcador `tcc-ufsc-caronas` (contrato compartilhado, com
  testes de assinatura).
- Os cenários do `quickstart.md` da feature 002 que publicam a nota de teste pela UI deixam de ser
  executáveis no passageiro; a interoperabilidade se verifica com `dart run tool/check_relays.dart` e
  pelo app do motorista.

**Validação**: testes automatizados passando (242) e conferido no emulador `Pixel_6_API34_1`.

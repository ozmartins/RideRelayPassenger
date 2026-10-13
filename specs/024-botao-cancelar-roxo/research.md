# Research — Botões de cancelar corrida em roxo (passageiro)

## D1. Constituição

- **Decision**: nenhuma emenda nesta feature; a 2.12.0 (`662fda7`) já descreve o "Botão de cancelamento de
  corrida" em roxo nas duas apps.

## D2. Como obter o roxo

- **Decision**: `IdentidadeVisual.estiloAcaoPrimaria(altura: 48)` nos botões do mapa e da lista de orçamentos,
  a mesma fonte que o botão da confirmação já usa.
- **Rationale**: uma fonte única impede divergência (SC-003) e é o que o pedido descreve ("botões que já
  existem com esta aparência").
- **Alternatives**: copiar cores num `styleFrom` próprio (duplica).

## D3. Botão do mapa: de `TextButton` para `FilledButton`

- **Decision**: `_BotaoCancelarCorrida` passa de `TextButton.icon` (texto em erro) para `FilledButton.icon` com
  o estilo de D2, mantendo o cartão `folha`, a chave `botao-cancelar-corrida`, o rótulo e a altura 48.
- **Consequência nos testes**: o localizador `confirmar = find.widgetWithText(FilledButton, 'Cancelar corrida')`
  de `map_screen_test.dart` passaria a achar também o botão do mapa. Ele é ajustado para excluir o botão de
  chave `botao-cancelar-corrida` (mesma solução do motorista, onde o botão do mapa tem chave e o da modal não).
- **Ícone**: o ícone herda a cor do botão (branco); remove-se a cor de erro explícita.

## D4. Botão da lista de orçamentos

- **Decision**: `FilledButton.icon` com `estiloAcaoPrimaria(altura: 48)` no lugar do `styleFrom` em erro;
  `SizedBox` de 48 de altura e largura total mantido. O teste existente por `widgetWithText(FilledButton,
  'Cancelar')` segue válido.

## D5. Contraste

- **Decision**: nenhuma cor nova; branco sobre `#6B3FE0` ≈ 6,2:1 pela fórmula WCAG; os testes calculam a razão
  sobre as cores resolvidas e exigem ≥ 4,5:1.

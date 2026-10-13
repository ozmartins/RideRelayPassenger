# Contrato — consumo do `kind: 20012` "Corrida cancelada" (emenda 14)

Esta feature **não altera nenhum formato de evento**. O `kind: 20012` é definido pela emenda 14 do
contrato único (`specs/002-nostr-relay-connection/contracts/nostr-events.md`), escrita pela feature
`018-cancelar-corrida-motorista` do motorista nas duas cópias. Aqui só se consome.

## Pré-condição (Princípio IV)

Antes de qualquer código desta feature, a cópia do passageiro MUST conter a emenda 14 (linha `20012`
na tabela de kinds, linha 14 no histórico, inscrição do passageiro com `20012`, seção *Conteúdo do
kind 20012*) e MUST ser idêntica à do motorista, exceto pelo cabeçalho de procedência. A verificação
é a T001 de `tasks.md`; se faltar, implementar antes a T001/T002 da feature 018 do motorista.

## O que esta feature consome

Texto da emenda 14, "Consumo pelo passageiro", realizado aqui:

- só vale evento assinado pelo motorista cujo orçamento o passageiro aceitou e que referencia o
  `quoteId` da corrida aceita, com o passageiro em "orçamento aceito", "motorista a caminho" ou "em
  corrida";
- efeito: modal informando o cancelamento e encerramento da corrida no app do passageiro;
- fora dessas condições (outra corrida, outro autor, corrida já encerrada ou concluída), ignorado sem
  erro; duplicata ou reentrega sem efeito além do primeiro.

## Inscrição

O passageiro MUST incluir `20012` em `EventFeed.acceptedKinds` (`lib/main.dart`), como a "Forma da
inscrição" da emenda 14 define. A inscrição do motorista não muda.

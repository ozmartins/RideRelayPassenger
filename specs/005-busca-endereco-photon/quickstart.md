# Phase 1 — Quickstart / Validação: Busca de Endereço via Photon

Comandos executados a partir de `Prototipo/passenger`. O cenário 1 é automatizado; os demais exigem
emulador/aparelho com conectividade de rede real até `https://photon.komoot.io` (D2 de
`research.md` — não há dublê da rede real nesta validação manual, só nos testes automatizados).

## Pré-requisitos

- Ambiente das features 001–004 funcionando (ver `README.md`)
- Dependências instaladas: `flutter pub get`
- Conectividade de internet no emulador/aparelho (para alcançar a instância pública da Photon)

## Cenário 1 — Gates automatizados

```bash
flutter analyze   # esperado: No issues found!
flutter test      # esperado: todos os testes passam
```

Cobre, com dublê de `GeocodingService` (sem rede real): sugestões exibidas ao digitar, destino
registrado só ao tocar uma sugestão, destino preservado ao editar o texto sem selecionar de novo,
destino desfeito ao apagar o campo, mensagens de "sem resultado" e de falha. Cobre também, com
`http.Client` dublê, o parsing da resposta da Photon em `PhotonGeocodingService` (sucesso, vazio,
erro HTTP, corpo malformado, timeout — D1 de `research.md`).

## Cenário 2 — Sugestões aparecem ao digitar (US1, SC-001)

```bash
flutter run
```

1. Na tela inicial, toque no campo de destino e digite um trecho de um endereço real e conhecido
   (ex.: um bairro ou cidade brasileira).

**Esperado**: depois de uma pequena pausa na digitação (não a cada tecla), uma lista de endereços
sugeridos aparece abaixo do campo, sem precisar tocar em nenhum botão de busca.

## Cenário 3 — Selecionar uma sugestão define o destino (US2 cenário 1, SC-002)

Com uma lista de sugestões visível (Cenário 2):

1. Toque em uma das sugestões da lista.

**Esperado**: o campo passa a mostrar o texto completo do endereço selecionado (não necessariamente
igual ao texto digitado), e a lista de sugestões fecha.

## Cenário 4 — Trocar a seleção (US2 cenário 2)

Com um destino já selecionado (Cenário 3):

1. Toque no campo e edite o texto (ex.: apague parte e digite outro trecho).
2. Antes de tocar em uma nova sugestão, observe que o destino anterior continua sendo o registrado
   internamente (verificável por log de depuração temporário, removido antes de concluir a feature).
3. Toque em uma nova sugestão da lista atualizada.

**Esperado**: o destino passa a ser o da nova seleção; o anterior deixa de valer.

## Cenário 5 — Sem resultado (US3 cenário 1, SC-003)

1. Digite um texto sem correspondência real (ex.: uma sequência aleatória de letras).

**Esperado**: em até 1 segundo após o fim da busca, uma mensagem informa que nenhum endereço foi
encontrado — não uma lista vazia sem explicação.

## Cenário 6 — Falha do serviço (US3 cenário 2, SC-003)

1. Desligue a conectividade de rede do emulador/aparelho.
2. Digite um texto qualquer no campo de destino.

**Esperado**: em até 1 segundo após a tentativa falhar, uma mensagem informa que não foi possível
buscar endereços no momento; a tela continua respondendo (não trava), e reconectar a rede e digitar
de novo volta a mostrar sugestões.

## Cenário 7 — Apagar o texto desfaz o destino (Edge Case do `spec.md`, FR-012)

Com um destino já selecionado (Cenário 3):

1. Apague todo o texto do campo de destino.

**Esperado**: o app volta ao estado sem destino definido (mesmo estado da abertura do app), sem
nenhuma sugestão visível.

## Cenário 8 — Independência da posição do passageiro (SC-004, mantém garantia da feature 004)

1. Negue a permissão de localização (ou abra o app sem GPS disponível).
2. Repita o Cenário 2.

**Esperado**: a busca de endereço funciona normalmente, mesmo com a mensagem de indisponibilidade de
posição visível na tela.

## Verificação de não vazamento (Princípio I, por não aplicabilidade)

Esta feature não toca chave privada, semente nem material de assinatura — não há verificação de
vazamento criptográfico a executar. A verificação aplicável é a da exceção da constituição 2.2.0:
inspecionar, com um proxy HTTP ou os logs do `http.Client`, que a requisição à Photon contém apenas
`q`, `lang` e `limit` — nunca a chave pública do usuário, seu nome de exibição ou sua posição atual.

## Resultados da validação em aparelho (T026, emulador `Pixel_6_API34_1`, 2026-09-18)

Cenários 2, 3, 5, 6 e 7 executados com rede real até `https://photon.komoot.io`; cenário 8 coberto
pelos demais, já que todos rodaram com a posição sendo obtida em paralelo (mensagem de
indisponibilidade nunca apareceu, mas a busca nunca dependeu dela — mesma garantia estrutural da
feature 004). Cenário 4 (trocar a seleção) já coberto pelos testes automatizados de widget
(T012–T014); não repetido manualmente.

- **Cenário 2**: busca por "Lisboa" trouxe 5 sugestões reais da Photon (`Lisboa, Lisboa, Portugal`,
  `Lisboa, Portugal`, `Lisboa - Rossio, ...`, etc.) após uma pequena pausa na digitação, sem botão de
  busca — confirmado.
- **Cenário 3**: tocar em "Lisboa, Lisboa, Portugal" preencheu o campo com esse texto exato e fechou a
  lista — confirmado.
- **Cenário 5**: busca por um texto sem correspondência (`"qzxwvbjfk"`) mostrou "Nenhum endereço
  encontrado para esse texto." — confirmado.
- **Cenário 6**: com Wi-Fi e dados desligados no emulador, a busca mostrou "Não foi possível buscar
  endereços no momento..." sem travar a tela; religando a rede e buscando de novo voltou a trazer
  sugestões reais — confirmado.
- **Cenário 7**: apagar todo o texto depois de uma seleção voltou ao estado sem destino (hint "Para
  onde você quer ir?" de volta, nenhuma sugestão visível) — confirmado.

**Dois defeitos reais encontrados e corrigidos durante esta validação** (não visíveis nos testes
automatizados, que usam dublê de rede — Princípio II): a Photon pública bloqueia com HTTP 403 o
`User-Agent` padrão do `package:http`, e rejeita `lang=pt` com HTTP 400 (só aceita
`default`/`de`/`en`/`fr`). Ambos corrigidos em `PhotonGeocodingService` — ver D4 de `research.md`.
Uma primeira tentativa de corrigir o `User-Agent` com um valor em português falhou de um jeito
diferente (`FormatException` do próprio `package:http`, por caracteres fora de ASCII em cabeçalho
HTTP) antes de chegar ao valor final em ASCII puro.

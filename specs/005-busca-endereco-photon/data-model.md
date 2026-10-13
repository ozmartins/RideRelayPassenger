# Phase 1 — Data Model: Busca de Endereço via Photon

## AddressSuggestion (novo)

Representa a **Sugestão de Endereço** do `spec.md`: um endereço candidato retornado pela Photon a
partir do texto digitado. Vive em `lib/domain/address_suggestion.dart`.

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `id` | `String` | sim | Identificador estável da sugestão, composto de `osm_type` + `osm_id` da resposta da Photon (ex.: `"R123456"`). Existe só para distinguir sugestões com o mesmo texto exibido (Edge Case do `spec.md` — endereços homônimos em bairros diferentes) — nunca exibido ao usuário. |
| `displayText` | `String` | sim | Texto completo do endereço, já formatado para exibição — junção de `name`, `street`/`housenumber`, `city`/`county`, `state`, `country` presentes na resposta, separados por `", "`, pulando os campos ausentes. |

**Regras de validação**: nenhuma além de vir de uma resposta bem-sucedida da Photon — não há entrada
de usuário direta neste tipo (FR-004: o destino nunca é construído a partir de texto bruto).

**Igualdade**: por `id` (duas sugestões só são iguais se vierem do mesmo lugar do OpenStreetMap).

**Relacionamentos**: uma lista de `AddressSuggestion` é o estado transitório de uma busca; nenhuma é
persistida. Selecionar uma gera um `DestinationAddress` (abaixo) a partir do seu `displayText`.

## DestinationAddress (existente — `lib/domain/destination_address.dart`, sem mudança de forma)

Continua representando o **Endereço de Destino** do `spec.md`: `text` (`String`) e igualdade por
`text`, exatamente como na feature 004.

**Mudança de contrato de uso** (não de forma): a partir desta feature, o único construtor válido em
`MapScreen` passa a ser `DestinationAddress(sugestão.displayText)`, chamado **apenas** quando o
usuário toca uma `AddressSuggestion` — nunca a partir do texto corrente do campo (FR-004, FR-005).
O comentário de classe existente ("Aceita qualquer texto... sem validação de formato ou de
correspondência a um endereço real") deixa de valer e MUST ser atualizado na implementação para
refletir que o texto agora sempre vem de uma sugestão validada pela Photon.

## Estados da busca (não é uma entidade persistida — estado local de `MapScreen`)

Modelam os cenários das User Stories 1 e 3; não precisam de um tipo novo, apenas de campos de estado
já no padrão usado por `_mensagemIndisponibilidade`/`_carregando` da tela:

| Estado | Quando ocorre | O que a tela mostra |
|---|---|---|
| Ocioso | Campo vazio, nenhuma busca em andamento | Nenhuma lista de sugestões |
| Buscando | Debounce expirou e a requisição está em voo | Indicador de carregamento (opcional; a busca é rápida o bastante para ser dispensável, mas não proibido) |
| Sugestões disponíveis | Resposta com uma ou mais `AddressSuggestion` | Lista tocável das sugestões |
| Sem resultado | Resposta bem-sucedida, lista vazia | Mensagem "nenhum endereço encontrado" (FR-008) |
| Falha | Exceção de rede, timeout ou resposta malformada | Mensagem de falha, sem travar a tela (FR-009) |
| Destino selecionado | Usuário tocou uma sugestão | Campo mostra o `displayText` selecionado; lista de sugestões fecha |

Transição "Destino selecionado" → "Ocioso": ao apagar todo o texto do campo (FR-012). Transição
"Destino selecionado" → "Buscando"/"Sugestões disponíveis": ao editar o texto de novo (FR-007) — o
destino anterior permanece válido até uma nova seleção substituí-lo.

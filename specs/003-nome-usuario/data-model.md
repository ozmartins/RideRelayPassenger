# Phase 1 Data Model: Nome do Usuário no Passageiro

## Entidade: Perfil do usuário (local)

Representa a identificação legível que a pessoa escolhe para si dentro do app do passageiro.
Não se confunde com `Identity` (`domain/identity.dart`), que é a identidade criptográfica Nostr
(chave pública/privada) já existente — são dois conceitos independentes que coexistem no mesmo
app.

| Atributo | Tipo | Regras |
|---|---|---|
| `displayName` | `String` | Não vazio após remover espaços nas extremidades (trim). Tamanho máximo: 60 caracteres. Sem outra validação de formato — qualquer texto dentro do limite é aceito (ver spec, seção Assumptions). |

Não há relacionamento com outras entidades do domínio (`Identity`, `Relay`, `NostrEvent`): o
nome não é incluído em nenhum evento publicado nem em nenhuma mensagem trocada com relay — ele é
puramente local e de exibição dentro do próprio app.

### Ciclo de vida

- **Inexistente**: estado inicial, antes da primeira confirmação de nome. É o estado que dispara
  a exibição da tela de nome antes da tela principal (FR-001, FR-002).
- **Definido**: existe um valor salvo. Passa a ser retornado nas aberturas seguintes (FR-009) e
  pode ser substituído a qualquer momento pela tela de alteração (FR-007), permanecendo sempre em
  estado "Definido" — não há transição de volta para "Inexistente" nesta feature (não há ação de
  remover o nome).

### Persistência

Armazenado como uma única string sob uma chave fixa no `KeyValueStore` já existente (decisão D1
de `research.md`), reaproveitando o mesmo mecanismo (`shared_preferences`/`PrefsKeyValueStore`)
usado pela lista de relays. Não requer schema, migração nem novo serviço de armazenamento —
apenas uma chave nova sobre a abstração já em uso.

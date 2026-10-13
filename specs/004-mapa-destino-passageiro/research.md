# Phase 0 — Research: Mapa e Destino do Passageiro

## D1 — Biblioteca de geolocalização (atende FR-001 a FR-005)

**Decision**: adotar **`geolocator` versão `^14.0.3`** — a mesma versão já decidida e em uso no app do
motorista (`driver/specs/004-mapa-status-motorista/research.md`, D1).

**Contexto da decisão**: o motorista já resolveu exatamente o mesmo problema (permissão de localização,
posição atual, fluxo contínuo de posições) na mesma data (17/09/2026), com o mesmo levantamento de
alternativas no pub.dev. Reavaliar do zero não traria informação nova; a diferença entre as duas apps
não está em qual biblioteca de localização usar, e sim em como cada uma a integra (Structure Decision
abaixo).

### Alternativas avaliadas

Ver `driver/specs/004-mapa-status-motorista/research.md` (D1) — mesma comparação entre `geolocator` e
`location`, mesmo resultado.

### Critérios aplicados

1. **Cobertura do caso de uso com a menor superfície** — a feature precisa de permissão, posição atual
   e stream contínuo de posições; `geolocator` resolve as três sem `permission_handler` à parte.
2. **Manutenção e adoção** — pacote de geolocalização mais adotado do ecossistema Flutter.
3. **Confinamento de tipos (Princípio III)** — a API de `geolocator` fica atrás de uma interface própria
   do projeto (`LocationService`), nunca exposta a `domain/` ou `screens/` diretamente.
4. **Consistência entre as duas apps** — usar a mesma versão que o motorista evita divergência
   desnecessária entre protótipos que resolvem o mesmo problema, embora isso não seja exigido pela
   constituição (não há contrato de evento envolvido aqui).

### Riscos assumidos e mitigação

- **Risco de acoplamento**: mitigado confinando `package:geolocator` a
  `lib/services/geolocator_location_service.dart`; `lib/domain/` usa um tipo próprio
  (`PassengerPosition`), nunca o `Position` da biblioteca.
- **Permissão de localização**: dado sensível pela constituição (Restrições de Segurança e Privacidade).
  O pedido só acontece ao abrir a tela de mapa, nunca antes — justificativa por escrito nas Assumptions
  do `spec.md`.

## D2 — Biblioteca de mapa (atende FR-001 a FR-003)

**Decision**: adotar **`flutter_map` versão `^8.3.2`** com **`latlong2` versão `^0.10.1`**, usando o
serviço público de mosaicos do OpenStreetMap — mesma decisão do motorista
(`driver/specs/004-mapa-status-motorista/research.md`, D2).

**Contexto da decisão**: mesmo raciocínio do motorista se aplica sem alteração: o app do passageiro é o
mesmo tipo de protótipo acadêmico, com a mesma exigência de rodar sem credencial de terceiro para quem
avalia o trabalho.

### Alternativas avaliadas

Ver `driver/specs/004-mapa-status-motorista/research.md` (D2) — mesma comparação entre `flutter_map`,
`google_maps_flutter` e `mapbox_maps_flutter`, mesmo resultado.

### Critérios aplicados

1. **Reprodutibilidade acadêmica sem credencial externa** — critério decisivo, idêntico ao motorista.
2. **Manutenção ativa** — inalterado.
3. **Simplicidade proporcional (Princípio V)** — a feature pede um mapa com um indicador de posição e
   um campo de texto, nada além disso.

### Riscos assumidos e mitigação

Idênticos aos do motorista: `userAgentPackageName` próprio da aplicação no `TileLayer`, atribuição
"© OpenStreetMap contributors" visível (requisito de implementação, não de especificação), e ausência de
rede tratada como mapa não carregando os mosaicos, sem travar o aplicativo.

## D3 — Campo de destino: sem dependência nova (atende FR-006 a FR-010)

**Decision**: implementar o campo de destino com o widget `TextField`/`TextEditingController` já
incluído no Flutter — nenhuma biblioteca de geocodificação, autocompletar de endereços ou máscara de
texto é necessária.

**Contexto da decisão**: a spec (Assumptions) já define que o campo é texto livre, sem validação de
endereço real, sem geocodificação e sem exibição do destino no mapa nesta feature. Não há requisito que
justifique trazer uma dependência de terceiros para isso.

### Alternativas avaliadas

| Opção | Observação |
|-------|------------|
| **`TextField` nativo do Flutter** | Cobre integralmente FR-006 a FR-010: campo de texto livre, sem validação, refletindo o valor mais recente digitado. Zero dependência nova. |
| Pacote de autocompletar de endereço (ex.: `google_places_flutter`, `flutter_google_places`) | Rejeitado: exigiria conta e chave de API de um provedor de geocodificação, na mesma linha do que já descartou `google_maps_flutter` em D2, e nenhum requisito desta feature pede autocompletar. |

### Critérios aplicados

1. **Simplicidade proporcional (Princípio V)** — nenhum requisito desta feature pede validação,
   geocodificação ou sugestão de endereços; usar um widget nativo é a medida exata do que foi pedido.
2. **Dependência de terceiros exige decisão registrada (Princípio III)** — não se aplica: nenhuma
   dependência nova é introduzida por este item.

### Riscos assumidos e mitigação

- Nenhum risco novo: `TextField` é parte do SDK do Flutter, já usado em outras telas do próprio app
  (ex.: `NameScreen`).

## Resumo das decisões

| # | Decisão | Tipo |
|---|---------|------|
| D1 | `geolocator ^14.0.3` para permissão, posição atual e fluxo contínuo de posições | Dependência de terceiros adicionada (mesma versão do motorista) |
| D2 | `flutter_map ^8.3.2` + `latlong2 ^0.10.1`, com mosaicos do OpenStreetMap, para o mapa | Dependência de terceiros adicionada (mesma versão do motorista) |
| D3 | Campo de destino com `TextField` nativo, sem geocodificação | Nenhuma dependência nova |

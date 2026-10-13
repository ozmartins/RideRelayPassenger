# Quickstart — Rota do motorista no mapa do passageiro

Validação em `Prototipo/passenger/`. Pré-requisito: emenda 13 nas duas cópias do contrato e feature 017
do motorista implementada (para o ponta a ponta). Dois aparelhos/emuladores Android com relay em comum;
chave ORS só no motorista (`--dart-define=ORS_API_KEY=...`).

## Automatizados

```bash
flutter analyze        # "No issues found!"
flutter test test/domain/ride_route_test.dart
flutter test test/screens/map_screen_test.dart
flutter test           # suíte completa
```

## Cenários manuais (referem FR/SC de `spec.md`)

### 1. Rota aparece em "Em corrida" (US1, SC-001)
1. Levar a corrida até "Em corrida" (aceitar orçamento, motorista a caminho, confirmar encontro).
2. **Esperado**: em segundos, uma linha roxa do trajeto até o destino aparece no mapa do passageiro.

### 2. Recálculo substitui a linha (US1)
1. O motorista avança > 50 m.
2. **Esperado**: a linha passa a ser a nova; nunca duas linhas ao mesmo tempo.

### 3. Passageiro não calcula (US2, SC-004)
1. Em "Em corrida" com um destino escolhido na etapa anterior, mover o passageiro > 50 m.
2. **Esperado**: nenhuma consulta de rota do passageiro (conferir no log/ORS); sem rota do motorista,
   nenhuma linha de rota é mostrada. A linha local de antes da corrida desaparece ao entrar em
   "Em corrida".

### 4. Rota ilegítima é ignorada (US3, SC-002)
1. Publicar `kind: 20011` de outra chave, de outro orçamento, com `content` inválido (ex.: 1 ponto,
   1001 pontos, latitude 200) e fora de "Em corrida" (ex.: em "motorista a caminho").
2. **Esperado**: o mapa não muda em nenhum dos casos.

### 5. Some ao terminar (US3, SC-005)
1. Confirmar o destino.
2. **Esperado**: a linha some em até 1 s.

## Estado da validação (2026-10-03)

- **Automatizados**: `flutter analyze` sem problemas; `flutter test` com 334 testes passando.
- **Em aparelho (cenários 1 a 5): PENDENTE.** A sessão que implementou só enxergava o alvo `linux`
  (`flutter devices`; nenhum AVD Android listado em `flutter emulators`), e o ponta a ponta exige dois
  aparelhos/emuladores Android com relay em comum e a chave `ORS_API_KEY` no motorista. Do lado do
  motorista, a publicação do `kind: 20011` em relay real foi verificada por `tool/probe_ride_route.dart`
  (ver o quickstart da feature 017 do motorista); falta observar o mapa do passageiro desenhando a linha.

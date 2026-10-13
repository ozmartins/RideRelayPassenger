# Quickstart — Rota real até o destino

Guia de validação manual desta feature, em `Prototipo/passenger/`. Pressupõe emulador/aparelho
Android disponível (`flutter emulators --launch Pixel_6_API34_1`) e que a feature 005
(busca-endereco-photon) e 004 (mapa-destino-passageiro) já funcionam.

## Pré-requisitos

1. Obter uma chave de API gratuita em <https://openrouteservice.org/dev/#/signup> (D3 de
   `research.md`).
2. Rodar o app passando a chave por `--dart-define`, nunca commitada:

   ```bash
   flutter run --dart-define=ORS_API_KEY=sua-chave-aqui
   ```

   Para os testes automatizados, nenhuma chave real é necessária — `FakeRouteService` substitui o
   serviço real (Princípio II aplicado por analogia).

## Cenários de validação (referem os FR/SC de `spec.md`)

### 1. Distância real exibida (US1, SC-001, SC-002)

1. Com posição atual disponível, abrir a tela do mapa.
2. Buscar um endereço e selecionar uma sugestão como destino (feature 005).
3. **Esperado**: em até 3 s, a tela exibe a distância do trajeto rodoviário — maior ou igual à
   distância em linha reta entre os dois pontos (visível comparando com a régua do mapa).

### 2. Traçado da rota no mapa (US2)

1. Com um destino já escolhido (cenário 1), observar o mapa.
2. **Esperado**: uma linha contínua liga a posição atual ao destino, seguindo vias reais — não uma
   linha reta.
3. Trocar o destino para outro endereço.
4. **Esperado**: a linha antiga desaparece e uma nova linha é desenhada para o novo destino; a
   distância exibida também é atualizada (FR-003).

### 3. Recálculo por deslocamento, não por atualização de GPS (FR-003, D2 de `research.md`)

1. Com uma rota já traçada (cenário 2), caminhar/simular deslocamento menor que 50 m.
2. **Esperado**: nenhuma nova requisição de rota é feita (rota exibida permanece a mesma) — pode ser
   observado por log de depuração da camada de serviço.
3. Deslocar-se (ou simular) mais de 50 m a partir do ponto de origem do último cálculo.
4. **Esperado**: uma nova requisição é feita e a rota exibida é atualizada.

### 4. Falha do serviço de rota não bloqueia a solicitação de corrida (US3, SC-003)

1. Desligar a rede do aparelho/emulador (ou usar uma chave de API inválida).
2. Escolher um destino.
3. **Esperado**: a tela indica que a distância não pôde ser calculada (sem trava/erro bloqueante).
4. Tocar em "Solicitar corrida" (feature 006).
5. **Esperado**: a solicitação é publicada normalmente — o evento `kind: 20001` não depende do
   resultado do cálculo de rota (FR-006, FR-009).

### 5. Origem e destino coincidentes (Edge Cases)

1. Escolher como destino um endereço muito próximo da posição atual (mesmo ponto, na prática).
2. **Esperado**: distância exibida é aproximadamente zero; nenhuma linha de rota é desenhada, ou uma
   linha degenerada de comprimento nulo (sem erro).

## Verificação automatizada

```bash
flutter analyze                     # deve dizer "No issues found!"
flutter test test/services/route_service_test.dart
flutter test test/domain/route_result_test.dart
flutter test test/screens/map_screen_test.dart
flutter test                        # suíte completa
```

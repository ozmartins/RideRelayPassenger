# Quickstart: 026-conexao-em-segundo-plano

**Pré-requisitos**: dois aparelhos/emuladores (`flutter emulators --launch Pixel_6_API34_1`), relay em comum com o
motorista (que já tem a 025 e a ORS), `flutter pub get`.

## Automatizado
```bash
cd Prototipo/passenger && flutter analyze
flutter test test/domain/background_notification_rule_test.dart
flutter test test/services/background/
flutter test test/screens/map_screen_test.dart   # lento: rodar em lote à parte
```
Esperado: sem avisos; suíte existente (474) + novos verdes.

## Cenários em aparelho (registrar tudo, inclusive falhas)
1. **Spike (T001)**: serviço de teste no manifesto do passageiro, deslizar dos recentes, confirmar vivo.
2. **US1**: solicitar corrida → deslizar o app → motorista envia orçamento → notificação ≤ 10 s → tocar → lista de orçamentos.
3. **US1.2**: com corrida aceita e app fechado: motorista chega (`20007`), conclui (`20009`), cancela (`20012`) → uma notificação cada.
4. **US1.4**: app em primeiro plano → só a interface, sem notificação.
5. **Recusas**: sem corrida ativa; `20005` periódico; autor/tag errados → nenhuma notificação.
6. **US2**: notificação fixa durante a corrida; ao terminar com app fechado, serviço e notificação somem.
7. **US3 / SC-004**: tela apagada 10 min, trocar Wi-Fi↔dados, mensagem ainda chega.
8. **Permissão**: negar `POST_NOTIFICATIONS` → aviso ao solicitar, serviço não sobrevive à saída do app.
9. **Validade**: mensagem recebida fechado, abrir após > 5 min → não reentregue.
10. **Forçar parada**: serviço morre (esperado); reabrir restaura o estado persistido.

## Não vazamento (Princípio I)
`adb logcat | grep -i -E "nsec|privkey|secret"` vazio nos cenários 2–7; teste confere imports de `services/background/`
e o tráfego do canal.

## Medições (método junto do número)
SC-001: 10 mensagens, publicação→notificação. SC-006: `dumpsys batterystats` 1 h, tela apagada, corrida ativa.

## Resultados (emulador `Pixel_6_API34_1`, Android 14, 2026-10-12)

**Nada abaixo foi medido em aparelho real.** O emulador (sem janela, `-no-snapshot`) subiu pelo binário `emulator`
direto; `flutter emulators --launch` não o levantou nesta sessão.

Método: apk de debug instalado por `adb`; permissões de notificação e localização concedidas por `pm grant`; a
corrida ativa foi **simulada** gravando em `FlutterSharedPreferences.xml` (via `run-as`) o estado
`aguardandoOrcamentos` com um `solicitacaoId` de 64 hexadecimais, sem passar pela UI nem pelo motorista; o motorista
foi simulado por `tool/publish_test_message.dart`, que assina um `kind: 20002` válido (marcador, `p` = chave pública
do passageiro, `e` = a solicitação) com `content` qualquer — o serviço nunca o lê — e o publica nos três relays
padrão (todos responderam `OK true`). O app foi removido dos recentes por gesto na tela de recentes.

| Cenário | Resultado |
|---|---|
| Spike / US2.1 — serviço inicia com `specialUse` | OK: `isForeground=true`, `types=0x40000000`, notificação fixa no canal `passenger_service` |
| US2 — app aberto sem corrida, vai a segundo plano | OK: o serviço **encerra** (0 serviços em primeiro plano); com o app aberto roda |
| US2 — app em segundo plano com solicitação ativa | OK: o serviço continua; notificação fixa "Acompanhando sua corrida" |
| Sobrevive à remoção dos recentes (com corrida ativa) | OK: mesmo PID, serviço em primeiro plano, 3 sockets estabelecidos (os 3 relays) |
| US1.1 — orçamento (`20002`) com o app fechado | OK: notificação "Novo orçamento de corrida" no canal `ride_messages` (importância 4, alta) |
| FR-011 — estado persistido | OK: `background.service_state` com chave pública, estado e `requestId`; sem chave privada |
| **SC-001** — latência publicação → notificação | 10 amostras: 189, 206, 236, 239, 243, 262, 265, 273, 275, 277 ms (mediana ≈ 262 ms, máx. 277 ms). Relógio do script × relógio do aparelho (mesmo host); inclui o RTT até os relays. Meta: ≤ 10 s |

Descoberta no caminho: os relays recusam `["e", <não-hex>]` com `invalid: unexpected size for fixed-size tag: e`; um
id de teste precisa ter 64 hexadecimais.

**Não feito (pendente):** US1.2 (`20007`/`20009`/`20012`/`20006` de uma corrida aceita, só testados em unidade);
US1.3 (tocar na notificação e a interface mostrar a lista de orçamentos — o `content` de teste não decifra, então a
interface descarta o evento por desenho); cenário 8 (permissão negada); cenário 9 (validade de 5 min com o app
aberto de novo); cenário 10 (forçar parada); **SC-004** (10 min de tela apagada com troca de rede); **SC-006**
(bateria); toda a validação em aparelho real; o ponta a ponta com o app do motorista.

Observação fora do escopo: com `aguardandoOrcamentos` restaurado, a tela de orçamentos substitui o mapa e a
primeira posição de GPS dispara `_MapScreenState._aoReceberPosicao` → "You need to have the FlutterMap widget rendered
at least once before using the MapController" (exceção não tratada no log). Não vem desta feature; não corrigido.

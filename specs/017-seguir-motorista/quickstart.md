# Quickstart — Seguir o motorista no mapa do passageiro

Guia de validação em `Prototipo/passenger/`. Os cenários manuais exigem dois aparelhos/emuladores com
relay em comum (o motorista não mudou).

## Automatizado

```bash
cd Prototipo/passenger
flutter analyze        # No issues found!
flutter test           # suíte completa
flutter test test/screens/map_screen_test.dart
```

## Manual

Pré-requisito: passageiro com solicitação aceita; motorista com "Iniciar corrida" tocado,
publicando `kind: 20005` a cada 50 m.

1. **Foco (US1)** — ao entrar em "motorista a caminho", o mapa fica centrado no carro; mover o
   motorista no emulador: a câmera o acompanha mantendo o zoom.
2. **GPS do passageiro não puxa a câmera** — mover o passageiro: o mapa continua no motorista; o
   marcador do passageiro anda (e pode sair da tela).
3. **Sem botão (US2)** — em nenhum momento do estado aparece o botão "Centralizar", nem depois de
   arrastar o mapa; a próxima posição do motorista traz a câmera de volta a ele.
4. **Saída do estado (US3)** — ao confirmar o encontro, mover o passageiro volta a mover o mapa.
5. **SC-004 em aparelho** — com o motorista andando, acompanhar ao menos 10 posições seguidas sem
   tocar no mapa: a câmera termina no motorista (já coberto pelo teste automatizado de T003(f)).
6. **Sem posição do motorista** — reabrir o app em "motorista a caminho" com o motorista parado:
   o mapa segue o passageiro até a primeira posição do motorista chegar.

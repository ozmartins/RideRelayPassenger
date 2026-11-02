# Phase 1 — Quickstart / Validação: Mapa e Destino do Passageiro

Comandos executados a partir de `Prototipo/passenger`. O cenário 1 é automatizado; os demais exigem
emulador/aparelho com localização simulável e, para carregar os mosaicos do mapa, conectividade de
rede (D2 de `research.md`).

## Pré-requisitos

- Ambiente das features 001–003 funcionando (ver `README.md`)
- Dependências instaladas: `flutter pub get`
- No emulador: localização simulada disponível (Android Studio → Extended Controls → Location, ou
  `adb emu geo fix <longitude> <latitude>`)

## Cenário 1 — Gates automatizados

```bash
flutter analyze   # esperado: No issues found!
flutter test      # esperado: todos os testes passam
```

Cobre, com dublê de `LocationService` e sem sensor real (Princípio II por analogia): posição exibida
quando disponível, mensagem quando indisponível, indicador acompanhando a posição, e o campo de
destino refletindo o texto digitado sem nenhuma chamada de publicação a relay.

## Cenário 2 — Mapa na posição real, com ícone de carro (US1, SC-001)

```bash
flutter run
```

1. Com localização simulada configurada no emulador, abra o aplicativo.

**Esperado**: a tela inicial é um mapa centrado na posição simulada, com um ícone de carro marcando
aquele ponto, em até 5 segundos.

## Cenário 3 — Indicador acompanha o deslocamento (US1 cenário 2, SC-002)

Com o aplicativo aberto na tela de mapa:

```bash
adb emu geo fix -49.4900 -28.9350   # primeira posição
# aguardar o indicador aparecer, depois:
adb emu geo fix -49.4950 -28.9400   # posição deslocada
```

**Esperado**: o ícone de carro se move para a nova posição sem nenhuma ação manual, em até 10
segundos.

## Cenário 4 — Permissão de localização (US1 cenários 3 e 4)

1. Instale o aplicativo do zero (ou revogue a permissão de localização pelas configurações do sistema)
   e abra-o.

**Esperado**: o aplicativo solicita a permissão de localização, explicando o motivo. Ao negar, a tela
de mapa mostra uma mensagem compreensível em vez de travar ou mostrar erro técnico.

## Cenário 5 — Informar o destino, sem publicação a relay (US2 cenários 1 a 3, SC-003, SC-004)

Com a tela de mapa aberta (localização disponível ou não, ver Cenário 6):

1. Toque no campo de destino e digite um endereço, por exemplo "Rua das Flores, 123, Araranguá".
2. Apague parte do texto e digite outro valor.
3. Observe, via `read_network_requests`/logs do relay ou instrumentação de teste, se alguma mensagem
   foi enviada a algum relay durante os passos 1 e 2.

**Esperado**: o texto digitado aparece refletido no campo em até 1 segundo a cada alteração (passos 1
e 2); nenhuma mensagem é publicada em nenhum relay como consequência de digitar, alterar ou apagar o
texto (passo 3).

## Cenário 6 — Campo de destino independe da posição (US2 cenário 5, FR-010)

1. Sem localização disponível (permissão negada, ou emulador sem localização simulada configurada),
   toque no campo de destino e digite um endereço.

**Esperado**: o campo aceita e reflete o texto normalmente, mesmo com a mensagem de localização
indisponível exibida na mesma tela.

## Cenário 7 — Campo vazio com texto de apoio (US2 cenário 4)

1. Abra a tela de mapa sem ter digitado nada antes no campo de destino.

**Esperado**: o campo aparece vazio, com um texto de apoio indicando o que digitar (ex.: "Para onde
você quer ir?").

## Resultado da execução

Executado em 2026-09-17 no emulador `Pixel_6_API34_1` (build release, `flutter build apk --release` +
`adb install -r`, com `adb emu geo fix` para simular posição).

- **Cenário 1**: `flutter analyze` → `No issues found!`; `flutter test` → 120/120 testes passando.
- **Cenário 2**: PASS. Ao abrir o app com localização simulada (`-49.4900 -28.9350`), a tela inicial
  mostrou o mapa centrado na posição, com o indicador de posição, em poucos segundos.
- **Cenário 3**: PASS. Com `adb emu geo fix -49.4950 -28.9400`, o indicador se moveu para a nova
  posição sem nenhuma ação manual.
- **Cenário 4**: PASS. Instalação nova solicitou a permissão (diálogo do sistema, com opções
  Precise/Approximate); ao negar (via revogação com `pm revoke` simulando "negada permanentemente"),
  a tela mostrou "Permissão de localização negada permanentemente. Conceda-a pelas configurações do
  aparelho para usar o mapa." — sem travar.
- **Cenário 5**: PASS. Digitar, alterar e apagar o texto no campo de destino refletiu cada mudança
  imediatamente (testado via teclado real do sistema). Não há qualquer via de código no app que
  publique em relay a partir deste campo (`MapScreen` não recebe `RelayService`/`EventFeed` —
  verificado também por teste automatizado, T016).
- **Cenário 6**: PASS. Com a permissão negada permanentemente (mensagem de indisponibilidade ocupando
  a maior parte da tela), o campo de destino permaneceu visível e aceitou o texto "Destino sem
  localizacao" normalmente.
- **Cenário 7**: PASS. Ao abrir a tela sem texto prévio, o campo aparece vazio com o texto de apoio
  "Para onde você quer ir?".

Nenhuma limitação de ambiente: o emulador ficou de pé durante toda a sessão de validação, ao
contrário do que ocorreu na feature equivalente do motorista.

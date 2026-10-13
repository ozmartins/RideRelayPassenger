# Phase 1 — Quickstart / Validação: Base do Aplicativo do Passageiro

Guia para colocar a app do passageiro rodando a partir de um clone limpo e validar que a feature está
completa. Os detalhes de decisão estão em [research.md](./research.md); a identidade do app está em
[data-model.md](./data-model.md).

## Pré-requisitos

- Flutter **3.47.4** (canal stable) com Dart 3.13.3 — outras versões próximas devem funcionar, mas esta
  é a validada.
- Android SDK configurado e um emulador ou aparelho Android conectado.
- Verificação:

  ```bash
  flutter --version
  flutter doctor
  ```

  Apenas o grupo **`[✓] Android toolchain`** precisa estar OK. Falhas em `Chrome` e `Linux toolchain`
  são esperadas neste ambiente e **não** impedem o trabalho — web e desktop estão fora de escopo.

## Setup

```bash
cd Prototipo/passenger
flutter pub get
```

## Executar

Com um emulador aberto ou aparelho conectado (`flutter devices` para listar):

```bash
cd Prototipo/passenger
flutter run
```

## Verificação estática e testes

```bash
cd Prototipo/passenger

# análise estática — deve reportar "No issues found!"
flutter analyze

# suíte completa de testes
flutter test

# um único teste, por nome
flutter test --plain-name "exibe o título da tela inicial"

# um único arquivo de teste
flutter test test/home_screen_test.dart
```

## Critérios de validação

A feature está completa quando **todos** os itens abaixo se verificam:

| # | Verificação | Origem |
|---|---|---|
| 1 | `flutter analyze` termina sem nenhuma violação | FR-007, SC-003 |
| 2 | `flutter test` executa e 100% dos testes passam | FR-006, SC-003 |
| 3 | `flutter run` compila, instala e abre o app no dispositivo Android sem erro | US1 cenário 1, FR-001 |
| 4 | A tela inicial exibe o título "Caronas Passageiro" | US1 cenário 3, FR-002 |
| 5 | Na gaveta de aplicativos, o app aparece como "Caronas Passageiro" | US1 cenário 4, FR-010 |
| 6 | Não há contador, botão flutuante nem qualquer texto do template padrão na tela | FR-003, SC-005 |
| 7 | Enviar o app para segundo plano e retornar mantém a tela inicial responsiva | US1 cenário 2 |
| 8 | Com o Wi-Fi e os dados móveis desligados, o app abre normalmente | FR-004, edge case de rede |
| 9 | Alternando o tema do sistema entre claro e escuro, a tela permanece legível | Edge case de tema |
| 10 | `grep -r applicationId android/app/build.gradle.kts` mostra `br.ufsc.tcc.caronas.passenger` | FR-010 |
| 11 | Existem `lib/main.dart`, `lib/screens/` e `lib/shared/`, cada um com propósito documentado no README | FR-008 |
| 12 | O README documenta setup, execução, análise, suíte de testes e como rodar um único teste | FR-009 |
| 13 | `ios/`, `web/`, `linux/`, `macos/` e `windows/` **não** existem no projeto | FR-005 |
| 14 | `pubspec.yaml` não declara nenhuma dependência de rede, Nostr ou criptografia | FR-011 |
| 15 | `git status` mostra que `.specify/`, `.claude/` e `specs/` não foram alterados pelo scaffold | Risco D5 |

## Validação de coexistência com a app do motorista

Quando a app do motorista também estiver construída, instale as duas no mesmo dispositivo e confirme
que aparecem como dois ícones distintos ("Caronas Motorista" e "Caronas Passageiro") e que instalar uma
não substitui a outra. Isso valida os `applicationId` irmãos e é pré-requisito dos testes ponta a ponta
das features de comunicação via Nostr.

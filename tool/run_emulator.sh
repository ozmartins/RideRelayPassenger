#!/usr/bin/env bash
# Sobe o emulador Android e roda o app do passageiro nele (build debug).
#
# Uso: tool/run_emulator.sh [EXEC_ID]
#   EXEC_ID  identifica a execução nos logs (ver LOGS.md); padrão "manual".
#            Use o mesmo valor no app do motorista.
# Variáveis opcionais:
#   AVD_NAME     nome do AVD (padrão Pixel_6_API34_2)
#   ORS_API_KEY  chave do OpenRouteService (sem ela a rota cai no fallback)
set -euo pipefail

AVD_NAME="${AVD_NAME:-Pixel_6_API34_2}"
EXEC_ID="${1:-manual}"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
EMULATOR="$(command -v emulator || echo "$SDK/emulator/emulator")"
ADB="$(command -v adb || echo "$SDK/platform-tools/adb")"

cd "$(dirname "$0")/.."

for bin in "$EMULATOR" "$ADB"; do
  [[ -x "$bin" ]] || { echo "não encontrei $bin (defina ANDROID_HOME)" >&2; exit 1; }
done
command -v flutter >/dev/null || { echo "flutter não está no PATH" >&2; exit 1; }
"$EMULATOR" -list-avds | grep -qx "$AVD_NAME" \
  || { echo "AVD '$AVD_NAME' não existe. Disponíveis:" >&2; "$EMULATOR" -list-avds >&2; exit 1; }

# Procura um emulador já em execução com este AVD.
find_serial() {
  local s
  for s in $("$ADB" devices | awk '/^emulator-[0-9]+[[:space:]]+device/ {print $1}'); do
    if "$ADB" -s "$s" emu avd name 2>/dev/null | tr -d '\r' | head -n1 | grep -qx "$AVD_NAME"; then
      echo "$s"; return 0
    fi
  done
  return 1
}

SERIAL="$(find_serial || true)"
if [[ -n "$SERIAL" ]]; then
  echo ">> $AVD_NAME já está rodando em $SERIAL"
else
  echo ">> subindo $AVD_NAME..."
  mkdir -p build
  nohup "$EMULATOR" -avd "$AVD_NAME" -no-snapshot-save >build/emulator.log 2>&1 &
  "$ADB" start-server >/dev/null

  for _ in $(seq 1 120); do
    SERIAL="$(find_serial || true)"
    [[ -n "$SERIAL" ]] && break
    sleep 2
  done
  [[ -n "$SERIAL" ]] || { echo "emulador não apareceu no adb (veja build/emulator.log)" >&2; exit 1; }

  echo ">> aguardando o boot de $SERIAL..."
  "$ADB" -s "$SERIAL" wait-for-device
  for _ in $(seq 1 180); do
    [[ "$("$ADB" -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] && break
    sleep 2
  done
  [[ "$("$ADB" -s "$SERIAL" shell getprop sys.boot_completed | tr -d '\r')" == "1" ]] \
    || { echo "o emulador não terminou o boot" >&2; exit 1; }
fi

DEFINES=(--dart-define="EXEC_ID=$EXEC_ID")
[[ -n "${ORS_API_KEY:-}" ]] && DEFINES+=(--dart-define="ORS_API_KEY=$ORS_API_KEY")

echo ">> flutter pub get"
flutter pub get

echo ">> instalando e rodando o app em $SERIAL (EXEC_ID=$EXEC_ID)"
exec flutter run -d "$SERIAL" "${DEFINES[@]}"

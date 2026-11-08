#!/usr/bin/env bash
# Extrai do aparelho os logs do fluxo do app do passageiro (build debug; ver LOGS.md).
#
# Uso: tool/extract_logs.sh [DESTINO]    (padrão: logs-passenger)
# Variáveis opcionais:
#   SERIAL    aparelho a usar (ver 'adb devices'); sem ela, usa o emulador do AVD_NAME
#             ou o único aparelho conectado
#   AVD_NAME  nome do AVD do passageiro (padrão Pixel_6_API34_2)
#   PACOTE    pacote do app (padrão br.ufsc.tcc.corridas.passenger)
set -euo pipefail

DESTINO="${1:-logs-passenger}"
PACOTE="${PACOTE:-br.ufsc.tcc.corridas.passenger}"
AVD_NAME="${AVD_NAME:-Pixel_6_API34_2}"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
ADB="$(command -v adb || echo "$SDK/platform-tools/adb")"

cd "$(dirname "$0")/.."

[[ -x "$ADB" ]] || { echo "não encontrei o adb (defina ANDROID_HOME)" >&2; exit 1; }

# Procura um emulador em execução com este AVD.
find_serial() {
  local s
  for s in $("$ADB" devices | awk '/^emulator-[0-9]+[[:space:]]+device/ {print $1}'); do
    if "$ADB" -s "$s" emu avd name 2>/dev/null | tr -d '\r' | head -n1 | grep -qx "$AVD_NAME"; then
      echo "$s"; return 0
    fi
  done
  return 1
}

SERIAL="${SERIAL:-$(find_serial || true)}"
if [[ -z "$SERIAL" ]]; then
  mapfile -t APARELHOS < <("$ADB" devices | awk 'NR>1 && $2=="device" {print $1}')
  case "${#APARELHOS[@]}" in
    0) echo "nenhum aparelho conectado (ver 'adb devices')" >&2; exit 1 ;;
    1) SERIAL="${APARELHOS[0]}" ;;
    *) echo "há ${#APARELHOS[@]} aparelhos e nenhum com o AVD $AVD_NAME; informe SERIAL=<serial>" >&2
       exit 1 ;;
  esac
fi
echo ">> aparelho: $SERIAL (pacote $PACOTE)"

mkdir -p "$DESTINO"
extraidos=0
for f in fluxo-ui.jsonl fluxo-servico.jsonl fluxo-ui.jsonl.1 fluxo-servico.jsonl.1; do
  saida="$DESTINO/$f"
  # run-as só funciona em build debug; arquivo inexistente faz o cat falhar.
  if "$ADB" -s "$SERIAL" exec-out run-as "$PACOTE" cat "databases/logs/$f" \
      >"$saida" 2>/dev/null && [[ -s "$saida" ]]; then
    echo "$f: $(wc -l <"$saida") linhas"
    extraidos=$((extraidos + 1))
  else
    rm -f "$saida"
  fi
done

if [[ "$extraidos" -eq 0 ]]; then
  echo "nenhum log extraído: o app é build debug e já rodou uma corrida?" >&2
  exit 1
fi
echo "Logs em $DESTINO/. Contêm dados de passageiros: anonimize antes de sair da máquina."

#!/usr/bin/env bash
# Recompila el ELF a una carpeta temporal y copia al runner SOLO los .cpp que
# cambiaron, para que la compilación siguiente sea incremental (minutos, no media hora).
# Uso (desde esta carpeta, con SLPS_259.83 copiado aquí):  ./incr_recomp.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
RUNNER="$REPO/ps2xRuntime/src/runner"
RECOMP="${RECOMP:-$REPO/out-host/ps2xRecomp/ps2_recomp}"
TMP="$HERE/.recomp_tmp"
rm -rf "$TMP"; mkdir -p "$TMP" "$RUNNER"
sed -e "s|^output = .*|output = \"$TMP/\"|" \
    -e "s|^input = .*|input = \"$HERE/SLPS_259.83\"|" \
    -e "s|^ghidra_output = .*|ghidra_output = \"$HERE/SLPS_259.83.csv\"|" \
    "$HERE/config.toml" > "$HERE/.config_tmp.toml"
"$RECOMP" "$HERE/.config_tmp.toml" > "$HERE/recomp.log" 2>&1
changed=0
for f in "$TMP"/*; do
  b=$(basename "$f")
  if ! cmp -s "$f" "$RUNNER/$b"; then cp "$f" "$RUNNER/$b"; changed=$((changed+1)); fi
done
for f in "$RUNNER"/*; do
  b=$(basename "$f")
  [ -e "$TMP/$b" ] || { rm "$f"; changed=$((changed+1)); }
done
for h in "$RUNNER"/ps2_recompiled_*.h; do
  cmp -s "$h" "$REPO/ps2xRuntime/include/$(basename "$h")" || cp "$h" "$REPO/ps2xRuntime/include/"
done
echo "archivos cambiados: $changed"

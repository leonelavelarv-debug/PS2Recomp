#!/usr/bin/env bash
# Compila las herramientas de PC (ps2_recomp y ps2_analyzer) en Linux o WSL.
# Se usan en tu PC para convertir el ELF del juego en código C++; el resultado
# luego se compila para la consola con ./rg35xxh/build.sh
#
# En Windows 11 también puedes usar Visual Studio (ver README principal),
# pero con WSL todo el flujo queda en un solo lugar.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${OUT:-$REPO_ROOT/out-host}"

GEN=()
command -v ninja >/dev/null && GEN=(-G Ninja)

EXTRA=()
case "$(uname -m)" in
x86_64) EXTRA=(-DCMAKE_CXX_FLAGS=-msse4.1 -DCMAKE_C_FLAGS=-msse4.1) ;;
esac

cmake -S "$REPO_ROOT" -B "$OUT" "${GEN[@]}" -DCMAKE_BUILD_TYPE=Release \
    -DPS2X_BUILD_RUNTIME=OFF -DPS2X_BUILD_STUDIO=OFF -DPS2X_BUILD_TEST=OFF \
    "${EXTRA[@]}"
cmake --build "$OUT" -j"$(nproc)"

echo ""
echo "==> listo:"
echo "    $OUT/ps2xRecomp/ps2_recomp"
echo "    $OUT/ps2xAnalyzer/ps2_analyzer"

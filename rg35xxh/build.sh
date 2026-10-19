#!/usr/bin/env bash
# Compila el runtime de PS2Recomp (con el código recompilado de tu juego, si ya
# está en ps2xRuntime/src/runner/) para la Anbernic RG35XX H con KNULLI.
#
# Uso:
#   ./rg35xxh/build.sh
#
# Variables opcionales:
#   BUILD_DIR   carpeta de compilación (por defecto: <repo>/out-rg35xxh)
#   CLEAN=1     borra la carpeta de compilación antes de configurar
#   LTO=1       activa LTO (más rápido en la consola, pero necesita MUCHA RAM al
#               compilar juegos grandes; por defecto apagado)
#   JOBS=N      hilos de compilación (por defecto: nproc)
#   DEBUG_LOGS=1  deja los logs del runtime activos (útil mientras portas el juego)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HERE="$REPO_ROOT/rg35xxh"
BUILD_DIR="${BUILD_DIR:-$REPO_ROOT/out-rg35xxh}"
RG35XXH_HOME="${RG35XXH_HOME:-$HERE/.deps}"
JOBS="${JOBS:-$(nproc)}"

fail() { echo "error: $*" >&2; exit 1; }

if [ ! -f "$RG35XXH_HOME/env.sh" ]; then
    echo "==> primera vez: preparando dependencias"
    "$HERE/setup.sh"
fi
# shellcheck disable=SC1091
source "$RG35XXH_HOME/env.sh"

case "$REPO_ROOT" in
/mnt/*) echo "aviso: compilar dentro de /mnt/ (disco de Windows) en WSL es MUY lento; clona el repo en tu carpeta de Linux (~)." >&2 ;;
esac

if ! ls "$REPO_ROOT/ps2xRuntime/src/runner/"*.cpp 2>/dev/null | grep -qv register_functions.cpp; then
    echo "aviso: ps2xRuntime/src/runner/ no tiene código recompilado de ningún juego;" >&2
    echo "       se compilará solo el runtime (sirve para probar que todo funciona)." >&2
fi

# Los encabezados generados por ps2_recomp van en ps2xRuntime/include (como indica upstream)
for header in ps2_recompiled_functions.h ps2_recompiled_stubs.h; do
    if [ -f "$REPO_ROOT/ps2xRuntime/src/runner/$header" ]; then
        cp -f "$REPO_ROOT/ps2xRuntime/src/runner/$header" "$REPO_ROOT/ps2xRuntime/include/$header"
    fi
done

[ "${CLEAN:-0}" = "1" ] && rm -rf "$BUILD_DIR"

if [ -f "$BUILD_DIR/CMakeCache.txt" ] &&
    ! grep -q "CMAKE_HOME_DIRECTORY:INTERNAL=$REPO_ROOT\$" "$BUILD_DIR/CMakeCache.txt"; then
    echo "caché de CMake de otro entorno; recreando $BUILD_DIR"
    rm -rf "$BUILD_DIR"
fi

GEN=()
command -v ninja >/dev/null && GEN=(-G Ninja)

LOG_FLAGS=(-DPS2X_ENABLE_RUNTIME_LOGS=OFF)
[ "${DEBUG_LOGS:-0}" = "1" ] && LOG_FLAGS=(-DPS2X_ENABLE_RUNTIME_LOGS=ON)

LTO_FLAG=-DPS2X_ENABLE_IPO=OFF
[ "${LTO:-0}" = "1" ] && LTO_FLAG=-DPS2X_ENABLE_IPO=ON

echo "==> configurando"
cmake -S "$REPO_ROOT" -B "$BUILD_DIR" "${GEN[@]}" \
    -DCMAKE_TOOLCHAIN_FILE="$HERE/cmake/rg35xxh-toolchain.cmake" \
    -DRG35XXH_TOOLCHAIN_DIR="$RG35XXH_TOOLCHAIN_DIR" \
    -DRG35XXH_DEPS_PREFIX="$RG35XXH_DEPS_PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DPS2X_TARGET_RG35XXH=ON \
    "$LTO_FLAG" "${LOG_FLAGS[@]}"

echo "==> compilando ($JOBS hilos)"
cmake --build "$BUILD_DIR" --target ps2EntryRunner -j"$JOBS"

BIN="$BUILD_DIR/ps2xRuntime/ps2EntryRunner"
[ -f "$BIN" ] || fail "no se generó $BIN"
echo ""
echo "==> listo: $BIN"
echo "    ahora empaqueta el port:  ./rg35xxh/package.sh \"Nombre del juego\" SLUS_XXX.XX"

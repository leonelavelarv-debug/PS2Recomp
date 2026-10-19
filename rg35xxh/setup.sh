#!/usr/bin/env bash
# Prepara lo necesario para compilar PS2Recomp para la Anbernic RG35XX H.
#  1. Descarga el compilador cruzado aarch64 (GCC 14, glibc 2.27, Cortex-A53).
#  2. Compila SDL2 para aarch64 (solo se usa para ENLAZAR: en la consola se usa
#     el SDL2 de KNULLI, que es el que sabe hablar con la GPU Mali y los botones).
#
# Se ejecuta una sola vez. Funciona en Linux x86_64 y en WSL (Ubuntu) de Windows 11.
# Requisitos del sistema: git, curl, tar, xz, cmake (>= 3.21), ninja (opcional), make.
#
# Variables:
#   RG35XXH_HOME   dónde se instala todo (por defecto: <repo>/rg35xxh/.deps)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RG35XXH_HOME="${RG35XXH_HOME:-$HERE/.deps}"
TC_VERSION="1.4.0"
TC_NAME="x-tools-aarch64-rpi3-linux-gnu-gcc14"
SDL_TAG="release-2.30.9"
TRIPLE="aarch64-rpi3-linux-gnu"

fail() { echo "error: $*" >&2; exit 1; }
for tool in git curl tar xz cmake make; do
    command -v "$tool" >/dev/null || fail "falta '$tool' (sudo apt install git curl xz-utils cmake make ninja-build)"
done

mkdir -p "$RG35XXH_HOME"
HOST_ARCH="$(uname -m)"

# --- 1. compilador -----------------------------------------------------------
TC_DIR="$RG35XXH_HOME/x-tools/$TRIPLE"
if [ "$HOST_ARCH" = "aarch64" ]; then
    echo "==> host aarch64: se usará el gcc nativo (necesita g++ >= 11)"
    TC_DIR=""
elif [ ! -x "$TC_DIR/bin/$TRIPLE-g++" ]; then
    echo "==> descargando compilador cruzado ($TC_NAME)"
    curl -fL --retry 3 -o "$RG35XXH_HOME/tc.tar.xz" \
        "https://github.com/tttapa/toolchains/releases/download/$TC_VERSION/$TC_NAME.tar.xz"
    tar -xJf "$RG35XXH_HOME/tc.tar.xz" -C "$RG35XXH_HOME"
    rm -f "$RG35XXH_HOME/tc.tar.xz"
else
    echo "==> compilador ya instalado"
fi

# --- 2. SDL2 (para enlazar) --------------------------------------------------
SDL_PREFIX="$RG35XXH_HOME/sdl2"
if [ ! -f "$SDL_PREFIX/lib/libSDL2-2.0.so.0" ] && [ ! -f "$SDL_PREFIX/lib/libSDL2.so" ]; then
    echo "==> compilando SDL2 ($SDL_TAG) para aarch64"
    rm -rf "$RG35XXH_HOME/SDL"
    git clone --depth 1 --branch "$SDL_TAG" https://github.com/libsdl-org/SDL.git "$RG35XXH_HOME/SDL"
    GEN=()
    command -v ninja >/dev/null && GEN=(-G Ninja)
    cmake -S "$RG35XXH_HOME/SDL" -B "$RG35XXH_HOME/SDL/build" "${GEN[@]}" \
        -DCMAKE_TOOLCHAIN_FILE="$HERE/cmake/rg35xxh-toolchain.cmake" \
        -DRG35XXH_TOOLCHAIN_DIR="$TC_DIR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$SDL_PREFIX" \
        -DSDL_SHARED=ON -DSDL_STATIC=OFF -DSDL_TEST=OFF \
        -DSDL_X11=OFF -DSDL_WAYLAND=OFF -DSDL_KMSDRM=OFF -DSDL_VULKAN=OFF \
        -DSDL_OPENGL=OFF -DSDL_OPENGLES=ON \
        -DSDL_PULSEAUDIO=OFF -DSDL_PIPEWIRE=OFF -DSDL_JACK=OFF -DSDL_SNDIO=OFF \
        -DSDL_ALSA=OFF -DSDL_LIBSAMPLERATE=OFF -DSDL_IBUS=OFF -DSDL_DBUS=OFF \
        -DSDL_HIDAPI=OFF -DSDL_LIBUDEV=OFF
    cmake --build "$RG35XXH_HOME/SDL/build" -j"$(nproc)"
    cmake --install "$RG35XXH_HOME/SDL/build"
    rm -rf "$RG35XXH_HOME/SDL"
else
    echo "==> SDL2 ya compilado"
fi

cat > "$RG35XXH_HOME/env.sh" <<EOF
export RG35XXH_TOOLCHAIN_DIR="$TC_DIR"
export RG35XXH_DEPS_PREFIX="$SDL_PREFIX"
EOF

echo ""
echo "==> listo. Dependencias en: $RG35XXH_HOME"

# Toolchain para Anbernic RG35XX H (Allwinner H700, 4x Cortex-A53, Mali-G31)
# con KNULLI / PortMaster.
#
# Usa el compilador cruzado GCC 14 + glibc 2.27 de tttapa/toolchains
# (aarch64-rpi3-linux-gnu, el mismo núcleo Cortex-A53). glibc 2.27 hace que el
# binario corra en cualquier firmware moderno (KNULLI, MuOS, ROCKNIX, stock).
#
# Variables:
#   RG35XXH_TOOLCHAIN_DIR  carpeta que contiene bin/aarch64-rpi3-linux-gnu-g++
#   RG35XXH_DEPS_PREFIX    prefijo con SDL2 (solo para enlazar; el de KNULLI se usa al ejecutar)

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

if(NOT RG35XXH_TOOLCHAIN_DIR)
    set(RG35XXH_TOOLCHAIN_DIR "$ENV{RG35XXH_TOOLCHAIN_DIR}")
endif()
if(NOT RG35XXH_DEPS_PREFIX)
    set(RG35XXH_DEPS_PREFIX "$ENV{RG35XXH_DEPS_PREFIX}")
endif()
# Hace que las variables lleguen a los try_compile internos de CMake
list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES RG35XXH_TOOLCHAIN_DIR RG35XXH_DEPS_PREFIX)

set(RG35XXH_TRIPLE aarch64-rpi3-linux-gnu)

if(RG35XXH_TOOLCHAIN_DIR)
    set(CMAKE_C_COMPILER   "${RG35XXH_TOOLCHAIN_DIR}/bin/${RG35XXH_TRIPLE}-gcc")
    set(CMAKE_CXX_COMPILER "${RG35XXH_TOOLCHAIN_DIR}/bin/${RG35XXH_TRIPLE}-g++")
    set(CMAKE_AR           "${RG35XXH_TOOLCHAIN_DIR}/bin/${RG35XXH_TRIPLE}-gcc-ar" CACHE FILEPATH "")
    set(CMAKE_RANLIB       "${RG35XXH_TOOLCHAIN_DIR}/bin/${RG35XXH_TRIPLE}-gcc-ranlib" CACHE FILEPATH "")
    set(CMAKE_STRIP        "${RG35XXH_TOOLCHAIN_DIR}/bin/${RG35XXH_TRIPLE}-strip" CACHE FILEPATH "")
    set(CMAKE_SYSROOT      "${RG35XXH_TOOLCHAIN_DIR}/${RG35XXH_TRIPLE}/sysroot")
else()
    # Compilación nativa en un equipo aarch64 (p. ej. runner ARM de GitHub)
    set(CMAKE_C_COMPILER   gcc)
    set(CMAKE_CXX_COMPILER g++)
endif()

# Cortex-A53 con CRC y NEON. Sin +crypto: no todos los H700 la exponen.
set(CMAKE_C_FLAGS_INIT   "-mcpu=cortex-a53+crc+simd")
set(CMAKE_CXX_FLAGS_INIT "-mcpu=cortex-a53+crc+simd")

# libstdc++/libgcc estáticos: el GCC 14 trae un libstdc++ más nuevo que el del firmware
set(CMAKE_EXE_LINKER_FLAGS_INIT "-static-libstdc++ -static-libgcc")

if(RG35XXH_DEPS_PREFIX)
    list(APPEND CMAKE_FIND_ROOT_PATH "${RG35XXH_DEPS_PREFIX}")
    list(APPEND CMAKE_PREFIX_PATH "${RG35XXH_DEPS_PREFIX}")
endif()

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Marca de plataforma que lee el CMake del proyecto
set(PS2X_TARGET_RG35XXH ON CACHE BOOL "Build for Anbernic RG35XX H (KNULLI/PortMaster)" FORCE)

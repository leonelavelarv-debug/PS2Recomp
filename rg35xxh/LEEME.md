# PS2Recomp para Anbernic RG35XX H (KNULLI / PortMaster)

Fork de [ran-j/PS2Recomp](https://github.com/ran-j/PS2Recomp) que añade un target
para la **Anbernic RG35XX H** (Allwinner H700, 4× Cortex-A53, Mali-G31, 1 GB RAM,
pantalla 640×480) con **KNULLI**, empaquetado como port de **PortMaster**.

Funciona igual que upstream: en tu PC conviertes el ELF de un juego de PS2 a C++,
y ese C++ se compila junto con el runtime. La diferencia es que aquí el
resultado es un binario **aarch64 nativo** para la consola, listo para la
carpeta `ports`.

## Antes de empezar: qué esperar

- PS2Recomp upstream es **experimental**. Cada juego necesita trabajo manual
  (stubs, overrides, depuración) antes de arrancar siquiera, también en PC.
- Upstream avisa que el rendimiento de **VU y GS es muy malo**: el GS se dibuja
  por CPU. En un Cortex-A53 a 1.5 GHz los juegos 3D pesados irán lentos; los
  2D o ligeros tienen más posibilidades.
- Lo práctico es **hacer que el juego corra primero en PC** y después compilarlo
  para la consola: depurar directamente en la RG35XX H es mucho más lento.
- No se incluye ni se descarga ningún juego. Usa tu propio disco.

## Qué cambia respecto a upstream

| Área | Cambio |
|---|---|
| CMake | Opción `PS2X_TARGET_RG35XXH`: solo compila el runtime, apaga UI de depuración, logs agresivos y FFmpeg |
| Gráficos | raylib sobre **SDL2 + OpenGL ES 2.0**, usando el SDL2 de KNULLI (Mali, KMSDRM) |
| Pantalla | Ventana a pantalla completa 640×480, escalado `fit` / `stretch` / `integer`, filtro nearest/linear |
| Controles | Mando integrado vía SDL GameController (mapeo de PortMaster), L2/R2 también como gatillos analógicos, opción para invertir X/O |
| Salir | Mantener **MENU + START** (o SELECT + START) 1 segundo, además del atajo de gptokeyb |
| Compilador | GCC 14 cruzado, glibc 2.27, `-mcpu=cortex-a53+crc+simd`, libstdc++ estático → corre en cualquier firmware |
| Port | `package.sh` genera el `.zip` de PortMaster: lanzador `.sh`, `port.json`, `conf/ps2x.conf`, carpeta `game/` |
| CI | `.github/workflows/rg35xxh.yml` compila el runtime para la consola en cada push |

Archivos nuevos: todo lo que hay en `rg35xxh/`. Cambios en código existente:
`CMakeLists.txt`, `ps2xRuntime/CMakeLists.txt`, `ps2xRuntime/cmake/ReleaseMode.cmake`,
`ps2xRuntime/src/lib/ps2_runtime.cpp`, `ps2xRuntime/src/lib/ps2_pad.cpp` (todo
protegido con `PLATFORM_RG35XXH`, no afecta a las builds de PC/Vita/Android).

## Requisitos (Windows 11)

1. Instala WSL con Ubuntu: en PowerShell como administrador, `wsl --install -d Ubuntu`.
2. Dentro de Ubuntu:
   ```bash
   sudo apt update
   sudo apt install -y git cmake ninja-build build-essential curl xz-utils zip
   ```
3. Clona tu fork **dentro de la carpeta de Linux** (no en `/mnt/c/...`, es muy lento):
   ```bash
   cd ~
   git clone --recurse-submodules https://github.com/TU_USUARIO/PS2Recomp.git
   cd PS2Recomp
   ```
4. [Ghidra](https://github.com/NationalSecurityAgency/ghidra/releases) en Windows
   para el flujo recomendado con juegos comerciales.

## Paso a paso

### 1. Prepara los archivos del juego

Copia todo el contenido de tu disco a una carpeta. El ejecutable se llama como el
serial, por ejemplo `SLUS_203.12`.

### 2. Compila las herramientas de PC

```bash
./rg35xxh/host-tools.sh
```

### 3. Recompila el ELF a C++

Flujo recomendado (juegos comerciales sin símbolos): abre el ELF en Ghidra,
ejecuta `ps2xRecomp/tools/ghidra/ExportPS2Functions.java` y usa el TOML/CSV que
exporta. Ajusta en ese `config.toml`:

```toml
[general]
input = "/home/TU_USUARIO/juegos/miJuego/SLUS_203.12"
ghidra_output = "/home/TU_USUARIO/juegos/miJuego/SLUS_203.12.csv"
output = "/home/TU_USUARIO/PS2Recomp/ps2xRuntime/src/runner"
single_file_output = false
low_memory_mode = true
```

```bash
./out-host/ps2xRecomp/ps2_recomp config.toml
```

Para pruebas rápidas o ELFs con símbolos: `./out-host/ps2xAnalyzer/ps2_analyzer SLUS_203.12 config.toml`.

Los stubs, overrides por juego y el ciclo de depuración están explicados en el
README principal y en la [wiki de upstream](https://github.com/ran-j/PS2Recomp/wiki).

### 4. Compila para la RG35XX H

```bash
./rg35xxh/build.sh
```

La primera vez descarga el compilador cruzado (~100 MB) y compila SDL2 para
enlazar. Opciones:

| Variable | Efecto |
|---|---|
| `CLEAN=1` | borra la compilación anterior |
| `LTO=1` | optimización en el enlace: más rendimiento, pero necesita mucha RAM con juegos grandes |
| `DEBUG_LOGS=1` | deja los logs del runtime (útil mientras portas; luego quítalos, cuestan rendimiento) |
| `JOBS=4` | limita hilos si WSL se queda sin memoria |

Si WSL se queda sin RAM con el código generado (puede ser enorme), dale más
memoria creando `C:\Users\TU_USUARIO\.wslconfig` con:

```ini
[wsl2]
memory=12GB
swap=16GB
```

### 5. Empaqueta el port

```bash
./rg35xxh/package.sh "Nombre del juego" SLUS_203.12
```

Genera `dist-rg35xxh/<carpeta>.zip`. Desde Windows lo encuentras en
`\\wsl$\Ubuntu\home\TU_USUARIO\PS2Recomp\dist-rg35xxh\`.

### 6. Instálalo en la consola

1. Descomprime el `.zip` en la carpeta `ports` de la SD (en KNULLI:
   `/userdata/roms/ports/`). Quedan `Nombre del juego.sh` y la carpeta del port.
2. Copia el contenido de tu disco a `ports/<carpeta>/game/` (con el ELF en la raíz).
3. En KNULLI: menú → Ajustes del juego → **Actualizar lista de juegos**, y ábrelo desde **Ports**.

Requiere PortMaster instalado (viene con KNULLI).

## Ajustes en la consola

Edita `ports/<carpeta>/conf/ps2x.conf`:

| Ajuste | Valores |
|---|---|
| `PS2X_SCALE` | `fit` (proporción correcta), `stretch` (pantalla completa), `integer` |
| `PS2X_FILTER` | `nearest` (nítido) o `linear` (suavizado) |
| `PS2X_SWAP_FACE` | `1` si X/O y Cuadrado/Triángulo salen invertidos |

Controles (por posición, como en un DualShock): abajo = X, derecha = O,
izquierda = Cuadrado, arriba = Triángulo; L1/R1/L2/R2, SELECT, START, sticks y
L3/R3 tal cual.

## Si algo falla

- Revisa `ports/<carpeta>/log.txt`: ahí queda toda la salida del runtime.
- Pantalla negra al abrir y vuelve al menú: casi siempre falta el ELF en `game/`
  o el nombre no coincide exactamente con el que diste a `package.sh`.
- El juego arranca en PC pero no en la consola: compila con `DEBUG_LOGS=1` y
  compara el `log.txt` con la salida en PC.

## Mantener el fork al día con upstream

```bash
git remote add upstream https://github.com/ran-j/PS2Recomp.git
git fetch upstream
git merge upstream/main
```

Los cambios del fork son pequeños y están aislados, así que los conflictos
deberían ser raros.

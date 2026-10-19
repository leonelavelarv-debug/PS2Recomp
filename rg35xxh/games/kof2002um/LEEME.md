# The King of Fighters 2002 Unlimited Match (PS2, SLPS-25983) — en progreso

Configuración y herramientas para recompilar KOF 2002 UM con PS2Recomp, con
destino final la Anbernic RG35XX H. **No incluye ningún archivo del juego**: usa
tu propio disco (versión japonesa, SLPS-25983).

## Estado

| Etapa | Estado |
|---|---|
| ELF recompilado a C++ (28 338 funciones, 0 errores) | ✅ |
| Carga de los 7 módulos IOP (SIO2MAN, PADMAN, MCMAN, MCSERV, LIBSD, SDRDRV, CRI_ADXI) | ✅ |
| Hilos del juego (5) y sincronización con vblank | ✅ |
| Busca y encuentra su primer archivo (`ADX\BGM.AFS`) | ✅ |
| Lectura de datos del disco por el driver CRI en el IOP | ⏳ siguiente bloqueo |
| Imagen en pantalla (GS) | ⏳ |
| Compilación para la RG35XX H | ⏳ (después de que se vea en PC) |

## Archivos

| Archivo | Para qué |
|---|---|
| `config.toml` | Configuración de `ps2_recomp`: stubs, `entry_points` y parches |
| `SLPS_259.83.csv` | Mapa de funciones (formato del exportador de Ghidra) ya corregido |
| `refine_map.py` | Regenera/corrige el mapa: separa funciones fusionadas y agrega punteros a función |
| `incr_recomp.sh` | Recompila y copia al runner solo los `.cpp` que cambiaron |
| `make_bgm_placeholder.py` | Crea un `ADX\BGM.AFS` de relleno (silencio) para pruebas sin el de 1.27 GB |

## Uso (WSL / Linux)

```bash
cd ~/PS2Recomp
./rg35xxh/host-tools.sh                       # una vez
cp /ruta/a/tu/disco/SLPS_259.83 rg35xxh/games/kof2002um/
cd rg35xxh/games/kof2002um && ./incr_recomp.sh   # genera ps2xRuntime/src/runner
```

Luego compila el runtime de PC para probar (ver el README principal) y ejecuta
desde una carpeta con el contenido del disco:

```bash
cd /ruta/al/contenido/del/disco
PS2X_TRACE_SYSCALLS=1 PS2X_TRACE_CD=1 ~/PS2Recomp/out-pc/ps2xRuntime/ps2EntryRunner ./SLPS_259.83
```

## Notas técnicas

- El ELF trae código y datos en **una sola sección**. Por eso el analizador
  automático: (1) tomaba los datos del final (desde `0x507580`) como código,
  (2) marcaba 39 escrituras normales como "código automodificable" y las cambiaba
  por `NOP` (causaba un bloqueo entre hilos). Este `config.toml` ya no tiene esos
  parches y el mapa termina el código en `0x507518`.
- Parche en `0x145310`: el callback de audio de CRI se colgaba en un bucle
  infinito si recibía un buffer NULL. Ahora regresa sin hacer nada. Es temporal;
  quítalo cuando el audio funcione.
- `sceCdSearchFile` está enlazado a mano (`0x11B808` y `0x11BB08`); el analizador
  no lo reconoció.

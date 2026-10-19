#!/usr/bin/env bash
# Empaqueta el runtime compilado como port de PortMaster para KNULLI.
#
# Uso:
#   ./rg35xxh/package.sh "Título del juego" SLUS_XXX.XX [carpeta]
#
#   Título   nombre que verás en la lista de Ports (también nombre del .sh)
#   ELF      nombre EXACTO del ejecutable del disco (p. ej. SLUS_203.12)
#   carpeta  nombre de la carpeta del port (por defecto: título en minúsculas sin espacios)
#
# Resultado: dist-rg35xxh/<carpeta>.zip  ->  descomprímelo en /userdata/roms/ports/
# NO incluye archivos del juego: tú copias el contenido de TU disco a <carpeta>/game/.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$REPO_ROOT/out-rg35xxh}"
DIST_DIR="${DIST_DIR:-$REPO_ROOT/dist-rg35xxh}"

fail() { echo "error: $*" >&2; exit 1; }

[ $# -ge 2 ] || fail "uso: $0 \"Título\" SLUS_XXX.XX [carpeta]"
TITLE="$1"
ELF_NAME="$2"
SLUG="${3:-$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')}"
[ -n "$SLUG" ] || fail "no pude generar un nombre de carpeta; pásalo como tercer argumento"
SCRIPT_NAME="$(echo "$TITLE" | sed 's#[/\\:*?"<>|]##g').sh"

BIN="$BUILD_DIR/ps2xRuntime/ps2EntryRunner"
[ -f "$BIN" ] || fail "no existe $BIN; ejecuta antes ./rg35xxh/build.sh"

STAGE="$DIST_DIR/stage"
rm -rf "$STAGE"
mkdir -p "$STAGE/$SLUG/game/mc0" "$STAGE/$SLUG/libs" "$STAGE/$SLUG/conf"

cp "$BIN" "$STAGE/$SLUG/ps2EntryRunner"
chmod +x "$STAGE/$SLUG/ps2EntryRunner"

# --- lanzador PortMaster ------------------------------------------------------
sed -e "s#@SLUG@#$SLUG#g" -e "s#@ELF@#$ELF_NAME#g" -e "s#@TITLE@#$TITLE#g" \
    "$REPO_ROOT/rg35xxh/port/launcher.sh.in" > "$STAGE/$SCRIPT_NAME"
chmod +x "$STAGE/$SCRIPT_NAME"

cp "$REPO_ROOT/rg35xxh/port/ps2x.conf" "$STAGE/$SLUG/conf/ps2x.conf"

cat > "$STAGE/$SLUG/game/LEEME.txt" <<EOF
Copia aquí el CONTENIDO de tu disco de $TITLE (todos sus archivos y carpetas).
El ejecutable $ELF_NAME debe quedar directamente en esta carpeta:

  ports/$SLUG/game/$ELF_NAME

Las partidas guardadas (memory card) se crean en ports/$SLUG/game/mc0/.
EOF

cat > "$STAGE/$SLUG/port.json" <<EOF
{
  "version": 3,
  "name": "$SLUG.zip",
  "items": ["$SCRIPT_NAME", "$SLUG"],
  "items_opt": [],
  "attr": {
    "title": "$TITLE",
    "porter": ["PS2Recomp-RG35XXH"],
    "desc": "$TITLE recompilado estáticamente con PS2Recomp y ejecutado de forma nativa.",
    "inst": "Copia el contenido de tu disco a ports/$SLUG/game/ (con $ELF_NAME en la raíz).",
    "genres": [],
    "image": {},
    "rtr": false,
    "exp": true,
    "runtime": null,
    "reqs": [],
    "arch": ["aarch64"],
    "availability": "full",
    "store": []
  }
}
EOF

mkdir -p "$DIST_DIR"
ZIP="$DIST_DIR/$SLUG.zip"
rm -f "$ZIP"
if command -v zip >/dev/null; then
    (cd "$STAGE" && zip -qr "$ZIP" "$SCRIPT_NAME" "$SLUG")
else
    (cd "$STAGE" && python3 -c "import sys,zipfile,os
z=zipfile.ZipFile(sys.argv[1],'w',zipfile.ZIP_DEFLATED)
for root in sys.argv[2:]:
    if os.path.isfile(root):
        i=zipfile.ZipInfo.from_file(root); i.external_attr=0o100755<<16; z.writestr(i,open(root,'rb').read(),zipfile.ZIP_DEFLATED); continue
    for d,_,fs in os.walk(root):
        z.write(d)
        for f in fs:
            p=os.path.join(d,f); i=zipfile.ZipInfo.from_file(p)
            if os.access(p,os.X_OK): i.external_attr=0o100755<<16
            z.writestr(i,open(p,'rb').read(),zipfile.ZIP_DEFLATED)
" "$ZIP" "$SCRIPT_NAME" "$SLUG")
fi

echo "==> port listo: $ZIP"
echo "    1. Descomprímelo en la carpeta ports de tu SD (/userdata/roms/ports/)."
echo "    2. Copia el contenido de tu disco a ports/$SLUG/game/"
echo "    3. En KNULLI: Ports -> $TITLE (si no aparece, actualiza la lista de juegos)."

#!/usr/bin/env python3
"""Crea un ADX\\BGM.AFS de relleno (todas las pistas en silencio).

El BGM.AFS real del disco pesa 1.27 GB; este sirve para probar el arranque sin
subirlo. En la consola se usa el archivo original del disco.

Uso: make_bgm_placeholder.py <salida> [numero_de_pistas]
"""
import struct
import sys

out = sys.argv[1] if len(sys.argv) > 1 else "BGM.AFS"
tracks = int(sys.argv[2]) if len(sys.argv) > 2 else 256

RATE = 44100
CHANNELS = 2
SECONDS = 2
FRAMES = (RATE * SECONDS + 31) // 32  # 32 muestras por bloque de 18 bytes
COPYRIGHT_OFFSET = 0x34                # los datos empiezan en offset + 4


def silent_adx():
    hdr = bytearray(COPYRIGHT_OFFSET + 4)
    struct.pack_into(">HHBBBBIIHBB", hdr, 0,
                     0x8000, COPYRIGHT_OFFSET, 3, 18, 4, CHANNELS,
                     RATE, FRAMES * 32, 500, 3, 0)
    hdr[COPYRIGHT_OFFSET - 2:COPYRIGHT_OFFSET + 4] = b"(c)CRI"
    data = bytes(18 * FRAMES * CHANNELS)
    end = b"\x80\x01\x00\x0e" + bytes(14)
    return bytes(hdr) + data + end


def align(n, a=0x800):
    return (n + a - 1) // a * a


adx = silent_adx()
data_off = align(8 + 8 * tracks + 8)
toc = bytearray(b"AFS\0" + struct.pack("<I", tracks))
for _ in range(tracks):
    toc += struct.pack("<II", data_off, len(adx))  # todas las pistas comparten el mismo audio
toc += struct.pack("<II", 0, 0)                    # sin tabla de nombres
blob = bytes(toc) + bytes(data_off - len(toc)) + adx
blob += bytes(align(len(blob)) - len(blob))
open(out, "wb").write(blob)
print(f"{out}: {tracks} pistas, {len(blob)} bytes")

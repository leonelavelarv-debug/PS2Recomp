#!/usr/bin/env python3
"""Refina el mapa de funciones de SLPS_259.83 (KOF 2002 UM, PS2).

1. Parte funciones que el analizador fusionó: después de un `jr $ra` + delay slot
   (+ nops de relleno), empieza una función nueva si ninguna rama cruza ese punto.
2. Busca punteros a función (palabras en la zona de datos y pares lui/addiu en
   el código) y los agrega como funciones nuevas o como entry_points.
"""
import csv
import struct
import sys

ELF = sys.argv[1] if len(sys.argv) > 1 else "SLPS_259.83"
CSV_IN = sys.argv[2] if len(sys.argv) > 2 else "SLPS_259.83.csv"
CSV_OUT = sys.argv[3] if len(sys.argv) > 3 else CSV_IN
ENTRY_OUT = sys.argv[4] if len(sys.argv) > 4 else "entry_points.txt"

BASE, OFF = 0x100000, 0x100
TEXT_END = 0x507518
DATA_START, DATA_END = 0x507580, 0x100000 + 0x48EE00
JR_RA = 0x03E00008

d = open(ELF, "rb").read()


def word(a):
    return struct.unpack_from("<I", d, a - BASE + OFF)[0]


def branch_target(a, w):
    """Destino de una rama condicional/incondicional relativa (no J/JAL), o None."""
    op = w >> 26
    rt = (w >> 16) & 0x1F
    imm = w & 0xFFFF
    if imm & 0x8000:
        imm -= 0x10000
    tgt = a + 4 + (imm << 2)
    if op in (4, 5, 6, 7, 20, 21, 22, 23):  # beq bne blez bgtz + likely
        return tgt
    if op == 1 and rt in (0, 1, 2, 3, 16, 17, 18, 19):  # REGIMM bltz/bgez/...
        return tgt
    if op == 0x11 and ((w >> 21) & 0x1F) == 8:  # bc1x
        return tgt
    if op == 0x12 and ((w >> 21) & 0x1F) == 8:  # bc2x
        return tgt
    return None


def jump_target(a, w):
    if w >> 26 in (2, 3):
        return ((a + 4) & 0xF0000000) | ((w & 0x3FFFFFF) << 2)
    return None


rows = sorted((int(r["Start"], 16), int(r["End"], 16)) for r in csv.DictReader(open(CSV_IN)))

# --- 1. partir funciones fusionadas ---
new_rows = []
splits = 0
for s, e in rows:
    branches = []  # (origen, destino)
    for a in range(s, e, 4):
        w = word(a)
        t = branch_target(a, w)
        if t is None:
            t = jump_target(a, w)
            if t is not None and w >> 26 == 3:
                t = None  # JAL es llamada, no rama interna
        if t is not None:
            branches.append((a, t))
    cands = []
    # funciones con jr a registro (switch por tabla): no se parten
    if any((word(x) & 0xFC1FFFFF) == 0x00000008 and ((word(x) >> 21) & 0x1F) != 31
           for x in range(s, e, 4)):
        new_rows.append((s, e))
        continue
    a = s
    while a < e - 8:
        wa = word(a)
        is_end = wa == JR_RA
        if wa >> 26 == 2:  # j fuera de la función = llamada de cola
            jt = jump_target(a, wa)
            is_end = not (s <= jt < e)
        if is_end:
            p = a + 8
            while p < e and word(p) == 0:
                p += 4
            if s < p < e:
                cands.append(p)
        a += 4
    cur = s
    for p in cands:
        cross = any((src < p <= dst) or (dst < p <= src) for src, dst in branches
                    if s <= dst < e)
        if not cross and p > cur:
            new_rows.append((cur, p))
            cur = p
            splits += 1
    new_rows.append((cur, e))

starts = {s for s, _ in new_rows}

# --- 2. punteros a función ---
def looks_like_start(t):
    if not (BASE <= t < TEXT_END) or t & 3:
        return False
    w0 = word(t)
    if (w0 >> 16) == 0x27BD and (w0 & 0x8000):  # addiu sp, sp, -N
        return True
    # justo después de jr ra + delay (+ nops)
    p = t - 4
    while p > BASE and word(p) == 0:
        p -= 4
    wp = word(p - 4)
    return wp == JR_RA or (wp >> 26 == 2 and not (p - 4 < jump_target(p - 4, wp) < t))


ptrs = set()
for a in range(DATA_START, DATA_END, 4):
    v = word(a)
    if looks_like_start(v):
        ptrs.add(v)
# lui rX, hi ; addiu rY, rX, lo  (en las siguientes 8 instrucciones)
for a in range(BASE, TEXT_END, 4):
    w = word(a)
    if w >> 26 != 0x0F:
        continue
    rt = (w >> 16) & 0x1F
    hi = (w & 0xFFFF) << 16
    for b in range(a + 4, min(a + 36, TEXT_END), 4):
        w2 = word(b)
        if w2 >> 26 in (9, 0x19) and ((w2 >> 21) & 0x1F) == rt:  # addiu/daddiu
            lo = w2 & 0xFFFF
            if lo & 0x8000:
                lo -= 0x10000
            v = (hi + lo) & 0xFFFFFFFF
            if looks_like_start(v):
                ptrs.add(v)
            break

added = 0
entry_points = set()
final = sorted(new_rows)
for t in sorted(ptrs):
    if t in starts:
        continue
    for i, (s, e) in enumerate(final):
        if s < t < e:
            entry_points.add(t)
            break
    else:
        added += 1

with open(CSV_OUT, "w") as f:
    f.write("Name,Start,End,Size\n")
    for s, e in final:
        name = f"sub_{s:08X}" if e != TEXT_END else f"fn_{s:08X}"
        f.write(f"{name},0x{s:08x},0x{e:08x},{e - s}\n")

with open(ENTRY_OUT, "w") as f:
    for t in sorted(entry_points):
        f.write(f"0x{t:08X}\n")

print(f"funciones: {len(rows)} -> {len(final)} (partidas {splits})")
print(f"punteros a función: {len(ptrs)}; ya eran inicio: {len(ptrs & set(s for s,_ in final))}; "
      f"entry_points internos: {len(entry_points)}; fuera de mapa: {added}")
print("0x13f6d8 es inicio:", 0x13F6D8 in {s for s, _ in final})

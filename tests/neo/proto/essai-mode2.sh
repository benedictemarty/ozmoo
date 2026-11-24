#!/bin/bash
# essai-mode2.sh — construit et lance le prototype essai-mode2 dans l'émulateur neo, écrit une capture PNG.
#
#   tests/neo/proto/essai-mode2.sh FICHIER_IMAGES SORTIE.png [--mode or|pair|impair]
#
# FICHIER_IMAGES : un fichier d'images v6 (JOURNEY.MG1, ou celui de tools/neo/mkpic.py --mg1), copié sous le nom PIC.MG1.
# Le programme écrit en $0F00 les erreurs des appels (0 partout attendu) et $AA en $0FFF à la fin.
# Auteur : bmarty <bmarty@mailo.com>
set -eu
# Variable GARDE : dossier où recopier ESSAI.NEO et PIC.MG1 (pour un essai sur la carte).
ICI=$(cd "$(dirname "$0")" && pwd)
PIC=$(realpath "${1:?fichier d\'images}"); PNG=$(realpath -m "${2:?capture}"); shift 2
NEO=${NEO:-$HOME/Projets/Neo6502Trinity/bin/neo}
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT
python3 "$ICI/mkfonts.py" "$ICI/../../../fonts/en/ClairsysOzmoo-Regular-US.fnt" "$w/police8.nf1" "$w/police4.nf1" "$@"
python3 "$ICI/textes.py" > "$w/textes.asm"
cp "$ICI/essai-mode2.asm" "$w/"
( cd "$w" && acme -f plain -o essai.bin --symbollist essai.sym essai-mode2.asm )
python3 - "$w" <<'PY'
import sys, re
w = sys.argv[1]
b = open(w + '/essai.bin', 'rb').read()
start = int(re.search(r'start\s*=\s*\$([0-9a-f]+)', open(w + '/essai.sym').read()).group(1), 16)
d = bytes([3, 0x4e, 0x45, 0x4f, 0, 0, start & 255, start >> 8, 0, 0, 0x10, len(b) & 255, len(b) >> 8, 0]) + b
open(w + '/ESSAI.NEO', 'wb').write(d)
PY
cp "$PIC" "$w/PIC.MG1"
[ -n "${GARDE:-}" ] && mkdir -p "$GARDE" && cp "$w/ESSAI.NEO" "$w/PIC.MG1" "$GARDE/"
( cd "$w" && NEO_NO_HOST_INPUT=1 SDL_AUDIODRIVER=dummy timeout -k 5 120 "$NEO" ESSAI.NEO path:. shot:150000000:shot.ppm cycles:151000000 > neo.log 2>&1 || true )
python3 - "$w" "$PNG" <<'PY'
import sys
from PIL import Image
w, png = sys.argv[1:]
Image.open(w + '/shot.ppm').save(png)
try:
    m = open(w + '/memory.dump', 'rb').read()
    print('erreurs par appel ($0F00..$0F0B) :', ' '.join('%02x' % c for c in m[0xf00:0xf0c]), ' fin :', '%02x' % m[0xfff])
    t = [m[0xf10 + 2 * i] + 256 * m[0xf11 + 2 * i] for i in range(5)]
    print('images (1/60 s) : image %d, texte 40 col %d, texte 80 col %d, banc 50x %d' % tuple(t[i + 1] - t[i] for i in range(4)))
except OSError:
    print('pas de memory.dump')
PY

#!/bin/bash
# mode2_test.sh — test du prototype essai-mode2 avec un fichier d'images libre (tools/neo/mkpic.py --mg1) :
# tous les appels au firmware sans erreur, fin atteinte, image 1 visible en haut à gauche, texte dans la
# dernière rangée de la zone du bas (le défilement a eu lieu et la ligne du banc y est écrite).
# Auteur : bmarty <bmarty@mailo.com>
set -eu
ICI=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT
python3 -I "$ICI/../../../tools/neo/mkpic.py" "$w/ESSAI.MG1" --mg1
sortie=$("$ICI/essai-mode2.sh" "$w/ESSAI.MG1" "$w/ecran.png")
echo "$sortie" | grep -q "erreurs par appel (\$0F00..\$0F0B) : 00 00 00 00 00 00 00 00 00 00 00 00  fin : aa" \
	|| { echo "ÉCHEC mode2 : $sortie"; exit 1; }
python3 -I - "$w/ecran.png" <<'PY' || exit 1
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert('RGB')
noir = (0, 0, 0)
image = sum(im.getpixel((x, y)) != noir for x in range(64) for y in range(32))
bas = sum(im.getpixel((x, y)) != noir for x in range(320) for y in range(232, 240))
haut_droite = sum(im.getpixel((x, y)) != noir for x in range(112, 320) for y in range(0, 8))
if image < 1000 or bas < 100 or haut_droite < 50:
    sys.exit('ÉCHEC mode2 : pixels allumés image %d, dernière rangée %d, texte de droite %d' % (image, bas, haut_droite))
print('mode2 : OK (image %d, dernière rangée %d, texte de droite %d pixels allumés)' % (image, bas, haut_droite))
PY

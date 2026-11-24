#!/bin/bash
# run_story.sh — joue une histoire Z-machine dans l'émulateur neo (firmware Trinity) et
# écrit l'écran final (grille 80 x 25 du mode texte 3) dans un fichier texte.
#
#   tests/neo/run_story.sh HISTOIRE SORTIE.txt [TOUCHES] [CYCLES] [OPTIONS make.rb...]
#
# Le programme est construit avec -neotest : l'invite [MORE] ne bloque pas, et à la
# sortie (quit) l'interpréteur recopie la grille en $F000 puis saute en $FFFF, ce qui
# arrête neo et écrit memory.dump. TOUCHES suit la syntaxe du crochet keys: de neo
# (\n = Entrée ; \e = Échap, qui arrête une version de test comme quit), elles sont tapées à partir du cycle KEYSTART (défaut 20 000 000) ;
# l'écran d'accueil est désactivé (-sw:0).
# Variable HIDKEYS : codes HID bruts en hexadécimal (crochet hid: de neo, sans modificateur),
# envoyés à partir de HIDSTART (défaut KEYSTART), par exemple avec la locale -neokbd:fr pour les touches accentuées ;
# une seconde salve facultative HIDKEYS2 part au cycle HIDSTART2.
# Le nombre de lectures de blocs de l'histoire (neo_readblocks) est écrit dans SORTIE.txt.lectures,
# SORTIE.txt.fin vaut 1 si le jeu s'est arrêté (quit ou Échap), 0 sinon ;
# le mode d'écran (3 ou 4) dans SORTIE.txt.mode ; avec -pics, l'état des images dans SORTIE.txt.images.
# Variable SHOT : si définie, capture PNG de l'écran un million de cycles avant la fin (ou au cycle SHOTCYCLE).
# Variable NEO : chemin de l'émulateur (défaut : ~/Projets/Neo6502Trinity/bin/neo).
# Auteur : bmarty <bmarty@mailo.com>
set -u
HERE=$(cd "$(dirname "$0")/../.." && pwd)
STORY=${1:?histoire}; OUT=${2:?sortie}; KEYS=${3:-}; CYCLES=${4:-400000000}
shift 4 2>/dev/null || shift $#
NEO=${NEO:-$HOME/Projets/Neo6502Trinity/bin/neo}
[ -x "$NEO" ] || { echo "émulateur neo introuvable : $NEO"; exit 2; }
name=$(basename "$STORY"); name=${name%.*}
cd "$HERE" || exit 2
ruby make.rb -t:neo -neotest -sw:0 "$@" "$STORY" > "build-neo-$name.log" 2>&1 || { cat "build-neo-$name.log"; exit 2; }
dir="$HERE/neo_$name"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
cp "$dir"/*.* "$work"/
prog=$(cd "$work" && ls *.NEO)
args=("$prog" "path:.")
[ -n "$KEYS" ] && args+=("keys:${KEYSTART:-20000000}:$KEYS")
[ -n "${HIDKEYS:-}" ] && args+=("hid:${HIDSTART:-${KEYSTART:-20000000}}:$HIDKEYS")
[ -n "${HIDKEYS2:-}" ] && args+=("hid:$HIDSTART2:$HIDKEYS2")
args+=("shot:${SHOTCYCLE:-$((CYCLES - 1000000))}:shot.ppm" "cycles:$CYCLES")
( cd "$work" && NEO_NO_HOST_INPUT=1 SDL_AUDIODRIVER=dummy timeout -k 5 300 "$NEO" "${args[@]}" > neo.log 2>&1 )
if grep -q "cycles:$CYCLES reached" "$work/neo.log"; then
	echo "ATTENTION : $name ne s'est pas terminé en $CYCLES cycles (pas de quit)" >&2
	echo 0 > "$OUT.fin"
else
	echo 1 > "$OUT.fin"
fi
[ -n "${SHOT:-}" ] && [ -r "$work/shot.ppm" ] && python3 -c "from PIL import Image; Image.open('$work/shot.ppm').save('$SHOT')"
python3 - "$work/memory.dump" "$OUT" <<'PY'
import sys
m = open(sys.argv[1], 'rb').read()
g = m[0xf000:0xf000 + 2000]
lines = [''.join(chr(c) if 32 <= c < 127 else bytes([c]).decode('cp437') if c >= 128 else '.' for c in g[r*80:r*80+80]).rstrip() for r in range(25)]
open(sys.argv[2], 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
open(sys.argv[2] + '.lectures', 'w').write('%d\n' % (m[0xf000 + 2000] + 256 * m[0xf000 + 2001]))
open(sys.argv[2] + '.mode', 'w').write('%d\n' % (4 if m[0xf000 + 2002] == 1 else 3))
# version construite avec -pics : dernière erreur de 41,2, nombre de dessins, cellules graphiques par rangée
d = m[0xf000 + 2003: 0xf000 + 2030]
open(sys.argv[2] + '.images', 'w').write('erreur %02x dessins %d rangees %s\n' % (d[0], d[1], ' '.join(str(c) for c in d[2:])))
# attributs de la grille (papier << 4 | encre), une ligne de 80 chiffres hexadécimaux par rangée
a = m[0xe800: 0xe800 + 2000]
# journal des 16 derniers dessins d'images (numéro, x, y, colonnes c0-c1, rangées r0-r1)
n = m[0xf000 + 2004]; j = m[0xe700: 0xe780]
lignes = []
for k in range(min(n, 16)):
    e = j[((n - min(n, 16) + k) % 16) * 8:][:8]
    lignes.append('image %d x %d y %d colonnes %d-%d rangees %d-%d' % (e[0], e[1] + 256 * e[2], e[3], e[4], e[5], e[6], e[7]))
open(sys.argv[2] + '.dessins', 'w').write('\n'.join(lignes) + '\n')
n = m[0xf000 + 2030]; j = m[0xe680: 0xe700]
lignes = []
for k in range(min(n, 16)):
    e = j[((n - min(n, 16) + k) % 16) * 8:][:8]
    lignes.append('rangee %d colonnes %d-%d appelant $%04x' % (e[0], e[1], e[2] - 1, e[3] + 256 * e[4] - 2))
open(sys.argv[2] + '.conversions', 'w').write('%d conversions\n' % n + '\n'.join(lignes) + '\n')
open(sys.argv[2] + '.attributs', 'w').write(''.join(a[r*80:r*80+80].hex() + '\n' for r in range(25)))
PY
rm -f "build-neo-$name.log"

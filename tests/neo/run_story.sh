#!/bin/bash
# run_story.sh — joue une histoire Z-machine dans l'émulateur neo (firmware Trinity) et
# écrit l'écran final (grille 80 x 25 du mode texte 3) dans un fichier texte.
#
#   tests/neo/run_story.sh HISTOIRE SORTIE.txt [TOUCHES] [CYCLES] [OPTIONS make.rb...]
#
# Le programme est construit avec -neotest : l'invite [MORE] ne bloque pas, et à la
# sortie (quit) l'interpréteur recopie la grille en $F000 puis saute en $FFFF, ce qui
# arrête neo et écrit memory.dump. TOUCHES suit la syntaxe du crochet keys: de neo
# (\n = Entrée), elles sont tapées à partir du cycle KEYSTART (défaut 20 000 000) ;
# l'écran d'accueil est désactivé (-sw:0).
# Variable HIDKEYS : codes HID bruts en hexadécimal (crochet hid: de neo, sans modificateur),
# envoyés à partir de KEYSTART, par exemple avec la locale -neokbd:fr pour les touches accentuées.
# Le nombre de lectures de blocs de l'histoire (neo_readblocks) est écrit dans SORTIE.txt.lectures.
# Variable SHOT : si définie, capture PNG de l'écran un million de cycles avant la fin.
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
[ -n "${HIDKEYS:-}" ] && args+=("hid:${KEYSTART:-20000000}:$HIDKEYS")
args+=("shot:$((CYCLES - 1000000)):shot.ppm" "cycles:$CYCLES")
( cd "$work" && NEO_NO_HOST_INPUT=1 SDL_AUDIODRIVER=dummy timeout -k 5 300 "$NEO" "${args[@]}" > neo.log 2>&1 )
if grep -q "cycles:$CYCLES reached" "$work/neo.log"; then
	echo "ATTENTION : $name ne s'est pas terminé en $CYCLES cycles (pas de quit)" >&2
fi
[ -n "${SHOT:-}" ] && [ -r "$work/shot.ppm" ] && python3 -c "from PIL import Image; Image.open('$work/shot.ppm').save('$SHOT')"
python3 - "$work/memory.dump" "$OUT" <<'PY'
import sys
m = open(sys.argv[1], 'rb').read()
g = m[0xf000:0xf000 + 2000]
lines = [''.join(chr(c) if 32 <= c < 127 else bytes([c]).decode('cp437') if c >= 128 else '.' for c in g[r*80:r*80+80]).rstrip() for r in range(25)]
open(sys.argv[2], 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
open(sys.argv[2] + '.lectures', 'w').write('%d\n' % (m[0xf000 + 2000] + 256 * m[0xf000 + 2001]))
PY
rm -f "build-neo-$name.log"

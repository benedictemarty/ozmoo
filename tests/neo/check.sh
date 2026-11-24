#!/bin/bash
# check.sh — joue un cas de test et vérifie que l'écran final contient les lignes attendues.
#
#   tests/neo/check.sh NOM
#
# Le cas est décrit par tests/neo/cas/NOM.cas (variables shell) :
#   STORY=examples/minizork.z3      histoire à jouer
#   KEYS=' open mailbox\nquit\ny\n'  touches (syntaxe du crochet keys: de neo)
#   KEYSTART=20000000               cycle de la première touche (facultatif)
#   CYCLES=400000000                cycles au plus (facultatif)
#   OPTS="-neokbd:fr"               options de make.rb (facultatif)
#   HIDKEYS=1f,24,28                codes HID bruts, à la place de KEYS (facultatif)
# et par tests/neo/cas/NOM.attendu : une expression régulière (grep -E) par ligne, chacune
# devant correspondre à au moins une ligne de l'écran final.
# Auteur : bmarty <bmarty@mailo.com>
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
NAME=${1:?nom du cas}
CAS="$HERE/cas/$NAME.cas"; ATT="$HERE/cas/$NAME.attendu"
[ -r "$CAS" ] && [ -r "$ATT" ] || { echo "cas introuvable : $NAME"; exit 2; }
STORY=""; KEYS=""; KEYSTART=20000000; CYCLES=400000000; OPTS=""; HIDKEYS=""
. "$CAS"
OUT="$HERE/../../build-neo/$NAME.ecran"
mkdir -p "$(dirname "$OUT")"
# shellcheck disable=SC2086
KEYSTART=$KEYSTART HIDKEYS=$HIDKEYS "$HERE/run_story.sh" "$STORY" "$OUT" "$KEYS" "$CYCLES" $OPTS || { echo "ÉCHEC : $NAME (exécution)"; exit 1; }
fail=0
while IFS= read -r motif; do
	[ -z "$motif" ] && continue
	grep -Eq -- "$motif" "$OUT" || { echo "  absent : $motif"; fail=1; }
done < "$ATT"
if [ $fail = 0 ]; then echo "OK : $NAME"; else echo "ÉCHEC : $NAME (écran dans $OUT)"; cat "$OUT"; exit 1; fi

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
#   HIDKEYS=1f,24,28                codes HID bruts (facultatif), à partir de HIDSTART (défaut KEYSTART)
#   HIDKEYS2=29 HIDSTART2=700000000 seconde salve de codes HID (facultatif)
#   LECTURES=1-40                   bornes du nombre de blocs lus dans l'histoire (facultatif)
#   MODE=4                          mode d'écran attendu (facultatif ; 3 texte, 4 jeux v6)
#   IMAGES='^erreur 00 dessins 2 '  état des images (version -pics) : expression régulière sur SORTIE.images
#                                   (« erreur EE dessins N rangees c0 .. c24 », cellules graphiques par rangée)
#   SI_PRESENT=1                    cas sauté si STORY est absente (jeux commerciaux gardés hors du dépôt)
# et par tests/neo/cas/NOM.attendu : une expression régulière (grep -E) par ligne, chacune
# devant correspondre à au moins une ligne de l'écran final ; une ligne « !~ motif » exige au
# contraire qu'aucune ligne n'y corresponde.
# Auteur : bmarty <bmarty@mailo.com>
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
NAME=${1:?nom du cas}
CAS="$HERE/cas/$NAME.cas"; ATT="$HERE/cas/$NAME.attendu"
[ -r "$CAS" ] && [ -r "$ATT" ] || { echo "cas introuvable : $NAME"; exit 2; }
STORY=""; KEYS=""; KEYSTART=20000000; CYCLES=400000000; OPTS=""; HIDKEYS=""; HIDSTART=""; HIDKEYS2=""; HIDSTART2=""; LECTURES=""; MODE=""; IMAGES=""; SI_PRESENT=""
. "$CAS"
if [ -n "$SI_PRESENT" ] && [ ! -r "$HERE/../../$STORY" ]; then echo "SAUTÉ : $NAME ($STORY absente)"; exit 0; fi
OUT="$HERE/../../build-neo/$NAME.ecran"
mkdir -p "$(dirname "$OUT")"
# shellcheck disable=SC2086
KEYSTART=$KEYSTART HIDKEYS=$HIDKEYS HIDSTART=${HIDSTART:-$KEYSTART} HIDKEYS2=$HIDKEYS2 HIDSTART2=$HIDSTART2 "$HERE/run_story.sh" "$STORY" "$OUT" "$KEYS" "$CYCLES" $OPTS || { echo "ÉCHEC : $NAME (exécution)"; exit 1; }
fail=0
while IFS= read -r motif; do
	[ -z "$motif" ] && continue
	case "$motif" in
		'!~ '*) m=${motif#'!~ '}; ! grep -Eq -- "$m" "$OUT" || { echo "  présent à tort : $m"; fail=1; } ;;
		*) grep -Eq -- "$motif" "$OUT" || { echo "  absent : $motif"; fail=1; } ;;
	esac
done < "$ATT"
if [ "$(cat "$OUT.fin")" != 1 ]; then
	echo "  le jeu ne s'est pas arrêté (pas de quit ni d'Échap) : l'écran relu n'est pas fiable"; fail=1
fi
if [ -n "$IMAGES" ] && ! grep -Eq -- "$IMAGES" "$OUT.images"; then
	echo "  images : $(cat "$OUT.images"), attendu $IMAGES"; fail=1
fi
if [ -n "$MODE" ] && [ "$(cat "$OUT.mode")" != "$MODE" ]; then
	echo "  mode d'écran : $(cat "$OUT.mode"), attendu $MODE"; fail=1
fi
if [ -n "$LECTURES" ]; then
	n=$(cat "$OUT.lectures"); lo=${LECTURES%-*}; hi=${LECTURES#*-}
	[ "$n" -ge "$lo" ] && [ "$n" -le "$hi" ] || { echo "  lectures de blocs : $n, attendu $LECTURES"; fail=1; }
fi
if [ $fail = 0 ]; then echo "OK : $NAME"; else echo "ÉCHEC : $NAME (écran dans $OUT)"; cat "$OUT"; exit 1; fi

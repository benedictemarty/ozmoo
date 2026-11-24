#!/bin/bash
# paquet-cle.sh — prépare un dossier à copier sur la clé USB de la Neo6502 (firmware Trinity) :
# plusieurs histoires construites pour -t:neo (sans -neotest), chacune = <JEU>.NEO + son histoire,
# toutes dans le même dossier, plus le fichier ESSAI-CARTE.md (liste de vérifications).
#
#   tests/neo/paquet-cle.sh [DOSSIER]      (défaut : build-neo/cle/OZMOO)
#
# Le dossier est vérifié : chaque .NEO commence par l'en-tête 03 'N' 'E' 'O' et son histoire est
# présente. Code de retour non nul si une construction ou une vérification échoue.
# Auteur : bmarty <bmarty@mailo.com>
set -u
HERE=$(cd "$(dirname "$0")/../.." && pwd)
OUT=${1:-$HERE/build-neo/cle/OZMOO}
# histoire : ce qu'elle vérifie sur la carte
HISTOIRES=(
	examples/minizork.z3          # jeu court, préchargé en mémoire
	examples/advent_punyinform.z5 # 80 Ko : plus grand que la RAM, lecture USB pendant la partie
	examples/dragontroll.z5       # jeu Z5 ordinaire
	test/etude.z5                 # écran, clavier, saisie chronométrée (menu de tests)
	test/czech.z5                 # conformité de l'interpréteur
	test/praxix.z5                # conformité (commande all)
)
cd "$HERE" || exit 2
rm -rf "$OUT"; mkdir -p "$OUT"
err=0
for s in "${HISTOIRES[@]}"; do
	name=$(basename "$s"); name=${name%.*}
	if ! ruby make.rb -t:neo "$s" > "build-neo-$name.log" 2>&1; then
		echo "ÉCHEC construction : $s"; cat "build-neo-$name.log"; err=1; continue
	fi
	rm -f "build-neo-$name.log"
	for f in "neo_$name"/*.NEO "neo_$name"/*.Z[1-8]; do
		b=$(basename "$f")
		[ -e "$OUT/$b" ] && { echo "ÉCHEC : nom en double $b"; err=1; }
		cp "$f" "$OUT/"
	done
	rm -rf "neo_$name"
done
cp "$HERE/docs/neo/ESSAI-CARTE.md" "$OUT/"
# vérifications
for p in "$OUT"/*.NEO; do
	[ -e "$p" ] || { echo "ÉCHEC : aucun .NEO"; err=1; break; }
	[ "$(head -c 4 "$p" | od -An -tx1 | tr -d ' ')" = "034e454f" ] || { echo "ÉCHEC : en-tête $p"; err=1; }
	base=$(basename "$p" .NEO)
	[ ${#base} -le 8 ] || { echo "ÉCHEC : nom trop long $base"; err=1; }
	ls "$OUT/$base".Z? >/dev/null 2>&1 || { echo "ÉCHEC : histoire absente pour $base"; err=1; }
done
n=$(ls "$OUT"/*.NEO 2>/dev/null | wc -l)
extra=$(ls "$OUT" | grep -vcE '^[A-Z0-9_]{1,8}\.(NEO|Z[1-8])$|^ESSAI-CARTE\.md$')
[ "$extra" -eq 0 ] || { echo "ÉCHEC : $extra fichier(s) en trop"; err=1; }
[ "$n" -eq ${#HISTOIRES[@]} ] || { echo "ÉCHEC : $n programmes au lieu de ${#HISTOIRES[@]}"; err=1; }
[ $err -eq 0 ] && { echo "Paquet prêt : $OUT"; ls -l "$OUT"; }
exit $err

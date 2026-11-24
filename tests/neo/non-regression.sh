#!/bin/bash
# non-regression.sh — vérifie que la cible Neo ne change rien aux autres cibles : l'interpréteur
# assemblé (temp/ozmoo, avant compression par exomizer) doit être identique, octet pour octet,
# à celui du commit amont de référence, pour chaque cible et chaque version de Z-machine testée.
#
#   tests/neo/non-regression.sh [COMMIT_AMONT]      (défaut : 5b990fb, base du portage)
#
# exomizer n'est pas nécessaire : make.rb s'arrête après acme quand il manque, temp/ozmoo est déjà écrit.
# Auteur : bmarty <bmarty@mailo.com>
set -u
HERE=$(cd "$(dirname "$0")/../.." && pwd)
BASE=${1:-5b990fb}
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
mkdir -p "$work/amont" "$work/neo"
git -C "$HERE" archive "$BASE" | tar -x -C "$work/amont"
git -C "$HERE" ls-files -z | (cd "$HERE" && xargs -0 tar -c) | tar -x -C "$work/neo"
fail=0; n=0
for target in c64 c128 plus4 mega65 x16; do
	for story in examples/minizork.z3 test/czech.z5 test/praxix.z5; do
		for side in amont neo; do
			(cd "$work/$side" && rm -f temp/ozmoo && ruby make.rb -t:$target "$story" > build.log 2>&1)
			[ -s "$work/$side/temp/ozmoo" ] || { echo "ÉCHEC : $target $story ($side) ne s'assemble pas"; tail -5 "$work/$side/build.log"; fail=1; continue 2; }
			cp "$work/$side/temp/ozmoo" "$work/$side.bin"
		done
		n=$((n+1))
		if cmp -s "$work/amont.bin" "$work/neo.bin"; then echo "identique : $target $story"
		else echo "DIFFÉRENT : $target $story"; fail=1; fi
	done
done
[ $fail = 0 ] && echo "Non-régression : $n binaires identiques à $BASE." || { echo "Non-régression : ÉCHEC"; exit 1; }

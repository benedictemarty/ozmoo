# Tests de la cible Neo6502 (firmware Trinity) : chaque cas est joué dans l'émulateur neo,
# l'un après l'autre (ils partagent temp/ et neo_<jeu>/ à la racine du dépôt).
# make -C tests/neo            tous les cas
# make -C tests/neo minizork   un seul cas
# make -C tests/neo paquet     dossier pour la clé USB (build-neo/cle/OZMOO), vérifié
# make -C tests/neo images     décodeur des images Infocom (tools/neo/infopic.py)
# NEO=/chemin/vers/bin/neo     émulateur (défaut : ~/Projets/Neo6502Trinity/bin/neo)
CAS := $(basename $(notdir $(wildcard cas/*.cas)))

.PHONY: all paquet images $(CAS)
.NOTPARALLEL:

all: images $(CAS) paquet
	@echo "Tous les tests Neo6502 sont passés (images + $(words $(CAS)) cas + paquet)."

images:
	python3 -I ./infopic_test.py

paquet:
	./paquet-cle.sh > /dev/null || ./paquet-cle.sh

$(CAS):
	./check.sh $@

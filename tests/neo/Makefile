# Tests de la cible Neo6502 (firmware Trinity) : chaque cas est joué dans l'émulateur neo,
# l'un après l'autre (ils partagent temp/ et neo_<jeu>/ à la racine du dépôt).
# make -C tests/neo            tous les cas
# make -C tests/neo minizork   un seul cas
# NEO=/chemin/vers/bin/neo     émulateur (défaut : ~/Projets/Neo6502Trinity/bin/neo)
CAS := $(basename $(notdir $(wildcard cas/*.cas)))

.PHONY: all $(CAS)
.NOTPARALLEL:

all: $(CAS)
	@echo "Tous les tests Neo6502 sont passés ($(words $(CAS)) cas)."

$(CAS):
	./check.sh $@

# Histoires de test générées

`czech4.z4` et `czech8.z8` sont le testeur de conformité **czech** (`test/czech/czech.inf`, de l'amont)
compilé en versions 4 et 8 de la Z-machine, pour couvrir ces deux versions que les histoires du dépôt
n'atteignent pas :

```sh
inform -v4 test/czech/czech.inf tests/neo/histoires/czech4.z4
inform -v8 test/czech/czech.inf tests/neo/histoires/czech8.z8
```

(Inform 6.42 du 10 février 2024, compilées le 2026-11-24.)

`chrono.z5`, `accents.z5` et `annuler.z5` sont compilés depuis `tests/neo/sources/` (bmarty, domaine public) :

```sh
inform -v5 tests/neo/sources/chrono.inf tests/neo/histoires/chrono.z5
inform -v5 tests/neo/sources/accents.inf tests/neo/histoires/accents.z5
inform -v5 tests/neo/sources/annuler.inf tests/neo/histoires/annuler.z5
inform -v6 tests/neo/sources/images.inf tests/neo/histoires/images.z6
```

`essai.mg1` est le fichier d'images libre de `tools/neo/mkpic.py` (bmarty, domaine public), au format IBM
VGA, pour le cas `images-libres` :

```sh
python3 tools/neo/mkpic.py tests/neo/histoires/essai.mg1 --mg1
```

`testz6.z6` et `testz6scroll.z6` sont compilés depuis les sources de l'amont (`testz6.inf`,
`testz6scroll.inf`, à la racine du dépôt, licence d'Ozmoo) :

```sh
inform -v6 testz6.inf tests/neo/histoires/testz6.z6
inform -v6 testz6scroll.inf tests/neo/histoires/testz6scroll.z6
```

Licence de czech, reprise telle quelle de `test/czech/README.txt` :

```
Czech, v0.8
Copyright (C) 2003, Amir Karger

The copyright holder hereby grants the rights of usage, distribution
and modification of this software to everyone and for any purpose, as
long as this license and the copyright notice above are preserved and
not modified.  There is no warranty for this software.
```

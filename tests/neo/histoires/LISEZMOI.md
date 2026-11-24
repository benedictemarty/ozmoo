# Histoires de test générées

`czech4.z4` et `czech8.z8` sont le testeur de conformité **czech** (`test/czech/czech.inf`, de l'amont)
compilé en versions 4 et 8 de la Z-machine, pour couvrir ces deux versions que les histoires du dépôt
n'atteignent pas :

```sh
inform -v4 test/czech/czech.inf tests/neo/histoires/czech4.z4
inform -v8 test/czech/czech.inf tests/neo/histoires/czech8.z8
```

(Inform 6.42 du 10 février 2024, compilées le 2026-11-24.)

Licence de czech, reprise telle quelle de `test/czech/README.txt` :

```
Czech, v0.8
Copyright (C) 2003, Amir Karger

The copyright holder hereby grants the rights of usage, distribution
and modification of this software to everyone and for any purpose, as
long as this license and the copyright notice above are preserved and
not modified.  There is no warranty for this software.
```

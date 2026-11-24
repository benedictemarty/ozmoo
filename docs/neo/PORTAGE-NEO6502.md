# Ozmoo pour Neo6502 / firmware Trinity

Portage de l'interpréteur Z-machine [Ozmoo](https://github.com/johanberntsson/ozmoo) (Johan Berntsson et
Fredrik Ramsberg, GPLv2) vers la **Neo6502** d'Olimex avec le firmware **Trinity** (bmarty). Il part de
l'Ozmoo officiel (commit `5b990fb`, release 16) et ajoute une cible `-t:neo` (`TARGET_NEO`) ; les autres
cibles ne changent pas.

Dépôt : fork [benedictemarty/ozmoo](https://github.com/benedictemarty/ozmoo), branche `neo6502-trinity`
(remote `origin`) ; l'officiel est le remote `upstream`.

## Construire et lancer

```sh
ruby make.rb -t:neo examples/minizork.z3
```

produit le dossier `neo_minizork/` :

| Fichier | Contenu |
|---|---|
| `MINIZORK.NEO` | le programme : interpréteur, mémoire dynamique et blocs pré-chargés de l'histoire, configuration |
| `MINIZORK.Z3` | l'histoire telle quelle (après les correctifs éventuels de make.rb), lue pendant la partie |

Copier les deux fichiers dans le même dossier de la clé USB, puis lancer `MINIZORK` depuis NeoDOS.
Les parties sauvées sont écrites à côté : `MINIZORK.SV0` à `MINIZORK.SV9`.

Dans l'émulateur du firmware : `ruby make.rb -t:neo -s examples/minizork.z3` (exécutable `neo`, à mettre
dans le `PATH` ou à déclarer dans `.ozmoorc` : `NEO = /chemin/vers/Neo6502Trinity/bin/neo`).

## État (version 0.4.0, sprint 4)

Vérifié dans l'émulateur `neo` de Trinity (0.16.112), par `make -C tests/neo` :

| Cas | Histoire | Résultat |
|---|---|---|
| `czech-z3`, `czech-z4`, `czech-z5`, `czech-z8` | testeur de conformité czech | 349/0, 406/0, 406/0, 367/0 (réussis/échoués) |
| `praxix` | praxix.z5, commande `all` | seul `multiundo` échoue (un seul niveau d'annulation, comme sur les autres cibles d'Ozmoo) |
| `minizork` | minizork.z3 | partie, ligne de statut, `quit` |
| `vmem-sans-prechargement` | minizork.z3 construit avec `-p:0` | 12 commandes, toute l'histoire lue à la demande |
| `adventure` | advent_punyinform.z5 (80 Ko, plus que la RAM) | 12 commandes |
| `sauvegarde` | minizork.z3 | `save` puis `restore` dans l'emplacement 4 |
| `redemarrage` | minizork.z3 | `restart` (rechargement du `.NEO`) |
| `annuler` | annuler.z5 (`tests/neo/sources/`) | `save_undo` / `restore_undo` : annulation, puis échec de la seconde (un niveau) |
| `annuler-adventure` | advent_punyinform.z5 | commande `undo` du jeu |
| `saisie-chronometree` | chrono.z5 (`tests/neo/sources/`) | `read_char` et `aread` avec délai : routine appelée 10 fois par seconde |
| `accents` | accents.z5 (`tests/neo/sources/`) | lettres accentuées à l'écran, symboles `{ } ~ \` \| \\ _ ^`, composition `^e` → ê |
| `clavier-azerty` | accents.z5 avec `-neokbd:fr` | touches é è ç à ù du clavier AZERTY, `^` puis `e` |

Et `tests/neo/non-regression.sh` : l'interpréteur des cibles C64, C128, Plus/4, MEGA65 et X16 (minizork.z3,
czech.z5, praxix.z5) est identique, octet pour octet, à celui de l'amont `5b990fb`.

Fonctions :

- Versions Z1 à Z5, Z7 et Z8 en texte (Z3, Z4, Z5 et Z8 testées) ; Z6 est refusée par make.rb pour l'instant.
- Mémoire virtuelle par blocs de 512 octets lus dans le fichier de l'histoire (3,6 Seek + 3,8 Read), de
  `story_start` à `$FBFF` (pour Adventure : 28 blocs de mémoire dynamique et 68 de mémoire virtuelle).
- Écran : mode texte 3 de Trinity, **80 × 25** (5,13 Text Write, 5,14 Text Scroll, 5,15 Text Clear),
  ligne de statut et fenêtre haute, vidéo inverse, invite `[MORE]` clignotante, couleurs (noir sur blanc
  par défaut, comme Ozmoo ; options `-fgcol` et `-bgcol` de make.rb pour changer, non testées sur la Neo).
- Clavier par 2,1 : lettres, chiffres, ponctuation, Entrée, retour arrière, flèches.
- Accents (sans option `-cm:`, qui est ignorée pour la Neo) : les caractères de la table Unicode par défaut
  de la Z-machine (ZSCII 155-223) qui existent en CP437 s'affichent avec leur glyphe (é è ê à ç ù â î ô û
  ë ï ü ä ö ÿ á í ó ú ì ò å ñ æ ß « » ¡ ¿, et É Ä Ö Ü Å Æ Ç Ñ) ; les autres sans accent (À → A, œ → o).
  Saisie : les lettres Latin-1 de la locale du clavier (`LOCALE fr` dans NeoDOS, ou `-neokbd:fr` à la
  construction) ; `^` et `¨` sont des touches mortes (`^` puis `e` → ê, `^` puis espace → `^`). Une
  majuscule accentuée sans glyphe CP437 est saisie en minuscule.
- Saisie chronométrée : le temps vient du compteur de trames 5,37 (60 Hz).
- `save` / `restore` (emplacements 0 à 9), `restart`, `quit` (retour à NeoDOS par 1,3).
- Annulation (undo), active par défaut (`-u:0` pour la retirer) : un niveau, comme les autres cibles. L'état
  (page zéro, pile Z, mémoire dynamique) est copié par le blitter (12,2) dans la mémoire graphique `$90`
  (32 Ko, inutilisée en mode texte) ; make.rb retire l'undo si la mémoire dynamique et la pile dépassent
  32 Ko. Jeux Z5 et plus : par le jeu (`undo`) ; Z3 : Ctrl-U (non testé : `neo` n'envoie pas Ctrl).

Non testé : la saisie d'une majuscule accentuée (le crochet `hid:` de `neo` n'envoie pas Maj), la sortie vers NeoDOS
(les tests s'arrêtent avant, par `-neotest`), et **rien n'a encore été essayé sur la carte**.

## Architecture

| Fichier | Rôle |
|---|---|
| `asm/constants-neo.asm` | carte mémoire, page zéro (celle de la C64), registres de l'API, routines « KERNAL » |
| `asm/neo.asm` | appel de l'API, clavier, temps, lecture de l'histoire, primitives d'écran du mode 3, tables de caractères |
| `asm/chars-neo.asm` | caractères : codes internes des lettres accentuées, tables d'entrée et de sortie (remplace les sections `-cm:` de `streams.asm`) |
| `asm/undo-neo.asm` | annulation : copie de l'état dans la mémoire graphique `$90` par 12,2 |
| `asm/save-neo.asm` | sauvegarde, restauration, redémarrage (inclus dans la zone `save_restore` de `disk.asm`) |
| `asm/screenkernal.asm`, `asm/screen.asm` | branches `TARGET_NEO` à côté de celles de l'X16 |
| `asm/disk.asm`, `asm/ozmoo.asm`, `asm/utilities.asm` | le code de disquette CBM est exclu, la configuration est déjà en mémoire |
| `make.rb` | cible `neo`, mode `MODE_NEO`, écriture du `.NEO` (`write_neo_file`, `build_neo`) |

Ozmoo garde ses caractères en PETSCII ; la couche Neo traduit à la frontière : ASCII du clavier vers
PETSCII (`neo_ascii_to_petscii`), Latin-1 vers code interne (`neo_latin1_to_internal`), PETSCII vers
CP437 à l'écran (`neo_petscii_to_cp437`). Les lettres accentuées ont des codes internes libres
(`$e0-$fe`, `$b0-$b6`, voir `chars-neo.asm`). Les couleurs restent
des numéros de la C64, traduits en couleurs CGA du mode 3 (`neo_c64_to_cga`).

### Carte mémoire

| Adresses | Contenu |
|---|---|
| `$0000-$00FF` | page zéro d'Ozmoo (même disposition que la C64) |
| `$0100-$0150` | `print_buffer` (dans la pile, comme sur la C64) |
| `$0200-$02FF` | `print_buffer2`, petits tampons, `memory_buffer` |
| `$0300-$047F` | tampon de répertoire, nom de fichier pour l'API, chaîne pour 5,13, séquence de redémarrage |
| `$0480-$05FD` | table de la mémoire virtuelle (191 entrées) |
| `$0600-$07FF` | configuration chargée avec le `.NEO` |
| `$0800-...` | interpréteur, pile Z (`stack_start`) ; pas de cache de pages (`NO_VMEM_CACHE`, comme l'X16) |
| `story_start-$FBFF` | mémoire dynamique puis blocs de la mémoire virtuelle |
| `$FC00-$FFFF` | noyau du 6502 et registres de l'API (`$FF00-$FF0F`) |
| mémoire graphique `$90:0000` | état sauvé pour l'annulation (hors de l'espace du 6502) |

NeoDOS (résident en `$B800-$FBFF`) est écrasé ; `quit` le recharge par 1,3.

### Fichiers ouverts

Le chargeur du firmware (3,2) prend le canal 0 : l'histoire est ouverte sur le **canal 1** pendant toute
la partie. Les sauvegardes passent par 3,3 Store File et 3,2 Load File (taille vérifiée par 3,16 avant de
charger).

## Essai sur la carte

`tests/neo/paquet-cle.sh` (ou `make -C tests/neo paquet`) prépare `build-neo/cle/OZMOO/` : six histoires
(minizork, advent_punyinform, dragontroll, etude, czech, praxix) prêtes à copier sur la clé, avec la liste
de vérifications [ESSAI-CARTE.md](ESSAI-CARTE.md). Lancement depuis NeoDOS : `CD \OZMOO` puis `MINIZORK`.

## Tests

`tests/neo/run_story.sh` construit une histoire avec `-neotest`, la joue dans l'émulateur `neo` avec des
touches tapées (crochet `keys:`, ou codes HID bruts par `hid:`) et écrit l'écran final. Avec `-neotest`, `[MORE]` ne bloque pas et `quit`
recopie la grille du mode 3 en `$F000` (12,2) avant de sauter en `$FFFF`, ce qui arrête `neo` et écrit
`memory.dump`. `make -C tests/neo` joue toute la suite (voir `tests/neo/Makefile`).

Les versions de test comptent aussi les blocs lus dans l'histoire (`neo_test_reads`, recopié après la
grille) ; un cas peut en borner le nombre (`LECTURES=min-max`). Mesures de la 0.3.0 : Adventure, 27 blocs
pour 12 commandes ; minizork sans préchargement, 55 blocs ; les autres histoires tiennent en mémoire (0).

## Limites connues

- Pas de touches de fonction ; pas de glyphe pour les majuscules accentuées absentes du CP437 (À, È, Ê...).
- Pas d'images Z6, pas de son, pas d'historique de défilement, pas de mode sombre ; un seul niveau d'annulation.
- `neo_delay_1ms` est une boucle approximative (≈ 6 000 cycles, en supposant 6,25 MHz) : elle ne sert
  qu'aux pauses de l'affichage.

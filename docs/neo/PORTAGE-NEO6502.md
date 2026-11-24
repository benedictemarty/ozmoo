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

Jeux v6 avec images (firmware Trinity 0.16.115 ou plus) : donner le fichier d'images IBM d'origine,
`.MG1` (VGA, palette par image) ou `.EG1` (EGA, 640 de large, dessiné à moitié de largeur) :

```sh
ruby make.rb -t:neo -pics JOURNEY.MG1 JOURNEY.ZIP
```

Le fichier est copié à côté de l'histoire sous le nom `<JEU>.MG1` / `<JEU>.EG1` et lu pendant la partie
(les images ne sont ni converties ni mises dans le `.NEO`).

Dans l'émulateur du firmware : `ruby make.rb -t:neo -s examples/minizork.z3` (exécutable `neo`, à mettre
dans le `PATH` ou à déclarer dans `.ozmoorc` : `NEO = /chemin/vers/Neo6502Trinity/bin/neo`).

## État (version 0.6.0, sprint 6)

Vérifié dans l'émulateur `neo` de Trinity (0.16.115), par `make -C tests/neo` :

| Cas | Histoire | Résultat |
|---|---|---|
| `czech-z3`, `czech-z4`, `czech-z5`, `czech-z8` | testeur de conformité czech | 349/0, 406/0, 406/0, 367/0 (réussis/échoués) |
| `praxix` | praxix.z5, commande `all` | seul `multiundo` échoue (un seul niveau d'annulation, comme sur les autres cibles d'Ozmoo) |
| `minizork` | minizork.z3 | partie, ligne de statut, `quit` |
| `vmem-sans-prechargement` | minizork.z3 construit avec `-p:0` | 12 commandes, toute l'histoire lue à la demande |
| `adventure` | advent_punyinform.z5 (80 Ko, plus que la RAM) | 12 commandes |
| `sauvegarde` | minizork.z3 | `save` puis `restore` dans l'emplacement 4 |
| `redemarrage` | minizork.z3 | `restart` (rechargement du `.NEO`) |
| `z6-test` | testz6.z6 (`testz6.inf` de l'amont) | opcodes v6 : pile utilisateur, fenêtres, marges, flux 3, print_form, picture_data |
| `z6-defilement` | testz6scroll.z6 (`testz6scroll.inf` de l'amont) | fenêtre partielle (6 x 20) qui défile sans toucher au reste de l'écran |
| `annuler` | annuler.z5 (`tests/neo/sources/`) | `save_undo` / `restore_undo` : annulation, puis échec de la seconde (un niveau) |
| `annuler-adventure` | advent_punyinform.z5 | commande `undo` du jeu |
| `saisie-chronometree` | chrono.z5 (`tests/neo/sources/`) | `read_char` et `aread` avec délai : routine appelée 10 fois par seconde |
| `accents` | accents.z5 (`tests/neo/sources/`) | lettres accentuées à l'écran, symboles `{ } ~ \` \| \\ _ ^`, composition `^e` → ê |
| `clavier-azerty` | accents.z5 avec `-neokbd:fr` | touches é è ç à ù du clavier AZERTY, `^` puis `e` |
| `images-libres` | images.z6 (`tests/neo/sources/`) + `histoires/essai.mg1` (mkpic) | taille des images, dessin en mode 4, défilement de la fenêtre avec ses images, texte écrit sur une image |
| `infocom-journey-images`, `infocom-zorkzero-images` | Journey PC r83 + `JOURNEY.MG1`, Zork Zero PC r393 + `ZORK0.EG1` (hors dépôt, sautés s'ils manquent) | écran titre et introduction de Journey ; colonnes, rose des vents, ligne d'état et lettrines de Zork Zero |

Et `tests/neo/non-regression.sh` : l'interpréteur des cibles C64, C128, Plus/4, MEGA65 et X16 (minizork.z3,
czech.z5, praxix.z5, testz6.z6) est identique, octet pour octet, à celui de l'amont `5b990fb`.

Fonctions :

- Versions Z1 à Z5, Z7 et Z8 en texte (Z3, Z4, Z5 et Z8 testées).
- Version 6 (jeux à fenêtres : Journey, Arthur, Zork Zero, Shogun) en **mode 4** de Trinity (0.16.115) :
  texte 80 x 25 du mode 3 posé sur le graphisme 320 x 240 x 256 couleurs, une cellule montrant soit son
  texte soit le graphisme (5,44). Les fenêtres Z6 sont des rectangles qui défilent par 5,45. Avec `-pics`,
  les images sont dessinées par le firmware (voir « Images des jeux Z6 ») ; sans `-pics`, rien n'est
  dessiné à leur place. Sur un firmware sans mode 4, retour au mode 3, sans images (une fenêtre partielle
  y est recopiée ligne par ligne : grille relue par 12,2, réécrite par 5,13).
  L'invite `[MORE]` clignote dans le coin bas droit de la fenêtre et rend ensuite la cellule telle qu'elle était.
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
| `asm/screenkernal-z6.asm`, `asm/screen-z6.asm` | idem pour les jeux v6 ; primitives `neo_copy_cells`, `neo_blank_cells`, `neo_scroll_rows` dans `neo.asm` |
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

## Jeux d'Infocom (essais locaux)

Les jeux commerciaux ne sont pas dans le dépôt. Les cas `infocom-*` de `tests/neo/cas/` (`SI_PRESENT=1`)
jouent des histoires tirées de l'image Macintosh « Infocom Masterpieces » si elles sont présentes dans
`../infocom-masterpieces/jeux/` (à côté du dépôt), et sont sautés sinon. Extraction (hfsutils) : la partie
données de chaque programme Mac `IN..` est l'histoire (`hmount`, puis `hcopy -r`).

Version 6 (0.5.0) : Journey (PC r83, cas `infocom-journey`), Zork Zero (PC r393, `infocom-zorkzero`), Arthur
(Mac r54, `infocom-arthur`), en texte. Les versions PC viennent des archives de bmarty, rangées dans
`../infocom-masterpieces/ibm/`.

Essayés dans `neo` (0.4.0) : Zork I, Trinity (37,7 Ko de mémoire dynamique, 137 blocs lus pour 4
commandes), Sherlock (cas de test) ; A Mind Forever Voyaging, Beyond Zork, Border Zone (horloge en temps
réel) démarrent et répondent (captures, pas de cas).

## Images des jeux Z6

Choix de bmarty (2026-11-24) : les images sont décodées par le firmware Trinity, à la volée, depuis les
fichiers d'images d'origine posés sur la clé. Format retenu : celui des versions IBM (`.EG1` EGA, `.MG1`
VGA), décrit par `pix2gif` (ztools de Mark Howell) ; les fichiers Mac (`PIC.DATA`, `CPIC.DATA`) ne sont
pas décodables (compression inconnue).

- `tools/neo/infopic.py` : décodeur de référence (liste, PNG).
- `tools/neo/mkpic.py` : écrit un fichier d'images de test libre de droits (formats EG1 et MG1 ; codes
  jusqu'à 12 bits, remises à zéro de la table, transparence, image sans données, palette).
- `tests/neo/infopic_test.py` (`make -C tests/neo images`) : aller-retour mkpic/infopic ; si présent,
  `../infocom-masterpieces/ibm/zorkzero/ZORK0.EG1` (Zork Zero r393) : 396 images complètes ;
  `../infocom-masterpieces/ibm/journey/JOURNEY.MG1` (Journey r83) : 134 images avec palette.

Journey IBM r83 (mémoire dynamique 15,4 Ko) : `JOURNEY.MG1` (VGA), 134 images de 320 de large au plus,
chacune avec sa palette (14 couleurs au plus), donc sans réduction sur la Neo ; les images EGA sont réparties
sur deux fichiers (`JOURNEY.EG1`, `JOURNEY.EG2`, champ « part » de l'en-tête) ; dans `JOURNEY.CG1` (CGA,
drapeau 8), seules 23 images sur 134 se décodent avec cet algorithme (CGA non utilisé sur la Neo).

Zork Zero IBM r393 : 503 entrées, 396 images, 640 × 200 en EGA (moitié de la largeur sur l'écran de
320 × 240 du mode 2), 16 couleurs fixes de l'EGA ; mémoire dynamique 29,2 Ko.

Firmware : Trinity 0.16.114 apporte le groupe 41 « Infocom Pictures » (41,1 Picture Info, 41,2 Draw
Picture) ; 0.16.115 le mode 4 mixte (5,44 Set Cell Layer, 5,45 Text Scroll Rect, grille en page `$91`) et
l'option « couleur de base » de 41,2.

### Moteur d'images d'Ozmoo (`asm/pictures-neo.asm`, 0.6.0)

- **Unités** : Ozmoo compte en pixels d'image 320 x 200 (`Z6_PIXEL_UNITS`, comme l'amont) ; une cellule
  de texte fait 4 x 8 pixels du graphisme du mode 4, à la même échelle : une image se dessine à sa
  position telle quelle (41,2), sans conversion.
- **Taille** (`picture_data`) : demandée au firmware (41,1) à chaque appel, rien n'est gardé en mémoire ;
  une entrée sans pixels (rectangle d'Arthur) a une taille et ne dessine rien. L'image 0 rend le nombre
  d'images et la version lus dans l'en-tête du fichier.
- **Carte des cellules** : Ozmoo tient un bit par cellule (texte ou graphisme). Dessiner une image passe
  ses cellules en graphisme, après avoir peint au fond de la fenêtre (32,9) les pixels des cellules qui
  étaient du texte ; écrire ou effacer du texte (5,13, 5,15) repasse les cellules touchées en texte ; le
  défilement d'une fenêtre (5,45) fait aussi défiler ses pixels (12,3) et sa carte (vers le haut ; vers
  le bas, les images du rectangle repassent en texte).
- **4 suites par rangée** (limite du firmware) : quand une rangée en demande plus, une suite de texte
  faite d'espaces entre deux suites graphiques passe en graphisme (pixels peints à son papier : rendu
  identique), sinon la plus courte suite graphique repasse en texte. Zork Zero en a besoin : colonne,
  marge vide, lettrine, texte, colonne font 5 suites.
- **Couleurs** : les entrées 0-15 servent au texte ; au démarrage du mode 4 elles sont ramenées aux
  niveaux que le firmware montre pour le texte (00/55/AA/FF) pour que les pixels peints au fond aient
  exactement le papier du texte. Images VGA : une tranche de 16 entrées par image à partir de 16 (15
  tranches, réutilisées à tour de rôle, la même image gardant sa tranche) ; une image sans palette prend
  celle de la dernière image dessinée (la palette EGA si aucune). Images EGA : palette EGA en 16-31.
- **Numéro d'interpréteur** : 6 (IBM PC) avec `-pics`, la machine des fichiers d'images ; les jeux
  disposent alors leur écran comme sur PC.
- **Pas de superposition** : un caractère écrit sur une image remplace la cellule (4 x 8 pixels) ; le
  fond transparent des jeux (couleur −1) n'est pas rendu, les espaces cachent l'image.
- **Mémoire** : le moteur prend environ 2,5 Ko (Zork Zero : 22 blocs de mémoire virtuelle au lieu de 27).

Les versions de test (`-neotest`) relèvent l'état des images : dernière erreur de 41,2, nombre de dessins
et cellules graphiques par rangée (`SORTIE.images`, attendu `IMAGES=` d'un cas), journal des 16 derniers
dessins (`.dessins`) et des 16 dernières conversions en texte (`.conversions`), attributs de la grille
(`.attributs`).

### Prototype de l'écran v6 en mode 2 (`tests/neo/proto/`)

`essai-mode2.sh FICHIER_IMAGES SORTIE.png` construit `essai-mode2.asm` (programme autonome, hors d'Ozmoo)
et le lance dans `neo` : mode 2, image 1 du fichier dessinée par 41,2 (palette de l'image dans les entrées
2 et suivantes), texte de 40 colonnes (police 8 × 8) à droite de l'image et de 80 colonnes (police 4 × 8) en
dessous, puis 50 fois « défilement de la zone du bas + ligne de 80 caractères ». Il n'utilise que des
fonctions existantes de Trinity :

| Besoin | Fonction |
|---|---|
| police | 32,15 Set Font (format NF1, en RAM du 6502), polices tirées de Clairsys par `mkfonts.py` |
| papier d'une cellule | 32,9 Erase Rect |
| texte | 32,4 couleur, 32,5 Move To, 32,16 Draw String (encre seule, papier inchangé) |
| défilement d'un rectangle | 12,3 de la mémoire vidéo `$80` vers elle-même (octets, pas de 160) |
| image | 3,4 ouverture puis 41,2 Draw Picture |

Résultat dans l'émulateur (2026-11-24) : aucun appel en erreur ; affichage et défilement corrects (lignes
dans l'ordre). Les durées relevées par le compteur d'images (5,37, rangées en `$0F10`) valent 0 dans
l'émulateur, qui ne compte pas le temps passé dans le firmware : **elles ne valent que sur la carte, pas
encore mesurées**. `GARDE=dossier` recopie `ESSAI.NEO` et `PIC.MG1` pour un essai sur la carte.

Mesures sur la carte (session Trinity, 2026-11-24, firmware 0.16.114 de développement, `JOURNEY.MG1` réel) : les
12 appels sans erreur ; compteur d'images (résolution 1/60 s, soit 17 ms) : image 1 de Journey (110 × 127) en
5 images (environ 83 ms) ; 11 lignes de 40 colonnes en 1 image au plus ; 19 lignes de 80 colonnes avec 7
défilements en 1 image au plus ; 50 fois « défilement + ligne de 80 caractères » en 6 images (environ 2 ms
chacune). L'affichage de la carte (défilement par 12,3 quand source et destination se chevauchent) reste à
regarder à l'écran. Piège relevé : 3,4 refuse un canal laissé ouvert par un programme précédent ; Ozmoo et le
prototype ferment donc tous les canaux (3,5 avec `$FF`) avant d'ouvrir.

Constats :

- 80 colonnes de 4 pixels : lisibles mais grossières (« m », « w ») ; 40 colonnes de 8 pixels : nettes.
- Police réduite : `{ } \ _ | ~` absents (la police d'Ozmoo suit les codes écran de la C64).
- 16 couleurs pour tout l'écran : une image MG1 charge sa palette dans les entrées 2 à n+1, il ne reste au
  texte que les entrées 0 et 1 ; deux images de palettes différentes ne peuvent pas être justes ensemble.
- Le défilement par 12,3 recopie des octets (2 pixels) : les bords de rectangle doivent tomber sur des x
  pairs, ce qui est vrai pour des cellules de 4 ou 8 pixels. Le comportement de la carte quand la source et
  la destination se chevauchent n'est pas vérifié.

`make -C tests/neo mode2` (dans la suite) : le prototype avec le fichier libre de `mkpic.py --mg1`, sans
erreur, image et texte présents sur la capture.

## Essai sur la carte

`tests/neo/paquet-cle.sh` (ou `make -C tests/neo paquet`) prépare `build-neo/cle/OZMOO/` : six histoires
(minizork, advent_punyinform, dragontroll, etude, czech, praxix) prêtes à copier sur la clé, avec la liste
de vérifications [ESSAI-CARTE.md](ESSAI-CARTE.md). Lancement depuis NeoDOS : `CD \OZMOO` puis `MINIZORK`.

## Tests

`tests/neo/run_story.sh` construit une histoire avec `-neotest`, la joue dans l'émulateur `neo` avec des
touches tapées (crochet `keys:`, ou codes HID bruts par `hid:` à partir de `HIDSTART`) et écrit l'écran final. Avec `-neotest`, `[MORE]` ne bloque pas et `quit`
recopie la grille du mode 3 en `$F000` (12,2) avant de sauter en `$FFFF`, ce qui arrête `neo` et écrit
`memory.dump`. Dans une version de test, Échap (`\e`, ou le code HID 29) fait la même chose, pour les jeux
qu'on ne quitte pas simplement. Un attendu peut aussi exiger qu'une ligne soit absente (`!~ motif`).
`make -C tests/neo` joue toute la suite (voir `tests/neo/Makefile`).

Les versions de test comptent aussi les blocs lus dans l'histoire (`neo_test_reads`, recopié après la
grille) ; un cas peut en borner le nombre (`LECTURES=min-max`). Mesures de la 0.3.0 : Adventure, 27 blocs
pour 12 commandes ; minizork sans préchargement, 55 blocs ; les autres histoires tiennent en mémoire (0).

## Limites connues

- Pas de touches de fonction ; pas de glyphe pour les majuscules accentuées absentes du CP437 (À, È, Ê...).
- Images Z6 sans superposition du texte (voir plus haut) ; images Mac (Arthur) non lisibles ; pas de son, pas d'historique de défilement, pas de mode sombre ; un seul niveau d'annulation.
- `neo_delay_1ms` est une boucle approximative (≈ 6 000 cycles, en supposant 6,25 MHz) : elle ne sert
  qu'aux pauses de l'affichage.

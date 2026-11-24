# Essai d'Ozmoo sur la carte Neo6502 (firmware Trinity)

Liste de vérifications pour le premier essai sur la carte (épopée E2). Rien de ce qui suit n'a encore
été fait sur la carte : tout n'a été vérifié que dans l'émulateur `neo`.

## Préparer la clé

```sh
tests/neo/paquet-cle.sh            # écrit build-neo/cle/OZMOO/
```

Copier le dossier `OZMOO/` à la racine de la clé USB. Il contient, pour chaque histoire, le programme
`<JEU>.NEO` et l'histoire `<JEU>.Z3` / `.Z5` (les deux doivent rester dans le même dossier) :

| Programme | Histoire | Ce qu'il vérifie |
|---|---|---|
| `MINIZORK` | minizork.z3 | jeu court, tout en mémoire |
| `ADVENT_P` | advent_punyinform.z5 (80 Ko) | plus grand que la RAM : lecture de la clé pendant la partie |
| `DRAGONTR` | dragontroll.z5 | jeu Z5 ordinaire |
| `ETUDE` | etude.z5 | écran, clavier, saisie chronométrée (menu de tests) |
| `CZECH` | czech.z5 | conformité de l'interpréteur (résultat attendu : 406 réussis, 0 échec) |
| `PRAXIX` | praxix.z5 | conformité (taper `all`, attendu : « 2 tests failed overall: multiundo (2). » : un seul niveau d'annulation, comme sur les autres machines) |

## Lancer

Depuis NeoDOS : `CD \OZMOO` puis taper le nom du programme (avec ou sans `.NEO`), par exemple
`MINIZORK`. L'histoire et les sauvegardes sont ouvertes par un nom relatif, donc dans le répertoire
courant : il faut se placer dans `OZMOO` avant de lancer.

## Vérifications

Noter pour chaque point : OK, KO (avec une photo de l'écran si possible) ou non fait.

1. **Démarrage** (`MINIZORK`) : écran d'accueil centré en 80 colonnes, puis le jeu ; ligne de statut
   en vidéo inverse en haut.
2. **Clavier** : lettres, chiffres, ponctuation, Entrée, retour arrière, flèches (historique des
   commandes avec haut/bas). Noter toute touche qui ne fait rien ou affiche un mauvais caractère.
3. **Défilement et `[MORE]`** : taper `look` plusieurs fois ; l'astérisque clignote en bas à droite
   quand l'écran est plein, une touche continue.
4. **Vitesse** : chronométrer quelques commandes (temps entre Entrée et l'invite suivante). Pour
   comparer avec l'émulateur.
5. **Sauvegarde** : `save`, emplacement `4` ; vérifier que `MINIZORK.SV4` apparaît sur la clé ; jouer
   un coup ; `restore`, emplacement `4` : retour à la position sauvée.
6. **Redémarrage** : `restart` puis `y` : le jeu repart du début.
7. **Sortie** : `quit` puis `y` : retour à l'invite de NeoDOS (non testé dans l'émulateur).
8. **Grosse histoire** (`ADVENT_P`) : se déplacer dans plusieurs lieux (`e`, `w`, `in`, `xyzzy`…) ;
   pas d'erreur de lecture, pas de blocage. Noter les pauses dues à la lecture de la clé.
9. **Saisie chronométrée** (`ETUDE`) : lancer le test de saisie chronométrée du menu ; les
   événements doivent arriver à peu près au bon rythme (horloge 5,37 à 60 Hz).
10. **Accents** : dans NeoDOS, `LOCALE fr` avant de lancer `MINIZORK` ; taper `é è ç à ù`, puis `^` `e`
    (doit donner ê) : les lettres s'affichent avec leur accent (le jeu répond qu'il ne connaît pas le mot).
11. **Annulation** (`ADVENT_P`) : `in`, puis `undo` : « Previous turn undone. » et retour devant le
    bâtiment (`look`).
12. **Conformité** (`CZECH`, puis `PRAXIX` avec `all`) : comparer avec les résultats attendus
    ci-dessus.

## En cas de problème

- Écran noir ou retour immédiat à NeoDOS : noter le message éventuel ; vérifier que l'histoire est
  bien à côté du `.NEO` et qu'on est dans le bon répertoire.
- « Error » suivi d'un numéro : noter le numéro (erreur fatale d'Ozmoo).
- Rapporter les résultats dans la feuille de route (épopée E2).

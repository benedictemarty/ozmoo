#!/usr/bin/env python3
"""textes.py — textes de l'essai essai-mode2 (rédigés pour l'essai), coupés en lignes, en source acme."""
import textwrap
DROITE = ("The road bends north through a quiet valley. Tall grass hides the old stones of a wall, and a "
          "thin stream runs beside the path. Far ahead, smoke rises from a village; behind you the hills "
          "are already turning grey. Your companions wait for your decision, as they always do.")
BAS = ("This is the eighty column test: each character cell is four pixels wide and eight pixels high, "
       "drawn by QuickDraw with a font reduced from the Clairsys typeface. The lines below the picture "
       "scroll by one text row whenever a new line is added: the video memory is copied upward by the "
       "blitter and the last row is erased. Read this text on the screenshot to judge whether eighty "
       "columns of four pixels are comfortable enough for a long game, compared with the forty column "
       "text on the right of the picture, which uses the full eight pixel font. Numbers 0123456789 and "
       "punctuation: (a, b; c: d!) [e] {f} \"g\" 'h' - i? j/k\\l @m #n $o %p &q *r +s =t <u> _v |w ~x. "
       "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG. the quick brown fox jumps over the lazy dog. "
       "Last line of the test: if you can read it, scrolling kept every line in order.")
def bloc(nom, texte, largeur):
    print(nom)
    for l in textwrap.wrap(texte, largeur):
        print('\t+ligne "%s"' % l.replace('\\', '\\\\').replace('"', '\\"'))
    print('\t!byte 0')
bloc('texte_droite', DROITE, 26)
BAS += ''.join(' Numbered line %02d, to make the region scroll past its thirteen rows.' % i for i in range(1, 9))
bloc('texte_bas', BAS, 80)

#!/usr/bin/env python3
"""mkfonts.py — polices NF1 (QuickDraw 32,15 de Trinity) pour l'essai du texte des jeux v6 en mode 2.

  mkfonts.py POLICE.fnt SORTIE8.nf1 SORTIE4.nf1 [--mode or|pair|impair]

POLICE.fnt : police d'Ozmoo (256 glyphes 8 x 8 dans l'ordre des codes écran de la C64, jeu minuscule).
SORTIE8 : glyphes 8 x 8 des caractères ASCII 32-126 (texte sur 40 colonnes).
SORTIE4 : les mêmes réduits à 4 x 8 (texte sur 80 colonnes) : OU de deux colonnes voisines, ou une colonne sur deux.
Auteur : bmarty <bmarty@mailo.com>
"""
import argparse

def ecran(c):
    """code écran C64 (jeu minuscule) d'un caractère ASCII"""
    if 32 <= c <= 63: return c
    if c == 64: return 0
    if 65 <= c <= 90: return c            # majuscules
    if 91 <= c <= 95: return c - 64       # [ £ ] ↑ ←
    if 97 <= c <= 122: return c - 96      # minuscules
    return 32

def reduit(octet, mode):
    r = 0
    for i in range(4):
        g, d = (octet >> (7 - 2 * i)) & 1, (octet >> (6 - 2 * i)) & 1
        b = {'or': g | d, 'pair': g, 'impair': d}[mode]
        r |= b << (7 - i)
    return r

def nf1(glyphes, largeur):
    out = bytearray(b'NF' + bytes([1, 8, 32, len(glyphes), 0, 1]))
    for g in glyphes:
        out += bytes([largeur]) + bytes(g)
    return bytes(out)

ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
ap.add_argument('police'); ap.add_argument('sortie8'); ap.add_argument('sortie4')
ap.add_argument('--mode', default='or', choices=['or', 'pair', 'impair'])
a = ap.parse_args()
f = open(a.police, 'rb').read()
g8 = [f[ecran(c) * 8: ecran(c) * 8 + 8] for c in range(32, 127)]
open(a.sortie8, 'wb').write(nf1(g8, 8))
open(a.sortie4, 'wb').write(nf1([bytes(reduit(o, a.mode) for o in g) for g in g8], 4))

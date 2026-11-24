#!/usr/bin/env python3
"""mkpic.py — écrit un fichier d'images au format graphique Infocom v6 (comme un .EG1 / .MG1 d'IBM :
en-tête de 16 octets, répertoire, données LZW de pix2gif), avec des images de test libres de droits.

Sert de jeu d'essai au décodeur infopic.py et au décodeur du firmware Trinity.

  mkpic.py SORTIE.EG1 [--mg1]      (--mg1 : entrées de 14 octets avec une palette par image)

L'encodeur suit exactement l'état du décodeur de pix2gif : codes de 9 à 12 bits, bits de poids faible
d'abord, code 256 = remise à zéro, 257 = fin ; le décodeur élargit les codes quand le prochain code
libre vaut 2^n - 1, juste après avoir lu un code et avant d'ajouter l'entrée correspondante.
Auteur : bmarty <bmarty@mailo.com>
"""
import argparse, struct, sys

CLEAR, FIN, TABLE = 256, 257, 4096

class Bits:
    def __init__(self):
        self.out = bytearray(); self.acc = 0; self.n = 0
    def put(self, code, width):
        self.acc |= code << self.n; self.n += width
        while self.n >= 8:
            self.out.append(self.acc & 0xff); self.acc >>= 8; self.n -= 8
    def fin(self):
        if self.n:
            self.out.append(self.acc & 0xff)
        return bytes(self.out)

def compresser(pixels):
    b = Bits()
    tlen, dec_next = 9, CLEAR + 2   # état du décodeur
    first = True                    # premier code après une remise à zéro : pas d'ajout
    def emit(code):
        nonlocal tlen, dec_next, first
        b.put(code, tlen)
        if code == CLEAR:
            tlen, dec_next, first = 9, CLEAR + 2, True
            return
        if dec_next == (1 << tlen) - 1 and tlen < 12:
            tlen += 1
        if first:
            first = False
        else:
            dec_next += 1
    def reset():
        return {bytes([i]): i for i in range(256)}, CLEAR + 2
    emit(CLEAR)
    dico, enc_next = reset()
    w = b''
    for p in pixels:
        wc = w + bytes([p])
        if wc in dico:
            w = wc
            continue
        emit(dico[w])
        dico[wc] = enc_next; enc_next += 1
        w = bytes([p])
        if enc_next >= TABLE - 2:     # le décodeur de pix2gif ne borne pas sa table
            emit(dico[w]); w = b''
            emit(CLEAR)
            dico, enc_next = reset()
    if w:
        emit(dico[w])
    emit(FIN)
    return b.fin()

def images_de_test():
    """(numéro, largeur, hauteur, drapeaux, pixels, palette ou None)"""
    imgs = []
    # 1 : dégradé des 16 couleurs, 64 x 32
    imgs.append((1, 64, 32, 0, bytes((x // 4) & 15 for y in range(32) for x in range(64)), None))
    # 2 : bandes avec couleur transparente 1 (drapeaux : bit 0 + index transparent en bits 12-15), 640 x 20
    imgs.append((2, 640, 20, 0x1001, bytes(1 if (x // 8 + y // 4) % 3 == 0 else (x * 7 + y) % 16
                                           for y in range(20) for x in range(640)), None))
    # 3 : entrée sans données (comme les images « Rect » des jeux), 100 x 50
    imgs.append((3, 100, 50, 0, b'', None))
    # 4 : grande image très répétitive (remplit la table LZW et force des remises à zéro), 320 x 200
    imgs.append((4, 320, 200, 0, bytes(((x ^ y) >> 3) & 15 for y in range(200) for x in range(320)), None))
    # 5 : bruit pseudo-aléatoire (peu compressible), 200 x 100, palette propre
    s = 12345; px = bytearray()
    for _ in range(200 * 100):
        s = (s * 1103515245 + 12345) & 0x7fffffff; px.append((s >> 16) % 14 + 2)
    imgs.append((5, 200, 100, 0, bytes(px), [(i * 17, 255 - i * 17, (i * 40) & 255) for i in range(14)]))
    return imgs

def ecrire(chemin, mg1=False):
    imgs = images_de_test()
    taille = 14 if mg1 else 12
    pos = 16 + taille * len(imgs)
    blocs, entrees = [], []
    for num, w, h, fl, px, pal in imgs:
        adr_pal = 0
        if mg1 and pal:
            adr_pal = pos
            bloc = bytes([len(pal)]) + b''.join(bytes(c) for c in pal)
            blocs.append(bloc); pos += len(bloc)
        adr = 0
        if px:
            adr = pos
            bloc = compresser(px)
            blocs.append(bloc); pos += len(bloc)
        e = struct.pack('<HHHH', num, w, h, fl) + adr.to_bytes(3, 'big')
        e += adr_pal.to_bytes(3, 'big') if mg1 else b'\0'
        entrees.append(e)
    entete = struct.pack('<BBHHHBBHHH', 1, 0, 0, len(imgs), 0, taille, 0, 0, 0, 0)
    open(chemin, 'wb').write(entete + b''.join(entrees) + b''.join(blocs))
    return imgs

if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('sortie'); ap.add_argument('--mg1', action='store_true')
    a = ap.parse_args()
    ecrire(a.sortie, a.mg1)

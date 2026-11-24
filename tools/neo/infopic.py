#!/usr/bin/env python3
"""infopic.py — décodeur de référence des fichiers d'images des jeux Infocom v6, version IBM
(*.EG1 EGA, *.MG1 VGA, *.CG1 CGA), pour la Neo6502.

Algorithme repris de pix2gif.c (ztools 7/3.1, Mark Howell, 1992-1998) : en-tête de 16 octets (mots
poids faible d'abord), répertoire d'entrées de 12 ou 14 octets (adresses sur 3 octets, poids fort
d'abord), LZW à codes de 9 à 12 bits (bits de poids faible d'abord, 256 = remise à zéro, 257 = fin),
palette facultative (nombre de couleurs, puis RVB, rangée à partir de l'index 2), couleur transparente
(drapeaux : bit 0, index dans les bits 12-15). Vérifié sur ZORK0.EG1 et ZORK0.CG1 (Zork Zero r393).

Fichiers Macintosh (PIC.DATA, CPIC.DATA) : seul le répertoire se lit (--mac, mots poids fort d'abord) ;
leurs données ne sont pas ce LZW et leur format n'est pas connu ici.

  infopic.py FICHIER --liste
  infopic.py FICHIER --png DOSSIER [--num N ...]
Auteur : bmarty <bmarty@mailo.com>
"""
import argparse, os, struct, sys

EGA = [(0,0,0),(0,0,170),(0,170,0),(0,170,170),(170,0,0),(170,0,170),(170,170,0),(170,170,170),
       (85,85,85),(85,85,255),(85,255,85),(85,255,255),(255,85,85),(255,85,255),(255,255,85),(255,255,255)]

class Image:
    pass

def lire(fichier, ibm=True):
    d = open(fichier, 'rb').read()
    w = (lambda o: d[o] | d[o+1] << 8) if ibm else (lambda o: d[o] << 8 | d[o+1])
    a3 = lambda o: d[o] << 16 | d[o+1] << 8 | d[o+2]
    ent = {'part': d[0], 'flags': d[1], 'images': w(4), 'dir_size': d[8], 'checksum': w(10), 'version': w(14)}
    imgs = []
    o = 16
    for _ in range(ent['images']):
        im = Image()
        im.num, im.larg, im.haut, im.flags = w(o), w(o+2), w(o+4), w(o+6)
        im.donnees = a3(o+8)
        im.palette_adr = a3(o+11) if ent['dir_size'] == 14 else 0
        o += ent['dir_size']
        imgs.append(im)
    return d, ent, imgs

def palette(d, im):
    pal = list(EGA)
    n = 16
    if im.palette_adr:
        c = min(d[im.palette_adr], 14)  # « Fix for some buggy Arthur pictures » (pix2gif)
        for i in range(c):
            pal[2 + i] = tuple(d[im.palette_adr + 1 + 3*i: im.palette_adr + 4 + 3*i])
        n = c + 2
    transp = (im.flags >> 12) if im.flags & 1 else None
    return pal, n, transp

def decompresser(d, im):
    """LZW de pix2gif : clear = 256, fin = 257, codes de 9 bits au départ, 12 au plus."""
    CODE_SIZE, TABLE = 8, 4096
    masque = [(1 << i) - 1 for i in range(16)]
    clear = 1 << CODE_SIZE
    prefixe = [TABLE] * TABLE
    pixel = list(range(TABLE))
    pos = im.donnees * 8          # position en bits
    tlen, suivant = CODE_SIZE + 1, clear + 2
    out = bytearray()
    total = im.larg * im.haut
    def code_lu():
        nonlocal pos, tlen
        c, t = 0, 0
        n = tlen
        while n:
            b = min(((pos + 8) & ~7) - pos, n)
            c |= ((d[pos >> 3] >> (pos & 7)) & masque[b]) << t
            n -= b; t += b; pos += b
        if suivant == masque[tlen] and tlen < 12:
            tlen += 1
        return c
    old = 0
    while True:
        code = code_lu()
        if code == clear + 1:
            break
        if code == clear:
            tlen, suivant = CODE_SIZE + 1, clear + 2
            code = code_lu()
        else:
            first = old if code == suivant else code
            while prefixe[first] != TABLE:
                first = prefixe[first]
            prefixe[suivant] = old
            pixel[suivant] = pixel[first]
            suivant += 1
        old = code
        tampon = []
        c = code
        while True:
            tampon.append(pixel[c])
            c = prefixe[c]
            if c == TABLE:
                break
        out.extend(reversed(tampon))
        if len(out) >= total:
            break
    return bytes(out[:total])

def vers_png(d, im, chemin):
    from PIL import Image as PImage
    px = decompresser(d, im)
    pal, n, transp = palette(d, im)
    img = PImage.frombytes('P', (im.larg, im.haut), px.ljust(im.larg * im.haut, b'\0'))
    flat = []
    for c in pal:
        flat.extend(c)
    img.putpalette(flat + [0] * (768 - len(flat)))
    if transp is not None:
        img.info['transparency'] = transp
    img.save(chemin)
    return max(px) if px else 0

def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('fichier')
    ap.add_argument('--mac', action='store_true', help="répertoire d'un fichier Mac (mots poids fort d'abord) ; données non décodables")
    ap.add_argument('--liste', action='store_true')
    ap.add_argument('--png')
    ap.add_argument('--num', type=int, nargs='*')
    a = ap.parse_args()
    d, ent, imgs = lire(a.fichier, not a.mac)
    if a.liste:
        print(ent)
        for im in imgs:
            pal, n, t = palette(d, im)
            print(f"image {im.num:3d} {im.larg:3d} x {im.haut:3d} drapeaux {im.flags:04x} données ${im.donnees:05x} "
                  f"palette ${im.palette_adr:05x} couleurs {n} transparent {t}")
    if a.png:
        os.makedirs(a.png, exist_ok=True)
        for im in imgs:
            if a.num and im.num not in a.num or im.donnees == 0:
                continue
            m = vers_png(d, im, os.path.join(a.png, f'pic{im.num:03d}.png'))
            print(f'image {im.num}: {im.larg}x{im.haut}, index max {m}')

if __name__ == '__main__':
    main()

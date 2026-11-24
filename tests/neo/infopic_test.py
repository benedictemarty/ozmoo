#!/usr/bin/env python3
"""infopic_test.py — test du décodeur d'images Infocom (tools/neo/infopic.py).

1. Aller-retour : mkpic.py écrit un fichier d'images de test (format .EG1 puis .MG1, libre de droits),
   infopic.py le relit ; les pixels, tailles, drapeaux et palettes doivent être identiques.
2. Si les images IBM de Zork Zero sont présentes (../infocom-masterpieces/ibm/zorkzero/ZORK0.EG1,
   gardées hors du dépôt) : les 396 images avec données se décodent entièrement, et l'image 1
   (écran titre 640 x 200) a l'empreinte attendue.
Auteur : bmarty <bmarty@mailo.com>
"""
import hashlib, os, sys, tempfile
ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ICI, '..', '..', 'tools', 'neo'))
import infopic, mkpic

# Empreinte des pixels de l'image 1 de ZORK0.EG1 (écran titre), relevée le 2026-11-24 après
# vérification visuelle du PNG produit.
EMPREINTE_PIC1 = '7d82963d786ac6e6'

def aller_retour(mg1):
    with tempfile.TemporaryDirectory() as t:
        f = os.path.join(t, 'TEST.MG1' if mg1 else 'TEST.EG1')
        ref = mkpic.ecrire(f, mg1)
        d, ent, imgs = infopic.lire(f, ibm=True)
        assert ent['images'] == len(ref), 'nombre d\'images'
        for (num, w, h, fl, px, pal), im in zip(ref, imgs):
            assert (im.num, im.larg, im.haut, im.flags) == (num, w, h, fl), f'entrée {num}'
            if not px:
                assert im.donnees == 0, f'image {num} : données inattendues'
                continue
            assert infopic.decompresser(d, im) == px, f'image {num} : pixels différents'
            p, n, transp = infopic.palette(d, im)
            if mg1 and pal:
                assert p[2:2 + len(pal)] == pal and n == len(pal) + 2, f'image {num} : palette'
            if fl & 1:
                assert transp == fl >> 12, f'image {num} : transparence'
    return len(ref)

n = aller_retour(False) + aller_retour(True)
print(f'OK : aller-retour mkpic/infopic ({n} entrées, formats EG1 et MG1)')

zz = os.path.join(ICI, '..', '..', '..', 'infocom-masterpieces', 'ibm', 'zorkzero', 'ZORK0.EG1')
if os.path.exists(zz):
    d, ent, imgs = infopic.lire(zz, ibm=True)
    completes = sum(1 for im in imgs if im.donnees and len(infopic.decompresser(d, im)) == im.larg * im.haut)
    assert completes == 396, f'Zork Zero : {completes} images complètes au lieu de 396'
    un = next(im for im in imgs if im.num == 1)
    h = hashlib.sha256(infopic.decompresser(d, un)).hexdigest()[:16]
    assert h == EMPREINTE_PIC1, f'Zork Zero image 1 : empreinte {h}'
    print('OK : Zork Zero EG1, 396 images complètes, image 1 conforme')
else:
    print('SAUTÉ : images de Zork Zero absentes')

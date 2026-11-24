; essai-mode2.asm — prototype : écran des jeux v6 en mode graphique 2 (320 x 240, 16 couleurs) de Trinity.
;
; Une image Infocom dessinée par le firmware (41,2, fichier PIC.MG1 ouvert sur le canal 1), du texte de 40
; colonnes (police 8 x 8) à droite de l'image et du texte de 80 colonnes (police 4 x 8) en dessous, écrit par
; QuickDraw (32,9 Erase Rect puis 32,16 Draw String). La zone du bas défile d'une rangée de texte par ligne
; ajoutée, en recopiant la mémoire vidéo par le blitter (12,3) puis en effaçant la dernière rangée.
; Durées (compteur d'images 5,37) en $0F10 : avant l'image, après l'image, après le texte de droite, après
; le texte du bas, après 50 fois « défilement + ligne de 80 caractères » (mot de 16 bits chacun).
; Rien de cela n'est dans Ozmoo : c'est un essai pour juger la lisibilité et vérifier les fonctions.
; Auteur : bmarty <bmarty@mailo.com>

	* = $1000

API_CMD   = $ff00
API_FUNC  = $ff01
API_ERR   = $ff02
P         = $ff04
zp        = $80          ; pointeur de chaîne
CH_PIC    = 1
RESULT    = $0f00        ; erreurs relevées, lues dans memory.dump

; appel : A = fonction, X = groupe ; A = erreur au retour, cumulée dans RESULT+n (n = Y)
call
	sta API_FUNC
	stx API_CMD
-	lda API_CMD
	bne -
	lda API_ERR
	beq +
	sta RESULT, y
+	rts

start
	ldx #0
	txa
-	sta RESULT, x
	inx
	bne -
	lda #2                ; 5,9 : mode 2
	sta P
	ldy #0
	lda #9
	ldx #5
	jsr call
	lda #1                ; 32,1 Init Graf
	ldy #1
	ldx #32
	jsr call
	; 3,4 : ouvre PIC.MG1
	lda #CH_PIC
	sta P
	lda #<nom_pic
	sta P+1
	lda #>nom_pic
	sta P+2
	lda #0
	sta P+3
	lda #4
	ldx #3
	ldy #2
	jsr call
	ldx #0
	jsr top               ; t0 : avant l'image
	; 41,2 : image 1 en (0,0), palette de l'image dans les entrées 2..n+1
	lda #CH_PIC
	sta P
	lda #1
	sta P+1
	lda #0
	sta P+2
	sta P+3
	sta P+4
	sta P+5
	sta P+6
	lda #4
	sta P+7
	lda #2
	ldx #41
	ldy #3
	jsr call
	ldx #2
	jsr top               ; t1 : après l'image
	; texte de 40 colonnes à droite de l'image
	lda #<police8
	ldx #>police8
	jsr set_font
	lda #<texte_droite
	sta zp
	lda #>texte_droite
	sta zp+1
	lda #0
	sta ligne
-	lda ligne
	asl
	asl
	asl
	sta py
	lda #112
	sta px
	lda #0
	sta px+1
	lda #8
	sta cell_w
	jsr draw_line
	inc ligne
	ldy #0
	lda (zp), y
	bne -
	ldx #4
	jsr top               ; t2 : après le texte de droite
	; texte de 80 colonnes en dessous, qui défile
	lda #<police4
	ldx #>police4
	jsr set_font
	lda #<texte_bas
	sta zp
	lda #>texte_bas
	sta zp+1
	lda #0
	sta ligne
-	lda ligne
	cmp #13
	bcc +
	jsr scroll_bas
	lda #12
+	asl
	asl
	asl
	clc
	adc #136
	sta py
	lda #0
	sta px
	sta px+1
	lda #4
	sta cell_w
	jsr draw_line
	inc ligne
	ldy #0
	lda (zp), y
	bne -
	ldx #6
	jsr top               ; t3 : après le texte du bas
	; banc : 50 fois (défilement de la zone du bas + ligne de 80 caractères)
	lda #50
	sta banc
-	jsr scroll_bas
	lda #<ligne_banc
	sta zp
	lda #>ligne_banc
	sta zp+1
	lda #232
	sta py
	lda #0
	sta px
	sta px+1
	jsr draw_line
	dec banc
	bne -
	ldx #8
	jsr top               ; t4 : après le banc
	; repère : fin
	lda #$aa
	sta RESULT + $ff
fin	jmp fin

; relève le compteur d'images (5,37, 60 Hz) en RESULT+$10+X (deux octets bas)
top
	stx tmp
	lda #37
	ldx #5
	ldy #11
	jsr call
	ldx tmp
	lda P
	sta RESULT + $10, x
	lda P+1
	sta RESULT + $11, x
	rts

; A/X : adresse de la police NF1 en RAM du 6502
set_font
	sta P+1
	stx P+2
	lda #0
	sta P
	lda #15
	ldx #32
	ldy #4
	jmp call

; efface la cellule de la ligne (papier 0) puis écrit la chaîne (zp) en encre 1 à (px, py) ; zp avance
draw_line
	ldy #0
	lda (zp), y           ; longueur
	sta len
	; rectangle : px .. px + len * cell_w, py .. py + 8
	lda px
	sta rect
	lda px+1
	sta rect+1
	lda py
	sta rect+2
	clc
	adc #8
	sta rect+6
	lda #0
	sta rect+3
	sta rect+7
	; largeur = len * cell_w (cell_w = 4 ou 8)
	lda len
	sta tmp
	lda #0
	sta tmp+1
	lda cell_w
	lsr
-	lsr
	beq +
	asl tmp
	rol tmp+1
	jmp -
+	asl tmp
	rol tmp+1
	asl tmp
	rol tmp+1
	clc
	lda px
	adc tmp
	sta rect+4
	lda px+1
	adc tmp+1
	sta rect+5
	lda #<rect
	sta P
	lda #>rect
	sta P+1
	lda #0
	sta P+2
	lda #9                ; 32,9 Erase Rect
	ldx #32
	ldy #5
	jsr call
	lda #1                ; 32,4 couleur du crayon
	sta P
	lda #4
	ldx #32
	ldy #6
	jsr call
	lda px                ; 32,5 Move To
	sta P
	lda px+1
	sta P+1
	lda py
	sta P+2
	lda #0
	sta P+3
	lda #5
	ldx #32
	ldy #7
	jsr call
	lda zp                ; 32,16 Draw String
	sta P
	lda zp+1
	sta P+1
	lda #16
	ldx #32
	ldy #8
	jsr call
	sec                   ; zp += len + 1
	lda zp
	adc len
	sta zp
	bcc +
	inc zp+1
+	rts

; défile la zone du bas (lignes 136-239, toute la largeur) d'une rangée de 8 lignes vers le haut
scroll_bas
	lda #0
	sta P
	lda #<blit_src
	sta P+1
	lda #>blit_src
	sta P+2
	lda #<blit_dst
	sta P+3
	lda #>blit_dst
	sta P+4
	lda #3
	ldx #12
	ldy #9
	jsr call
	lda #0
	sta rect
	sta rect+1
	sta rect+3
	sta rect+7
	lda #232
	sta rect+2
	lda #240
	sta rect+6
	lda #<320
	sta rect+4
	lda #>320
	sta rect+5
	lda #<rect
	sta P
	lda #>rect
	sta P+1
	lda #0
	sta P+2
	lda #9
	ldx #32
	ldy #10
	jmp call

blit_src
	!word 144 * 160
	!byte $80, 0
	!word 160
	!byte 0, 0, 0, 96
	!word 160
blit_dst
	!word 136 * 160
	!byte $80, 0
	!word 160
	!byte 0, 0, 0, 0
	!word 0

px      !word 0
py      !byte 0
len     !byte 0
cell_w  !byte 0
ligne   !byte 0
banc    !byte 0
tmp     !word 0
rect    !fill 8, 0

nom_pic !byte 7
	!text "PIC.MG1"

!macro ligne .s {
	!byte .l
.d	!text .s
.l = * - .d
}
!source "textes.asm"
ligne_banc
	+ligne "Benchmark line: eighty characters drawn after each scroll of the bottom region.."

police8 !binary "police8.nf1"
police4 !binary "police4.nf1"

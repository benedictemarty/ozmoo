; neo.asm — couche Neo6502 / firmware Trinity (TARGET_NEO)
;
; Tout ce qui parle au firmware passe par ici : l'appel de l'API, le clavier (2,1),
; le temps (5,37, trames à 60 Hz), le fichier de l'histoire (3,4 / 3,6 / 3,8), l'écran
; du mode texte 3 (5,9, 5,13, 5,14, 5,15) et la sortie (1,0 puis 1,3).
;
; Canaux de fichiers : 0 est pris par le chargeur du firmware (3,2), l'histoire est
; ouverte sur le canal 1 pendant toute la partie.

!zone neo {

NEO_STORY_CHANNEL = 1

; --- Registres du VIC simulés : le code commun y écrit la couleur de fond et de bord ---
neo_reg_background	!byte 0
neo_reg_border		!byte 0

neo_tmp_y			!byte 0
neo_tmp_rev			!byte 0
neo_tmp_ink			!byte 0
neo_tmp_paper		!byte 0
neo_save_x			!byte 0
neo_save_y			!byte 0
!ifdef NEO_TEST {
neo_test_reads		!byte 0, 0 ; appels de neo_readblocks (un bloc de 512 octets chacun en jeu)
}

; ---------------------------------------------------------------------------------
; neo_api_call : A = fonction, X = groupe ; les paramètres sont déjà en $FF04...
; Attend la fin de la commande. Retour : A = code d'erreur ($FF02), Z = 1 si aucune.
; ---------------------------------------------------------------------------------
neo_api_call
	sta neo_api_function
	stx neo_api_command
-	lda neo_api_command
	bne -
	lda neo_api_error
	rts

; ---------------------------------------------------------------------------------
; Clavier : 2,1 rend le code ASCII de la file (0 si vide). Ozmoo travaille en PETSCII :
; on convertit comme le ferait le KERNAL de la C64. X et Y sont préservés.
; ---------------------------------------------------------------------------------
neo_getchar
	stx neo_save_x
	sty neo_save_y
	lda #1
	ldx #2
	jsr neo_api_call
	lda neo_api_param
	beq .gc_done
	ldx neo_dead_key
	bne .gc_compose
	cmp #'^'
	beq .gc_dead
	cmp #$a8 ; tréma
	beq .gc_dead
.gc_plain
	tax
	bmi .gc_high
	lda neo_ascii_to_petscii,x
.gc_done
	ldx neo_save_x
	ldy neo_save_y
	cmp #0
	rts
.gc_high
	; Latin-1 (locale du clavier, 1,6) : code interne de chars-neo.asm, 0 si sans équivalent
	cpx #$a0
	bcc .gc_none
	lda neo_latin1_to_internal - $a0,x
	jmp .gc_done
.gc_dead
	; ^ et ¨ sont des touches mortes : la touche suivante est composée
	sta neo_dead_key
.gc_none
	lda #0
	beq .gc_done ; toujours
.gc_compose
	; A = touche, X = touche morte en attente
	ldy #0
	sty neo_dead_key
	cmp #$20
	bne .gc_letter
	cpx #'^' ; ^ puis espace : ^ ; ¨ puis espace : rien (pas de ¨ en ZSCII)
	bne .gc_none
	txa
	jmp .gc_plain
.gc_letter
	sta neo_tmp_key
	ora #$20 ; minuscule (les majuscules composées donnent la minuscule)
	ldy #5
-	cmp neo_dead_vowels,y
	beq .gc_vowel
	dey
	bpl -
.gc_uncomposed
	lda neo_tmp_key ; pas une voyelle : la touche morte est perdue
	jmp .gc_plain
.gc_vowel
	cpx #'^'
	bne +
	lda neo_dead_circumflex,y
	jmp ++
+	lda neo_dead_diaeresis,y
++	beq .gc_uncomposed ; pas de ŷ
	jmp .gc_done

neo_dead_key		!byte 0
neo_tmp_key			!byte 0
neo_dead_vowels		!byte 'a', 'e', 'i', 'o', 'u', 'y'
neo_dead_circumflex	!byte NEO_ACIR_L, NEO_ECIR_L, NEO_ICIR_L, NEO_OCIR_L, NEO_UCIR_L, 0
neo_dead_diaeresis	!byte NEO_AUML_L, NEO_EUML_L, NEO_IUML_L, NEO_OUML_L, NEO_UUML_L, NEO_YUML_L

; ---------------------------------------------------------------------------------
; Temps : le compteur de trames (5,37) avance à 60 Hz, la cadence des « jiffies »
; que le code commun attend. Retour : A = octet bas, X = milieu, Y = haut.
; ---------------------------------------------------------------------------------
neo_readtime
	lda #37
	ldx #5
	jsr neo_api_call
	lda neo_api_param
	ldx neo_api_param + 1
	ldy neo_api_param + 2
	rts

; Attend une touche (rend son code PETSCII)
neo_wait_key
-	jsr neo_getchar
	beq -
	rts

neo_settime
	; Le compteur de trames ne se règle pas ; seul l'aléa s'en servait sur la C64.
	rts

; Attente d'environ 1 ms. Le 65C02 de la Neo tourne à environ 6,25 MHz : ~6 000 cycles.
; (approximatif : sert seulement aux pauses de l'affichage)
neo_delay_1ms
	pha
	txa
	pha
	ldx #0
-	nop
	nop
	nop
	nop
	nop
	dex
	bne -
	ldx #200
-	nop
	nop
	dex
	bne -
	pla
	tax
	pla
	rts

; Attend la trame suivante (1/60 s).
neo_wait_frame
	pha
	txa
	pha
	tya
	pha
	jsr neo_readtime
	sta neo_tmp_y
-	jsr neo_readtime
	cmp neo_tmp_y
	beq -
	pla
	tay
	pla
	tax
	pla
	rts

; ---------------------------------------------------------------------------------
; Sortie du programme : remet le firmware dans son état de départ (1,0) puis recharge
; l'environnement résident (1,3, NeoDOS sur Trinity) et le lance par jmp ($0000).
; ---------------------------------------------------------------------------------
neo_reset
!ifdef NEO_TEST {
	jsr neo_test_dump_screen
	jmp $ffff ; l'émulateur neo s'arrête et écrit memory.dump
}
	lda #$ff
	sta neo_api_param
	lda #5
	ldx #3
	jsr neo_api_call ; 3,5 : ferme tous les fichiers
	lda #0
	ldx #1
	jsr neo_api_call ; 1,0 : remise à zéro de l'API (mode 0, console...)
	lda #3
	ldx #1
	jsr neo_api_call ; 1,3 : charge NeoDOS
	jmp ($0000)

!ifdef NEO_TEST {
; Copie la grille du mode 3 ($80:0000, 2 000 codes) en RAM, pour que le test la lise
; dans memory.dump (12,2 Simple Blit Copy).
NEO_TEST_DUMP = $f000 ; dans la mémoire virtuelle (on ne revient pas), loin du code qui copie
neo_test_dump_screen
	; nombre de blocs de 512 octets lus dans l'histoire, après la grille (NEO_TEST_DUMP + 2000)
	lda neo_test_reads
	sta NEO_TEST_DUMP + 2000
	lda neo_test_reads + 1
	sta NEO_TEST_DUMP + 2001
	lda #$80
	sta neo_api_param
	lda #0
	sta neo_api_param + 1
	sta neo_api_param + 2
	sta neo_api_param + 3
	lda #<NEO_TEST_DUMP
	sta neo_api_param + 4
	lda #>NEO_TEST_DUMP
	sta neo_api_param + 5
	lda #<2000
	sta neo_api_param + 6
	lda #>2000
	sta neo_api_param + 7
	lda #2
	ldx #12
	jmp neo_api_call
}

; ---------------------------------------------------------------------------------
; Initialisation : mode texte 3 (80 x 25), curseur de la console caché, ouverture du
; fichier de l'histoire. Appelée une fois, au début de deletable_init_start.
; ---------------------------------------------------------------------------------
neo_init
!ifdef NEO_LOCALE_1 {
	; -neokbd:xx : locale du clavier (1,6), avant le changement de mode qui efface l'écran
	lda #NEO_LOCALE_1
	sta neo_api_param
	lda #NEO_LOCALE_2
	sta neo_api_param + 1
	lda #6
	ldx #1
	jsr neo_api_call
}
	lda #3
	sta neo_api_param
	lda #9
	ldx #5
	jsr neo_api_call ; 5,9 : mode 3
	beq +
	lda #<.msg_no_mode3
	ldy #>.msg_no_mode3
	jmp neo_fatal_message
+
	lda #0
	sta neo_api_param
	lda #19
	ldx #2
	jsr neo_api_call ; 2,19 : curseur de la console invisible
!ifdef NEO_TEST {
	lda #1
	sta neo_api_param
	lda #20
	ldx #2
	jsr neo_api_call ; 2,20 : écho de la console vers le port de debug (stderr)
}
	; Ouvre l'histoire en lecture sur le canal 1
	lda #NEO_STORY_CHANNEL
	sta neo_api_param
	lda #<neo_story_filename
	sta neo_api_param + 1
	lda #>neo_story_filename
	sta neo_api_param + 2
	lda #0 ; lecture seule
	sta neo_api_param + 3
	lda #4
	ldx #3
	jsr neo_api_call ; 3,4 : ouverture
	beq +
	lda #<.msg_no_story
	ldy #>.msg_no_story
	jmp neo_fatal_message
+	rts

; Écrit un message (ASCII, terminé par 0) en haut de l'écran par la console, attend une
; touche et sort. Sert avant que l'écran d'Ozmoo existe.
neo_fatal_message
	sta neo_zp_ptr
	sty neo_zp_ptr + 1
	ldy #0
-	lda (neo_zp_ptr),y
	beq +
	sta neo_api_param
	tya
	pha
	lda #6
	ldx #2
	jsr neo_api_call ; 2,6 : écrit un caractère sur la console
	pla
	tay
	iny
	bne -
+
-	jsr neo_getchar
	beq -
	jmp neo_reset

.msg_no_mode3
	!text 13, "Ozmoo: this firmware has no text mode 3 (Trinity 0.16.89 or later is needed).", 13, 0
.msg_no_story
	!text 13, "Ozmoo: cannot open the story file ", 0

; ---------------------------------------------------------------------------------
; Lecture de pages de l'histoire : readblocks_numblocks pages de 256 octets à partir
; de la page readblocks_currentblock, vers readblocks_mempos. Le fichier sur la clé
; est l'histoire telle quelle : la page n est à l'octet n * 256.
; ---------------------------------------------------------------------------------
neo_readblocks
!ifdef NEO_TEST {
	inc neo_test_reads
	bne +
	inc neo_test_reads + 1
+
}
	lda #NEO_STORY_CHANNEL
	sta neo_api_param
	lda #0
	sta neo_api_param + 1
	lda readblocks_currentblock
	sta neo_api_param + 2
	lda readblocks_currentblock + 1
	sta neo_api_param + 3
	lda #0
	sta neo_api_param + 4
	lda #6
	ldx #3
	jsr neo_api_call ; 3,6 : se placer
	bne .rb_error
	lda #NEO_STORY_CHANNEL
	sta neo_api_param
	lda readblocks_mempos
	sta neo_api_param + 1
	lda readblocks_mempos + 1
	sta neo_api_param + 2
	lda #0
	sta neo_api_param + 3
	lda readblocks_numblocks
	sta neo_api_param + 4
	lda #8
	ldx #3
	jsr neo_api_call ; 3,8 : lire
	bne .rb_error
	; Avance comme le faisait la boucle de readblocks
	lda readblocks_numblocks
	clc
	adc readblocks_mempos + 1
	sta readblocks_mempos + 1
	lda readblocks_numblocks
	clc
	adc readblocks_currentblock
	sta readblocks_currentblock
	bcc +
	inc readblocks_currentblock + 1
+	lda #0
	sta readblocks_numblocks
	rts
.rb_error
	lda #ERROR_FLOPPY_READ_ERROR
	jmp fatalerror

; Une seule page (équivalent du readblock de la C64, qui ne fait pas avancer les
; compteurs) : seul le chemin des blocs « sous la ROM » l'appelle, jamais pris sur la Neo.
readblock
	lda readblocks_mempos + 1
	pha
	lda readblocks_currentblock
	pha
	lda readblocks_currentblock + 1
	pha
	lda #1
	sta readblocks_numblocks
	jsr neo_readblocks
	pla
	sta readblocks_currentblock + 1
	pla
	sta readblocks_currentblock
	pla
	sta readblocks_mempos + 1
neo_rts
	rts

; ---------------------------------------------------------------------------------
; Écran : mode texte 3. Une cellule a un code CP437 et un attribut (papier << 4 | encre,
; entrées 0-15 de la palette, couleurs CGA). Ozmoo garde ses couleurs en numéros de la
; C64 : on les traduit au moment d'écrire.
; ---------------------------------------------------------------------------------

; Attribut courant. Entrée : X = $80 pour la vidéo inverse, sinon 0. Y préservé.
neo_make_attr
	stx neo_tmp_rev
	lda s_colour
	and #$0f
	tax
	lda neo_c64_to_cga,x
	sta neo_tmp_ink
	lda neo_reg_background
	and #$0f
	tax
	lda neo_c64_to_cga,x
	sta neo_tmp_paper
	bit neo_tmp_rev
	bmi +
	asl
	asl
	asl
	asl
	ora neo_tmp_ink
	rts
+	lda neo_tmp_ink
	asl
	asl
	asl
	asl
	ora neo_tmp_paper
	rts

; Attribut du fond seul (pour effacer)
neo_bg_attr
	ldx #0
	jsr neo_make_attr
	rts

; Écrit un caractère. Entrée : A = code PETSCII, Y = colonne, X = $80 si inverse,
; ligne = zp_screenline + 1. Y préservé.
neo_print_petscii
	stx neo_tmp_rev
	tax
	lda neo_petscii_to_cp437,x
	ldx neo_tmp_rev
; Même chose avec A = code CP437.
neo_print_cp437
	cpy #SCREEN_WIDTH
	bcs .pc_done
	sta neo_text_buffer + 1
	lda #1
	sta neo_text_buffer
	sty neo_tmp_y
	jsr neo_make_attr
	sta neo_api_param + 2
	lda neo_tmp_y
	sta neo_api_param
	lda zp_screenline + 1
	sta neo_api_param + 1
	lda #<neo_text_buffer
	sta neo_api_param + 3
	lda #>neo_text_buffer
	sta neo_api_param + 4
	lda #13
	ldx #5
	jsr neo_api_call ; 5,13 : Text Write
	ldy neo_tmp_y
.pc_done
	rts

; Écrit print_buffer[Y .. last_break_char_buffer_pos - 1] à partir de la colonne Y de la
; ligne zp_screenline + 1, par tronçons de même vidéo inverse (print_buffer2).
neo_print_buffer_line
.pbl_next_run
	cpy last_break_char_buffer_pos
	bcs .pbl_done
	sty neo_tmp_y ; colonne de départ du tronçon
	lda print_buffer2,y
	sta neo_tmp_rev
	ldx #0
-	lda print_buffer,y
	sty neo_save_y
	tay
	lda neo_petscii_to_cp437,y
	ldy neo_save_y
	sta neo_text_buffer + 1,x
	inx
	iny
	cpy last_break_char_buffer_pos
	bcs +
	lda print_buffer2,y
	cmp neo_tmp_rev
	beq -
+	stx neo_text_buffer
	sty neo_save_y ; début du tronçon suivant
	ldx neo_tmp_rev
	jsr neo_make_attr
	sta neo_api_param + 2
	lda neo_tmp_y
	sta neo_api_param
	lda zp_screenline + 1
	sta neo_api_param + 1
	lda #<neo_text_buffer
	sta neo_api_param + 3
	lda #>neo_text_buffer
	sta neo_api_param + 4
	lda #13
	ldx #5
	jsr neo_api_call ; 5,13 : Text Write (coupé en fin de ligne par le firmware)
	ldy neo_save_y
	jmp .pbl_next_run
.pbl_done
	rts

; Efface la ligne zp_screenline + 1 de la colonne Y à la fin, au fond courant.
neo_erase_to_eol
	cpy #SCREEN_WIDTH
	bcs +
	sty neo_api_param
	lda zp_screenline + 1
	sta neo_api_param + 1
	sta neo_api_param + 3
	lda #SCREEN_WIDTH - 1
	sta neo_api_param + 2
	jsr neo_bg_attr
	sta neo_api_param + 4
	lda #15
	ldx #5
	jsr neo_api_call ; 5,15 : Text Clear
+	rts

; Fait monter d'une ligne les lignes A (haut) à X (bas, incluse), la ligne libérée
; prend le fond courant.
neo_scroll_up
	sta neo_api_param
	stx neo_api_param + 1
	lda #1
	sta neo_api_param + 2
	jsr neo_bg_attr
	sta neo_api_param + 3
	lda #14
	ldx #5
	jmp neo_api_call ; 5,14 : Text Scroll

; Curseur d'Ozmoo : un pavé (219) à la couleur du curseur, ou un espace quand le
; curseur clignotant est éteint. Y = colonne.
neo_draw_cursor
	lda s_colour
	pha
	lda current_cursor_colour
	sta s_colour
	lda cursor_character
	cmp #$20
	beq +
	lda #219
+	ldx #0
	jsr neo_print_cp437
	pla
	sta s_colour
	rts

; Invite [MORE] : un « * » en inverse dans le coin bas droit.
neo_show_more
	sty neo_save_y
	lda zp_screenline + 1
	pha
	lda s_screen_height_minus_one
	sta zp_screenline + 1
	ldy s_screen_width_minus_one
	lda #'*'
	ldx #$80
	jsr neo_print_cp437
	jmp +
neo_hide_more
	sty neo_save_y
	lda zp_screenline + 1
	pha
	lda s_screen_height_minus_one
	sta zp_screenline + 1
	ldy s_screen_width_minus_one
	lda #' '
	ldx #0
	jsr neo_print_cp437
+	pla
	sta zp_screenline + 1
	ldy neo_save_y
	rts

; ---------------------------------------------------------------------------------
; Tables
; ---------------------------------------------------------------------------------

; Couleurs de la C64 (numéros 0-15) vers les couleurs CGA du mode 3 (palette 0-15)
neo_c64_to_cga
	;     noir blanc rouge cyan violet vert bleu jaune
	!byte 0,   15,   4,    3,   5,     2,   1,   14
	;     orange brun rouge_cl gris_f gris vert_cl bleu_cl gris_cl
	!byte 6,     6,   12,      8,     7,   10,     9,      7

; Clavier de la Neo (ASCII, codes de la console) vers PETSCII
neo_ascii_to_petscii
	;     0    1(g) 2    3    4(d) 5    6    7    8(ret.arr.) 9  10   11   12   13   14   15
	!byte 0,   $9d, 0,   0,   $1d, 0,   0,   0,   $14, 0,   0,   11,  0,   13,  0,   0
	;     16   17   18   19(b) 20  21   22   23(h) 24  25   26(suppr) 27  28   29   30   31
	!byte 0,   0,   0,   $11, 0,   21,  0,   $91, 0,   0,   $14, 0,   0,   0,   0,   0
	; $20-$3f : identiques
	!byte $20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2a,$2b,$2c,$2d,$2e,$2f
	!byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3a,$3b,$3c,$3d,$3e,$3f
	; $40 @, $41-$5a majuscules -> $c1-$da, [ \ ] ^ _
	!byte $40,$c1,$c2,$c3,$c4,$c5,$c6,$c7,$c8,$c9,$ca,$cb,$cc,$cd,$ce,$cf
	!byte $d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$d8,$d9,$da,$5b,$bf,$5d,$5e,$af
	; ` puis minuscules -> $41-$5a, { | } ~ DEL
	!byte $a9,$41,$42,$43,$44,$45,$46,$47,$48,$49,$4a,$4b,$4c,$4d,$4e,$4f
	!byte $50,$51,$52,$53,$54,$55,$56,$57,$58,$59,$5a,$a6,$dd,$a7,$a8,0

; Clavier de la Neo, Latin-1 $A0-$FF (locales de Trinity) vers code interne (chars-neo.asm).
; Les majuscules accentuées sans glyphe CP437 donnent la minuscule (le dictionnaire est en minuscules).
neo_latin1_to_internal
	; $a0 espace insécable, ¡ ¢ £ ¤ ¥ ¦ § ¨ © ª « ¬ shy ® ¯
	!byte $20, NEO_IEXCL, 0, $5c, 0, 0, 0, 0, 0, 0, 0, NEO_LAQUO, 0, 0, 0, 0
	; $b0 ° ± ² ³ ´ µ ¶ · ¸ ¹ º » ¼ ½ ¾ ¿
	!byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, NEO_RAQUO, 0, 0, 0, NEO_IQUES
	; $c0 À Á Â Ã Ä Å Æ Ç È É Ê Ë Ì Í Î Ï
	!byte NEO_AGRV_L, NEO_AACU_L, NEO_ACIR_L, 0, NEO_AUML_U, NEO_ARNG_U, NEO_AELI_U, NEO_CCED_U
	!byte NEO_EGRV_L, NEO_EACU_U, NEO_ECIR_L, NEO_EUML_L, NEO_IGRV_L, NEO_IACU_L, NEO_ICIR_L, NEO_IUML_L
	; $d0 Ð Ñ Ò Ó Ô Õ Ö × Ø Ù Ú Û Ü Ý Þ ß
	!byte 0, NEO_NTIL_U, NEO_OGRV_L, NEO_OACU_L, NEO_OCIR_L, 0, NEO_OUML_U, 0
	!byte 0, NEO_UGRV_L, NEO_UACU_L, NEO_UCIR_L, NEO_UUML_U, 0, 0, NEO_SZLIG
	; $e0 à á â ã ä å æ ç è é ê ë ì í î ï
	!byte NEO_AGRV_L, NEO_AACU_L, NEO_ACIR_L, 0, NEO_AUML_L, NEO_ARNG_L, NEO_AELI_L, NEO_CCED_L
	!byte NEO_EGRV_L, NEO_EACU_L, NEO_ECIR_L, NEO_EUML_L, NEO_IGRV_L, NEO_IACU_L, NEO_ICIR_L, NEO_IUML_L
	; $f0 ð ñ ò ó ô õ ö ÷ ø ù ú û ü ý þ ÿ
	!byte 0, NEO_NTIL_L, NEO_OGRV_L, NEO_OACU_L, NEO_OCIR_L, 0, NEO_OUML_L, 0
	!byte 0, NEO_UGRV_L, NEO_UACU_L, NEO_UCIR_L, NEO_UUML_L, 0, 0, NEO_YUML_L

; PETSCII (jeu minuscules/majuscules de la C64) vers CP437 du mode 3
neo_petscii_to_cp437
	; $00-$1f : codes de commande, jamais affichés
	!fill 32, $20
	; $20-$3f
	!byte $20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2a,$2b,$2c,$2d,$2e,$2f
	!byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3a,$3b,$3c,$3d,$3e,$3f
	; $40 @, $41-$5a minuscules, [ £ ] ^ _
	!byte $40,$61,$62,$63,$64,$65,$66,$67,$68,$69,$6a,$6b,$6c,$6d,$6e,$6f
	!byte $70,$71,$72,$73,$74,$75,$76,$77,$78,$79,$7a,$5b,$9c,$5d,$5e,$5f
	; $60-$7f : trait horizontal, puis majuscules (graphismes en jeu minuscule)
	!byte $c4,$41,$42,$43,$44,$45,$46,$47,$48,$49,$4a,$4b,$4c,$4d,$4e,$4f
	!byte $50,$51,$52,$53,$54,$55,$56,$57,$58,$59,$5a,$c5,$b3,$b3,$b0,$b1
	; $80-$9f : codes de commande
	!fill 32, $20
	; $a0-$bf : $a6 {, $a7 }, $a8 ~, $a9 `, $af _, $bf \ (chars-neo.asm),
	; $b0-$b6 : æ Æ ç Ç ¡ ¿ Ñ (codes internes de chars-neo.asm)
	!byte $20,$dd,$dc,$c4,$c4,$7c,$7b,$7d,$7e,$60,$b3,$c3,$dc,$c0,$bf,$5f
	!byte $91,$92,$87,$80,$ad,$a8,$a5,$c4,$df,$dc,$d9,$c0,$d9,$bf,$b0,$5c
	; $c0-$df : trait, majuscules, puis $dd |
	!byte $c4,$41,$42,$43,$44,$45,$46,$47,$48,$49,$4a,$4b,$4c,$4d,$4e,$4f
	!byte $50,$51,$52,$53,$54,$55,$56,$57,$58,$59,$5a,$c5,$b3,$7c,$b0,$b1
	; $e0-$fe : lettres accentuées (codes internes de chars-neo.asm)
	;     ä   ö   ü   Ä   Ö   Ü   ß   »   «   ë   ï   ÿ   á   é   í   ó
	!byte $84,$94,$81,$8e,$99,$9a,$e1,$af,$ae,$89,$8b,$98,$a0,$82,$a1,$a2
	;     ú   É   à   è   ì   ò   ù   â   ê   î   ô   û   å   Å   ñ
	!byte $a3,$90,$85,$8a,$8d,$95,$97,$83,$88,$8c,$93,$96,$86,$8f,$a4,$b1

!source "../temp/neo-files.asm"

} ; zone neo

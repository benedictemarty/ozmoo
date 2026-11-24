; pictures-neo.asm — images des jeux v6 sur la Neo6502 (firmware Trinity 0.16.115 ou plus)
;
; Le firmware décode les images à la volée depuis le fichier d'images IBM d'origine (.MG1 VGA ou .EG1
; EGA), posé sur la clé à côté de l'histoire et ouvert sur le canal NEO_PIC_CHANNEL : 41,1 donne la taille
; d'une image, 41,2 la dessine dans le graphisme du mode 4 (320 x 240, 256 couleurs). Le mode 4 montre,
; cellule par cellule de la grille 80 x 25, soit le texte soit le graphisme dessous (5,44). Une cellule
; fait 4 x 8 pixels du graphisme, et le graphisme est à l'échelle des pixels d'image 320 x 200 qu'Ozmoo
; utilise comme unités (Z6_PIXEL_UNITS) : une image se dessine à sa position telle quelle.
;
; Ozmoo tient la carte des cellules en graphisme (neo_gfx_map, un bit par cellule, et neo_row_gfx, le
; nombre de cellules graphiques par rangée) :
; - dessiner une image passe ses cellules en graphisme, après avoir peint au fond de la fenêtre les
;   pixels des cellules qui étaient du texte (bords de l'image, pixels transparents) ;
; - écrire ou effacer du texte (5,13, 5,15) repasse les cellules touchées en texte (neo_text_layer) ;
; - le défilement d'une fenêtre (5,45) fait aussi défiler ses pixels (12,3) et sa carte.
; Le firmware refuse plus de 4 suites de cellules de même type par rangée (erreur 2) : la rangée reste
; alors comme elle était (image) ou repasse entièrement en texte (texte), pour que le texte reste lisible.
;
; Couleurs : les entrées 0-15 de la palette servent au texte (et au fond des pixels) ; chaque image VGA
; prend une tranche de 16 entrées à partir de 16 (option « couleur de base » de 41,2), réutilisée si la
; même image est redessinée ; les images EGA ont la palette EGA fixe, en 16-31.
; Auteur : bmarty <bmarty@mailo.com>

NEO_PIC_CHANNEL = 2
NEO_PIC_SLOTS = 15
picture_count = 0 ; non utilisé sur la Neo (le nombre vient de l'en-tête du fichier, neo_pic_hdr)

neo_pic_ok		!byte 0 ; 1 : fichier d'images ouvert et mode 4
neo_pic_hdr		!fill 16, 0
!ifdef NEO_TEST {
neo_pic_last_err	!byte $ee ; dernière erreur de 41,2 ($ee : aucun dessin)
neo_pic_draws		!byte 0
neo_pic_log			!fill 128, 0
neo_tl_count		!byte 0
neo_tl_log			!fill 128, 0
} ; en-tête du fichier : nombre d'images en +4, version en +14

.np_num		!byte 0, 0
.np_w		!byte 0, 0 ; en pixels d'image (moitié de la largeur du fichier en EGA)
.np_h		!byte 0, 0
.np_flags	!byte 0, 0 ; bit 0 : transparente
.np_kind	!byte 0 ; bit 0 : a des pixels, bit 1 : a une palette
.np_exists	!byte 0 ; 1 : l'entrée existe (image ou simple rectangle)
.np_c0		!byte 0 ; cellules couvertes : colonnes c0..c1, rangées r0..r1 (incluses)
.np_c1		!byte 0
.np_r0		!byte 0
.np_r1		!byte 0
.np_row		!byte 0
.np_col		!byte 0
.np_tmp		!byte 0, 0
.np_bg		!byte 0
.np_rect	!fill 8, 0 ; Rect de QuickDraw : gauche, haut, droite, bas (exclus), mots signés
!ifndef NEO_PIC_EGA {
.np_slot_lo	!fill NEO_PIC_SLOTS, $ff ; image de chaque tranche de palette
.np_slot_hi	!fill NEO_PIC_SLOTS, $ff
.np_next_slot	!byte 0
.np_last_base	!byte 0 ; tranche de la dernière image dessinée avec une palette (0 : aucune)
}

neo_gfx_map		!fill 25 * 10, 0 ; un bit par cellule, 10 octets par rangée (bit 7 = colonne 8n)
neo_row_gfx		!fill 25, 0 ; nombre de cellules en graphisme par rangée
neo_row10		!for .r, 0, 24 { !byte .r * 10 }
neo_bit_mask	!byte $80, $40, $20, $10, $08, $04, $02, $01
neo_row2560_lo	!for .r, 0, 24 { !byte <(.r * 2560) } ; adresse du pixel (0, 8r) dans la mémoire vidéo
neo_row2560_hi	!for .r, 0, 24 { !byte >(.r * 2560) }

; ---------------------------------------------------------------------------------
; Ouverture du fichier d'images et lecture de son en-tête (au démarrage, après neo_init).
; Sans mode 4 (firmware trop ancien) ou sans fichier, aucune image n'est dessinée.
; ---------------------------------------------------------------------------------
neo_pic_init
	lda neo_mode4
	beq .npi_done
	lda #NEO_PIC_CHANNEL
	sta neo_api_param
	lda #<neo_pic_filename
	sta neo_api_param + 1
	lda #>neo_pic_filename
	sta neo_api_param + 2
	lda #0 ; lecture seule
	sta neo_api_param + 3
	lda #4
	ldx #3
	jsr neo_api_call ; 3,4 : ouverture
	bne .npi_done
	lda #NEO_PIC_CHANNEL
	sta neo_api_param
	lda #0
	sta neo_api_param + 1
	sta neo_api_param + 2
	sta neo_api_param + 3
	sta neo_api_param + 4
	lda #6
	ldx #3
	jsr neo_api_call ; 3,6 : début du fichier
	bne .npi_done
	lda #NEO_PIC_CHANNEL
	sta neo_api_param
	lda #<neo_pic_hdr
	sta neo_api_param + 1
	lda #>neo_pic_hdr
	sta neo_api_param + 2
	lda #16
	sta neo_api_param + 3
	lda #0
	sta neo_api_param + 4
	lda #8
	ldx #3
	jsr neo_api_call ; 3,8 : les 16 octets de l'en-tête
	bne .npi_done
	lda #1
	ldx #32
	jsr neo_api_call ; 32,1 : QuickDraw, découpe sur tout l'écran
	lda #1
	sta neo_pic_ok
.npi_done
	rts

; ---------------------------------------------------------------------------------
; .pic_find : A = octet haut, X = octet bas du numéro d'image. Demande l'entrée au firmware (41,1).
; C = 1 si l'image a des pixels ; .np_exists = 1 si l'entrée existe (image ou rectangle), avec sa
; taille dans .np_w / .np_h. X et Y ne sont pas conservés.
; ---------------------------------------------------------------------------------
.pic_find
	sta .np_num + 1
	stx .np_num
	lda #0
	sta .np_exists
	lda neo_pic_ok
	beq .pf_none
	lda #NEO_PIC_CHANNEL
	sta neo_api_param
	lda .np_num
	sta neo_api_param + 1
	lda .np_num + 1
	sta neo_api_param + 2
	lda #1
	ldx #41
	jsr neo_api_call ; 41,1 : Picture Info
	bne .pf_none
	ldx #6
-	lda neo_api_param,x
	sta .np_w,x ; .np_w, .np_h, .np_flags, .np_kind se suivent
	dex
	bpl -
!ifdef NEO_PIC_EGA {
	; image EGA de 640 de large dessinée à moitié de largeur (colonnes paires) : ceil(w / 2)
	inc .np_w
	bne +
	inc .np_w + 1
+	lsr .np_w + 1
	ror .np_w
}
	lda #1
	sta .np_exists
	lda .np_kind
	lsr ; C = bit 0 : l'entrée a des pixels
	rts
.pf_none
	clc
	rts

; ---------------------------------------------------------------------------------
; Cellules couvertes par l'image (.pic_px, .pic_py, .np_w, .np_h). C = 0 si aucune.
; ---------------------------------------------------------------------------------
.npc_none
	clc
	rts
.np_cells
	lda .np_w
	ora .np_w + 1
	beq .npc_none
	lda .np_h
	ora .np_h + 1
	beq .npc_none
	lda .pic_py + 1
	bne .npc_none
	lda .pic_py
	cmp #200
	bcs .npc_none
	; colonnes : px / 4 .. (px + w - 1) / 4, limitées à 79
	lda .pic_px + 1
	cmp #>320
	bcc +
	bne .npc_none
	lda .pic_px
	cmp #<320
	bcs .npc_none
+	lda .pic_px + 1
	sta .np_tmp + 1
	lda .pic_px
	lsr .np_tmp + 1
	ror
	lsr .np_tmp + 1
	ror
	sta .np_c0
	clc
	lda .pic_px
	adc .np_w
	sta .np_tmp
	lda .pic_px + 1
	adc .np_w + 1
	sta .np_tmp + 1
	lda .np_tmp ; - 1
	bne +
	dec .np_tmp + 1
+	dec .np_tmp
	lsr .np_tmp + 1
	ror .np_tmp
	lsr .np_tmp + 1
	ror .np_tmp
	lda .np_tmp + 1
	bne +
	lda .np_tmp
	cmp #SCREEN_WIDTH
	bcc ++
+	lda #SCREEN_WIDTH - 1
++	sta .np_c1
	; rangées : py / 8 .. (py + h - 1) / 8, limitées à 24
	lda .pic_py
	lsr
	lsr
	lsr
	sta .np_r0
	clc
	lda .pic_py
	adc .np_h
	sta .np_tmp
	lda #0
	adc .np_h + 1
	sta .np_tmp + 1
	lda .np_tmp
	bne +
	dec .np_tmp + 1
+	dec .np_tmp
	ldx #3
-	lsr .np_tmp + 1
	ror .np_tmp
	dex
	bne -
	lda .np_tmp + 1
	bne +
	lda .np_tmp
	cmp #SCREEN_HEIGHT
	bcc ++
+	lda #SCREEN_HEIGHT - 1
++	sta .np_r1
	sec
	rts

; Couleur du fond de la fenêtre courante (papier de l'attribut d'effacement), dans .np_bg
.np_get_bg
	ldx s_colour_swap
	jsr neo_make_attr
	lsr
	lsr
	lsr
	lsr
	sta .np_bg
	rts

; ---------------------------------------------------------------------------------
; Carte des cellules. .nm_cell : A = rangée, Y = colonne -> X = index de l'octet, A = masque.
; ---------------------------------------------------------------------------------
.nm_cell
	tax
	tya
	lsr
	lsr
	lsr
	clc
	adc neo_row10,x
	tax
	tya
	and #7
	tay
	lda neo_bit_mask,y
	rts

; .nm_is_gfx : A = rangée, Y = colonne -> Z = 0 si la cellule est en graphisme. Y conservé.
.nm_is_gfx
	sty .np_tmp
	jsr .nm_cell
	ldy .np_tmp
	and neo_gfx_map,x
	rts

; .nm_mark : .np_row, colonnes .np_col (incluse) à Y (exclue) ; C = 1 graphisme, C = 0 texte.
; Tient neo_row_gfx à jour.
.nm_mark
	sty .nmm_end
	ror .nmm_set ; bit 7 = C
	ldy .np_col
-	cpy .nmm_end
	bcs .nmm_done
	lda .np_row
	jsr .nm_cell
	sta .np_tmp + 1 ; masque
	bit .nmm_set
	bmi .nmm_to_gfx
	; vers le texte
	and neo_gfx_map,x
	beq .nmm_next ; déjà du texte
	lda .np_tmp + 1
	eor #$ff
	and neo_gfx_map,x
	sta neo_gfx_map,x
	ldx .np_row
	dec neo_row_gfx,x
	jmp .nmm_next
.nmm_to_gfx
	and neo_gfx_map,x
	bne .nmm_next ; déjà du graphisme
	lda .np_tmp + 1
	ora neo_gfx_map,x
	sta neo_gfx_map,x
	ldx .np_row
	inc neo_row_gfx,x
.nmm_next
	; .nm_cell a mis colonne & 7 dans Y : retrouver la colonne
	inc .nmm_col
	ldy .nmm_col
	jmp -
.nmm_done
	rts
.nmm_end	!byte 0
.nmm_set	!byte 0
.nmm_col	!byte 0

; 5,44 sur les colonnes .np_col (incluse) à Y (exclue) de la rangée .np_row ; C = 1 graphisme.
; A = erreur du firmware, Z = 1 si aucune.
.nm_layer
	lda #0
	rol
	eor #1 ; P4 = 1 texte, 0 graphisme
	sta neo_api_param + 4
	dey
	sty neo_api_param + 2
	lda .np_col
	sta neo_api_param
	lda .np_row
	sta neo_api_param + 1
	sta neo_api_param + 3
	lda #44
	ldx #5
	jmp neo_api_call ; 5,44 : Set Cell Layer

; Réapplique au firmware la carte de la rangée .np_row entre les colonnes .nra_left (incluse) et
; .nra_right (exclue) : tout en texte, puis chaque suite de cellules graphiques. Une suite refusée
; (plus de 4 par rangée) repasse en texte dans la carte.
.nm_reapply_row
	lda .nra_left
	sta .np_col
	ldy .nra_right
	clc
	jsr .nm_layer
	ldx .np_row
	lda neo_row_gfx,x
	beq .nra_done
	ldy .nra_left
.nra_scan
	cpy .nra_right
	bcs .nra_done
	lda .np_row
	jsr .nm_is_gfx
	bne +
	iny
	jmp .nra_scan
+	sty .np_col
-	iny
	cpy .nra_right
	bcs +
	lda .np_row
	jsr .nm_is_gfx
	bne -
+	sty .nra_y
	sec
	jsr .nm_layer
	beq +
	ldy .nra_y ; refusé : la suite redevient du texte dans la carte
	clc
	jsr .nm_mark_col
+	ldy .nra_y
	jmp .nra_scan
.nra_done
	rts
.nra_left	!byte 0
.nra_right	!byte 0
.nra_y		!byte 0

; .nm_mark avec la colonne de départ .np_col (garde .np_col)
.nm_mark_col
	php
	lda .np_col
	sta .nmm_col
	plp
	jmp .nm_mark

; ---------------------------------------------------------------------------------
; .nm_fit_apply : la carte de la rangée .np_row vient de changer ; la ramène à 4 suites au plus (limite du
; firmware) puis l'applique (5,44) sur toute la rangée. Pour réduire le nombre de suites :
; 1. une suite de texte entre deux suites graphiques, faite seulement d'espaces et hors de la plage
;    protégée .fit_p0..fit_p1 ($ff : aucune), passe en graphisme, ses pixels peints au papier de sa
;    première cellule (rendu identique) : la plus courte d'abord ;
; 2. sinon la plus courte suite graphique passe en texte (un morceau d'image est perdu).
; Zork Zero en a besoin : colonne d'image, marge vide, lettrine, texte, colonne d'image = 5 suites.
; ---------------------------------------------------------------------------------
.fit_p0		!byte $ff
.fit_p1		!byte 0
.fit_fetched	!byte 0
.run_s		!byte 0
.run_e		!byte 0
.run_t		!byte 0
.best_s		!byte 0
.best_e		!byte 0
.best_len	!byte 0

.nm_fit_apply
	lda #0
	sta .fit_fetched
.nfa_loop
	jsr .nm_count
	cmp #5
	bcc .nfa_apply
	lda .fit_fetched
	bne +
	inc .fit_fetched
	jsr .nm_fetch_row
+	lda #0 ; 1. vide de texte à absorber
	jsr .nm_find_run
	bcc .nfa_drop
	lda neo_row_attrs,y ; papier de la première cellule du vide (Y = .best_s)
	lsr
	lsr
	lsr
	lsr
	sta .np_bg
	lda .best_s
	sta .np_col
	ldy .best_e
	jsr .np_fill_cells
	lda .best_s
	sta .np_col
	ldy .best_e
	sec
	jsr .nm_mark_col
	jmp .nfa_loop
.nfa_drop
	lda #1 ; 2. plus petite suite graphique sacrifiée
	jsr .nm_find_run
	bcc .nfa_apply
	lda .best_s
	sta .np_col
	ldy .best_e
	clc
	jsr .nm_mark_col
	jmp .nfa_loop
.nfa_apply
	lda #0
	sta .nra_left
	lda #SCREEN_WIDTH
	sta .nra_right
	jmp .nm_reapply_row

; type de la cellule (.np_row, Y) -> A = 1 graphisme, 0 texte ; Y conservé
.nm_type
	lda .np_row
	jsr .nm_is_gfx
	beq +
	lda #1
+	rts

; fin de la suite qui commence en Y -> Y = première cellule d'un autre type (ou 80), .run_t = type
.nm_run_end
	jsr .nm_type
	sta .run_t
-	iny
	cpy #SCREEN_WIDTH
	bcs +
	jsr .nm_type
	cmp .run_t
	beq -
+	rts

; nombre de suites de la rangée .np_row -> A
.nm_count
	ldy #0
	ldx #0
-	cpy #SCREEN_WIDTH
	bcs +
	inx
	txa
	pha
	jsr .nm_run_end
	pla
	tax
	jmp -
+	txa
	rts

; plus courte suite de type A (0 : vide de texte absorbable, 1 : suite graphique) -> C = 1 si trouvée,
; .best_s / .best_e (exclue), Y = .best_s
.nm_find_run
	sta .nfr_want
	lda #$ff
	sta .best_len
	ldy #0
.nfr_next
	cpy #SCREEN_WIDTH
	bcs .nfr_done
	sty .run_s
	jsr .nm_run_end
	sty .run_e
	lda .run_t
	cmp .nfr_want
	bne .nfr_next
	cmp #1
	beq .nfr_candidate
	; vide de texte : entre deux suites graphiques, hors de la plage protégée, rien que des espaces
	lda .run_s
	beq .nfr_skip
	lda .run_e
	cmp #SCREEN_WIDTH
	bcs .nfr_skip
	lda .fit_p0
	cmp #$ff
	beq +
	lda .fit_p1 ; chevauchement si p0 < run_e et run_s <= p1
	cmp .run_s
	bcc +
	lda .fit_p0
	cmp .run_e
	bcc .nfr_skip
+	ldx .run_s
-	lda neo_row_glyphs,x
	cmp #$20
	bne .nfr_skip
	inx
	cpx .run_e
	bcc -
.nfr_candidate
	lda .run_e
	sec
	sbc .run_s
	cmp .best_len
	bcs .nfr_skip
	sta .best_len
	lda .run_s
	sta .best_s
	lda .run_e
	sta .best_e
.nfr_skip
	ldy .run_e
	jmp .nfr_next
.nfr_done
	ldy .best_s
	lda .best_len
	cmp #$ff ; C = 1 si rien trouvé
	rol ; inverse : C = 1 si trouvé
	eor #1
	lsr
	rts
.nfr_want	!byte 0

; glyphes et attributs de la rangée .np_row (12,2 depuis la grille) dans neo_row_glyphs / neo_row_attrs
.nm_fetch_row
	lda #<neo_row_glyphs
	ldx #>neo_row_glyphs
	ldy #0
	jsr .nmf_one
	lda #<neo_row_attrs
	ldx #>neo_row_attrs
	ldy #1
.nmf_one
	sta neo_api_param + 4
	stx neo_api_param + 5
	ldx .np_row
	lda neo_row80_lo,x
	sta neo_api_param + 1
	lda neo_row80_hi,x
	sta neo_api_param + 2
	dey
	bne +
	clc
	lda neo_api_param + 1
	adc neo_grid_attrs
	sta neo_api_param + 1
	lda neo_api_param + 2
	adc neo_grid_attrs + 1
	sta neo_api_param + 2
+	lda neo_grid_page
	sta neo_api_param
	lda #0
	sta neo_api_param + 3
	sta neo_api_param + 7
	lda #SCREEN_WIDTH
	sta neo_api_param + 6
	lda #2
	ldx #12
	jmp neo_api_call ; 12,2 : Simple Blit Copy

; ---------------------------------------------------------------------------------
; neo_text_layer : la rangée A, colonnes X à Y (incluses) vont recevoir du texte (5,13, 5,15) : les
; cellules en graphisme repassent en texte. Les paramètres de l'API sont conservés.
; ---------------------------------------------------------------------------------
neo_text_layer
	sta .ntl_row
	cmp #SCREEN_HEIGHT
	bcs .ntl_rts
	stx .ntl_c0
	tax
	lda neo_row_gfx,x
	beq .ntl_rts
	cpy #SCREEN_WIDTH
	bcc +
	ldy #SCREEN_WIDTH - 1
+	iny
	sty .ntl_c1x
	; une cellule graphique dans l'intervalle ?
	ldy .ntl_c0
-	cpy .ntl_c1x
	bcs .ntl_rts
	lda .ntl_row
	jsr .nm_is_gfx
	bne .ntl_found
	iny
	jmp -
.ntl_found
!ifdef NEO_TEST {
	jsr .ntl_log
}
	ldx #8
-	lda neo_api_param,x
	sta .ntl_save,x
	dex
	bpl -
	lda .ntl_row
	sta .np_row
	lda .ntl_c0
	sta .np_col
	sta .fit_p0 ; les cellules qui vont recevoir le texte restent du texte
	ldy .ntl_c1x
	dey
	sty .fit_p1
	iny
	clc
	jsr .nm_mark_col
	jsr .nm_fit_apply
	ldx #8
-	lda .ntl_save,x
	sta neo_api_param,x
	dex
	bpl -
.ntl_rts
	rts
.ntl_row	!byte 0
!ifdef NEO_TEST {
.ntl_log
	; journal des 16 dernières conversions en texte : rangée, c0, c1 (exclue), appelant (2 octets)
	lda neo_tl_count
	and #15
	asl
	asl
	asl
	tax
	lda .ntl_row
	sta neo_tl_log,x
	lda .ntl_c0
	sta neo_tl_log + 1,x
	lda .ntl_c1x
	sta neo_tl_log + 2,x
	stx .np_tmp
	tsx
	lda $0103,x
	pha
	lda $0104,x
	ldx .np_tmp
	sta neo_tl_log + 4,x
	pla
	sta neo_tl_log + 3,x
	inc neo_tl_count
	rts
}
.ntl_c0		!byte 0
.ntl_c1x	!byte 0
.ntl_save	!fill 9, 0

; ---------------------------------------------------------------------------------
; neo_pic_draw : dessine l'image .np_num à (.pic_px, .pic_py) (après .pic_find et .pic_place_cursor).
; ---------------------------------------------------------------------------------
neo_pic_draw
	jsr .np_get_bg
	jsr .np_cells
	bcc .npd_draw
	; 1. pixels des cellules encore en texte : au fond de la fenêtre (rangée par rangée)
	lda .np_r0
	sta .np_row
.npd_row
	ldy .np_c0
.npd_scan
	cpy .np_c1
	beq +
	bcs .npd_row_done
+	lda .np_row
	jsr .nm_is_gfx
	beq +
	iny
	jmp .npd_scan
+	sty .np_col
-	iny
	cpy .np_c1
	beq +
	bcs ++
+	lda .np_row
	jsr .nm_is_gfx
	beq -
++	sty .nra_y
	jsr .np_fill_cells ; colonnes .np_col à Y (exclue)
	ldy .nra_y
	jmp .npd_scan
.npd_row_done
	lda .np_row
	inc .np_row
	cmp .np_r1
	bne .npd_row
.npd_draw
	; 2. l'image
	lda #NEO_PIC_CHANNEL
	sta neo_api_param
	lda .np_num
	sta neo_api_param + 1
	lda .np_num + 1
	sta neo_api_param + 2
	lda .pic_px
	sta neo_api_param + 3
	lda .pic_px + 1
	sta neo_api_param + 4
	lda .pic_py
	sta neo_api_param + 5
	lda .pic_py + 1
	sta neo_api_param + 6
	lda .np_flags
	and #1
	asl ; bit 1 : ne pas écrire la couleur transparente
	ora #$10 ; bit 4 : couleur de base en P8
!ifdef NEO_PIC_EGA {
	ora #$09 ; bit 0 : moitié de largeur, bit 3 : palette EGA
	sta neo_api_param + 7
	lda #16
} else {
	sta neo_api_param + 7
	jsr .np_choose_base
}
	sta neo_api_param + 8
	lda #2
	ldx #41
	jsr neo_api_call ; 41,2 : Draw Picture
!ifdef NEO_TEST {
	sta neo_pic_last_err
	; journal des 16 derniers dessins, 8 octets chacun : numéro, x (2), y, c0, c1, r0, r1
	lda neo_pic_draws
	and #15
	asl
	asl
	asl
	tax
	lda .np_num
	sta neo_pic_log,x
	lda .pic_px
	sta neo_pic_log + 1,x
	lda .pic_px + 1
	sta neo_pic_log + 2,x
	lda .pic_py
	sta neo_pic_log + 3,x
	lda .np_c0
	sta neo_pic_log + 4,x
	lda .np_c1
	sta neo_pic_log + 5,x
	lda .np_r0
	sta neo_pic_log + 6,x
	lda .np_r1
	sta neo_pic_log + 7,x
	inc neo_pic_draws
}
	; 3. les cellules couvertes passent en graphisme
	jsr .np_cells
	bcc .npd_done
	lda .np_r0
	sta .np_row
-	lda .np_c0
	sta .np_col
	ldy .np_c1
	iny
	sec
	jsr .nm_mark_col
	lda #$ff ; rien à protéger
	sta .fit_p0
	jsr .nm_fit_apply
	lda .np_row
	inc .np_row
	cmp .np_r1
	bne -
.npd_done
	rts

; peint au fond (.np_bg) les pixels des cellules .np_col (incluse) à Y (exclue) de la rangée .np_row
.np_fill_cells
	tya
	asl
	asl
	sta .np_rect + 4
	lda #0
	rol
	sta .np_rect + 5
	lda .np_col
	asl
	asl
	sta .np_rect
	lda #0
	rol
	sta .np_rect + 1
	lda .np_row
	asl
	asl
	asl
	sta .np_rect + 2
	clc
	adc #8
	sta .np_rect + 6
	lda #0
	sta .np_rect + 3
	sta .np_rect + 7
	lda #<.np_rect
	sta neo_api_param
	lda #>.np_rect
	sta neo_api_param + 1
	lda .np_bg
	sta neo_api_param + 2
	lda #9
	ldx #32
	jmp neo_api_call ; 32,9 : Erase Rect

!ifndef NEO_PIC_EGA {
; Tranche de palette de l'image .np_num -> A = couleur de base. Une image sans palette prend celle de
; la dernière image dessinée avec une palette, ou la palette EGA si aucune ne l'a été.
.np_choose_base
	lda .np_kind
	and #2
	bne +
	lda .np_last_base
	bne ++
	lda neo_api_param + 7 ; aucune palette chargée encore : la palette EGA, en 16-31
	ora #8
	sta neo_api_param + 7
	lda #16
++	rts
+	lda neo_api_param + 7
	ora #4 ; bit 2 : palette de l'image à base + 2
	sta neo_api_param + 7
	ldx #NEO_PIC_SLOTS - 1
-	lda .np_slot_lo,x
	cmp .np_num
	bne +
	lda .np_slot_hi,x
	cmp .np_num + 1
	beq .ncb_found
+	dex
	bpl -
	ldx .np_next_slot ; tranche suivante, à tour de rôle
	lda .np_num
	sta .np_slot_lo,x
	lda .np_num + 1
	sta .np_slot_hi,x
	txa
	pha
	inx
	cpx #NEO_PIC_SLOTS
	bcc +
	ldx #0
+	stx .np_next_slot
	pla
	tax
.ncb_found
	inx ; tranche x -> base 16 * (x + 1)
	txa
	asl
	asl
	asl
	asl
	sta .np_last_base
	rts
}

; ---------------------------------------------------------------------------------
; neo_pic_erase : efface la place de l'image (texte : espaces au fond de la fenêtre, ce qui repasse les
; cellules en texte).
; ---------------------------------------------------------------------------------
neo_pic_erase
	jsr .np_cells
	bcc +
	lda .np_r0
	sta .np_row
-	lda .np_row
	ldy .np_c0
	ldx .np_c1
	inx
	jsr neo_blank_cells
	lda .np_row
	inc .np_row
	cmp .np_r1
	bne -
+	rts

; ---------------------------------------------------------------------------------
; neo_gfx_scroll : le texte du rectangle neo_gs_left..neo_gs_right (exclue), rangées neo_gs_top à
; neo_gs_bottom, vient de défiler d'une rangée (Y = 1 vers le haut, $ff vers le bas) : les pixels et la
; carte suivent. Vers le bas (rare avec des images), les cellules graphiques repassent en texte.
; ---------------------------------------------------------------------------------
neo_gs_left		!byte 0
neo_gs_right	!byte 0
neo_gs_top		!byte 0
neo_gs_bottom	!byte 0

neo_gfx_scroll
	sty .ngs_dir
	; une rangée du rectangle a-t-elle du graphisme ?
	ldx neo_gs_top
-	lda neo_row_gfx,x
	bne .ngs_some
	cpx neo_gs_bottom
	inx
	bcc -
	rts
.ngs_some
	lda neo_gs_left
	sta .nra_left
	lda neo_gs_right
	sta .nra_right
	lda .ngs_dir
	cmp #1
	beq .ngs_up
	; vers le bas : tout le rectangle en texte
	lda neo_gs_top
	sta .np_row
-	lda neo_gs_left
	sta .np_col
	ldy neo_gs_right
	clc
	jsr .nm_mark_col
	lda #$ff
	sta .fit_p0
	jsr .nm_fit_apply
	lda .np_row
	inc .np_row
	cmp neo_gs_bottom
	bne -
	rts
.ngs_up
	; pixels : rangées top+1..bottom vers top..bottom-1 (12,3, de haut en bas)
	lda neo_gs_bottom
	sec
	sbc neo_gs_top
	beq .ngs_map
	asl
	asl
	asl
	sta .ngs_src + 9 ; hauteur en lignes
	lda neo_gs_right
	sec
	sbc neo_gs_left
	asl
	asl
	sta .ngs_src + 10 ; largeur en octets
	lda #0
	rol
	sta .ngs_src + 11
	lda neo_gs_left
	asl
	asl
	sta .np_tmp
	lda #0
	rol
	sta .np_tmp + 1
	ldx neo_gs_top
	clc
	lda neo_row2560_lo,x
	adc .np_tmp
	sta .ngs_dst
	lda neo_row2560_hi,x
	adc .np_tmp + 1
	sta .ngs_dst + 1
	inx
	clc
	lda neo_row2560_lo,x
	adc .np_tmp
	sta .ngs_src
	lda neo_row2560_hi,x
	adc .np_tmp + 1
	sta .ngs_src + 1
	lda #0
	sta neo_api_param
	lda #<.ngs_src
	sta neo_api_param + 1
	lda #>.ngs_src
	sta neo_api_param + 2
	lda #<.ngs_dst
	sta neo_api_param + 3
	lda #>.ngs_dst
	sta neo_api_param + 4
	lda #3
	ldx #12
	jsr neo_api_call ; 12,3 : Complex Blit Copy
.ngs_map
	; carte : chaque rangée prend celle du dessous, la dernière passe en texte
	lda neo_gs_top
	sta .np_row
.ngs_row
	lda .np_row
	cmp neo_gs_bottom
	beq .ngs_last
	ldy neo_gs_left
-	cpy neo_gs_right
	bcs .ngs_next
	sty .np_col
	ldx .np_row
	inx
	txa
	jsr .nm_is_gfx ; Z = 0 si la cellule du dessous est en graphisme
	php
	ldy .np_col
	iny
	plp
	beq +
	sec
	!byte $24 ; bit : saute le clc
+	clc
	jsr .nm_mark_col
	ldy .np_col
	iny
	jmp -
.ngs_next
	lda #$ff
	sta .fit_p0
	jsr .nm_fit_apply
	inc .np_row
	jmp .ngs_row
.ngs_last
	lda neo_gs_left
	sta .np_col
	ldy neo_gs_right
	clc
	jsr .nm_mark_col
	lda #$ff
	sta .fit_p0
	jmp .nm_fit_apply

.ngs_dir	!byte 0
.ngs_src	!byte 0, 0, $80, 0, <320, >320, 0, 0, 0, 0, 0, 0 ; adresse (page $80 : mémoire vidéo), pas, format 0, ..., hauteur, largeur
.ngs_dst	!byte 0, 0, $80, 0, <320, >320, 0, 0, 0, 0, 0, 0

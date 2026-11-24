; undo-neo.asm — annulation (undo) pour TARGET_NEO
;
; Inclus dans la zone save_restore de disk.asm, après save-neo.asm (.swap_pointers_for_save,
; .neo_save_start). L'état sauvé est la même zone contiguë qu'une partie sauvée : les registres de
; page zéro (recopiés sous la pile), la pile Z et la mémoire dynamique. Il est copié par le blitter
; du firmware (12,2) dans la mémoire graphique ($90:0000, 32 Ko), qu'Ozmoo n'utilise pas en mode
; texte. make.rb vérifie que la zone tient dans 32 Ko.
; Auteur : bmarty <bmarty@mailo.com>

NEO_UNDO_PAGE = $90

; Prépare les paramètres de 12,2 : C = 0 sauvegarde (RAM -> $90), C = 1 restauration.
; À appeler avant .swap_pointers_for_save (read_header_word lit la page zéro).
.neo_undo_params
	php
	ldy #header_static_mem
	jsr read_header_word ; A = octet haut, X = octet bas
	pha
	txa
	clc
	adc #<(story_start - .neo_save_start)
	sta neo_api_param + 6
	pla
	adc #>(story_start - .neo_save_start)
	sta neo_api_param + 7
	plp
	bcs +
	lda #0                 ; source : RAM du 6502
	sta neo_api_param
	lda #<.neo_save_start
	sta neo_api_param + 1
	lda #>.neo_save_start
	sta neo_api_param + 2
	lda #NEO_UNDO_PAGE     ; destination : mémoire graphique
	sta neo_api_param + 3
	lda #0
	sta neo_api_param + 4
	sta neo_api_param + 5
	rts
+	lda #NEO_UNDO_PAGE     ; source : mémoire graphique
	sta neo_api_param
	lda #0
	sta neo_api_param + 1
	sta neo_api_param + 2
	sta neo_api_param + 3  ; destination : RAM du 6502
	lda #<.neo_save_start
	sta neo_api_param + 4
	lda #>.neo_save_start
	sta neo_api_param + 5
	rts

.neo_undo_blit
	lda #2
	ldx #12
	jmp neo_api_call ; 12,2 Simple Blit Copy ; A = erreur, Z = 1 si aucune

do_save_undo
	clc
	jsr .neo_undo_params
	jsr .swap_pointers_for_save
	jsr .neo_undo_blit
	php
	jsr .swap_pointers_for_save
	plp
	bne +
	ldx #1
	stx undo_state_available
	rts                     ; X = 1 : sauvé
+	ldx #0                  ; X = 0 : échec
	stx undo_state_available
	rts

do_restore_undo
	sec
	jsr .neo_undo_params
	jsr .swap_pointers_for_save
	jsr .neo_undo_blit
	ldx #0
	stx undo_state_available
	jsr .swap_pointers_for_save
	jmp get_page_at_z_pc

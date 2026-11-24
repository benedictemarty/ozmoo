; save-neo.asm — sauvegarde, restauration et redémarrage pour TARGET_NEO
;
; Inclus dans la zone save_restore de disk.asm (accès à .input_alphanum et .inputstring).
; Une partie sauvée est un fichier <JEU>.SV0 à <JEU>.SV9 à côté de l'histoire. Il contient,
; comme sur la C64, la zone contiguë qui va des registres de page zéro (recopiés sous la
; pile par .swap_pointers_for_save) jusqu'à la fin de la mémoire dynamique.

.neo_save_start = stack_start - zp_bytes_to_save
.neo_save_len	!byte 0, 0

.saveslot_msg_save		!pet 13,"Save to",0
.saveslot_msg_restore	!pet 13,"Restore from",0
.saveslot_msg			!pet " slot (0-9, RETURN=cancel): ",0
.save_msg				!pet 13,"Saving...",13,0
.restore_msg			!pet 13,"Restoring...",13,0
.neo_no_save_msg		!pet 13,"No saved game in that slot.",13,0
.neo_error_msg			!pet 13,"Disk error.",13,0

.swap_pointers_for_save
	ldx #zp_bytes_to_save - 1
-	lda zp_save_start,x
	ldy stack_start - zp_bytes_to_save,x
	sta stack_start - zp_bytes_to_save,x
	sty zp_save_start,x
	dex
	bpl -
	rts

; Demande le numéro de partie. Entrée : A/X = message (haut/bas). Retour : C = 1 si
; annulé, sinon le nom de fichier est prêt dans neo_save_filename.
.neo_ask_slot
	jsr printstring_raw
	lda #>.saveslot_msg
	ldx #<.saveslot_msg
	jsr printstring_raw
	jsr .input_alphanum
	cpx #1
	bne .neo_cancel
	lda .inputstring
	cmp #$30
	bcc .neo_cancel
	cmp #$3a
	bcs .neo_cancel
	sta neo_save_filename_digit
	; Longueur de la zone sauvée : story_start + mémoire dynamique - début
	ldy #header_static_mem
	jsr read_header_word ; a = octet haut, x = octet bas
	stx .neo_save_len
	clc
	adc #>story_start
	sta .neo_save_len + 1
	lda .neo_save_len
	sec
	sbc #<.neo_save_start
	sta .neo_save_len
	lda .neo_save_len + 1
	sbc #>.neo_save_start
	sta .neo_save_len + 1
	clc
	rts
.neo_cancel
	sec
	rts

.neo_set_name_param
	lda #<neo_save_filename
	sta neo_api_param
	lda #>neo_save_filename
	sta neo_api_param + 1
	rts

save_game
	lda #>.saveslot_msg_save
	ldx #<.saveslot_msg_save
	jsr .neo_ask_slot
	bcs .neo_save_failed
	lda #>.save_msg
	ldx #<.save_msg
	jsr printstring_raw
	jsr .swap_pointers_for_save
	jsr .neo_set_name_param
	lda #<.neo_save_start
	sta neo_api_param + 2
	lda #>.neo_save_start
	sta neo_api_param + 3
	lda .neo_save_len
	sta neo_api_param + 4
	lda .neo_save_len + 1
	sta neo_api_param + 5
	lda #3
	ldx #3
	jsr neo_api_call ; 3,3 : Store File
	pha
	jsr .swap_pointers_for_save
	pla
	bne .neo_disk_error
	ldx #0
	jsr erase_window
	lda #0
	ldx #1
	rts
.neo_disk_error
	lda #>.neo_error_msg
	ldx #<.neo_error_msg
	jsr printstring_raw
.neo_save_failed
	ldx #0
	jsr erase_window
	lda #0
	tax
	rts

restore_game
	lda #>.saveslot_msg_restore
	ldx #<.saveslot_msg_restore
	jsr .neo_ask_slot
	bcs .neo_save_failed
	; La partie existe-t-elle, et a-t-elle la bonne taille ? (3,16 : File Stat)
	jsr .neo_set_name_param
	lda #16
	ldx #3
	jsr neo_api_call
	bne .neo_no_save
	lda neo_api_param
	cmp .neo_save_len
	bne .neo_no_save
	lda neo_api_param + 1
	cmp .neo_save_len + 1
	bne .neo_no_save
	lda neo_api_param + 2
	ora neo_api_param + 3
	bne .neo_no_save
	lda #>.restore_msg
	ldx #<.restore_msg
	jsr printstring_raw
	jsr .swap_pointers_for_save
	jsr .neo_set_name_param
	lda #<.neo_save_start
	sta neo_api_param + 2
	lda #>.neo_save_start
	sta neo_api_param + 3
	lda #2
	ldx #3
	jsr neo_api_call ; 3,2 : Load File
	beq +
	; La lecture a échoué en route : la mémoire n'est plus fiable.
	lda #ERROR_FLOPPY_READ_ERROR
	jsr fatalerror
+	jsr .swap_pointers_for_save
	ldx #0
	jsr erase_window
	jsr get_page_at_z_pc
	lda #0
	ldx #1
	rts
.neo_no_save
	lda #>.neo_no_save_msg
	ldx #<.neo_no_save_msg
	jsr printstring_raw
	jmp .neo_save_failed

; ---------------------------------------------------------------------------------
; restart : recharge le programme .NEO lui-même par 3,2 (qui écrit JMP <exécution> en
; $FF08) puis y saute. Le chargement écrase le code qui l'appelle, donc la séquence est
; recopiée et exécutée hors du programme, en NEO_RESTART_STUB (voir constants-neo.asm).
; ---------------------------------------------------------------------------------

!ifdef RESTART_SUPPORTED {
z_ins_restart
	lda #$ff
	sta neo_api_param
	lda #5
	ldx #3
	jsr neo_api_call ; 3,5 : ferme tous les fichiers
	ldx #.neo_stub_end - .neo_stub - 1
-	lda .neo_stub,x
	sta NEO_RESTART_STUB,x
	dex
	bpl -
	ldx #neo_program_filename_len
-	lda neo_program_filename,x
	sta neo_filename_buffer,x
	dex
	bpl -
	jmp NEO_RESTART_STUB

.neo_stub
	lda #<neo_filename_buffer
	sta neo_api_param
	lda #>neo_filename_buffer
	sta neo_api_param + 1
	lda #$ff ; l'adresse est ignorée pour un .NEO
	sta neo_api_param + 2
	sta neo_api_param + 3
	lda #2
	sta neo_api_function
	lda #3
	sta neo_api_command
-	lda neo_api_command
	bne - ; adresse relative : la séquence peut être déplacée
	jmp neo_api_param + 4 ; $FF08 : JMP <adresse d'exécution du .NEO>
.neo_stub_end
}

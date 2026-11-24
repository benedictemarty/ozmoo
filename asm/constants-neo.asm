; constants-neo.asm — carte mémoire de la cible Neo6502 / firmware Trinity (TARGET_NEO)
;
; La Neo6502 a 64 Ko de RAM plate : aucune ROM ni E/S projetée, sauf le noyau du 6502
; en $FC00-$FFFF, dont les registres de l'API en $FF00-$FF0F. Le programme peut donc
; utiliser $0000-$FBFF (NeoDOS, résident en $B800-$FBFF, est écrasé et rechargé par
; la fonction 1,3 à la sortie).
;
; La page zéro reprend la disposition de la C64 (constants.asm), tout y est libre ;
; les tampons que la C64 range dans les zones de son KERNAL et de son écran ($0200-$07FF)
; sont regroupés en $0200-$07FF.

SCREEN_HEIGHT         = 25
SCREEN_WIDTH          = 80
SCREEN_ROW_BYTES      = SCREEN_WIDTH
; Pas de mémoire d'écran visible par le 6502 : le mode texte 3 de Trinity est écrit
; par les fonctions 5,13 / 5,14 / 5,15. Ces deux adresses ne servent que d'origine
; aux pointeurs de ligne, qui portent le numéro de ligne dans leur octet haut.
SCREEN_ADDRESS        = $0000
COLOUR_ADDRESS        = $0000
COLOUR_ADDRESS_DIFF   = 0

num_rows 			  = $a6 ; !byte 0
CURRENT_DEVICE        = $ba
use_reu				  = $9b
window_start_row	  = $2a ; 4 bytes

!ifndef Z6 {
s_ignore_next_linebreak = $b0 ; 3 bytes
}
s_reverse 			  = $b3 ; !byte 0

zp_temp               = $fb ; 5 bytes
savefile_zp_pointer   = $c1 ; 2 bytes
is_buffered_window	  = $c8 ;  !byte 1
; Aucune mémoire en banque : toute la RAM utile est lisible directement.
first_banked_memory_page = $fc

; --- Tampons hors page zéro ---
; $0100-$0150 : print_buffer (pile du 6502, comme sur la C64)
; $0200-$0250 : print_buffer2
reu_filled            = $0255 ; 4 bytes
keyboard_buff_len     = $0259 ; (non utilisé par le Neo, gardé pour le code commun)
key_repeat            = $025a
charset_switchable 	  = $025b
keyboard_buff         = $0260 ; 10 octets (non utilisé)
memory_buffer         =	$02a7
memory_buffer_length  = 89    ; jusqu'à $02ff
directory_buffer      = $0300 ; 140 octets
neo_filename_buffer   = $0390 ; 64 octets : nom de fichier à longueur en tête (API)
neo_text_buffer       = $03d0 ; 82 octets : chaîne à longueur en tête pour 5,13
NEO_RESTART_STUB      = $0430 ; 80 octets : séquence de redémarrage (save-neo.asm)
; La RAM ne peut pas tenir plus de ~110 blocs de 512 octets : 191 entrées suffisent.
vmap_buffer_start     = $0480
vmap_buffer_end       = $05fe
; Configuration (identifiant, table de la mémoire virtuelle), chargée avec le .NEO.
; Sur la C64 elle est lue dans le cache de la mémoire virtuelle, après l'écran
; d'accueil qui y vit : ici elle a sa propre place, jusqu'à 512 octets.
NEO_CONFIG_ADDRESS    = $0600

; --- Page zéro (identique à la C64, voir constants.asm) ---
zero_datadirection    = $00
zero_processorports   = $01
z_opcode              = $02
mem_temp              = $05 ; 2 bytes
z_extended_opcode	  = $07

mempointer_y          = $08 ; 1 byte
z_opcode_number       = $09
zp_pc_h               = $0a
zp_pc_l               = $0b
z_operand_count		  = $0d
zword				  = $0e ; 6 bytes

zp_mempos             = $14 ; 2 bytes

z_operand_value_high_arr = $16 ; 8 bytes
z_operand_value_low_arr = $1e ; 8 bytes

	z_local_vars_ptr		= $75 ; 2 bytes
	z_local_var_count		= $77
	stack_pushed_bytes		= $78 ; 2 bytes
	stack_ptr				= $7a ; 2 bytes
	stack_top_value			= $7c ; 2 bytes
	stack_has_top_value		= $7e
	z_pc					= $7f ; 3 bytes (last byte shared with z_pc_mempointer)
	z_pc_mempointer			= $81 ; 2 bytes (first byte shared with z_pc)
	zp_save_start			= z_local_vars_ptr
	zp_bytes_to_save		= z_pc + 3 - z_local_vars_ptr

vmap_max_entries	  = $34

zchar_triplet_cnt	  = $35
packed_text			  = $36 ; 2 bytes
alphabet_offset		  = $38
escape_char			  = $39
escape_char_counter	  = $3a
abbreviation_command  = $40

parse_array           = $41 ; 2 bytes
string_array          = $43 ; 2 bytes

z_address			  = $45 ; 3 bytes
z_address_temp		  = $48

object_tree_ptr       = $49 ; 2 bytes
object_num			  = $4b ; 2 bytes
object_temp			  = $4d ; 2 bytes

vmap_used_entries	  = $4f

z_low_global_vars_ptr	  = $50 ; 2 bytes
z_high_global_vars_ptr	  = $52 ; 2 bytes
z_trace_index		  = $54
z_exe_mode	  		  = $55

stack_tmp			  = $56 ; 5 bytes
default_properties_ptr = $5b ; 2 bytes
zchars				  = $5d ; 3 bytes

vmap_quick_index_match= $60
vmap_next_quick_index = $61
vmap_quick_index	  = $62 ; Must follow vmap_next_quick_index!
vmap_quick_index_length = 6

z_temp				  = $68 ; 12 bytes

s_colour 			  = $74

mempointer            = $26 ; 2 bytes

vmem_temp			  = $92 ; 2 bytes

; Pointeur de travail de la couche Neo (appels de l'API qui prennent une adresse)
neo_zp_ptr            = $94 ; 2 bytes

current_window		  = $d8

s_stored_x			  = $b4
s_stored_y			  = $b5
s_current_screenpos_row = $b6

max_chars_on_line	  = $bd
buffer_index		  = $be
last_break_char_buffer_pos = $bf

zp_cursorswitch       = $cc
zp_screenline         = $d1 ; 2 bytes : octet haut = ligne courante
zp_screencolumn       = $d3
zp_screenrow          = $d6
zp_colourline         = $f3 ; 2 bytes (non utilisé : la couleur est un attribut de cellule)
cursor_row			  = $f7 ; 2 bytes

print_buffer		  = $100 ; SCREEN_WIDTH + 1 bytes
print_buffer2         = $200 ; SCREEN_WIDTH + 1 bytes

; --- Registres de l'API Neo6502 (noyau Trinity) ---
neo_api_command       = $ff00
neo_api_function      = $ff01
neo_api_error         = $ff02
neo_api_status        = $ff03
neo_api_param         = $ff04 ; Paramètres 0 à 7 : $ff04-$ff0b

; --- Routines du « KERNAL » : implémentées par la couche Neo (neo.asm) ---
kernal_reset          = neo_reset
kernal_delay_1ms      = neo_delay_1ms
kernal_readtime       = neo_readtime
kernal_settime        = neo_settime
kernal_getchar        = neo_getchar
kernal_clrchn         = neo_rts      ; pas de canaux d'entrée/sortie à la CBM
kernal_readchar       = neo_wait_key ; attend une touche (seul usage : fatalerror)

; --- Registres du VIC : variables en RAM (neo.asm), lues par la couche écran ---
reg_backgroundcolour  = neo_reg_background
reg_bordercolour      = neo_reg_border

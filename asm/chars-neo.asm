; chars-neo.asm — caractères de la cible Neo6502 (TARGET_NEO), inclus par streams.asm à la place des
; sections par langue (-cm:) : l'écran du mode 3 est en CP437 et le clavier de Trinity rend du
; Latin-1, il n'y a donc pas de police à choisir selon la langue.
;
; Ozmoo garde ses caractères dans un « PETSCII » interne. Les lettres accentuées de la table Unicode
; par défaut de la Z-machine (ZSCII 155-223) qui existent en CP437 reçoivent un code interne libre
; ($e0-$fe et $b0-$b6, que s_printchar affiche tels quels) ; neo_petscii_to_cp437 (neo.asm) les
; dessine, neo_latin1_to_internal (neo.asm) les rend depuis le clavier. Les autres (majuscules
; accentuées absentes du CP437, œ, ø, ã...) s'affichent sans accent.
; Auteur : bmarty <bmarty@mailo.com>

; Codes internes
NEO_AUML_L = $e0 ; ä
NEO_OUML_L = $e1 ; ö
NEO_UUML_L = $e2 ; ü
NEO_AUML_U = $e3 ; Ä
NEO_OUML_U = $e4 ; Ö
NEO_UUML_U = $e5 ; Ü
NEO_SZLIG  = $e6 ; ß
NEO_RAQUO  = $e7 ; »
NEO_LAQUO  = $e8 ; «
NEO_EUML_L = $e9 ; ë
NEO_IUML_L = $ea ; ï
NEO_YUML_L = $eb ; ÿ
NEO_AACU_L = $ec ; á
NEO_EACU_L = $ed ; é
NEO_IACU_L = $ee ; í
NEO_OACU_L = $ef ; ó
NEO_UACU_L = $f0 ; ú
NEO_EACU_U = $f1 ; É
NEO_AGRV_L = $f2 ; à
NEO_EGRV_L = $f3 ; è
NEO_IGRV_L = $f4 ; ì
NEO_OGRV_L = $f5 ; ò
NEO_UGRV_L = $f6 ; ù
NEO_ACIR_L = $f7 ; â
NEO_ECIR_L = $f8 ; ê
NEO_ICIR_L = $f9 ; î
NEO_OCIR_L = $fa ; ô
NEO_UCIR_L = $fb ; û
NEO_ARNG_L = $fc ; å
NEO_ARNG_U = $fd ; Å
NEO_NTIL_L = $fe ; ñ
NEO_AELI_L = $b0 ; æ
NEO_AELI_U = $b1 ; Æ
NEO_CCED_L = $b2 ; ç
NEO_CCED_U = $b3 ; Ç
NEO_IEXCL  = $b4 ; ¡
NEO_IQUES  = $b5 ; ¿
NEO_NTIL_U = $b6 ; Ñ

; Lettres sans accent (PETSCII interne : minuscule = ASCII - $20, majuscule = ASCII + $80)
!macro neo_lc .c { !byte .c - $20 }
!macro neo_uc .c { !byte .c + $80 }

; Entrée : code interne -> ZSCII. Trié par code interne décroissant.
character_translation_table_in
!byte NEO_NTIL_L, NEO_ARNG_U, NEO_ARNG_L, NEO_UCIR_L, NEO_OCIR_L, NEO_ICIR_L, NEO_ECIR_L, NEO_ACIR_L
!byte NEO_UGRV_L, NEO_OGRV_L, NEO_IGRV_L, NEO_EGRV_L, NEO_AGRV_L, NEO_EACU_U, NEO_UACU_L, NEO_OACU_L
!byte NEO_IACU_L, NEO_EACU_L, NEO_AACU_L, NEO_YUML_L, NEO_IUML_L, NEO_EUML_L, NEO_LAQUO, NEO_RAQUO
!byte NEO_SZLIG, NEO_UUML_U, NEO_OUML_U, NEO_AUML_U, NEO_UUML_L, NEO_OUML_L, NEO_AUML_L
!byte $dd, $bf ; | et \ (voir neo_ascii_to_petscii)
!byte NEO_NTIL_U, NEO_IQUES, NEO_IEXCL, NEO_CCED_U, NEO_CCED_L, NEO_AELI_U, NEO_AELI_L
!byte $af, $a9, $a8, $a7, $a6 ; _ ` ~ } {
!byte $a0, $9d, $91, $8b, $8a, $89, $88, $87, $86, $5c, $1d, $14, $11
character_translation_table_in_end
!byte 206, 202, 201, 195, 194, 193, 192, 191
!byte 185, 184, 183, 182, 181, 176, 173, 172
!byte 171, 170, 169, 166, 165, 164, 163, 162
!byte 161, 160, 159, 158, 157, 156, 155
!byte $7c, $5c
!byte 209, 223, 222, 214, 213, 212, 211
!byte $5f, $60, $7e, $7d, $7b
!byte $20, $83, $81, $8a, $88, $86, $8b, $89, $87, $db, $84, $08, $82
character_translation_table_in_mappings_end

; Sortie : ZSCII -> code interne, pour les caractères ASCII que le PETSCII n'a pas. Trié par ZSCII
; décroissant. Les ZSCII 155-223 passent par default_unicode_out ci-dessous.
character_translation_table_out
!byte $db, $7e, $7d, $7c, $7b, $60, $5f, $5c
character_translation_table_out_end
!byte $5c, $a8, $a7, $dd, $a6, $a9, $af, $bf
character_translation_table_out_mappings_end

; Saisie : majuscule ZSCII -> minuscule (les mots du dictionnaire sont en minuscules).
; Trié par source décroissante.
character_downcase_table
!byte 214, 212, 209, 202, 176, 160, 159, 158
character_downcase_table_end
!byte 213, 211, 206, 201, 170, 157, 156, 155
character_downcase_table_mappings_end

; ZSCII 155-223 (table Unicode par défaut de la Z-machine) -> code interne
default_unicode_out
!byte NEO_AUML_L, NEO_OUML_L, NEO_UUML_L, NEO_AUML_U, NEO_OUML_U, NEO_UUML_U ; 155 ä ö ü Ä Ö Ü
!byte NEO_SZLIG, NEO_RAQUO, NEO_LAQUO, NEO_EUML_L, NEO_IUML_L, NEO_YUML_L   ; 161 ß » « ë ï ÿ
+neo_uc 'E'                                                                  ; 167 Ë
+neo_uc 'I'                                                                  ; 168 Ï
!byte NEO_AACU_L, NEO_EACU_L, NEO_IACU_L, NEO_OACU_L, NEO_UACU_L           ; 169 á é í ó ú
+neo_lc 'y'                                                                  ; 174 ý
+neo_uc 'A'                                                                  ; 175 Á
!byte NEO_EACU_U                                                             ; 176 É
+neo_uc 'I'                                                                  ; 177 Í
+neo_uc 'O'                                                                  ; 178 Ó
+neo_uc 'U'                                                                  ; 179 Ú
+neo_uc 'Y'                                                                  ; 180 Ý
!byte NEO_AGRV_L, NEO_EGRV_L, NEO_IGRV_L, NEO_OGRV_L, NEO_UGRV_L           ; 181 à è ì ò ù
+neo_uc 'A'                                                                  ; 186 À
+neo_uc 'E'                                                                  ; 187 È
+neo_uc 'I'                                                                  ; 188 Ì
+neo_uc 'O'                                                                  ; 189 Ò
+neo_uc 'U'                                                                  ; 190 Ù
!byte NEO_ACIR_L, NEO_ECIR_L, NEO_ICIR_L, NEO_OCIR_L, NEO_UCIR_L           ; 191 â ê î ô û
+neo_uc 'A'                                                                  ; 196 Â
+neo_uc 'E'                                                                  ; 197 Ê
+neo_uc 'I'                                                                  ; 198 Î
+neo_uc 'O'                                                                  ; 199 Ô
+neo_uc 'U'                                                                  ; 200 Û
!byte NEO_ARNG_L, NEO_ARNG_U                                                 ; 201 å Å
+neo_lc 'o'                                                                  ; 203 ø
+neo_uc 'O'                                                                  ; 204 Ø
+neo_lc 'a'                                                                  ; 205 ã
!byte NEO_NTIL_L                                                             ; 206 ñ
+neo_lc 'o'                                                                  ; 207 õ
+neo_uc 'A'                                                                  ; 208 Ã
!byte NEO_NTIL_U                                                             ; 209 Ñ
+neo_uc 'O'                                                                  ; 210 Õ
!byte NEO_AELI_L, NEO_AELI_U, NEO_CCED_L, NEO_CCED_U                       ; 211 æ Æ ç Ç
+neo_lc 't'                                                                  ; 215 þ
+neo_lc 't'                                                                  ; 216 ð
+neo_uc 'T'                                                                  ; 217 Þ
+neo_uc 'T'                                                                  ; 218 Ð
!byte $5c                                                                    ; 219 £
+neo_lc 'o'                                                                  ; 220 œ
+neo_uc 'O'                                                                  ; 221 Œ
!byte NEO_IEXCL, NEO_IQUES                                                   ; 222 ¡ ¿
!if * - default_unicode_out != 69 {
	!error "default_unicode_out Neo : 69 octets attendus"
}

	.extern	RBASIC_START
	.extern	listing
	.extern RAPTOR_particle_gfx
	.extern RAPTOR_sprite_table
	.extern	RAPTOR_module_list
	.extern	RUPDALL_FLAG
	.extern	pixel_list
	
			include				"RAPTOR/INCS/RAPTOR.INC"								; Include RAPTOR library labels
			include				"U235SE.021/U235SE.INC"									; Include U235SE library labels

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
;                                                                                   ;
;       Enhanced BASIC for the Motorola MC680xx                                     ;
;                                                                                   ;
;       This is the generic version with I/O and LOAD/SAVE example code for the     ;
;       EASy68k editor/simulator. 2002-2012.                                        ;
;                                                                                   ;
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
;                                                                                   ;
;       Copyright(C) 2002-12 by Lee Davison. This program may be freely distributed ;
;       for personal use only. All commercial rights are reserved.                  ;
;                                                                                   ;
;       More 68000 and other projects can be found on my website at ..              ;
;                                                                                   ;
;        http://mycorner.no-ip.org/index.html                                       ;
;                                                                                   ;
;       mail : leeedavison@googlemail.com                                           ;
;                                                                                   ;
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;

; <~ggn> after your init, just put your ram pointer to a0, ram size to d0 and jump to LAB_COLD

; Ver 3.52

; Ver 3.52 stops USING$() from reading beyond the end of the format string
; Ver 3.51 fixes the UCASE$() and LCASE$() functions for null strings
; Ver 3.50 uniary minus in concatenate generates a type mismatch error
; Ver 3.49 doesn't tokenise 'DEF' or 'DEC' within a hex value
; Ver 3.48 allows scientific notation underflow in the USING$() function
; Ver 3.47 traps the use of array elements as the FOR loop variable
; Ver 3.46 updates function and function variable handling

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; Ver 3.45 makes the handling of non existant variables consistent and gives the
; option of not returning an error for a non existant variable. If this is the
; behaviour you want just change novar to some non zero value

;                OPT D+
;       OFFSET  0                       ; start of RAM
;                RSRESET

;ram_strt:       RS.L 256
ram_strt        EQU 0
;                               rept $100
;                               dc.l 0
;                               endr
;ds.l   $100                    ; allow 1K for the stack, this should be plenty
; for any BASIC program that doesn't do something
; silly, it could even be much less.
ram_base        equ ram_strt+1024
LAB_WARM       equ ram_base ;RS.W 1          ; BASIC warm start entry point
Wrmjpv         equ LAB_WARM+2 ;RS.L 1          ; BASIC warm start jump vector
                
Usrjmp         EQU Wrmjpv+4 ;RS.W 1          ; USR function JMP address
Usrjpv         EQU Usrjmp+2 ;RS.L 1          ; USR function JMP vector

;; system dependant i/o vectors
;; these are in RAM and are set at start-up

V_INPT         EQU Usrjpv+4 ;RS.W 1          ; non halting scan input device entry point
V_INPTv        EQU V_INPT+2 ;RS.L 1          ; non halting scan input device jump vector

V_OUTP         EQU V_INPTv+4 ;RS.W 1          ; send byte to output device entry point
V_OUTPv        EQU V_OUTP+2 ;RS.L 1          ; send byte to output device jump vector

V_LOAD         EQU V_OUTPv+4 ;RS.W 1          ; load BASIC program entry point
V_LOADv        EQU V_LOAD+2 ;RS.L 1          ; load BASIC program jump vector

V_SAVE         EQU V_LOADv+4 ;RS.W 1          ; save BASIC program entry point
V_SAVEv        EQU V_SAVE+2 ;RS.L 1          ; save BASIC program jump vector

V_CTLC         EQU V_SAVEv+4 ;RS.W 1          ; save CTRL-C check entry point
V_CTLCv        EQU V_CTLC+2 ;RS.L 1          ; save CTRL-C check jump vector

Itemp          EQU V_CTLCv+4 ;RS.L 1          ; temporary integer     (for GOTO etc)

Smeml          EQU Itemp+4 ;RS.L 1          ; start of memory               (start of program)

;; the program is stored as a series of lines each line having the following format
;*
;*              ds.l    1                       ; pointer to the next line or $00000000 if [EOT]
;*              ds.l    1                       ; line number
;*              ds.b    n                       ; program bytes
;*              dc.b    $00                     ; [EOL] marker, there will be a second $00 byte, if
;*                                              ; needed, to pad the line to an even number of bytes

Sfncl          EQU Smeml+4 ;RS.L 1          ; start of functions    (end of Program)

;; the functions are stored as function name, function execute pointer and function
;; variable name
;*
;*              ds.l    1                       ; name
;*              ds.l    1                       ; execute pointer
;*              ds.l    1                       ; function variable

Svarl          EQU Sfncl+4 ;RS.L 1          ; start of variables    (end of functions)

;; the variables are stored as variable name, variable value
;*
;*              ds.l    1                       ; name
;*              ds.l    1                       ; packed float or integer value

Sstrl          EQU Svarl+4 ;RS.L 1          ; start of strings      (end of variables)

;; the strings are stored as string name, string pointer and string length
;*
;*              ds.l    1                       ; name
;*              ds.l    1                       ; string pointer
;*              ds.w    1                       ; string length

Sarryl         EQU Sstrl+4 ;RS.L 1          ; start of arrays               (end of strings)

;; the arrays are stored as array name, array size, array dimensions count, array
;; dimensions upper bounds and array elements
;*
;*              ds.l    1                       ; name
;*              ds.l    1                       ; size including this header
;*              ds.w    1                       ; dimensions count
;*              ds.w    1                       ; 1st dimension upper bound
;*              ds.w    1                       ; 2nd dimension upper bound
;*              ...                             ; ...
;*              ds.w    1                       ; nth dimension upper bound
;*
;; then (i1+1)*(i2+1)...*(in+1) of either ..
;*
;*              ds.l    1                       ; packed float or integer value
;*
;; .. if float or integer, or ..
;*
;*              ds.l    1                       ; string pointer
;*              ds.w    1                       ; string length
;*
;; .. if string

Earryl         EQU Sarryl+4 ;RS.L 1          ; end of arrays         (start of free mem)
Sstorl         EQU Earryl+4 ;RS.L 1          ; string storage                (moving down)
Ememl          EQU Sstorl+4 ;RS.L 1          ; end of memory         (upper bound of RAM)
Sutill         EQU Ememl+4 ;RS.L 1          ; string utility ptr
Clinel         EQU Sutill+4 ;RS.L 1          ; current line          (Basic line number)
Blinel         EQU Clinel+4 ;RS.L 1          ; break line            (Basic line number)

Cpntrl         EQU Blinel+4 ;RS.L 1          ; continue pointer
Dlinel         EQU Cpntrl+4 ;RS.L 1          ; current DATA line
Dptrl          EQU Dlinel+4 ;RS.L 1          ; DATA pointer
Rdptrl         EQU Dptrl+4 ;RS.L 1          ; read pointer
Varname        EQU Rdptrl+4 ;RS.L 1          ; current var name
Cvaral         EQU Varname+4 ;RS.L 1          ; current var address
Lvarpl         EQU Cvaral+4 ;RS.L 1          ; variable pointer for LET and FOR/NEXT

des_sk_e       EQU Lvarpl+4 ;RS.L 6          ; descriptor stack end address
des_sk         EQU des_sk_e+(4*6) ;RS.W 1          ; descriptor stack start address
; use a4 for the descriptor pointer
Ibuffs         EQU des_sk+2 ;RS.L $40
;               rept $40
;               dc.l    0
;               endr
; ds.l $40                     ; start of input buffer
Ibuffe          EQU Ibuffs+($40*4) ;^^RSCOUNT
; end of input buffer

FAC1_m         EQU Ibuffe ; RS.L 1          ; FAC1 mantissa1
FAC1_e         EQU FAC1_m+4 ; RS.W 1          ; FAC1 exponent
FAC1_s          EQU FAC1_e+1    ; FAC1 sign (b7)
                ;EQU RS.W 1

FAC2_m         EQU FAC1_e+4 ;RS.L 1          ; FAC2 mantissa1
FAC2_e         EQU FAC2_m+4 ; RS.L 1          ; FAC2 exponent
FAC2_s          EQU FAC2_e+1    ; FAC2 sign (b7)
FAC_sc          EQU FAC2_e+2    ; FAC sign comparison, Acc#1 vs #2
flag            EQU FAC2_e+3    ; flag byte for divide routine

PRNlword       EQU FAC2_e+4 ;RS.L 1          ; PRNG seed long word

ut1_pl         EQU PRNlword+4 ;RS.L 1          ; utility pointer 1

Asptl          EQU ut1_pl+4 ;RS.L 1          ; array size/pointer
Astrtl         EQU Asptl+4 ;RS.L 1          ; array start pointer

numexp          EQU Astrtl      ; string to float number exponent count
expcnt          EQU Astrtl+1    ; string to float exponent count

expneg          EQU Astrtl+3    ; string to float eval exponent -ve flag

func_l         EQU Astrtl+4 ;RS.L 1          ; function pointer


;                                              ; these two need to be a word aligned pair !
Defdim         EQU func_l+4 ;RS.W 1          ; default DIM flag
cosout          EQU Defdim      ; flag which CORDIC output (re-use byte)
Dtypef          EQU Defdim+1    ; data type flag, $80=string, $40=integer, $00=float


Binss          EQU Defdim+2 ;RS.L 4          ; number to bin string start (32 chrs)

Decss          EQU Binss+(4*4) ;RS.L 1          ; number to decimal string start (16 chrs)
                ; RS.W 1          ;*
Usdss          EQU Decss+6 ; RS.W 1          ; unsigned decimal string start (10 chrs)

Hexss          EQU Usdss+2 ; RS.L 2          ; number to hex string start (8 chrs)

BHsend         EQU Hexss+(4*2) ; RS.W 1          ; bin/decimal/hex string end


prstk          EQU BHsend+2 ;RS.B 1          ; stacked function index

tpower         EQU prstk+1 ;RS.B 1          ; remember CORDIC power

Asrch          EQU tpower+1 ;RS.B 1          ; scan-between-quotes flag, alt search character

Dimcnt         EQU Asrch+1 ;RS.B 1          ; # of dimensions

Breakf         EQU Dimcnt+1 ;RS.B 1          ; break flag, $00=END else=break
Oquote         EQU Breakf+1 ;RS.B 1          ; open quote flag (Flag: DATA; LIST; memory)
Gclctd         EQU Oquote+1 ;RS.B 1          ; garbage collected flag
Sufnxf         EQU Gclctd+1 ;RS.B 1          ; subscript/FNX flag, 1xxx xxx = FN(0xxx xxx)
Imode          EQU Sufnxf+1 ;RS.B 1          ; input mode flag, $00=INPUT, $98=READ

Cflag          EQU Imode+1 ; RS.B 1          ; comparison evaluation flag

TabSiz         EQU Cflag+1 ; RS.B 1          ; TAB step size

comp_f         EQU TabSiz+1 ; RS.B 1          ; compare function flag, bits 0,1 and 2 used
;                            ; bit 2 set if >
;                            ; bit 1 set if =
;                            ; bit 0 set if <

Nullct         EQU comp_f+1 ; RS.B 1          ; nulls output after each line
TPos           EQU Nullct+1 ; RS.B 1          ; BASIC terminal position byte
TWidth         EQU TPos+1 ;  RS.B 1          ; BASIC terminal width byte
Iclim          EQU TWidth+1 ; RS.B 1          ; input column limit
ccflag         EQU Iclim+1 ; RS.B 1          ; CTRL-C check flag
ccbyte         EQU ccflag+1 ; RS.B 1          ; CTRL-C last received byte
ccnull         EQU ccbyte+1 ; RS.B 1          ; CTRL-C last received byte 'life' timer

;; these variables for simulator load/save routines

file_byte      EQU ccnull+1 ; RS.B 1          ; load/save data byte
file_id        EQU file_byte+1 ; RS.L 1          ; load/save file ID

                ;RS.W 1          ; dummy even value and zero pad byte

prg_strt        EQU file_id+6 ; ^^RSCOUNT

;ORG   ;*

;                pea     cls(PC)
;                move.w  #9,-(SP)
;                trap    #1
;                addq.l  #6,SP

;                lea     RAM,A0
;                move.l  #RAM_SIZE,D0
;                bra     LAB_COLD

;cls:            DC.B 27,'E',0
;                EVEN


novar           .EQU 0           ; non existant variables cause errors


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *

; Ver 3.44 adds overflow indication to the USING$() function
; Ver 3.43 removes an undocumented feature of concatenating null strings
; Ver 3.42 reimplements backspace so that characters are overwritten with [SPACE]
; Ver 3.41 removes undocumented features of the USING$() function
; Ver 3.40 adds the USING$() function
; Ver 3.33 adds the file r.EQUester to LOAD and SAVE
; Ver 3.32 adds the optional ELSE clause to IF .. THEN

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; Version 3.25 adds the option to change the behaviour of INPUT so that a null
; response does not cause a program break. If this is the behaviour you want just
; change nobrk to some non zero value.

nobrk           .EQU 0           ; null response to INPUT causes a break


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; Version 3.xx replaces the fixed RAM addressing from previous versions with a RAM
; pointer in a3. this means that this could now be run as a task on a multitasking
; system where memory resources may change.


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *


;       INCLUDE "Basic68k.inc"
; RAM offset definitions

;       ORG             $000400                 ; past the vectors in a real system


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;
; parse a plain ASCII file instead of having to enter it.
; a6 has the pointer to the text. terminate the text with a null.
; text can have either CRLF (Windows) or LF (Unix) line endings.

PARSE_FILE:
                lea     Ibuffs(A3),A5   ; buffer space to temporarily store the current line (we need to terminate it with a NULL at the end)
                movea.l A5,A1           ; copy line buffer pointer to a1

PARSE_FILE_loop:
                move.b  (A6)+,D0        ; read a character
                beq.s   PARSE_FILE_out  ; end of file? clear off if yes
                cmp.b   #13,D0          ; CR?
                beq.s   PARSE_FILE_loop ; if yes, skip it (whatever happens we'll either wait for a LF character for EOL)
                cmp.b   #10,D0          ; LF?
                beq.s   PARSE_FILE_do_parse ; yep, so we're done. go parse the line
                move.b  D0,(A1)+        ; if we got here, then we have a valid character - copy it to the line buffer
                bra.s   PARSE_FILE_loop ; and loop back

PARSE_FILE_do_parse_fix:
                subq.l  #1,A6           ; if we got here, then we have a file whose
; last line has code and isn't terminated by return. since we already parsed the null, decrease input pointer so we'll reparse it next iteration
PARSE_FILE_do_parse:
                clr.b   (A1)            ; zero the last byte for the parser
zz:
;                movea.l Smeml(A3),A0    ; start of program memory
;                lea     $3F8000,A0
                movea.l A5,A0
                bsr     LAB_1295        ; a0=output buffer, a5=input buffer
; TODO: checks to see if a syntax error occurs or anything.
                bra.s   PARSE_FILE      ; and go to next line

PARSE_FILE_out:

                lea     Ibuffs(A3),A0   ; buffer space to temporarily store the current line (we need to terminate it with a NULL at the end)
                cmpa.l  A0,A5           ; one last check before we go: does the file buffer contain anything? (i.e. last line might not be terminated by a return)
                bne.s   PARSE_FILE_do_parse_fix ; if it does, parse that line too

                bra     LAB_RUN

                rts                     ; otherwise take the highway

;parse_file_buffer:
;                REPT 64
;                DC.L 0
;                ENDR


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; the following code is simulator specific, change to suit your system

; output character to the console from register d0.b

VEC_OUT:		movem.l D0-A6,-(SP)     ; save d0, d1

				move.b	d0,VEC_OUT_char
 
				move.l	rap_c_y,d1
				move.l	rap_c_x,d2
 
				cmp.b	#$0a,d0
				beq		.done_update
				
				cmp.b	#$0d,d0
				bne		.print
				
				clr.l	d2				; clear x
				add.l	#8,d1			; inc y
				bra		.done_update

.print:			cmp.l	#200,d1
				bne		.do_out

				lea		RAPTOR_particle_gfx,a0
				lea		1280(a0),a1
				move.l	#639,d7
.up:			movem.l	(a1)+,d0-d6/a2-a6
				movem.l	d0-d6/a2-a6,(a0)
				lea		48(a0),a0
				dbra	d7,.up
				move.l	#((160*8)/16)-1,d7
.clr:			clr.l	(a0)+
				clr.l	(a0)+
				clr.l	(a0)+
				clr.l	(a0)+
				dbra	d7,.clr

				lea		scrnbuffer,a0
				lea		40(a0),a1
				move.l	#((10*23)/4)-1,d7
.scrl:			move.l	(a1)+,(a0)+
				dbra	d7,.scrl
				
				moveq	#0,d2
				move.l	#192,d1
			
.do_out:		move.l	d1,rap_c_y
				move.l	d2,d0
				addq	#8,d2
				move.l	d2,rap_c_x
				lea		VEC_OUT_char(pc),a0

				moveq	#0,d2
				moveq	#0,d3
				jsr		RAPTOR_print

				move.l	rap_c_x,d1
				move.l	rap_c_y,d2
				asr		#3,d1
				asr		#3,d2
				mulu	#40,d2
				subq	#1,d1
				lea		scrnbuffer,a0
				add.w	d1,a0
				add.w	d2,a0
				move.b	VEC_OUT_char,(a0)
								
.done:			movem.l (SP)+,D0-A6     ; restore d0, d1

                rts

.done_update:	move.l	d1,rap_c_y
				move.l	d2,rap_c_x
				
				movem.l (SP)+,D0-A6     ; restore d0, d1
                rts

				
VEC_OUT_char:   DC.B	0,-1

rap_c_x:		dc.l	0
rap_c_y:		dc.l	0

scrnbuffer:		
				.rept 24
				dc.b	'                    '
				dc.b	'                    '
				.endr

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; input a character from the console into register d0
; else return Cb=0 if there's no character available

VEC_IN:
;                move.l  D1,-(SP)        ; save d1
;                moveq   #7,D0           ; get the status
;                trap    #15             ; do I/O function

;                move.b  D1,D0           ; copy the returned status
;                bne.s   RETCHR          ; if a character is waiting go get it

;                move.l  (SP)+,D1        ; else restore d1
;                tst.b   D0              ; set the z flag
;;       ANDI.b  #$FE,CCR                        ; clear the carry, flag we got no byte
;;                                                       ; done by the TST.b
                movem.l D1/A0-A1,-(SP)
                move.w  #2,-(SP)
                move.w  #2,-(SP)
                trap    #13
                addq.l  #4,SP
                movem.l (SP)+,D1/A0-A1
                tst.b   D0
                beq.s   VEC_IN_EXIT
                ori     #1,CCR
VEC_IN_EXIT:
                rts

RETCHR:
                moveq   #5,D0           ; get byte form the keyboard
                trap    #15             ; do I/O function

                move.b  D1,D0           ; copy the returned byte
                move.l  (SP)+,D1        ; restore d1
                tst.b   D0              ; set the z flag on the received byte
                ori     #1,CCR          ; set the carry, flag we got a byte
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; LOAD routine for the Easy68k simulator

VEC_LD:
                lea     load_title(PC),A1 ; set the LOAD r.EQUest title string pointer
                bsr     get_filename    ; get the filename from the line or the r.EQUest

                beq     LAB_FCER        ; if null do function call error then warm start

                move.w  #51,D0          ; open existing file
                trap    #15             ; do I/O function

                tst.w   D0              ; test load result
                bne.s   LOAD_exit       ; if error clear up and exit

                move.l  D1,file_id(A3)  ; save the file ID

                lea     LOAD_in(PC),A1  ; get byte from file vector
                move.l  A1,V_INPTv(A3)  ; set the input vector
                bra     LAB_127D        ; now we just wait for Basic command, no "Ready"

LOAD_exit:
                bsr     LAB_147A        ; go do "CLEAR"
                bra     LAB_1274        ; BASIC warm start entry, go wait for Basic
; command

; input character to register d0 from file

LOAD_in:
                movem.l D1-D2/A1,-(SP)  ; save d1, d2 & a1
                move.l  file_id(A3),D1  ; get file ID back
                lea     file_byte(A3),A1 ; point to byte buffer
                moveq   #1,D2           ; set count for one byte
                moveq   #53,D0          ; read from file
                trap    #15             ; do I/O function

                tst.w   D0              ; test status
                bne.s   LOAD_eof        ; branch if byte read failed

                move.b  (A1),D0         ; get byte
                movem.l (SP)+,D1-D2/A1  ; restore d1, d2 & a1
                ori     #1,CCR          ; set carry, flag we got a byte
                rts
; got an error on read so restore the input
; vector and tidy up
LOAD_eof:
                moveq   #50,D0          ; close all files
                trap    #15             ; do I/O function

                lea     VEC_IN(PC),A1   ; get byte from input device vector
                move.l  A1,V_INPTv(A3)  ; set input vector
                moveq   #0,D0           ; clear byte
                movem.l (SP)+,D1-D2/A1  ; restore d1, d2 & a1
                bsr     LAB_147A        ; do CLEAR, erase variables/functions and
; flush stacks
                bra     LAB_1274        ; BASIC warm start entry, go wait for Basic
; command


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; get the filename from the line or from the filename r.EQUester
*
; if the name is null, "", or there is nothing following then the r.EQUester is used
; to get a filename else the filename is got from the line. if the r.EQUester is used
; the name buffer is allocated in string space and is always null terminated before
; it is passed to the file r.EQUester

get_filename:
                beq.s   get_name        ; if no following go use the r.EQUester

get_file:
                move.l  A1,-(SP)        ; save the title string pointer
                subq.w  #1,A5           ; decrement the execute pointer
                bsr     LAB_GVAL        ; get value from line
                movea.l (SP)+,A1        ; restore the title string pointer
                tst.b   Dtypef(A3)      ; test the data type flag
                bpl     LAB_TMER        ; if not string type do type mismatch error

                movea.l FAC1_m(A3),A2   ; get the descriptor pointer
                move.w  4(A2),D1        ; get the string length
                beq.s   get_name        ; if null go use the file r.EQUester

                movea.l (A2),A1         ; get the string pointer
                move.w  D1,D0           ; copy the string length
                addq.w  #1,D1           ; increment the string length
                bsr     LAB_2115        ; make space d1 bytes long

                move.b  #$00,0(A0,D0.w) ; null terminate the new string
                subq.w  #1,D0           ; decrement the string length
name_copy:
                move.b  0(A1,D0.w),0(A0,D0.w) ; copy a file name byte
                dbra    D0,name_copy    ; loop while more to do

                movea.l A0,A1           ; copy the new, terminated, file name pointer

                movea.l A2,A0           ; copy the old filename descriptor pointer
                bra     LAB_22B6        ; pop string off descriptor stack or from memory
; returns with d0 = length, a0 = pointer

; get a name with the file r.EQUester

get_name:
                move.l  A3,-(SP)        ; save the variables base pointer
                move.w  #$0100,D1       ; enough space for the r.EQUest filename
                bsr     LAB_2115        ; make space d1 bytes long
                movea.l A0,A3           ; copy the file name buffer pointer
                lea     file_list(PC),A2 ; set the file types list pointer
                moveq   #0,D1           ; file open
                move.b  D1,(A3)         ; ensure initial null file name
                moveq   #58,D0          ; file I/O
                trap    #15

                movea.l A3,A1           ; copy the file name pointer
                movea.l (SP)+,A3        ; restore the variables pointer
                tst.l   D1              ; did the user hit open
                rts


load_title:
                DC.B 'LOAD file',0 ; LOAD file title string

save_title:
                DC.B 'SAVE file',0 ; SAVE file title string

file_list:
                DC.B '*.bas',0  ; file type list
                DC.W 0          ; ensure even


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;
; SAVE routine for the Easy68k simulator

VEC_SV:
                lea     save_title(PC),A1 ; set the SAVE r.EQUest title string pointer
                pea     SAVE_RTN(PC)    ; set the return point
                beq.s   get_name        ; if no following go use the file r.EQUester

                cmp.b   #',',D0         ; compare the following byte with ","
                bne     get_file        ; if not "," get the filename from the line

                beq.s   get_name        ; else go use the file r.EQUester

SAVE_RTN:
                beq     LAB_FCER        ; if null do function call error then warm start

                movea.l A0,A1           ; copy filename pointer
                move.w  #52,D0          ; open new file
                trap    #15             ; do I/O function

                tst.w   D0              ; test save result
                bne     LAB_FCER        ; if error do function call error, warm start

                move.l  D1,file_id(A3)  ; save file ID

                move.l  V_OUTPv(A3),-(SP) ; save the output vector
                lea     SAVE_OUT(PC),A1 ; send byte to file vector
                move.l  A1,V_OUTPv(A3)  ; change the output vector

                move.b  TWidth(A3),-(SP) ; save the current line length
                move.b  #$00,TWidth(A3) ; set infinite length line for save

                bsr     LAB_GBYT        ; get next BASIC byte
                beq     SAVE_bas        ; if no following go do SAVE

                cmp.b   #',',D0         ; else compare with ","
                bne     LAB_SNER        ; if not "," so go do syntax error/warm start

                bsr     LAB_IGBY        ; increment & scan memory
SAVE_bas:
                bsr     LAB_LIST        ; go do list (line numbers applicable)
                move.b  (SP)+,TWidth(A3) ; restore the line length

                move.l  (SP)+,V_OUTPv(A3) ; restore the output vector
                moveq   #50,D0          ; close all files
                trap    #15             ; do I/O function

                rts


; output character to file from register d0

SAVE_OUT:
                movem.l D0-D2/A1,-(SP)  ; save d0, d1, d2 & a1
                move.l  file_id(A3),D1  ; get file ID back
                lea     file_byte(A3),A1 ; point to byte buffer
                move.b  D0,(A1)         ; save byte
                moveq   #1,D2           ; set byte count
                moveq   #54,D0          ; write to file
                trap    #15             ; do I/O function

                movem.l (SP)+,D0-D2/A1  ; restore d0, d1, d2 & a1
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; turn off simulator key echo

;code_start:
;                moveq   #12,D0          ; keyboard echo
;                moveq   #0,D1           ; turn off echo
;                trap    #15             ; do I/O function

; to tell EhBASIC where and how much RAM it has pass the address in a0 and the size
; in d0. these values are at the end of the .inc file

;                movea.l #ram_addr,A0    ; tell BASIC where RAM starts
;                move.l  #ram_size,D0    ; tell BASIC how big RAM is

; end of simulator specific code


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
;*
; Register use :- (must improve this !!)
;*
;       a6 -    temp Bpntr                              ; temporary BASIC execute pointer
;       a5 -    Bpntr                                   ; BASIC execute (get byte) pointer
;       a4 -    des_sk                          ; descriptor stack pointer
;       a3 -    ram_strt                                ; start of RAM. all RAM references are offsets
;                                                       ; from this value
;*

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; BASIC cold start entry point. assume entry with RAM address in a0 and RAM length
; in d0

LAB_COLD:
                cmp.l   #$4000,D0       ; compare size with 16k
                bge.s   LAB_sizok       ; branch if >= 16k

                moveq   #5,D0           ; error 5 - not enough RAM
                rts                     ; just exit. this as stands will never execute
; but could be used to exit back to an OS

LAB_sizok:
                movea.l A0,A3           ; copy RAM base to a3

                adda.l  D0,A0           ; a0 is top of RAM
                move.l  A0,Ememl(A3)    ; set end of mem
                lea     ram_base(A3),SP ; set stack to RAM start + 1k

                move.w  #$4EF9,D0       ; JMP opcode
                movea.l SP,A0           ; point to start of vector table

                move.w  D0,(A0)+        ; LAB_WARM
                lea     LAB_COLD(PC),A1 ; initial warm start vector
                move.l  A1,(A0)+        ; set vector

                move.w  D0,(A0)+        ; Usrjmp
                lea     LAB_FCER(PC),A1 ; initial user function vector
; "Function call" error
                move.l  A1,(A0)+        ; set vector

                move.w  D0,(A0)+        ; V_INPT JMP opcode
                lea     VEC_IN(PC),A1   ; get byte from input device vector
                move.l  A1,(A0)+        ; set vector

                move.w  D0,(A0)+        ; V_OUTP JMP opcode
                lea     VEC_OUT(PC),A1  ; send byte to output device vector
                move.l  A1,(A0)+        ; set vector

                move.w  D0,(A0)+        ; V_LOAD JMP opcode
                lea     VEC_LD(PC),A1   ; load BASIC program vector
                move.l  A1,(A0)+        ; set vector

                move.w  D0,(A0)+        ; V_SAVE JMP opcode
                lea     VEC_SV(PC),A1   ; save BASIC program vector
                move.l  A1,(A0)+        ; set vector

                move.w  D0,(A0)+        ; V_CTLC JMP opcode
                lea     VEC_CC(PC),A1   ; save CTRL-C check vector
                move.l  A1,(A0)+        ; set vector

; set-up start values

;*##
LAB_GMEM:
                moveq   #$00,D0         ; clear d0
                move.b  D0,Nullct(A3)   ; default NULL count
                move.b  D0,TPos(A3)     ; clear terminal position
                move.b  D0,ccflag(A3)   ; allow CTRL-C check
                move.w  D0,prg_strt-2(A3) ; clear start word
                move.w  D0,BHsend(A3)   ; clear value to string end word

                move.b  #40,TWidth(A3) ; default terminal width byte for simulator
                move.b  #$0E,TabSiz(A3) ; save default tab size = 14

                move.b  #$38,Iclim(A3)  ; default limit for TAB = 14 for simulator

                lea     des_sk(A3),A4   ; set descriptor stack start

                lea     prg_strt(A3),A0 ; get start of mem
                move.l  A0,Smeml(A3)    ; save start of mem

                bsr     LAB_1463        ; do "NEW" and "CLEAR"
                bsr     LAB_CRLF        ; print CR/LF
                move.l  Ememl(A3),D0    ; get end of mem
                sub.l   Smeml(A3),D0    ; subtract start of mem

         ;      bsr     LAB_295E        ; print d0 as unsigned integer (bytes free)
         ;      lea     LAB_SMSG(PC),A0 ; point to start message
         ;      bsr     LAB_18C3        ; print null terminated string from memory

                lea     LAB_RSED(PC),A0 ; get pointer to value
                bsr     LAB_UFAC        ; unpack memory (a0) into FAC1

                lea     LAB_1274(PC),A0 ; get warm start vector
                move.l  A0,Wrmjpv(A3)   ; set warm start vector
                bsr     LAB_RND         ; initialise
                jmp     LAB_WARM(A3)    ; go do warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do format error

LAB_FOER:
                moveq   #$2C,D7         ; error code $2C "Format" error
                bra.s   LAB_XERR        ; do error #d7, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do address error

LAB_ADER:
                moveq   #$2A,D7         ; error code $2A "Address" error
                bra.s   LAB_XERR        ; do error #d7, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; do wrong dimensions error

LAB_WDER:
                moveq   #$28,D7         ; error code $28 "Wrong dimensions" error
                bra.s   LAB_XERR        ; do error #d7, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do undimensioned array error

LAB_UDER:
                moveq   #$26,D7         ; error code $26 "undimensioned array" error
                bra.s   LAB_XERR        ; do error #d7, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do undefined variable error

LAB_UVER:

; if you do want a non existant variable to return an error then leave the novar
; value at the top of this file set to zero

                IF novar

                moveq   #$24,D7         ; error code $24 "undefined variable" error
                bra.s   LAB_XERR        ; do error #d7, then warm start

                ENDIF

; if you want a non existant variable to return a null value then set the novar
; value at the top of this file to some non zero value

                IF !novar

                add.l   D0,D0           ; .......$ .......& ........ .......0
                swap    D0              ; ........ .......0 .......$ .......&
                ror.b   #1,D0           ; ........ .......0 .......$ &.......
                lsr.w   #1,D0           ; ........ .......0 0....... $&.....­.
                and.b   #$C0,D0         ; mask the type bits
                move.b  D0,Dtypef(A3)   ; save the data type

                moveq   #0,D0           ; clear d0 and set the zero flag
                movea.l D0,A0           ; return a null address
                rts

                ENDIF


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do loop without do error

LAB_LDER:
                moveq   #$22,D7         ; error code $22 "LOOP without DO" error
                bra.s   LAB_XERR        ; do error #d7, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; do undefined function error

LAB_UFER:
                moveq   #$20,D7         ; error code $20 "Undefined function" error
                bra.s   LAB_XERR        ; do error #d7, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do can't continue error

LAB_CCER:
                moveq   #$1E,D7         ; error code $1E "Can't continue" error
                bra.s   LAB_XERR        ; do error #d7, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do string too complex error

LAB_SCER:
                moveq   #$1C,D7         ; error code $1C "String too complex" error
                bra.s   LAB_XERR        ; do error #d7, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do string too long error

LAB_SLER:
                moveq   #$1A,D7         ; error code $1A "String too long" error
                bra.s   LAB_XERR        ; do error #d7, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do type missmatch error

LAB_TMER:
                moveq   #$18,D7         ; error code $18 "Type mismatch" error
                bra.s   LAB_XERR        ; do error #d7, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do illegal direct error

LAB_IDER:
                moveq   #$16,D7         ; error code $16 "Illegal direct" error
                bra.s   LAB_XERR        ; do error #d7, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do divide by zero error

LAB_DZER:
                moveq   #$14,D7         ; error code $14 "Divide by zero" error
                bra.s   LAB_XERR        ; do error #d7, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do double dimension error

LAB_DDER:
                moveq   #$12,D7         ; error code $12 "Double dimension" error
                bra.s   LAB_XERR        ; do error #d7, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do array bounds error

LAB_ABER:
                moveq   #$10,D7         ; error code $10 "Array bounds" error
                bra.s   LAB_XERR        ; do error #d7, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do undefined satement error

LAB_USER:
                moveq   #$0E,D7         ; error code $0E "Undefined statement" error
                bra.s   LAB_XERR        ; do error #d7, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do out of memory error

LAB_OMER:
                moveq   #$0C,D7         ; error code $0C "Out of memory" error
                bra.s   LAB_XERR        ; do error #d7, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do overflow error

LAB_OFER:
                moveq   #$0A,D7         ; error code $0A "Overflow" error
                bra.s   LAB_XERR        ; do error #d7, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do function call error

LAB_FCER:
                moveq   #$08,D7         ; error code $08 "Function call" error
                bra.s   LAB_XERR        ; do error #d7, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do out of data error

LAB_ODER:
                moveq   #$06,D7         ; error code $06 "Out of DATA" error
                bra.s   LAB_XERR        ; do error #d7, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do return without gosub error

LAB_RGER:
                moveq   #$04,D7         ; error code $04 "RETURN without GOSUB" error
                bra.s   LAB_XERR        ; do error #d7, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do syntax error

LAB_SNER:
                moveq   #$02,D7         ; error code $02 "Syntax" error
                bra.s   LAB_XERR        ; do error #d7, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do next without for error

LAB_NFER:
                moveq   #$00,D7         ; error code $00 "NEXT without FOR" error


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do error #d7, then warm start

LAB_XERR:
                bsr     LAB_1491        ; flush stack & clear continue flag
                bsr     LAB_CRLF        ; print CR/LF
                lea     LAB_BAER(PC),A1 ; start of error message pointer table
                move.w  0(A1,D7.w),D7   ; get error message offset
                lea     0(A1,D7.w),A0   ; get error message address
                bsr     LAB_18C3        ; print null terminated string from memory
                lea     LAB_EMSG(PC),A0 ; point to " Error" message
LAB_1269:
                bsr     LAB_18C3        ; print null terminated string from memory
                move.l  Clinel(A3),D0   ; get current line
                bmi.s   LAB_1274        ; go do warm start if -ve # (was immediate mode)

; else print line number
                bsr     LAB_2953        ; print " in line [LINE #]"

; BASIC warm start entry point, wait for Basic command

LAB_1274:
             ;   lea     LAB_RMSG(PC),A0 ; point to "Ready" message
             ;   bsr     LAB_18C3        ; go do print string


; wait for Basic command - no "Ready"

LAB_127D:
                moveq   #-1,D1          ; set to -1
                move.l  D1,Clinel(A3)   ; set current line #
                move.b  D1,Breakf(A3)   ; set break flag
                lea     Ibuffs(A3),A5   ; set basic execute pointer ready for new line

qq:
                lea     listing,A6
                bsr     PARSE_FILE

LAB_127E:
                bsr     LAB_1357        ; call for BASIC input
                bsr     LAB_GBYT        ; scan memory
                beq.s   LAB_127E        ; loop while null

; got to interpret input line now ....

                bcs.s   LAB_newline     ; branch if numeric character, handle new
; BASIC line

; no line number so do immediate mode, a5
; points to the buffer start
                bsr     LAB_13A6        ; crunch keywords into Basic tokens
; crunch from (a5), output to (a0)
; returns ..
; d2 is length, d1 trashed, d0 trashed,
; a1 trashed
                bra     LAB_15F6        ; go scan & interpret code

LAB_newline:
                bsr.s   LAB_1295        ; run the handler
                bra.s   LAB_127D        ; now we just wait for Basic command, no "Ready"

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; handle a new BASIC line

LAB_1295:
                bsr     LAB_GFPN        ; get fixed-point number into temp integer & d1
                bsr     LAB_13A6        ; crunch keywords into Basic tokens
; crunch from (a5), output to (a0)
; returns .. d2 is length,
; d1 trashed, d0 trashed, a1 trashed
                move.l  Itemp(A3),D1    ; get r.EQUired line #
                bsr     LAB_SSLN        ; search BASIC for d1 line number
; returns pointer in a0
                bcs.s   LAB_12E6        ; branch if not found

; aroooogah! line # already exists! delete it

                movea.l (A0),A1         ; get start of block (next line pointer)
                move.l  Sfncl(A3),D0    ; get end of block (start of functions)
                sub.l   A1,D0           ; subtract start of block ( = bytes to move)
                lsr.l   #1,D0           ; /2 (word move)
                subq.l  #1,D0           ; adjust for DBF loop
                swap    D0              ; swap high word to low word
                movea.l A0,A2           ; copy destination
LAB_12AE:
                swap    D0              ; swap high word to low word
LAB_12B0:
                move.w  (A1)+,(A2)+     ; copy word
                dbra    D0,LAB_12B0     ; decrement low count and loop until done

                swap    D0              ; swap high word to low word
                dbra    D0,LAB_12AE     ; decrement high count and loop until done

                move.l  A2,Sfncl(A3)    ; start of functions
                move.l  A2,Svarl(A3)    ; save start of variables
                move.l  A2,Sstrl(A3)    ; start of strings
                move.l  A2,Sarryl(A3)   ; save start of arrays
                move.l  A2,Earryl(A3)   ; save end of arrays

; got new line in buffer and no existing same #
LAB_12E6:
                move.b  Ibuffs(A3),D0   ; get byte from start of input buffer
                beq.s   LAB_1325        ; if null line go do line chaining

; got new line and it isn't empty line
                movea.l Sfncl(A3),A1    ; get start of functions (end of block to move)
                lea     8(A1,D2.w),A2   ; copy it, add line length and add room for
; pointer and line number

                move.l  A2,Sfncl(A3)    ; start of functions
                move.l  A2,Svarl(A3)    ; save start of variables
                move.l  A2,Sstrl(A3)    ; start of strings
                move.l  A2,Sarryl(A3)   ; save start of arrays
                move.l  A2,Earryl(A3)   ; save end of arrays
                move.l  Ememl(A3),Sstorl(A3) ; copy end of mem to start of strings, clear
; strings

                move.l  A1,D1           ; copy end of block to move
                sub.l   A0,D1           ; subtract start of block to move
                lsr.l   #1,D1           ; /2 (word copy)
                subq.l  #1,D1           ; correct for loop end on -1
                swap    D1              ; swap high word to low word
LAB_12FF:
                swap    D1              ; swap high word to low word
LAB_1301:
                move.w  -(A1),-(A2)     ; decrement pointers and copy word
                dbra    D1,LAB_1301     ; decrement & loop

                swap    D1              ; swap high word to low word
                dbra    D1,LAB_12FF     ; decrement high count and loop until done

; space is opened up, now copy the crunched line from the input buffer into the space

                lea     Ibuffs(A3),A1   ; source is input buffer
                movea.l A0,A2           ; copy destination
                moveq   #-1,D1          ; set to allow re-chaining
                move.l  D1,(A2)+        ; set next line pointer (allow re-chaining)
                move.l  Itemp(A3),(A2)+ ; save line number
                lsr.w   #1,D2           ; /2 (word copy)
                subq.w  #1,D2           ; correct for loop end on -1
LAB_1303:
                move.w  (A1)+,(A2)+     ; copy word
                dbra    D2,LAB_1303     ; decrement & loop

                bra.s   LAB_1325        ; go test for end of prog

; rebuild chaining of BASIC lines

LAB_132E:
                addq.w  #8,A0           ; point to first code byte of line, there is
; always 1 byte + [EOL] as null entries are
; deleted
LAB_1330:
                tst.b   (A0)+           ; test byte
                bne.s   LAB_1330        ; loop if not [EOL]

; was [EOL] so get next line start
                move.w  A0,D1           ; past pad byte(s)
                andi.w  #1,D1           ; mask odd bit
                adda.w  D1,A0           ; add back to ensure even
                move.l  A0,(A1)         ; save next line pointer to current line
LAB_1325:
                movea.l A0,A1           ; copy pointer for this line
                tst.l   (A0)            ; test pointer to next line
                bne.s   LAB_132E        ; not end of program yet so we must
; go and fix the pointers

                bsr     LAB_1477        ; reset execution to start, clear variables
; and flush stack
                rts
;BRA           LAB_127D                        ; now we just wait for Basic command, no "Ready"


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; receive a line from the keyboard
; character $08 as delete key, BACKSPACE on
; standard keyboard
LAB_134B:
                bsr     LAB_PRNA        ; go print the character
                moveq   #' ',D0         ; load [SPACE]
                bsr     LAB_PRNA        ; go print
                moveq   #$08,D0         ; load [BACKSPACE]
                bsr     LAB_PRNA        ; go print
                subq.w  #$01,D1         ; decrement the buffer index (delete)
                bra.s   LAB_1359        ; re-enter loop

; print "? " and get BASIC input
; return a0 pointing to the buffer start

LAB_INLN:
                bsr     LAB_18E3        ; print "?" character
                moveq   #' ',D0         ; load " "
                bsr     LAB_PRNA        ; go print

; call for BASIC input (main entry point)
; return a0 pointing to the buffer start

LAB_1357:
                moveq   #$00,D1         ; clear buffer index
                lea     Ibuffs(A3),A0   ; set buffer base pointer
LAB_1359:
                jsr     V_INPT(A3)      ; call scan input device
                bcc.s   LAB_1359        ; loop if no byte

                beq.s   LAB_1359        ; loop if null byte

                cmp.b   #$07,D0         ; compare with [BELL]
                beq.s   LAB_1378        ; branch if [BELL]

                cmp.b   #$0D,D0         ; compare with [CR]
                beq     LAB_1866        ; do CR/LF exit if [CR]

                tst.w   D1              ; set flags on buffer index
                bne.s   LAB_1374        ; branch if not empty

; the next two lines ignore any non printing character and [SPACE] if the input buffer
; is empty

                cmp.b   #' ',D0         ; compare with [SP]+1
                bls.s   LAB_1359        ; if < ignore character

*##     CMP.b           #' '+1,d0                       ; compare with [SP]+1
*##     BCS.s           LAB_1359                        ; if < ignore character

LAB_1374:
                cmp.b   #$08,D0         ; compare with [BACKSPACE]
                beq.s   LAB_134B        ; go delete last character

LAB_1378:
                cmp.w   #(Ibuffe-Ibuffs-1),D1 ; compare character count with max-1
                bcc.s   LAB_138E        ; skip store & do [BELL] if buffer full

                move.b  D0,0(A0,D1.w)   ; else store in buffer
                addq.w  #$01,D1         ; increment index
LAB_137F:
                bsr     LAB_PRNA        ; go print the character
                bra.s   LAB_1359        ; always loop for next character

; announce buffer full

LAB_138E:
                moveq   #$07,D0         ; [BELL] character into d0
                bra.s   LAB_137F        ; go print the [BELL] but ignore input character


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; copy a hex value without crunching

LAB_1392:
                move.b  D0,0(A0,D2.w)   ; save the byte to the output
                addq.w  #1,D2           ; increment the buffer save index

                addq.w  #1,D1           ; increment the buffer read index
                move.b  0(A5,D1.w),D0   ; get a byte from the input buffer
                beq     LAB_13EC        ; if [EOL] go save it without crunching

                cmp.b   #' ',D0         ; compare the character with " "
                beq.s   LAB_1392        ; if [SPACE] just go save it and get another

                cmp.b   #'0',D0         ; compare the character with "0"
                bcs.s   LAB_13C6        ; if < "0" quit the hex save loop

                cmp.b   #'9',D0         ; compare with "9"
                bls.s   LAB_1392        ; if it is "0" to "9" save it and get another

                moveq   #-33,D5         ; mask xx0x xxxx, ASCII upper case
                and.b   D0,D5           ; mask the character

                cmp.b   #'A',D5         ; compare with "A"
                bcs.s   LAB_13CC        ; if < "A" quit the hex save loop

                cmp.b   #'F',D5         ; compare with "F"
                bls.s   LAB_1392        ; if it is "A" to "F" save it and get another

                bra.s   LAB_13CC        ; else continue crunching

; crunch keywords into Basic tokens
; crunch from (a5), output to (a0)
; returns ..
; d4 trashed
; d3 trashed
; d2 is length
; d1 trashed
; d0 trashed
; a1 trashed

; this is the improved BASIC crunch routine and is 10 to 100 times faster than the
; old list search

LAB_13A6:
                moveq   #0,D1           ; clear the read index
                move.l  D1,D2           ; clear the save index
                move.b  D1,Oquote(A3)   ; clear the open quote/DATA flag
LAB_13AC:
                moveq   #0,D0           ; clear word
                move.b  0(A5,D1.w),D0   ; get byte from input buffer
                beq.s   LAB_13EC        ; if null save byte then continue crunching

                cmp.b   #'_',D0         ; compare with "_"
                bcc.s   LAB_13EC        ; if >= "_" save byte then continue crunching

                cmp.b   #'<',D0         ; compare with "<"
                bcc.s   LAB_13CC        ; if >= "<" go crunch

                cmp.b   #'0',D0         ; compare with "0"
                bcc.s   LAB_13EC        ; if >= "0" save byte then continue crunching

                move.b  D0,Asrch(A3)    ; save buffer byte as search character
                cmp.b   #$22,D0         ; is it quote character?
                beq.s   LAB_1410        ; branch if so (copy quoted string)

                cmp.b   #'$',D0         ; is it the hex value character?
                beq.s   LAB_1392        ; if so go copy a hex value

LAB_13C6:
                cmp.b   #'*',D0         ; compare with "*"
                bcs.s   LAB_13EC        ; if <= "*" save byte then continue crunching

; crunch rest
LAB_13CC:
                btst    #6,Oquote(A3)   ; test open quote/DATA token flag
                bne.s   LAB_13EC        ; branch if b6 of Oquote set (was DATA)
; go save byte then continue crunching

                sub.b   #$2A,D0         ; normalise byte
                add.w   D0,D0           ; *2 makes word offset (high byte=$00)
                lea     TAB_CHRT(PC),A1 ; get keyword offset table address
                move.w  0(A1,D0.w),D0   ; get offset into keyword table
                bmi.s   LAB_141F        ; branch if no keywords for character

                lea     TAB_STAR(PC),A1 ; get keyword table address
                adda.w  D0,A1           ; add keyword offset
                moveq   #-1,D3          ; clear index
                move.w  D1,D4           ; copy read index
LAB_13D6:
                addq.w  #1,D3           ; increment table index
                move.b  0(A1,D3.w),D0   ; get byte from table
LAB_13D8:
                bmi.s   LAB_13EA        ; branch if token, save token and continue
; crunching

                addq.w  #1,D4           ; increment read index
                cmp.b   0(A5,D4.w),D0   ; compare byte from input buffer
                beq.s   LAB_13D6        ; loop if character match

                bra.s   LAB_1417        ; branch if no match

LAB_13EA:
                move.w  D4,D1           ; update read index
LAB_13EC:
                move.b  D0,0(A0,D2.w)   ; save byte to output
                addq.w  #1,D2           ; increment buffer save index
                addq.w  #1,D1           ; increment buffer read index
                tst.b   D0              ; set flags
                beq.s   LAB_142A        ; branch if was null [EOL]

; d0 holds token or byte here
                sub.b   #$3A,D0         ; subtract ":"
                beq.s   LAB_13FF        ; branch if it was ":" (is now $00)

; d0 now holds token-$3A
                cmp.b   #(TK_DATA-$3A),D0 ; compare with DATA token - $3A
                bne.s   LAB_1401        ; branch if not DATA

; token was : or DATA
LAB_13FF:
                move.b  D0,Oquote(A3)   ; save token-$3A ($00 for ":", TK_DATA-$3A for
; DATA)
LAB_1401:
                sub.b   #(TK_REM-$3A),D0 ; subtract REM token offset
                bne     LAB_13AC        ; If wasn't REM then go crunch rest of line

                move.b  D0,Asrch(A3)    ; else was REM so set search for [EOL]

; loop for REM, "..." etc.
LAB_1408:
                move.b  0(A5,D1.w),D0   ; get byte from input buffer
                beq.s   LAB_13EC        ; branch if null [EOL]

                cmp.b   Asrch(A3),D0    ; compare with stored character
                beq.s   LAB_13EC        ; branch if match (end quote, REM, :, or DATA)

; entry for copy string in quotes, don't crunch
LAB_1410:
                move.b  D0,0(A0,D2.w)   ; save byte to output
                addq.w  #1,D2           ; increment buffer save index
                addq.w  #1,D1           ; increment buffer read index
                bra.s   LAB_1408        ; loop

; not found keyword this go so find the end of this word in the table

LAB_1417:
                move.w  D1,D4           ; reset read pointer
LAB_141B:
                addq.w  #1,D3           ; increment keyword table pointer, flag
; unchanged
                move.b  0(A1,D3.w),D0   ; get keyword table byte
                bpl.s   LAB_141B        ; if not end of keyword go do next byte

                addq.w  #1,D3           ; increment keyword table pointer flag
; unchanged
                move.b  0(A1,D3.w),D0   ; get keyword table byte
                bne.s   LAB_13D8        ; go test next word if not zero byte (table end)

; reached end of table with no match
LAB_141F:
                move.b  0(A5,D1.w),D0   ; restore byte from input buffer
                bra.s   LAB_13EC        ; go save byte in output and continue crunching

; reached [EOL]
LAB_142A:
                moveq   #0,D0           ; ensure longword clear
                btst    D0,D2           ; test odd bit (fastest)
                beq.s   LAB_142C        ; branch if no bytes to fill

                move.b  D0,0(A0,D2.w)   ; clear next byte
                addq.w  #1,D2           ; increment buffer save index
LAB_142C:
                move.l  D0,0(A0,D2.w)   ; clear next line pointer, EOT in immediate mode
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; search Basic for d1 line number from start of mem

LAB_SSLN:
                movea.l Smeml(A3),A0    ; get start of program mem
                bra.s   LAB_SCLN        ; go search for r.EQUired line from a0

LAB_145F:
                movea.l D0,A0           ; copy next line pointer

; search Basic for d1 line number from a0
; returns Cb=0 if found
; returns a0 pointer to found or next higher (not found) line

LAB_SCLN:
                move.l  (A0)+,D0        ; get next line pointer and point to line #
                beq.s   LAB_145E        ; is end marker so we're done, do 'no line' exit

                cmp.l   (A0),D1         ; compare this line # with r.EQUired line #
                bgt.s   LAB_145F        ; loop if r.EQUired # > this #

                subq.w  #4,A0           ; adjust pointer, flags not changed
                rts

LAB_145E:
                subq.w  #4,A0           ; adjust pointer, flags not changed
                subq.l  #1,D0           ; make end program found = -1, set carry
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform NEW

LAB_NEW:
                bne.s   RTS_005         ; exit if not end of statement (do syntax error)

LAB_1463:
                movea.l Smeml(A3),A0    ; point to start of program memory
                moveq   #0,D0           ; clear longword
                move.l  D0,(A0)+        ; clear first line, next line pointer
                move.l  A0,Sfncl(A3)    ; set start of functions

; reset execution to start, clear variables and flush stack

LAB_1477:
                movea.l Smeml(A3),A5    ; reset BASIC execute pointer
                subq.w  #1,A5           ; -1 (as end of previous line)

; "CLEAR" command gets here

LAB_147A:
                move.l  Ememl(A3),Sstorl(A3) ; save end of mem as bottom of string space
                move.l  Sfncl(A3),D0    ; get start of functions
                move.l  D0,Svarl(A3)    ; start of variables
                move.l  D0,Sstrl(A3)    ; start of strings
                move.l  D0,Sarryl(A3)   ; set start of arrays
                move.l  D0,Earryl(A3)   ; set end of arrays
LAB_1480:
                moveq   #0,D0           ; set Zb
                move.b  D0,ccnull(A3)   ; clear get byte countdown
                bsr     LAB_RESTORE     ; perform RESTORE command

; flush stack & clear continue flag

LAB_1491:
                lea     des_sk(A3),A4   ; reset descriptor stack pointer

                movem.l (SP)+,D0-D1     ; pull 2 return addresses (at most)
                lea     ram_base(A3),SP ; set stack to RAM start + 1k, flush stack
                movem.l D0-D1,-(SP)     ; restore 2 return address

                moveq   #0,D0           ; clear longword
                move.l  D0,Cpntrl(A3)   ; clear continue pointer
                move.b  D0,Sufnxf(A3)   ; clear subscript/FNX flag
RTS_005:
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform CLEAR

LAB_CLEAR:
                beq.s   LAB_147A        ; if no following byte go do "CLEAR"

                rts                     ; was following byte (go do syntax error)


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform LIST [n][-m]

LAB_LIST:
                bcs.s   LAB_14BD        ; branch if next character numeric (LIST n...)

                moveq   #-1,D1          ; set end to $FFFFFFFF
                move.l  D1,Itemp(A3)    ; save to Itemp

                moveq   #0,D1           ; set start to $00000000
                tst.b   D0              ; test next byte
                beq.s   LAB_14C0        ; branch if next character [NULL] (LIST)

                cmp.b   #TK_MINUS,D0    ; compare with token for -
                bne.s   RTS_005         ; exit if not - (LIST -m)

; LIST [[n]-[m]] this sets the n, if present,
; as the start and end
LAB_14BD:
                bsr     LAB_GFPN        ; get fixed-point number into temp integer & d1
LAB_14C0:
                bsr     LAB_SSLN        ; search BASIC for d1 line number
; (pointer in a0)
                bsr     LAB_GBYT        ; scan memory
                beq.s   LAB_14D4        ; branch if no more characters

; this bit checks the - is present
                cmp.b   #TK_MINUS,D0    ; compare with token for -
                bne.s   RTS_005         ; return if not "-" (will be Syntax error)

                moveq   #-1,D1          ; set end to $FFFFFFFF
                move.l  D1,Itemp(A3)    ; save Itemp

; LIST [n]-[m] the - was there so see if
; there is an m to set as the end value
                bsr     LAB_IGBY        ; increment & scan memory
                beq.s   LAB_14D4        ; branch if was [NULL] (LIST n-)

                bsr     LAB_GFPN        ; get fixed-point number into temp integer & d1
LAB_14D4:
                move.b  #$00,Oquote(A3) ; clear open quote flag
                bsr     LAB_CRLF        ; print CR/LF
                move.l  (A0)+,D0        ; get next line pointer

                beq.s   RTS_005         ; if null all done so exit

                movea.l D0,A1           ; copy next line pointer
                bsr     LAB_1629        ; do CRTL-C check vector

                move.l  (A0)+,D0        ; get this line #
                cmp.l   Itemp(A3),D0    ; compare end line # with this line #
                bhi.s   RTS_005         ; if this line greater all done so exit

LAB_14E2:
                movem.l A0-A1,-(SP)     ; save registers
                bsr     LAB_295E        ; print d0 as unsigned integer
                movem.l (SP)+,A0-A1     ; restore registers
                moveq   #$20,D0         ; space is the next character
LAB_150C:
                bsr     LAB_PRNA        ; go print the character
                cmp.b   #$22,D0         ; was it " character
                bne.s   LAB_1519        ; branch if not

; we're either entering or leaving quotes
                eori.b  #$FF,Oquote(A3) ; toggle open quote flag
LAB_1519:
                move.b  (A0)+,D0        ; get byte and increment pointer
                bne.s   LAB_152E        ; branch if not [EOL] (go print)

; was [EOL]
                movea.l A1,A0           ; copy next line pointer
                move.l  A0,D0           ; copy to set flags
                bne.s   LAB_14D4        ; go do next line if not [EOT]

                rts

LAB_152E:
                bpl.s   LAB_150C        ; just go print it if not token byte

; else it was a token byte so maybe uncrunch it
                tst.b   Oquote(A3)      ; test the open quote flag
                bmi.s   LAB_150C        ; just go print character if open quote set

; else uncrunch BASIC token
                lea     LAB_KEYT(PC),A2 ; get keyword table address
                moveq   #$7F,D1         ; mask into d1
                and.b   D0,D1           ; copy and mask token
                lsl.w   #2,D1           ; *4
                lea     0(A2,D1.w),A2   ; get keyword entry address
                move.b  (A2)+,D0        ; get byte from keyword table
                bsr     LAB_PRNA        ; go print the first character
                moveq   #0,D1           ; clear d1
                move.b  (A2)+,D1        ; get remaining length byte from keyword table
                bmi.s   LAB_1519        ; if -ve done so go get next byte

                move.w  (A2),D0         ; get offset to rest
                lea     TAB_STAR(PC),A2 ; get keyword table address
                lea     0(A2,D0.w),A2   ; get address of rest
LAB_1540:
                move.b  (A2)+,D0        ; get byte from keyword table
                bsr     LAB_PRNA        ; go print the character
                dbra    D1,LAB_1540     ; decrement and loop if more to do

                bra.s   LAB_1519        ; go get next byte


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform FOR

LAB_FOR:
                bsr     LAB_LET         ; go do LET

                move.l  Lvarpl(A3),D0   ; get the loop variable pointer
                cmp.l   Sstrl(A3),D0    ; compare it with the end of vars memory
                bge     LAB_TMER        ; if greater go do type mismatch error

; test for not less than the start of variables memory if needed
;*
;       CMP.l           Svarl(a3),d0            ; compare it with the start of variables memory
;       BLT             LAB_TMER                        ; if not variables memory do type mismatch error

;       MOVEQ           #28,d0                  ; we need 28 bytes !
;       BSR.s           LAB_1212                        ; check room on stack for d0 bytes

                bsr     LAB_SNBS        ; scan for next BASIC statement ([:] or [EOL])
; returns a0 as pointer to [:] or [EOL]
                move.l  A0,(SP)         ; push onto stack (and dump the return address)
                move.l  Clinel(A3),-(SP) ; push current line onto stack

                moveq   #TK_TO-$0100,D0 ; set "TO" token
                bsr     LAB_SCCA        ; scan for CHR$(d0) else syntax error/warm start
                bsr     LAB_CTNM        ; check if source is numeric, else type mismatch
                move.b  Dtypef(A3),-(SP) ; push the FOR variable data type onto stack
                bsr     LAB_EVNM        ; evaluate expression and check is numeric else
; do type mismatch

                move.l  FAC1_m(A3),-(SP) ; push TO value mantissa
                move.w  FAC1_e(A3),-(SP) ; push TO value exponent and sign

                move.l  #$80000000,FAC1_m(A3) ; set default STEP size mantissa
                move.w  #$8100,FAC1_e(A3) ; set default STEP size exponent and sign

                bsr     LAB_GBYT        ; scan memory
                cmp.b   #TK_STEP,D0     ; compare with STEP token
                bne.s   LAB_15B3        ; jump if not "STEP"

; was STEP token so ....
                bsr     LAB_IGBY        ; increment & scan memory
                bsr     LAB_EVNM        ; evaluate expression & check is numeric
; else do type mismatch
LAB_15B3:
                move.l  FAC1_m(A3),-(SP) ; push STEP value mantissa
                move.w  FAC1_e(A3),-(SP) ; push STEP value exponent and sign

                move.l  Lvarpl(A3),-(SP) ; push variable pointer for FOR/NEXT
                move.w  #TK_FOR,-(SP)   ; push FOR token on stack

                bra.s   LAB_15C2        ; go do interpreter inner loop

LAB_15DC:                               ; have reached [EOL]+1
                move.w  A5,D0           ; copy BASIC execute pointer
                and.w   #1,D0           ; and make line start address even
                adda.w  D0,A5           ; add to BASIC execute pointer
                move.l  (A5)+,D0        ; get next line pointer
                beq     LAB_1274        ; if null go to immediate mode, no "BREAK"
; message (was immediate or [EOT] marker)

                move.l  (A5)+,Clinel(A3) ; save (new) current line #
LAB_15F6:
                bsr     LAB_GBYT        ; get BASIC byte
                bsr.s   LAB_15FF        ; go interpret BASIC code from (a5)

; interpreter inner loop (re)entry point

LAB_15C2:
        ;        bsr.s   LAB_1629        ; do CRTL-C check vector
        ;        tst.b   Clinel(A3)      ; test current line #, is -ve for immediate mode
        ;        bmi.s   LAB_15D1        ; branch if immediate mode

                move.l  A5,Cpntrl(A3)   ; save BASIC execute pointer as continue pointer
LAB_15D1:
                move.b  (A5)+,D0        ; get this byte & increment pointer
                beq.s   LAB_15DC        ; loop if [EOL]

                cmp.b   #$3A,D0         ; compare with ":"
                beq.s   LAB_15F6        ; loop if was statement separator

                bra     LAB_SNER        ; else syntax error, then warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; interpret BASIC code from (a5)

LAB_15FF:
                beq     RTS_006         ; exit if zero [EOL]

LAB_1602:
                eori.b  #$80,D0         ; normalise token
                bmi     LAB_LET         ; if not token, go do implied LET

                cmp.b   #(TK_TAB-$80),D0 ; compare normalised token with TAB
                bcc     LAB_SNER        ; branch if d0>=TAB, syntax error/warm start
; only tokens before TAB can start a statement

                ext.w   D0              ; byte to word (clear high byte)
				lsl.w	#2,d0
				move.l	LAB_CTBL(PC,d0.w),-(a7)
				bra		LAB_IGBY

 ;              add.w   D0,D0           ; *2
 ;              lea     LAB_CTBL(PC),A0 ; get vector table base address
 ;              move.w  0(A0,D0.w),D0   ; get offset to vector
 ;              pea     0(A0,D0.w)      ; push vector
 ;              bra     LAB_IGBY        ; get following byte & execute vector

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; command vector table

LAB_CTBL:
                dc.l LAB_END ; END
                dc.l LAB_FOR ; FOR
                dc.l LAB_NEXT ; NEXT
                dc.l LAB_DATA ; DATA
                dc.l LAB_INPUT ; INPUT
                dc.l LAB_DIM ; DIM
                dc.l LAB_READ ; READ
                dc.l LAB_LET ; LET
                dc.l LAB_DEC ; DEC
                dc.l LAB_GOTO ; GOTO
                dc.l LAB_RUN ; RUN
                dc.l LAB_IF ; IF
                dc.l LAB_RESTORE ; RESTORE
                dc.l LAB_GOSUB ; GOSUB
                dc.l LAB_RETURN ; RETURN
                dc.l LAB_REM ; REM
                dc.l LAB_STOP ; STOP
                dc.l LAB_ON ; ON
                dc.l LAB_NULL ; NULL
                dc.l LAB_INC ; INC
                dc.l LAB_WAIT ; WAIT
                dc.l LAB_LOAD ; LOAD
                dc.l LAB_SAVE ; SAVE
                dc.l LAB_DEF ; DEF
                dc.l LAB_POKE ; POKE
                dc.l LAB_DOKE ; DOKE
                dc.l LAB_LOKE ; LOKE
                dc.l LAB_CALL ; CALL
                dc.l LAB_DO ; DO
                dc.l LAB_LOOP ; LOOP
                dc.l LAB_PRINT ; PRINT
                dc.l LAB_CONT ; CONT
                dc.l LAB_LIST ; LIST
                dc.l LAB_CLEAR ; CLEAR
                dc.l LAB_NEW ; NEW
                dc.l LAB_WDTH ; WIDTH
                dc.l LAB_GET ; GET
                dc.l LAB_SWAP ; SWAP
                dc.l LAB_BITSET ; BITSET
                dc.l LAB_BITCLR ; BITCLR
				dc.l LAB_RPRINT 				; RPRINT
				dc.l LAB_RSETOBJ 				; RSETOBJ
				dc.l LAB_RUPDALL 				; RUPDALL
				dc.l LAB_RSETLIST 				; RSETLIST
				dc.l LAB_U235MOD 				; U235MOD()	
				dc.l LAB_U235SND				; U235SND()
				dc.l LAB_CLS					; CLS
				dc.l LAB_SETCUR				; SETCUR()
				dc.l LAB_PLOT					; PLOT()
				dc.l LAB_COLOUR				; COLOUR()
				dc.l LAB_RPARTI				; RPARTI()
				dc.l LAB_RSETMAP			; RSETMAP()
				
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; CTRL-C check jump. this is called as a subroutine but exits back via a jump if a
; key press is detected.

LAB_1629:
                rts
                jmp     V_CTLC(A3)      ; ctrl c check vector

; if there was a key press it gets back here .....

LAB_1636:
                cmp.b   #$03,D0         ; compare with CTRL-C
                beq.s   LAB_163B        ; STOP if was CTRL-C

LAB_1639:
                rts                     ;*


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform END

LAB_END:
                bne.s   LAB_1639        ; exit if something follows STOP
                move.b  #0,Breakf(A3)   ; clear break flag, indicate program end


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform STOP

LAB_STOP:
                bne.s   LAB_1639        ; exit if something follows STOP

LAB_163B:
                lea     Ibuffe(A3),A1   ; get buffer end
                cmpa.l  A1,A5           ; compare execute address with buffer end
                bcs.s   LAB_164F        ; branch if BASIC pointer is in buffer
; can't continue in immediate mode

; else...
                move.l  A5,Cpntrl(A3)   ; save BASIC execute pointer as continue pointer
LAB_1647:
                move.l  Clinel(A3),Blinel(A3) ; save break line
LAB_164F:
                addq.w  #4,SP           ; dump return address, don't return to execute
; loop
                move.b  Breakf(A3),D0   ; get break flag
                beq     LAB_1274        ; go do warm start if was program end

                lea     LAB_BMSG(PC),A0 ; point to "Break"
                bra     LAB_1269        ; print "Break" and do warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform RESTORE

LAB_RESTORE:
                movea.l Smeml(A3),A0    ; copy start of memory
                beq.s   LAB_1624        ; branch if next character null (RESTORE)

                bsr     LAB_GFPN        ; get fixed-point number into temp integer & d1
                cmp.l   Clinel(A3),D1   ; compare current line # with r.EQUired line #
                bls.s   LAB_GSCH        ; branch if >= (start search from beginning)

                movea.l A5,A0           ; copy BASIC execute pointer
LAB_RESs:
                tst.b   (A0)+           ; test next byte & increment pointer
                bne.s   LAB_RESs        ; loop if not EOL

                move.w  A0,D0           ; copy pointer
                and.w   #1,D0           ; mask odd bit
                adda.w  D0,A0           ; add pointer
; search for line in Itemp from (a0)
LAB_GSCH:
                bsr     LAB_SCLN        ; search for d1 line number from a0
; returns Cb=0 if found
                bcs     LAB_USER        ; go do "Undefined statement" error if not found

LAB_1624:
                tst.b   -(A0)           ; decrement pointer (faster)
                move.l  A0,Dptrl(A3)    ; save DATA pointer
RTS_006:
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform NULL

LAB_NULL:
                bsr     LAB_GTBY        ; get byte parameter, result in d0 and Itemp
                move.b  D0,Nullct(A3)   ; save new NULL count
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform CONT

LAB_CONT:
                bne     LAB_SNER        ; if following byte exit to do syntax error

                tst.b   Clinel(A3)      ; test current line #, is -ve for immediate mode
                bpl     LAB_CCER        ; if running go do can't continue error

                move.l  Cpntrl(A3),D0   ; get continue pointer
                beq     LAB_CCER        ; go do can't continue error if we can't

; we can continue so ...
                movea.l D0,A5           ; save continue pointer as BASIC execute pointer
                move.l  Blinel(A3),Clinel(A3) ; set break line as current line
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform RUN

LAB_RUN:
                bne.s   LAB_RUNn        ; if following byte do RUN n

                bsr     LAB_1477        ; execution to start, clear vars & flush stack
                move.l  A5,Cpntrl(A3)   ; save as continue pointer
                bra     LAB_15C2        ; go do interpreter inner loop
; (can't RTS, we flushed the stack!)

LAB_RUNn:
                bsr     LAB_147A        ; go do "CLEAR"
                bra.s   LAB_16B0        ; get n and do GOTO n


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform DO

LAB_DO:
;       MOVE.l  #$05,d0                 ; need 5 bytes for DO
;       BSR.s           LAB_1212                        ; check room on stack for A bytes
                move.l  A5,-(SP)        ; push BASIC execute pointer on stack
                move.l  Clinel(A3),-(SP) ; push current line on stack
                move.w  #TK_DO,-(SP)    ; push token for DO on stack
                pea     LAB_15C2(PC)    ; set return address
                bra     LAB_GBYT        ; scan memory & return to interpreter inner loop


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform GOSUB

LAB_GOSUB:
;       MOVE.l  #10,d0                  ; need 10 bytes for GOSUB
;       BSR.s           LAB_1212                        ; check room on stack for d0 bytes
                move.l  A5,-(SP)        ; push BASIC execute pointer
                move.l  Clinel(A3),-(SP) ; push current line
                move.w  #TK_GOSUB,-(SP) ; push token for GOSUB
LAB_16B0:
                bsr     LAB_GBYT        ; scan memory
                pea     LAB_15C2(PC)    ; return to interpreter inner loop after GOTO n

; this PEA is needed because either we just cleared the stack and have nowhere to return
; to or, in the case of GOSUB, we have just dropped a load on the stack and the address
; we whould have returned to is buried. This burried return address will be unstacked by
; the corresponding RETURN command


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform GOTO

LAB_GOTO:
                bsr     LAB_GFPN        ; get fixed-point number into temp integer & d1
                movea.l Smeml(A3),A0    ; get start of memory
                cmp.l   Clinel(A3),D1   ; compare current line with wanted #
                bls.s   LAB_16D0        ; branch if current # => wanted #

                movea.l A5,A0           ; copy BASIC execute pointer
LAB_GOTs:
                tst.b   (A0)+           ; test next byte & increment pointer
                bne.s   LAB_GOTs        ; loop if not EOL

                move.w  A0,D0           ; past pad byte(s)
                and.w   #1,D0           ; mask odd bit
                adda.w  D0,A0           ; add to pointer

LAB_16D0:
                bsr     LAB_SCLN        ; search for d1 line number from a0
; returns Cb=0 if found
                bcs     LAB_USER        ; if carry set go do "Undefined statement" error

                movea.l A0,A5           ; copy to basic execute pointer
                subq.w  #1,A5           ; decrement pointer
                move.l  A5,Cpntrl(A3)   ; save as continue pointer
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform LOOP

LAB_LOOP:
                cmpi.w  #TK_DO,4(SP)    ; compare token on stack with DO token
                bne     LAB_LDER        ; branch if no matching DO

                move.b  D0,D7           ; copy following token (byte)
                beq.s   LoopAlways      ; if no following token loop forever

                cmp.b   #':',D7         ; compare with ":"
                beq.s   LoopAlways      ; if no following token loop forever

                sub.b   #TK_UNTIL,D7    ; subtract token for UNTIL
                beq.s   DoRest          ; branch if was UNTIL

                subq.b  #1,D7           ; decrement result
                bne     LAB_SNER        ; if not WHILE go do syntax error & warm start
; only if the token was WHILE will this fail

                moveq   #-1,D7          ; set invert result longword
DoRest:
                bsr     LAB_IGBY        ; increment & scan memory
                bsr     LAB_EVEX        ; evaluate expression
                tst.b   FAC1_e(A3)      ; test FAC1 exponent
                beq.s   DoCmp           ; if = 0 go do straight compare

                move.b  #$FF,FAC1_e(A3) ; else set all bits
DoCmp:
                eor.b   D7,FAC1_e(A3)   ; EOR with invert byte
                bne.s   LoopDone        ; if <> 0 clear stack & back to interpreter loop

; loop condition wasn't met so do it again
LoopAlways:
                move.l  6(SP),Clinel(A3) ; copy DO current line
                movea.l 10(SP),A5       ; save BASIC execute pointer

                lea     LAB_15C2(PC),A0 ; get return address
                move.l  A0,(SP)         ; dump the call to this routine and set the
; return address
                bra     LAB_GBYT        ; scan memory and return to interpreter inner
; loop

; clear stack & back to interpreter loop
LoopDone:
                lea     14(SP),SP       ; dump structure and call from stack
                bra.s   LAB_DATA        ; go perform DATA (find : or [EOL])


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform RETURN

LAB_RETURN:
                bne.s   RTS_007         ; exit if following token to allow syntax error

                cmpi.w  #TK_GOSUB,4(SP) ; compare token from stack with GOSUB
                bne     LAB_RGER        ; do RETURN without GOSUB error if no matching
; GOSUB

                addq.w  #6,SP           ; dump calling address & token
                move.l  (SP)+,Clinel(A3) ; pull current line
                movea.l (SP)+,A5        ; pull BASIC execute pointer
; now do perform "DATA" statement as we could be
; returning into the middle of an ON <var> GOSUB
; n,m,p,q line (the return address used by the
; DATA statement is the one pushed before the
; GOSUB was executed!)


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform DATA

LAB_DATA:
                bsr.s   LAB_SNBS        ; scan for next BASIC statement ([:] or [EOL])
; returns a0 as pointer to [:] or [EOL]
                movea.l A0,A5           ; skip rest of statement
RTS_007:
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; scan for next BASIC statement ([:] or [EOL])
; returns a0 as pointer to [:] or [EOL]

LAB_SNBS:
                movea.l A5,A0           ; copy BASIC execute pointer
                moveq   #$22,D1         ; set string quote character
                moveq   #$3A,D2         ; set look for character = ":"
                bra.s   LAB_172D        ; go do search

LAB_172C:
                cmp.b   D0,D2           ; compare with ":"
                beq.s   RTS_007a        ; exit if found

                cmp.b   D0,D1           ; compare with '"'
                beq.s   LAB_1725        ; if found go search for [EOL]

LAB_172D:
                move.b  (A0)+,D0        ; get next byte
                bne.s   LAB_172C        ; loop if not null [EOL]

RTS_007a:
                subq.w  #1,A0           ; correct pointer
                rts

LAB_1723:
                cmp.b   D0,D1           ; compare with '"'
                beq.s   LAB_172D        ; if found go search for ":" or [EOL]

LAB_1725:
                move.b  (A0)+,D0        ; get next byte
                bne.s   LAB_1723        ; loop if not null [EOL]

                bra.s   RTS_007a        ; correct pointer & return


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform IF

LAB_IF:
                bsr     LAB_EVEX        ; evaluate expression
                bsr     LAB_GBYT        ; scan memory
                cmp.b   #TK_THEN,D0     ; compare with THEN token
                beq.s   LAB_174B        ; if it was THEN then continue

; wasn't IF .. THEN so must be IF .. GOTO
                cmp.b   #TK_GOTO,D0     ; compare with GOTO token
                bne     LAB_SNER        ; if not GOTO token do syntax error/warm start

; was GOTO so check for GOTO <n>
                movea.l A5,A0           ; save the execute pointer
                bsr     LAB_IGBY        ; scan memory, test for a numeric character
                movea.l A0,A5           ; restore the execute pointer
                bcc     LAB_SNER        ; if not numeric do syntax error/warm start

LAB_174B:
                move.b  FAC1_e(A3),D0   ; get FAC1 exponent
                beq.s   LAB_174E        ; if result was zero go look for an ELSE

                bsr     LAB_IGBY        ; increment & scan memory
                bcs     LAB_GOTO        ; if numeric do GOTO n
; a GOTO <n> will never return to the IF
; statement so there is no need to return
; to this code

                cmp.b   #TK_RETURN,D0   ; compare with RETURN token
                beq     LAB_1602        ; if RETURN then interpret BASIC code from (a5)
; and don't return here

                bsr     LAB_15FF        ; else interpret BASIC code from (a5)

; the IF was executed and there may be a following ELSE so the code needs to return
; here to check and ignore the ELSE if present

                move.b  (A5),D0         ; get the next basic byte
                cmp.b   #TK_ELSE,D0     ; compare it with the token for ELSE
                beq     LAB_DATA        ; if ELSE ignore the following statement

; there was no ELSE so continue execution of IF <expr> THEN <stat> [: <stat>]. any
; following ELSE will, correctly, cause a syntax error

                rts                     ; else return to interpreter inner loop

; perform ELSE after IF

LAB_174E:
                move.b  (A5)+,D0        ; faster increment past THEN
                moveq   #TK_ELSE,D3     ; set search for ELSE token
                moveq   #TK_IF,D4       ; set search for IF token
                moveq   #0,D5           ; clear the nesting depth
LAB_1750:
                move.b  (A5)+,D0        ; get next BASIC byte & increment ptr
                beq.s   LAB_1754        ; if EOL correct the pointer and return

                cmp.b   D4,D0           ; compare with "IF" token
                bne.s   LAB_1752        ; skip if not nested IF

                addq.w  #1,D5           ; else increment the nesting depth ..
                bra.s   LAB_1750        ; .. and continue looking

LAB_1752:
                cmp.b   D3,D0           ; compare with ELSE token
                bne.s   LAB_1750        ; if not ELSE continue looking

LAB_1756:
                dbra    D5,LAB_1750     ; loop if still nested

; found the matching ELSE, now do <{n|statement}>

                bsr     LAB_GBYT        ; scan memory
                bcs     LAB_GOTO        ; if numeric do GOTO n
; code will return to the interpreter loop
; at the tail end of the GOTO <n>

                bra     LAB_15FF        ; else interpret BASIC code from (a5)
; code will return to the interpreter loop
; at the tail end of the <statement>


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform REM, skip (rest of) line

LAB_REM:
                tst.b   (A5)+           ; test byte & increment pointer
                bne.s   LAB_REM         ; loop if not EOL

LAB_1754:
                subq.w  #1,A5           ; correct the execute pointer
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform ON

LAB_ON:
                bsr     LAB_GTBY        ; get byte parameter, result in d0 and Itemp
                move.b  D0,D2           ; copy byte
                bsr     LAB_GBYT        ; restore BASIC byte
                move.w  D0,-(SP)        ; push GOTO/GOSUB token
                cmp.b   #TK_GOSUB,D0    ; compare with GOSUB token
                beq.s   LAB_176C        ; branch if GOSUB

                cmp.b   #TK_GOTO,D0     ; compare with GOTO token
                bne     LAB_SNER        ; if not GOTO do syntax error, then warm start

; next character was GOTO or GOSUB

LAB_176C:
                subq.b  #1,D2           ; decrement index (byte value)
                bne.s   LAB_1773        ; branch if not zero

                move.w  (SP)+,D0        ; pull GOTO/GOSUB token
                bra     LAB_1602        ; go execute it

LAB_1773:
                bsr     LAB_IGBY        ; increment & scan memory
                bsr.s   LAB_GFPN        ; get fixed-point number into temp integer & d1
; (skip this n)
                cmp.b   #$2C,D0         ; compare next character with ","
                beq.s   LAB_176C        ; loop if ","

                move.w  (SP)+,D0        ; pull GOTO/GOSUB token (run out of options)
                rts                     ; and exit


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; get fixed-point number into temp integer & d1
; interpret number from (a5), leave (a5) pointing to byte after #

LAB_GFPN:
                moveq   #$00,D1         ; clear integer register
                move.l  D1,D0           ; clear d0
                bsr     LAB_GBYT        ; scan memory, Cb=1 if "0"-"9", & get byte
                bcc.s   LAB_1786        ; return if carry clear, chr was not "0"-"9"

                move.l  D2,-(SP)        ; save d2
LAB_1785:
                move.l  D1,D2           ; copy integer register
                add.l   D1,D1           ; *2
                bcs     LAB_SNER        ; if overflow do syntax error, then warm start

                add.l   D1,D1           ; *4
                bcs     LAB_SNER        ; if overflow do syntax error, then warm start

                add.l   D2,D1           ; *1 + *4
                bcs     LAB_SNER        ; if overflow do syntax error, then warm start

                add.l   D1,D1           ; *10
                bcs     LAB_SNER        ; if overflow do syntax error, then warm start

                sub.b   #$30,D0         ; subtract $30 from byte
                add.l   D0,D1           ; add to integer register, the top 24 bits are
; always clear
                bvs     LAB_SNER        ; if overflow do syntax error, then warm start
; this makes the maximum line number 2147483647
                bsr     LAB_IGBY        ; increment & scan memory
                bcs.s   LAB_1785        ; loop for next character if "0"-"9"

                move.l  (SP)+,D2        ; restore d2
LAB_1786:
                move.l  D1,Itemp(A3)    ; save Itemp
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform DEC

LAB_DEC:
                move.w  #$8180,-(SP)    ; set -1 sign/exponent
                bra.s   LAB_17B7        ; go do DEC


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform INC

LAB_INC:
                move.w  #$8100,-(SP)    ; set 1 sign/exponent
                bra.s   LAB_17B7        ; go do INC

; was "," so another INCR variable to do
LAB_17B8:
                bsr     LAB_IGBY        ; increment and scan memory
LAB_17B7:
                bsr     LAB_GVAR        ; get variable address in a0

; if you want a non existant variable to return a null value then set the novar
; value at the top of this file to some non zero value

                IF !novar

                beq.s   LAB_INCT        ; if variable not found skip the inc/dec

                ENDIF

                tst.b   Dtypef(A3)      ; test data type, $80=string, $40=integer,
; $00=float
                bmi     LAB_TMER        ; if string do "Type mismatch" error/warm start

                bne.s   LAB_INCI        ; go do integer INC/DEC

                move.l  A0,Lvarpl(A3)   ; save var address
                bsr     LAB_UFAC        ; unpack memory (a0) into FAC1
                move.l  #$80000000,FAC2_m(A3) ; set FAC2 mantissa for 1
                move.w  (SP),D0         ; move exponent & sign to d0
                move.w  D0,FAC2_e(A3)   ; move exponent & sign to FAC2
                move.b  FAC1_s(A3),FAC_sc(A3) ; make sign compare = FAC1 sign
                eor.b   D0,FAC_sc(A3)   ; make sign compare (FAC1_s EOR FAC2_s)
                bsr     LAB_ADD         ; add FAC2 to FAC1
                bsr     LAB_PFAC        ; pack FAC1 into variable (Lvarpl)
LAB_INCT:
                bsr     LAB_GBYT        ; scan memory
                cmpi.b  #$2C,D0         ; compare with ","
                beq.s   LAB_17B8        ; continue if "," (another variable to do)

                addq.w  #2,SP           ; else dump sign & exponent
                rts

LAB_INCI:
                tst.b   1(SP)           ; test sign
                bne.s   LAB_DECI        ; branch if DEC

                addq.l  #1,(A0)         ; increment variable
                bra.s   LAB_INCT        ; go scan for more

LAB_DECI:
                subq.l  #1,(A0)         ; decrement variable
                bra.s   LAB_INCT        ; go scan for more


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform LET

LAB_LET:
                bsr     LAB_SVAR        ; search for or create a variable
; return the variable address in a0
                move.l  A0,Lvarpl(A3)   ; save variable address
                move.b  Dtypef(A3),-(SP) ; push var data type, $80=string, $40=integer,
; $00=float
                moveq   #TK_EQUAL-$0100,D0 ; get = token
                bsr     LAB_SCCA        ; scan for CHR$(d0), else do syntax error/warm
; start
                bsr     LAB_EVEX        ; evaluate expression
                move.b  Dtypef(A3),D0   ; copy expression data type
                move.b  (SP)+,Dtypef(A3) ; pop variable data type
                rol.b   #1,D0           ; set carry if expression type = string
                bsr     LAB_CKTM        ; type match check, set C for string
                beq     LAB_PFAC        ; if number pack FAC1 into variable Lvarpl & RET

; string LET

LAB_17D5:
                movea.l Lvarpl(A3),A2   ; get pointer to variable
LAB_17D6:
                movea.l FAC1_m(A3),A0   ; get descriptor pointer
                movea.l (A0),A1         ; get string pointer
                cmpa.l  Sstorl(A3),A1   ; compare string memory start with string
; pointer
                bcs.s   LAB_1811        ; if it was in program memory assign the value
; and exit

                cmpa.l  Sfncl(A3),A0    ; compare functions start with descriptor
; pointer
                bcs.s   LAB_1811        ; branch if >= (string is on stack)

; string is variable$ make space and copy string
LAB_1810:
                moveq   #0,D1           ; clear length
                move.w  4(A0),D1        ; get string length
                movea.l (A0),A0         ; get string pointer
                bsr     LAB_20C9        ; copy string
                movea.l FAC1_m(A3),A0   ; get descriptor pointer back
; clean stack & assign value to string variable
LAB_1811:
                cmpa.l  A0,A4           ; is string on the descriptor stack
                bne.s   LAB_1813        ; skip pop if not

                addq.w  #$06,A4         ; else update stack pointer
LAB_1813:
                move.l  (A0)+,(A2)+     ; save pointer to variable
                move.w  (A0),(A2)       ; save length to variable
RTS_008:
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform GET

LAB_GET:
                bsr     LAB_SVAR        ; search for or create a variable
; return the variable address in a0
                move.l  A0,Lvarpl(A3)   ; save variable address as GET variable
                tst.b   Dtypef(A3)      ; test data type, $80=string, $40=integer,
; $00=float
                bmi.s   LAB_GETS        ; go get string character

; was numeric get
                bsr     INGET           ; get input byte
                bsr     LAB_1FD0        ; convert d0 to unsigned byte in FAC1
                bra     LAB_PFAC        ; pack FAC1 into variable (Lvarpl) & return

LAB_GETS:
                moveq   #$00,D1         ; assume no byte
                movea.l D1,A0           ; assume null string
                bsr     INGET           ; get input byte
                bcc.s   LAB_NoSt        ; branch if no byte received

                moveq   #$01,D1         ; string is single byte
                bsr     LAB_2115        ; make string space d1 bytes long
; return a0 = pointer, other registers unchanged

                move.b  D0,(A0)         ; save byte in string (byte IS string!)
LAB_NoSt:
                bsr     LAB_RTST        ; push string on descriptor stack
; a0 = pointer, d1 = length

                bra.s   LAB_17D5        ; do string LET & return


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; PRINT

LAB_1829:
                bsr     LAB_18C6        ; print string from stack
LAB_182C:
                bsr     LAB_GBYT        ; scan memory

; perform PRINT

LAB_PRINT:
                beq.s   LAB_CRLF        ; if nothing following just print CR/LF

LAB_1831:
                cmp.b   #TK_TAB,D0      ; compare with TAB( token
                beq.s   LAB_18A2        ; go do TAB/SPC

                cmp.b   #TK_SPC,D0      ; compare with SPC( token
                beq.s   LAB_18A2        ; go do TAB/SPC

                cmp.b   #',',D0         ; compare with ","
                beq.s   LAB_188B        ; go do move to next TAB mark

                cmp.b   #';',D0         ; compare with ";"
                beq     LAB_18BD        ; if ";" continue with PRINT processing

                bsr     LAB_EVEX        ; evaluate expression
                tst.b   Dtypef(A3)      ; test data type, $80=string, $40=integer,
; $00=float
                bmi.s   LAB_1829        ; branch if string

;*; replace the two lines above with this code

;*;     MOVE.b  Dtypef(a3),d0           ; get data type flag, $80=string, $00=numeric
;*;     BMI.s           LAB_1829                        ; branch if string

                bsr     LAB_2970        ; convert FAC1 to string
                bsr     LAB_20AE        ; print " terminated string to FAC1 stack

; don't check fit if terminal width byte is zero

                moveq   #0,D0           ; clear d0
                move.b  TWidth(A3),D0   ; get terminal width byte
                beq.s   LAB_185E        ; skip check if zero

                sub.b   7(A4),D0        ; subtract string length
                sub.b   TPos(A3),D0     ; subtract terminal position
                bcc.s   LAB_185E        ; branch if less than terminal width

                bsr.s   LAB_CRLF        ; else print CR/LF
LAB_185E:
                bsr.s   LAB_18C6        ; print string from stack
                bra.s   LAB_182C        ; always go continue processing line


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; CR/LF return to BASIC from BASIC input handler
; leaves a0 pointing to the buffer start

LAB_1866:
                move.b  #$00,0(A0,D1.w) ; null terminate input

; print CR/LF

LAB_CRLF:
                moveq   #$0D,D0         ; load [CR]
                bsr.s   LAB_PRNA        ; go print the character
                moveq   #$0A,D0         ; load [LF]
                bra.s   LAB_PRNA        ; go print the character & return

LAB_188B:
                move.b  TPos(A3),D2     ; get terminal position
                cmp.b   Iclim(A3),D2    ; compare with input column limit
                bcs.s   LAB_1898        ; branch if less than Iclim

                bsr.s   LAB_CRLF        ; else print CR/LF (next line)
                bra.s   LAB_18BD        ; continue with PRINT processing

LAB_1898:
                sub.b   TabSiz(A3),D2   ; subtract TAB size
                bcc.s   LAB_1898        ; loop if result was >= 0

                neg.b   D2              ; twos complement it
                bra.s   LAB_18B7        ; print d2 spaces

; do TAB/SPC
LAB_18A2:
                move.w  D0,-(SP)        ; save token
                bsr     LAB_SGBY        ; increment and get byte, result in d0 and Itemp
                move.w  D0,D2           ; copy byte
                bsr     LAB_GBYT        ; get basic byte back
                cmp.b   #$29,D0         ; is next character ")"
                bne     LAB_SNER        ; if not do syntax error, then warm start

                move.w  (SP)+,D0        ; get token back
                cmp.b   #TK_TAB,D0      ; was it TAB ?
                bne.s   LAB_18B7        ; branch if not (was SPC)

; calculate TAB offset
                sub.b   TPos(A3),D2     ; subtract terminal position
                bls.s   LAB_18BD        ; branch if result was <= 0
; can't TAB backwards or already there

; print d2.b spaces
LAB_18B7:
                moveq   #0,D0           ; clear longword
                subq.b  #1,D0           ; make d0 = $FF
                and.l   D0,D2           ; mask for byte only
                beq.s   LAB_18BD        ; branch if zero

                moveq   #$20,D0         ; load " "
                subq.b  #1,D2           ; adjust for DBF loop
LAB_18B8:
                bsr.s   LAB_PRNA        ; go print
                dbra    D2,LAB_18B8     ; decrement count and loop if not all done

; continue with PRINT processing
LAB_18BD:
                bsr     LAB_IGBY        ; increment & scan memory
                bne     LAB_1831        ; if byte continue executing PRINT

                rts                     ; exit if nothing more to print


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; print null terminated string from a0

LAB_18C3:
                bsr     LAB_20AE        ; print terminated string to FAC1/stack

; print string from stack

LAB_18C6:
                bsr     LAB_22B6        ; pop string off descriptor stack or from memory
; returns with d0 = length, a0 = pointer
                beq.s   RTS_009         ; exit (RTS) if null string

                move.w  D0,D1           ; copy length & set Z flag
                subq.w  #1,D1           ; -1 for BF loop
LAB_18CD:
                move.b  (A0)+,D0        ; get byte from string
                bsr.s   LAB_PRNA        ; go print the character
                dbra    D1,LAB_18CD     ; decrement count and loop if not done yet

RTS_009:
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; print "?" character

LAB_18E3:
                moveq   #$3F,D0         ; load "?" character


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;
; print character in d0, includes the null handler and infinite line length code
; changes no registers

LAB_PRNA:
                move.l  D1,-(SP)        ; save d1
                cmp.b   #$20,D0         ; compare with " "
                bcs.s   LAB_18F9        ; branch if less, non printing character

; don't check fit if terminal width byte is zero
                move.b  TWidth(A3),D1   ; get terminal width
                bne.s   LAB_18F0        ; branch if not zero (not infinite length)

; is "infinite line" so check TAB position
                move.b  TPos(A3),D1     ; get position
                sub.b   TabSiz(A3),D1   ; subtract TAB size
                bne.s   LAB_18F7        ; skip reset if different

                move.b  D1,TPos(A3)     ; else reset position
                bra.s   LAB_18F7        ; go print character

LAB_18F0:
                cmp.b   TPos(A3),D1     ; compare with terminal character position
                bne.s   LAB_18F7        ; branch if not at end of line

                move.l  D0,-(SP)        ; save d0

                bsr     LAB_CRLF        ; else print CR/LF
                move.l  (SP)+,D0        ; restore d0
LAB_18F7:
                addq.b  #$01,TPos(A3)   ; increment terminal position
LAB_18F9:
                jsr     V_OUTP(A3)      ; output byte via output vector
                cmp.b   #$0D,D0         ; compare with [CR]
                bne.s   LAB_188A        ; branch if not [CR]

; else print nullct nulls after the [CR]
                moveq   #$00,D1         ; clear d1
                move.b  Nullct(A3),D1   ; get null count
                beq.s   LAB_1886        ; branch if no nulls

                moveq   #$00,D0         ; load [NULL]
LAB_1880:
                jsr     V_OUTP(A3)      ; go print the character
                dbra    D1,LAB_1880     ; decrement count and loop if not all done

                moveq   #$0D,D0         ; restore the character
LAB_1886:
                move.b  D1,TPos(A3)     ; clear terminal position
LAB_188A:
                move.l  (SP)+,D1        ; restore d1
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; handle bad input data

LAB_1904:
                movea.l (SP)+,A5        ; restore execute pointer
                tst.b   Imode(A3)       ; test input mode flag, $00=INPUT, $98=READ
                bpl.s   LAB_1913        ; branch if INPUT (go do redo)

                move.l  Dlinel(A3),Clinel(A3) ; save DATA line as current line
                bra     LAB_TMER        ; do type mismatch error, then warm start

; mode was INPUT
LAB_1913:
                lea     LAB_REDO(PC),A0 ; point to redo message
                bsr     LAB_18C3        ; print null terminated string from memory
                movea.l Cpntrl(A3),A5   ; save continue pointer as BASIC execute pointer
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; perform INPUT

LAB_INPUT:
                bsr     LAB_CKRN        ; check not direct (back here if ok)
                cmpi.b  #'"',D0         ; compare the next byte with open quote
                bne.s   LAB_1934        ; if no prompt string just go get the input

                bsr     LAB_1BC1        ; print "..." string
                moveq   #';',D0         ; set the search character to ";"
                bsr     LAB_SCCA        ; scan for CHR$(d0), else do syntax error/warm
; start
                bsr     LAB_18C6        ; print string from Sutill/Sutilh
; finished the prompt, now read the data
LAB_1934:
                bsr     LAB_INLN        ; print "? " and get BASIC input
; return a0 pointing to the buffer start
                moveq   #0,D0           ; flag INPUT

; if you don't want a null response to INPUT to break the program then set the nobrk
; value at the top of this file to some non zero value

                IF !nobrk

                bra.s   LAB_1953        ; go handle the input

                ENDIF

; if you do want a null response to INPUT to break the program then leave the nobrk
; value at the top of this file set to zero

                IF nobrk

                tst.b   (A0)            ; test first byte from buffer
                bne.s   LAB_1953        ; branch if not null input

                bra     LAB_1647        ; go do BREAK exit

                ENDIF


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform READ

LAB_READ:
                movea.l Dptrl(A3),A0    ; get the DATA pointer
                moveq   #$98-$0100,D0   ; flag READ
LAB_1953:
                move.b  D0,Imode(A3)    ; set input mode flag, $00=INPUT, $98=READ
                move.l  A0,Rdptrl(A3)   ; save READ pointer

; READ or INPUT the next variable from list
LAB_195B:
                bsr     LAB_SVAR        ; search for or create a variable
; return the variable address in a0
                move.l  A0,Lvarpl(A3)   ; save variable address as LET variable
                move.l  A5,-(SP)        ; save BASIC execute pointer
LAB_1961:
                movea.l Rdptrl(A3),A5   ; set READ pointer as BASIC execute pointer
                bsr     LAB_GBYT        ; scan memory
                bne.s   LAB_1986        ; if not null go get the value

; the pointer was to a null entry
                tst.b   Imode(A3)       ; test input mode flag, $00=INPUT, $98=READ
                bmi.s   LAB_19DD        ; branch if READ (go find the next statement)

; else the mode was INPUT so get more
                bsr     LAB_18E3        ; print a "?" character
                bsr     LAB_INLN        ; print "? " and get BASIC input
; return a0 pointing to the buffer start

; if you don't want a null response to INPUT to break the program then set the nobrk
; value at the top of this file to some non zero value

                IF !nobrk

                move.l  A0,Rdptrl(A3)   ; save the READ pointer
                bra.s   LAB_1961        ; go handle the input

                ENDIF

; if you do want a null response to INPUT to break the program then leave the nobrk
; value at the top of this file set to zero

                IF nobrk

                tst.b   (A0)            ; test the first byte from the buffer
                bne.s   LAB_1984        ; if not null input go handle it

                bra     LAB_1647        ; else go do the BREAK exit

LAB_1984:
                movea.l A0,A5           ; set the execute pointer to the buffer
                subq.w  #1,A5           ; decrement the execute pointer

                ENDIF

LAB_1985:
                bsr     LAB_IGBY        ; increment & scan memory
LAB_1986:
                tst.b   Dtypef(A3)      ; test data type, $80=string, $40=integer,
; $00=float
                bpl.s   LAB_19B0        ; branch if numeric

; else get string
                move.b  D0,D2           ; save search character
                cmp.b   #$22,D0         ; was it " ?
                beq.s   LAB_1999        ; branch if so

                moveq   #':',D2         ; set new search character
                moveq   #',',D0         ; other search character is ","
                subq.w  #1,A5           ; decrement BASIC execute pointer
LAB_1999:
                addq.w  #1,A5           ; increment BASIC execute pointer
                move.b  D0,D3           ; set second search character
                movea.l A5,A0           ; BASIC execute pointer is source

                bsr     LAB_20B4        ; print d2/d3 terminated string to FAC1 stack
; d2 = Srchc, d3 = Asrch, a0 is source
                movea.l A2,A5           ; copy end of string to BASIC execute pointer
                bsr     LAB_17D5        ; go do string LET
                bra.s   LAB_19B6        ; go check string terminator

; get numeric INPUT
LAB_19B0:
                move.b  Dtypef(A3),-(SP) ; save variable data type
                bsr     LAB_2887        ; get FAC1 from string
                move.b  (SP)+,Dtypef(A3) ; restore variable data type
                bsr     LAB_PFAC        ; pack FAC1 into (Lvarpl)
LAB_19B6:
                bsr     LAB_GBYT        ; scan memory
                beq.s   LAB_19C2        ; branch if null (last entry)

                cmp.b   #',',D0         ; else compare with ","
                bne     LAB_1904        ; if not "," go handle bad input data

                addq.w  #1,A5           ; else was "," so point to next chr
; got good input data
LAB_19C2:
                move.l  A5,Rdptrl(A3)   ; save the read pointer for now
                movea.l (SP)+,A5        ; restore the execute pointer
                bsr     LAB_GBYT        ; scan the memory
                beq.s   LAB_1A03        ; if null go do extra ignored message

                pea     LAB_195B(PC)    ; set return address
                bra     LAB_1C01        ; scan for "," else do syntax error/warm start
; then go INPUT next variable from list

; find next DATA statement or do "Out of Data"
; error
LAB_19DD:
                bsr     LAB_SNBS        ; scan for next BASIC statement ([:] or [EOL])
; returns a0 as pointer to [:] or [EOL]
                movea.l A0,A5           ; add index, now = pointer to [EOL]/[EOS]
                addq.w  #1,A5           ; pointer to next character
                cmp.b   #':',D0         ; was it statement end?
                beq.s   LAB_19F6        ; branch if [:]

; was [EOL] so find next line

                move.w  A5,D1           ; past pad byte(s)
                and.w   #1,D1           ; mask odd bit
                adda.w  D1,A5           ; add pointer
                move.l  (A5)+,D2        ; get next line pointer
                beq     LAB_ODER        ; branch if end of program

                move.l  (A5)+,Dlinel(A3) ; save current DATA line
LAB_19F6:
                bsr     LAB_GBYT        ; scan memory
                cmp.b   #TK_DATA,D0     ; compare with "DATA" token
                beq     LAB_1985        ; was "DATA" so go do next READ

                bra.s   LAB_19DD        ; go find next statement if not "DATA"

; end of INPUT/READ routine

LAB_1A03:
                movea.l Rdptrl(A3),A0   ; get temp READ pointer
                tst.b   Imode(A3)       ; get input mode flag, $00=INPUT, $98=READ
                bpl.s   LAB_1A0E        ; branch if INPUT

                move.l  A0,Dptrl(A3)    ; else save temp READ pointer as DATA pointer
                rts


; we were getting INPUT
LAB_1A0E:
                tst.b   (A0)            ; test next byte
                bne.s   LAB_1A1B        ; error if not end of INPUT

                rts
; user typed too much
LAB_1A1B:
                lea     LAB_IMSG(PC),A0 ; point to extra ignored message
                bra     LAB_18C3        ; print null terminated string from memory & RTS


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; perform NEXT

LAB_NEXT:
                bne.s   LAB_1A46        ; branch if NEXT var

                addq.w  #4,SP           ; back past return address
                cmpi.w  #TK_FOR,(SP)    ; is FOR token on stack?
                bne     LAB_NFER        ; if not do NEXT without FOR err/warm start

                movea.l 2(SP),A0        ; get stacked FOR variable pointer
                bra.s   LAB_11BD        ; branch always (no variable to search for)

; NEXT var

LAB_1A46:
                bsr     LAB_GVAR        ; get variable address in a0
                addq.w  #4,SP           ; back past return address
                move.w  #TK_FOR,D0      ; set for FOR token
                moveq   #$1C,D1         ; set for FOR use size
                bra.s   LAB_11A6        ; enter loop for next variable search

LAB_11A5:
                adda.l  D1,SP           ; add FOR stack use size
LAB_11A6:
                cmp.w   (SP),D0         ; is FOR token on stack?
                bne     LAB_NFER        ; if not found do NEXT without FOR error and
; warm start

; was FOR token
                cmpa.l  2(SP),A0        ; compare var pointer with stacked var pointer
                bne.s   LAB_11A5        ; loop if no match found

LAB_11BD:
                move.w  6(SP),FAC2_e(A3) ; get STEP value exponent and sign
                move.l  8(SP),FAC2_m(A3) ; get STEP value mantissa

                move.b  18(SP),Dtypef(A3) ; restore FOR variable data type
                bsr     LAB_1C19        ; check type and unpack (a0)

                move.b  FAC2_s(A3),FAC_sc(A3) ; save FAC2 sign as sign compare
                move.b  FAC1_s(A3),D0   ; get FAC1 sign
                eor.b   D0,FAC_sc(A3)   ; EOR to create sign compare

                move.l  A0,Lvarpl(A3)   ; save variable pointer
                bsr     LAB_ADD         ; add STEP value to FOR variable
                move.b  18(SP),Dtypef(A3) ; restore FOR variable data type (again)
                bsr     LAB_PFAC        ; pack FAC1 into FOR variable (Lvarpl)

                move.w  12(SP),FAC2_e(A3) ; get TO value exponent and sign
                move.l  14(SP),FAC2_m(A3) ; get TO value mantissa

                move.b  FAC2_s(A3),FAC_sc(A3) ; save FAC2 sign as sign compare
                move.b  FAC1_s(A3),D0   ; get FAC1 sign
                eor.b   D0,FAC_sc(A3)   ; EOR to create sign compare

                bsr     LAB_27FA        ; compare FAC1 with FAC2 (TO value)
; returns d0=+1 if FAC1 > FAC2
; returns d0= 0 if FAC1 = FAC2
; returns d0=-1 if FAC1 < FAC2

                move.w  6(SP),D1        ; get STEP value exponent and sign
                eor.w   D0,D1           ; EOR compare result with STEP exponent and sign

                tst.b   D0              ; test for =
                beq.s   LAB_1A90        ; branch if = (loop INcomplete)

                tst.b   D1              ; test result
                bpl.s   LAB_1A9B        ; branch if > (loop complete)

; loop back and do it all again
LAB_1A90:
                move.l  20(SP),Clinel(A3) ; reset current line
                movea.l 24(SP),A5       ; reset BASIC execute pointer
                bra     LAB_15C2        ; go do interpreter inner loop

; loop complete so carry on
LAB_1A9B:
                adda.w  #28,SP          ; add 28 to dump FOR structure
                bsr     LAB_GBYT        ; scan memory
                cmp.b   #$2C,D0         ; compare with ","
                bne     LAB_15C2        ; if not "," go do interpreter inner loop

; was "," so another NEXT variable to do
                bsr     LAB_IGBY        ; else increment & scan memory
                bsr     LAB_1A46        ; do NEXT (var)


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; evaluate expression & check is numeric, else do type mismatch

LAB_EVNM:
                bsr.s   LAB_EVEX        ; evaluate expression


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; check if source is numeric, else do type mismatch

LAB_CTNM:
                cmp.w   D0,D0           ; r.EQUired type is numeric so clear carry


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; type match check, set C for string, clear C for numeric

LAB_CKTM:
                btst    #7,Dtypef(A3)   ; test data type flag, don't change carry
                bne.s   LAB_1ABA        ; branch if data type is string

; else data type was numeric
                bcs     LAB_TMER        ; if r.EQUired type is string do type mismatch
; error

                rts
; data type was string, now check r.EQUired type
LAB_1ABA:
                bcc     LAB_TMER        ; if r.EQUired type is numeric do type mismatch
; error
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; this routine evaluates any type of expression. first it pushes an end marker so
; it knows when the expression has been evaluated, this is a precedence value of zero.
; next the first value is evaluated, this can be an in line value, either numeric or
; string, a variable or array element of any type, a function or even an expression
; in parenthesis. this value is kept in FAC_1
; after the value is evaluated a test is made on the next BASIC program byte, if it
; is a comparrison operator i.e. "<", "=" or ">", then the corresponding bit is set
; in the comparison evaluation flag. this test loops until no more comparrison operators
; are found or more than one of any type is found. in the last case an error is generated

; evaluate expression

LAB_EVEX:
                subq.w  #1,A5           ; decrement BASIC execute pointer
LAB_EVEZ:
                moveq   #0,D1           ; clear precedence word
                move.b  D1,Dtypef(A3)   ; clear the data type, $80=string, $40=integer,
; $00=float
                bra.s   LAB_1ACD        ; enter loop

; get vector, set up operator then continue evaluation

LAB_1B43:                               ;       *
                lea     LAB_OPPT(PC),A0 ; point to operator vector table
                move.w  2(A0,D1.w),D0   ; get vector offset
                pea     0(A0,D0.w)      ; push vector

                move.l  FAC1_m(A3),-(SP) ; push FAC1 mantissa
                move.w  FAC1_e(A3),-(SP) ; push sign and exponent
                move.b  comp_f(A3),-(SP) ; push comparison evaluation flag

                move.w  0(A0,D1.w),D1   ; get precedence value
LAB_1ACD:
                move.w  D1,-(SP)        ; push precedence value
                bsr     LAB_GVAL        ; get value from line
                move.b  #$00,comp_f(A3) ; clear compare function flag
LAB_1ADB:
                bsr     LAB_GBYT        ; scan memory
LAB_1ADE:
                sub.b   #TK_GT,D0       ; subtract token for > (lowest compare function)
                bcs.s   LAB_1AFA        ; branch if < TK_GT

                cmp.b   #$03,D0         ; compare with ">" to "<" tokens
                bcs.s   LAB_1AE0        ; branch if <= TK_SGN (is compare function)

                tst.b   comp_f(A3)      ; test compare function flag
                bne.s   LAB_1B2A        ; branch if compare function

                bra     LAB_1B78        ; go do functions

; was token for > = or < (d0 = 0, 1 or 2)
LAB_1AE0:
                moveq   #1,D1           ; set to 0000 0001
                asl.b   D0,D1           ; 1 if >, 2 if =, 4 if <
                move.b  comp_f(A3),D0   ; copy old compare function flag
                eor.b   D1,comp_f(A3)   ; EOR in this compare function bit
                cmp.b   comp_f(A3),D0   ; compare old with new compare function flag
                bcc     LAB_SNER        ; if new <= old comp_f do syntax error and warm
; start, there was more than one <, = or >
                bsr     LAB_IGBY        ; increment & scan memory
                bra.s   LAB_1ADE        ; go do next character

; token is < ">" or > "<" tokens
LAB_1AFA:
                tst.b   comp_f(A3)      ; test compare function flag
                bne.s   LAB_1B2A        ; branch if compare function

; was < TK_GT so is operator or lower
                add.b   #(TK_GT-TK_PLUS),D0 ; add # of operators (+ - ; / ^ AND OR EOR)
                bcc.s   LAB_1B78        ; branch if < + operator

                bne.s   LAB_1B0B        ; branch if not + token

                tst.b   Dtypef(A3)      ; test data type, $80=string, $40=integer,
; $00=float
                bmi     LAB_224D        ; type is string & token was +

LAB_1B0B:
                moveq   #0,D1           ; clear longword
                add.b   D0,D0           ; *2
                add.b   D0,D0           ; *4
                move.b  D0,D1           ; copy to index
LAB_1B13:
                move.w  (SP)+,D0        ; pull previous precedence
                lea     LAB_OPPT(PC),A0 ; set pointer to operator table
                cmp.w   0(A0,D1.w),D0   ; compare with this opperator precedence
                bcc.s   LAB_1B7D        ; branch if previous precedence (d0) >=

                bsr     LAB_CTNM        ; check if source is numeric, else type mismatch
LAB_1B1C:
                move.w  D0,-(SP)        ; save precedence
LAB_1B1D:
                bsr     LAB_1B43        ; get vector, set-up operator and continue
; evaluation
                move.w  (SP)+,D0        ; restore precedence
                move.l  prstk(A3),D1    ; get stacked function pointer
                bpl.s   LAB_1B3C        ; branch if stacked values

                move.w  D0,D0           ; copy precedence (set flags)
                beq.s   LAB_1B7B        ; exit if done

                bra.s   LAB_1B86        ; else pop FAC2 & return (do function)

; was compare function (< = >)
LAB_1B2A:
                move.b  Dtypef(A3),D0   ; get data type flag
                move.b  comp_f(A3),D1   ; get compare function flag
                add.b   D0,D0           ; string bit flag into X bit
                addx.b  D1,D1           ; shift compare function flag

                move.b  #0,Dtypef(A3)   ; clear data type flag, $00=float
                move.b  D1,comp_f(A3)   ; save new compare function flag
                subq.w  #1,A5           ; decrement BASIC execute pointer
                moveq   #(TK_LT-TK_PLUS)*4,D1 ; set offset to last operator entry
                bra.s   LAB_1B13        ; branch always

LAB_1B3C:
                lea     LAB_OPPT(PC),A0 ; point to function vector table
                cmp.w   0(A0,D1.w),D0   ; compare with this opperator precedence
                bcc.s   LAB_1B86        ; branch if d0 >=, pop FAC2 & return

                bra.s   LAB_1B1C        ; branch always

; do functions

LAB_1B78:
                moveq   #-1,D1          ; flag all done
                move.w  (SP)+,D0        ; pull precedence word
LAB_1B7B:
                beq.s   LAB_1B9D        ; exit if done

LAB_1B7D:
                cmp.w   #$64,D0         ; compare previous precedence with $64
                beq.s   LAB_1B84        ; branch if was $64 (< function can be string)

                bsr     LAB_CTNM        ; check if source is numeric, else type mismatch
LAB_1B84:
                move.l  D1,prstk(A3)    ; save current operator index

; pop FAC2 & return
LAB_1B86:
                move.b  (SP)+,D0        ; pop comparison evaluation flag
                move.b  D0,D1           ; copy comparison evaluation flag
                lsr.b   #1,D0           ; shift out comparison evaluation lowest bit
                move.b  D0,Cflag(A3)    ; save comparison evaluation flag
                move.w  (SP)+,FAC2_e(A3) ; pop exponent and sign
                move.l  (SP)+,FAC2_m(A3) ; pop mantissa
                move.b  FAC2_s(A3),FAC_sc(A3) ; copy FAC2 sign
                move.b  FAC1_s(A3),D0   ; get FAC1 sign
                eor.b   D0,FAC_sc(A3)   ; EOR FAC1 sign and set sign compare

                lsr.b   #1,D1           ; type bit into X and C
                rts

LAB_1B9D:
                move.b  FAC1_e(A3),D0   ; get FAC1 exponent
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; get a value from the BASIC line

LAB_GVAL:
                bsr.s   LAB_IGBY        ; increment & scan memory
                bcs     LAB_2887        ; if numeric get FAC1 from string & return

                tst.b   D0              ; test byte
                bmi     LAB_1BD0        ; if -ve go test token values

; else it is either a string, number, variable
; or (<expr>)
                cmp.b   #'$',D0         ; compare with "$"
                beq     LAB_2887        ; if "$" get hex number from string & return

                cmp.b   #'%',D0         ; else compare with "%"
                beq     LAB_2887        ; if "%" get binary number from string & return

                cmp.b   #$2E,D0         ; compare with "."
                beq     LAB_2887        ; if so get FAC1 from string and return
; (e.g. .123)

; wasn't a number so ...
                cmp.b   #$22,D0         ; compare with "
                bne.s   LAB_1BF3        ; if not open quote it must be a variable or
; open bracket

; was open quote so get the enclosed string

; print "..." string to string stack

LAB_1BC1:
                move.b  (A5)+,D0        ; increment BASIC execute pointer (past ")
; fastest/shortest method
                movea.l A5,A0           ; copy basic execute pointer (string start)
                bsr     LAB_20AE        ; print " terminated string to stack
                movea.l A2,A5           ; restore BASIC execute pointer from temp
                rts

; get value from line .. continued
; wasn't any sort of number so ...
LAB_1BF3:
                cmp.b   #'(',D0         ; compare with "("
                bne.s   LAB_1C18        ; if not "(" get (var) and return value in FAC1
; and $ flag


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; evaluate expression within parentheses

LAB_1BF7:
                bsr     LAB_EVEZ        ; evaluate expression (no decrement)


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; all the 'scan for' routines return the character after the sought character

; scan for ")", else do syntax error, then warm start

LAB_1BFB:
                moveq   #$29,D0         ; load d0 with ")"
                bra.s   LAB_SCCA


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; scan for "," and get byte, else do Syntax error then warm start

LAB_SCGB:
                pea     LAB_GTBY(PC)    ; return address is to get byte parameter


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; scan for ",", else do syntax error, then warm start

LAB_1C01:
                moveq   #$2C,D0         ; load d0 with ","


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; scan for CHR$(d0) , else do syntax error, then warm start

LAB_SCCA:
                cmp.b   (A5)+,D0        ; check next byte is = d0
                beq.s   LAB_GBYT        ; if so go get next

                bra     LAB_SNER        ; else do syntax error/warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; BASIC increment and scan memory routine

LAB_IGBY:
                move.b  (A5)+,D0        ; get byte & increment pointer

; scan memory routine, exit with Cb = 1 if numeric character
; also skips any spaces encountered

LAB_GBYT:
                move.b  (A5),D0         ; get byte

                cmp.b   #$20,D0         ; compare with " "
                beq.s   LAB_IGBY        ; if " " go do next

; test current BASIC byte, exit with Cb = 1 if numeric character

                cmp.b   #TK_ELSE,D0     ; compare with the token for ELSE
                bcc.s   RTS_001         ; exit if >= (not numeric, carry clear)

                cmp.b   #$3A,D0         ; compare with ":"
                bcc.s   RTS_001         ; exit if >= (not numeric, carry clear)

                moveq   #$D0,D6         ; set -"0"
                add.b   D6,D0           ; add -"0"
                sub.b   D6,D0           ; subtract -"0"
RTS_001:                                ; carry set if byte = "0"-"9"
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; set-up for - operator

LAB_1C11:
                bsr     LAB_CTNM        ; check if source is numeric, else type mismatch
                moveq   #(TK_GT-TK_PLUS)*4,D1 ; set offset from base to - operator
LAB_1C13:
                lea     4(SP),SP        ; dump GVAL return address
                bra     LAB_1B1D        ; continue evaluating expression


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; variable name set-up
; get (var), return value in FAC_1 & data type flag

LAB_1C18:
                bsr     LAB_GVAR        ; get variable address in a0

; if you want a non existant variable to return a null value then set the novar
; value at the top of this file to some non zero value

                IF !novar

                bne.s   LAB_1C19        ; if it exists return it

                lea     LAB_1D96(PC),A0 ; else return a null descriptor/pointer

                ENDIF

; return existing variable value

LAB_1C19:
                tst.b   Dtypef(A3)      ; test data type, $80=string, $40=integer,
; $00=float
                beq     LAB_UFAC        ; if float unpack memory (a0) into FAC1 and
; return

                bpl.s   LAB_1C1A        ; if integer unpack memory (a0) into FAC1
; and return

                move.l  A0,FAC1_m(A3)   ; else save descriptor pointer in FAC1
                rts

LAB_1C1A:
                move.l  (A0),D0         ; get integer value
                bra     LAB_AYFC        ; convert d0 to signed longword in FAC1 & return


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; get value from line .. continued
; do tokens

LAB_1BD0:
                cmp.b   #TK_MINUS,D0    ; compare with token for -
                beq.s   LAB_1C11        ; branch if - token (do set-up for - operator)

; wasn't -123 so ...
                cmp.b   #TK_PLUS,D0     ; compare with token for +
                beq     LAB_GVAL        ; branch if + token (+n = n so ignore leading +)

                cmp.b   #TK_NOT,D0      ; compare with token for NOT
                bne.s   LAB_1BE7        ; branch if not token for NOT

; was NOT token
                move.w  #(TK_EQUAL-TK_PLUS)*4,D1 ; offset to NOT function
                bra.s   LAB_1C13        ; do set-up for function then execute

; wasn't +, - or NOT so ...
LAB_1BE7:
                cmp.b   #TK_FN,D0       ; compare with token for FN
                beq     LAB_201E        ; if FN go evaluate FNx

; wasn't +, -, NOT or FN so ...
                sub.b   #TK_SGN,D0      ; compare with token for SGN & normalise
                bcs     LAB_SNER        ; if < SGN token then do syntax error

; get value from line .. continued
; only functions left so set up function references

; new for V2.0+ this replaces a lot of IF .. THEN .. ELSEIF .. THEN .. that was needed
; to process function calls. now the function vector is computed and pushed on the stack
; and the preprocess offset is read. if the preprocess offset is non zero then the vector
; is calculated and the routine called, if not this routine just does RTS. whichever
; happens the RTS at the end of this routine, or the preprocess routine calls, the
; function code

; this also removes some less than elegant code that was used to bypass type checking
; for functions that returned strings

                and.w   #$7F,D0         ; mask byte
                add.w   D0,D0           ; *2 (2 bytes per function offset)

                lea     LAB_FTBL(PC),A0 ; pointer to functions vector table
                move.w  0(A0,D0.w),D1   ; get function vector offset
                pea     0(A0,D1.w)      ; push function vector

                lea     LAB_FTPP(PC),A0 ; pointer to functions preprocess vector table
                move.w  0(A0,D0.w),D0   ; get function preprocess vector offset
                beq.s   LAB_1C2A        ; no preprocess vector so go do function

                lea     0(A0,D0.w),A0   ; get function preprocess vector
                jmp     (A0)            ; go do preprocess routine then function


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; process string expression in parenthesis

LAB_PPFS:
                bsr     LAB_1BF7        ; process expression in parenthesis
                tst.b   Dtypef(A3)      ; test data type
                bpl     LAB_TMER        ; if numeric do Type missmatch Error/warm start

LAB_1C2A:
                rts                     ; else do function


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; process numeric expression in parenthesis

LAB_PPFN:
                bsr     LAB_1BF7        ; process expression in parenthesis
                tst.b   Dtypef(A3)      ; test data type
                bmi     LAB_TMER        ; if string do Type missmatch Error/warm start

                rts                     ; else do function


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; set numeric data type and increment BASIC execute pointer

LAB_PPBI:
                move.b  #$00,Dtypef(A3) ; clear data type flag, $00=float
                move.b  (A5)+,D0        ; get next BASIC byte
                rts                     ; do function


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; process string for LEFT$, RIGHT$ or MID$

LAB_LRMS:
                bsr     LAB_EVEZ        ; evaluate (should be string) expression
                tst.b   Dtypef(A3)      ; test data type flag
                bpl     LAB_TMER        ; if type is not string do type mismatch error

                move.b  (A5)+,D2        ; get BASIC byte
                cmp.b   #',',D2         ; compare with comma
                bne     LAB_SNER        ; if not "," go do syntax error/warm start

                move.l  FAC1_m(A3),-(SP) ; save descriptor pointer
                bsr     LAB_GTWO        ; get word parameter, result in d0 and Itemp
                movea.l (SP)+,A0        ; restore descriptor pointer
                rts                     ; do function


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; process numeric expression(s) for BIN$ or HEX$

LAB_BHSS:
                bsr     LAB_EVEZ        ; evaluate expression (no decrement)
                tst.b   Dtypef(A3)      ; test data type
                bmi     LAB_TMER        ; if string do Type missmatch Error/warm start

                bsr     LAB_2831        ; convert FAC1 floating to fixed
; result in d0 and Itemp
                moveq   #0,D1           ; set default to no leading "0"s
                move.b  (A5)+,D2        ; get BASIC byte
                cmp.b   #',',D2         ; compare with comma
                bne.s   LAB_BHCB        ; if not "," go check close bracket

                move.l  D0,-(SP)        ; copy number to stack
                bsr     LAB_GTBY        ; get byte value
                move.l  D0,D1           ; copy leading 0s #
                move.l  (SP)+,D0        ; restore number from stack
                move.b  (A5)+,D2        ; get BASIC byte
LAB_BHCB:
                cmp.b   #')',D2         ; compare with close bracket
                bne     LAB_SNER        ; if not ")" do Syntax Error/warm start

                rts                     ; go do function


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform EOR

LAB_EOR:
                bsr.s   GetFirst        ; get two values for OR, AND or EOR
; first in d0, and Itemp, second in d2
                eor.l   D2,D0           ; EOR values
                bra     LAB_AYFC        ; convert d0 to signed longword in FAC1 & RET


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform OR

LAB_OR:
                bsr.s   GetFirst        ; get two values for OR, AND or EOR
; first in d0, and Itemp, second in d2
                or.l    D2,D0           ; do OR
                bra     LAB_AYFC        ; convert d0 to signed longword in FAC1 & RET


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform AND

LAB_AND:
                bsr.s   GetFirst        ; get two values for OR, AND or EOR
; first in d0, and Itemp, second in d2
                and.l   D2,D0           ; do AND
                bra     LAB_AYFC        ; convert d0 to signed longword in FAC1 & RET


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; get two values for OR, AND, EOR
; first in d0, second in d2

GetFirst:
                bsr     LAB_EVIR        ; evaluate integer expression (no sign check)
; result in d0 and Itemp
                move.l  D0,D2           ; copy second value
                bsr     LAB_279B        ; copy FAC2 to FAC1, get first value in
; expression
                bra     LAB_EVIR        ; evaluate integer expression (no sign check)
; result in d0 and Itemp & return


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform NOT

LAB_EQUAL:
                bsr     LAB_EVIR        ; evaluate integer expression (no sign check)
; result in d0 and Itemp
                not.l   D0              ; bitwise invert
                bra     LAB_AYFC        ; convert d0 to signed longword in FAC1 & RET


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; perform comparisons
; do < compare

LAB_LTHAN:
                bsr     LAB_CKTM        ; type match check, set C for string
                bcs.s   LAB_1CAE        ; branch if string

; do numeric < compare
                bsr     LAB_27FA        ; compare FAC1 with FAC2
; returns d0=+1 if FAC1 > FAC2
; returns d0= 0 if FAC1 = FAC2
; returns d0=-1 if FAC1 < FAC2
                bra.s   LAB_1CF2        ; process result

; do string < compare
LAB_1CAE:
                move.b  #$00,Dtypef(A3) ; clear data type, $80=string, $40=integer,
; $00=float
                bsr     LAB_22B6        ; pop string off descriptor stack, or from top
; of string space returns d0 = length,
; a0 = pointer
                movea.l A0,A1           ; copy string 2 pointer
                move.l  D0,D1           ; copy string 2 length
                movea.l FAC2_m(A3),A0   ; get string 1 descriptor pointer
                bsr     LAB_22BA        ; pop (a0) descriptor, returns with ..
; d0 = length, a0 = pointer
                move.l  D0,D2           ; copy length
                bne.s   LAB_1CB5        ; branch if not null string

                tst.l   D1              ; test if string 2 is null also
                beq.s   LAB_1CF2        ; if so do string 1 = string 2

LAB_1CB5:
                sub.l   D1,D2           ; subtract string 2 length
                beq.s   LAB_1CD5        ; branch if strings = length

                bcs.s   LAB_1CD4        ; branch if string 1 < string 2

                moveq   #-1,D0          ; set for string 1 > string 2
                bra.s   LAB_1CD6        ; go do character comapare

LAB_1CD4:
                move.l  D0,D1           ; string 1 length is compare length
                moveq   #1,D0           ; and set for string 1 < string 2
                bra.s   LAB_1CD6        ; go do character comapare

LAB_1CD5:
                move.l  D2,D0           ; set for string 1 = string 2
LAB_1CD6:
                subq.l  #1,D1           ; adjust length for DBcc loop

; d1 is length to compare, d0 is <=> for length
; a0 is string 1 pointer, a1 is string 2 pointer
LAB_1CE6:
                cmpm.b  (A0)+,(A1)+     ; compare string bytes (1 with 2)
                dbne    D1,LAB_1CE6     ; loop if same and not end yet

                beq.s   LAB_1CF2        ; if = to here, then go use length compare

                bcc.s   LAB_1CDB        ; else branch if string 1 > string 2

                moveq   #-1,D0          ; else set for string 1 < string 2
                bra.s   LAB_1CF2        ; go set result

LAB_1CDB:
                moveq   #1,D0           ; and set for string 1 > string 2

LAB_1CF2:
                addq.b  #1,D0           ; make result 0, 1 or 2
                move.b  D0,D1           ; copy to d1
                moveq   #1,D0           ; set d0 longword
                rol.b   D1,D0           ; make 1, 2 or 4 (result = flag bit)
                and.b   Cflag(A3),D0    ; AND with comparison evaluation flag
                beq     LAB_27DB        ; exit if not a wanted result (i.e. false)

                moveq   #-1,D0          ; else set -1 (true)
                bra     LAB_27DB        ; save d0 as integer & return


LAB_1CFE:
                bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; perform DIM

LAB_DIM:
                moveq   #-1,D1          ; set "DIM" flag
                bsr.s   LAB_1D10        ; search for or dimension a variable
                bsr     LAB_GBYT        ; scan memory
                bne.s   LAB_1CFE        ; loop and scan for "," if not null

                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; perform << (left shift)

LAB_LSHIFT:
                bsr.s   GetPair         ; get an integer and byte pair
; byte is in d2, integer is in d0 and Itemp
                beq.s   NoShift         ; branch if byte zero

                cmp.b   #$20,D2         ; compare bit count with 32d
                bcc.s   TooBig          ; branch if >=

                asl.l   D2,D0           ; shift longword
NoShift:
                bra     LAB_AYFC        ; convert d0 to signed longword in FAC1 & RET


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; perform >> (right shift)

LAB_RSHIFT:
                bsr.s   GetPair         ; get an integer and byte pair
; byte is in d2, integer is in d0 and Itemp
                beq.s   NoShift         ; branch if byte zero

                cmp.b   #$20,D2         ; compare bit count with 32d
                bcs.s   Not2Big         ; branch if >= (return shift)

                tst.l   D0              ; test sign bit
                bpl.s   TooBig          ; branch if +ve

                moveq   #-1,D0          ; set longword
                bra     LAB_AYFC        ; convert d0 to longword in FAC1 & RET

Not2Big:
                asr.l   D2,D0           ; shift longword
                bra     LAB_AYFC        ; convert d0 to longword in FAC1 & RET

TooBig:
                moveq   #0,D0           ; clear longword
                bra     LAB_AYFC        ; convert d0 to longword in FAC1 & RET


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; get an integer and byte pair
; byte is in d2, integer is in d0 and Itemp

GetPair:
                bsr     LAB_EVBY        ; evaluate byte expression, result in d0 and
; Itemp
                move.b  D0,D2           ; save it
                bsr     LAB_279B        ; copy FAC2 to FAC1, get first value in
; expression
                bsr     LAB_EVIR        ; evaluate integer expression (no sign check)
; result in d0 and Itemp
                tst.b   D2              ; test byte value
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; check alpha, return C=0 if<"A" or >"Z" or <"a" to "z">

LAB_CASC:
                cmp.b   #$61,D0         ; compare with "a"
                bcc.s   LAB_1D83        ; if >="a" go check =<"z"


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; check alpha upper case, return C=0 if<"A" or >"Z"

LAB_CAUC:
                cmp.b   #$41,D0         ; compare with "A"
                bcc.s   LAB_1D8A        ; if >="A" go check =<"Z"

                or.w    D0,D0           ; make C=0
                rts

LAB_1D8A:
                cmp.b   #$5B,D0         ; compare with "Z"+1
; carry set if byte<="Z"
                rts

LAB_1D83:
                cmp.b   #$7B,D0         ; compare with "z"+1
; carry set if byte<="z"
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; search for or create variable. this is used to automatically create a variable if
; it is not found. any routines that need to create the variable call LAB_GVAR via
; this point and error generation is supressed and the variable will be created
;*
; return pointer to variable in Cvaral and a0
; set data type to variable type

LAB_SVAR:
                bsr.s   LAB_GVAR        ; search for variable
LAB_FVAR:
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; search for variable. if this routine is called from anywhere but the above call and
; the variable searched for does not exist then an error will be returned
;*
; DIM flag is in d1.b
; return pointer to variable in Cvaral and a0
; set data type to variable type

LAB_GVAR:
                moveq   #$00,D1         ; set DIM flag = $00
                bsr     LAB_GBYT        ; scan memory (1st character)
LAB_1D10:
                move.b  D1,Defdim(A3)   ; save DIM flag

; search for FN name entry point

LAB_1D12:
                bsr.s   LAB_CASC        ; check byte, return C=0 if<"A" or >"Z"
                bcc     LAB_SNER        ; if not, syntax error then warm start

; it is a variable name so ...
                moveq   #$00,D1         ; set index for name byte
                lea     Varname(A3),A0  ; pointer to variable name
                move.l  D1,(A0)         ; clear the variable name
                move.b  D1,Dtypef(A3)   ; clear the data type, $80=string, $40=integer,
; $00=float

LAB_1D2D:
                cmp.w   #$04,D1         ; done all significant characters?
                bcc.s   LAB_1D2E        ; if so go ignore any more

                move.b  D0,0(A0,D1.w)   ; save the character
                addq.w  #1,D1           ; increment index
LAB_1D2E:
                bsr     LAB_IGBY        ; increment & scan memory (next character)
                bcs.s   LAB_1D2D        ; branch if character = "0"-"9" (ok)

; character wasn't "0" to "9" so ...
                bsr.s   LAB_CASC        ; check byte, return C=0 if<"A" or >"Z"
                bcs.s   LAB_1D2D        ; branch if = "A"-"Z" (ok)

; check if string variable
                cmp.b   #'$',D0         ; compare with "$"
                bne.s   LAB_1D44        ; branch if not string

; type is string
                ori.b   #$80,Varname+1(A3) ; set top bit of 2nd character, indicate string
                bsr     LAB_IGBY        ; increment & scan memory
                bra.s   LAB_1D45        ; skip integer check

; check if integer variable
LAB_1D44:
                cmp.b   #'&',D0         ; compare with "&"
                bne.s   LAB_1D45        ; branch if not integer

; type is integer
                ori.b   #$80,Varname+2(A3) ; set top bit of 3rd character, indicate integer
                bsr     LAB_IGBY        ; increment & scan memory

; after we have determined the variable type we need to determine
; if it's an array of type

; gets here with character after var name in d0
LAB_1D45:
                tst.b   Sufnxf(A3)      ; test function name flag
                beq.s   LAB_1D48        ; if not FN or FN variable continue

                bpl.s   LAB_1D49        ; if FN variable go find or create it

; else was FN name
                move.l  Varname(A3),D0  ; get whole function name
                moveq   #8,D1           ; set step to next function size -4
                lea     Sfncl(A3),A0    ; get pointer to start of functions
                bra.s   LAB_1D4B        ; go find function

LAB_1D48:
                sub.b   #'(',D0         ; subtract "("
                beq     LAB_1E17        ; if "(" go find, or make, array

; either find or create var
; var name (1st four characters only!) is in Varname

; variable name wasn't var( .. so look for
; plain variable
LAB_1D49:
                move.l  Varname(A3),D0  ; get whole variable name
LAB_1D4A:
                moveq   #4,D1           ; set step to next variable size -4
                lea     Svarl(A3),A0    ; get pointer to start of variables

                btst    #23,D0          ; test if string name
                beq.s   LAB_1D4B        ; branch if not

                addq.w  #2,D1           ; 6 bytes per string entry
                addq.w  #(Sstrl-Svarl),A0 ; move to string area

LAB_1D4B:
                movea.l 4(A0),A1        ; get end address
                movea.l (A0),A0         ; get start address
                bra.s   LAB_1D5E        ; enter loop at exit check

LAB_1D5D:
                cmp.l   (A0)+,D0        ; compare this variable with name
                beq.s   LAB_1DD7        ; branch if match (found var)

                adda.l  D1,A0           ; add offset to next variable
LAB_1D5E:
                cmpa.l  A1,A0           ; compare address with variable space end
                bne.s   LAB_1D5D        ; if not end go check next

                tst.b   Sufnxf(A3)      ; is it a function or function variable
                bne.s   LAB_1D94        ; if was go do DEF or function variable

; reached end of variable mem without match
; ... so create new variable, possibly

                lea     LAB_FVAR(PC),A2 ; get the address of the create if doesn't
; exist call to LAB_GVAR
                cmpa.l  (SP),A2         ; compare the return address with expected
                bne     LAB_UVER        ; if not create go do error or return null

; this will only branch if the call to LAB_GVAR wasn't from LAB_SVAR

LAB_1D94:
                btst    #0,Sufnxf(A3)   ; test function search flag
                bne     LAB_UFER        ; if not doing DEF then go do undefined
; function error

; else create new variable/function
LAB_1D98:
                movea.l Earryl(A3),A2   ; get end of block to move
                move.l  A2,D2           ; copy end of block to move
                sub.l   A1,D2           ; calculate block to move size

                movea.l A2,A0           ; copy end of block to move
                addq.l  #4,D1           ; space for one variable/function + name
                adda.l  D1,A2           ; add space for one variable/function
                move.l  A2,Earryl(A3)   ; set new array mem end
                lsr.l   #1,D2           ; /2 for word copy
                beq.s   LAB_1DAF        ; skip move if zero length block

                subq.l  #1,D2           ; -1 for DFB loop
                swap    D2              ; swap high word to low word
LAB_1DAC:
                swap    D2              ; swap high word to low word
LAB_1DAE:
                move.w  -(A0),-(A2)     ; copy word
                dbra    D2,LAB_1DAE     ; loop until done

                swap    D2              ; swap high word to low word
                dbra    D2,LAB_1DAC     ; decrement high count and loop until done

; get here after creating either a function, variable or string
; if function set variables start, string start, array start
; if variable set string start, array start
; if string set array start

LAB_1DAF:
                tst.b   Sufnxf(A3)      ; was it function
                bmi.s   LAB_1DB0        ; branch if was FN

                btst    #23,D0          ; was it string
                bne.s   LAB_1DB2        ; branch if string

                bra.s   LAB_1DB1        ; branch if was plain variable

LAB_1DB0:
                add.l   D1,Svarl(A3)    ; set new variable memory start
LAB_1DB1:
                add.l   D1,Sstrl(A3)    ; set new start of strings
LAB_1DB2:
                add.l   D1,Sarryl(A3)   ; set new array memory start
                move.l  D0,(A0)+        ; save variable/function name
                move.l  #$00,(A0)       ; initialise variable
                btst    #23,D0          ; was it string
                beq.s   LAB_1DD7        ; branch if not string

                move.w  #$00,4(A0)      ; else initialise string length

; found a match for var ((Vrschl) = ptr)
LAB_1DD7:
                move.l  D0,D1           ; ........ $....... &....... ........
                add.l   D1,D1           ; .......$ .......& ........ .......0
                swap    D1              ; ........ .......0 .......$ .......&
                ror.b   #1,D1           ; ........ .......0 .......$ &.......
                lsr.w   #1,D1           ; ........ .......0 0....... $&.....­.
                and.b   #$C0,D1         ; mask the type bits
                move.b  D1,Dtypef(A3)   ; save the data type

                move.b  #$00,Sufnxf(A3) ; clear FN flag byte

; if you want a non existant variable to return a null value then set the novar
; value at the top of this file to some non zero value

                IF !novar

                moveq   #-1,D0          ; return variable found

                ENDIF

                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; set-up array pointer, d0, to first element in array
; set d0 to (a0)+2*(Dimcnt)+$0A

LAB_1DE6:
                moveq   #5,D0           ; set d0 to 5 (*2 = 10, later)
                add.b   Dimcnt(A3),D0   ; add # of dimensions (1, 2 or 3)
                add.l   D0,D0           ; *2 (bytes per dimension size)
                add.l   A0,D0           ; add array start pointer
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; evaluate unsigned integer expression

LAB_EVIN:
                bsr     LAB_IGBY        ; increment & scan memory
                bsr     LAB_EVNM        ; evaluate expression & check is numeric,
; else do type mismatch


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; evaluate positive integer expression, result in d0 and Itemp

LAB_EVPI:
                tst.b   FAC1_s(A3)      ; test FAC1 sign (b7)
                bmi     LAB_FCER        ; do function call error if -ve


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; evaluate integer expression, no sign check
; result in d0 and Itemp, exit with flags set correctly

LAB_EVIR:
                cmpi.b  #$A0,FAC1_e(A3) ; compare exponent with exponent = 2^32 (n>2^31)
                bcs     LAB_2831        ; convert FAC1 floating to fixed
; result in d0 and Itemp
                bne     LAB_FCER        ; if > do function call error, then warm start

                tst.b   FAC1_s(A3)      ; test sign of FAC1
                bpl     LAB_2831        ; if +ve then ok

                move.l  FAC1_m(A3),D0   ; get mantissa
                neg.l   D0              ; do -d0
                bvc     LAB_FCER        ; if not $80000000 do FC error, then warm start

                move.l  D0,Itemp(A3)    ; else just set it
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; find or make array

LAB_1E17:
                move.w  Defdim(A3),-(SP) ; get DIM flag and data type flag (word in mem)
                moveq   #0,D1           ; clear dimensions count

; now get the array dimension(s) and stack it (them) before the data type and DIM flag

LAB_1E1F:
                move.w  D1,-(SP)        ; save dimensions count
                move.l  Varname(A3),-(SP) ; save variable name
                bsr.s   LAB_EVIN        ; evaluate integer expression

                swap    D0              ; swap high word to low word
                tst.w   D0              ; test swapped high word
                bne     LAB_ABER        ; if too big do array bounds error

                move.l  (SP)+,Varname(A3) ; restore variable name
                move.w  (SP)+,D1        ; restore dimensions count
                move.w  (SP)+,D0        ; restore DIM and data type flags
                move.w  Itemp+2(A3),-(SP) ; stack this dimension size
                move.w  D0,-(SP)        ; save DIM and data type flags
                addq.w  #1,D1           ; increment dimensions count
                bsr     LAB_GBYT        ; scan memory
                cmp.b   #$2C,D0         ; compare with ","
                beq.s   LAB_1E1F        ; if found go do next dimension

                move.b  D1,Dimcnt(A3)   ; store dimensions count
                bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start
                move.w  (SP)+,Defdim(A3) ; restore DIM and data type flags (word in mem)
                movea.l Sarryl(A3),A0   ; get array mem start

; now check to see if we are at the end of array memory (we would be if there were
; no arrays).

LAB_1E5C:
                move.l  A0,Astrtl(A3)   ; save as array start pointer
                cmpa.l  Earryl(A3),A0   ; compare with array mem end
                beq.s   LAB_1EA1        ; go build array if not found

; search for array
                move.l  (A0),D0         ; get this array name
                cmp.l   Varname(A3),D0  ; compare with array name
                beq.s   LAB_1E8D        ; array found so branch

; no match
                movea.l 4(A0),A0        ; get this array size
                adda.l  Astrtl(A3),A0   ; add to array start pointer
                bra.s   LAB_1E5C        ; go check next array

; found array, are we trying to dimension it?
LAB_1E8D:
                tst.b   Defdim(A3)      ; are we trying to dimension it?
                bne     LAB_DDER        ; if so do double dimension error/warm start

; found the array and we're not dimensioning it so we must find an element in it

                bsr     LAB_1DE6        ; set data pointer, d0, to the first element
; in the array
                addq.w  #8,A0           ; index to dimension count
                move.w  (A0)+,D0        ; get no of dimensions
                cmp.b   Dimcnt(A3),D0   ; compare with dimensions count
                beq     LAB_1F28        ; found array so go get element

                bra     LAB_WDER        ; else wrong so do "Wrong dimensions" error

; array not found, so possibly build it
LAB_1EA1:
                tst.b   Defdim(A3)      ; test the default DIM flag
                beq     LAB_UDER        ; if default flag is clear then we are not
; explicitly dimensioning an array so go
; do an "Undimensioned array" error

                bsr     LAB_1DE6        ; set data pointer, d0, to the first element
; in the array
                move.l  Varname(A3),D0  ; get array name
                move.l  D0,(A0)+        ; save array name
                moveq   #4,D1           ; set 4 bytes per element
                btst    #23,D0          ; test if string array
                beq.s   LAB_1EDF        ; branch if not string

                moveq   #6,D1           ; else 6 bytes per element
LAB_1EDF:
                move.l  D1,Asptl(A3)    ; set array data size (bytes per element)
                move.b  Dimcnt(A3),D1   ; get dimensions count
                addq.w  #4,A0           ; skip the array size now (don't know it yet!)
                move.w  D1,(A0)+        ; set array's dimensions count

; now calculate the array data space size

LAB_1EC0:

; If you want arrays to dimension themselves by default then comment out the test
; above and uncomment the next three code lines and the label LAB_1ED0

;       MOVE.w  #$0A,d1                 ; set default dimension value, allow 0 to 9
;       TST.b           Defdim(a3)                      ; test default DIM flag
;       BNE.s           LAB_1ED0                        ; branch if b6 of Defdim is clear

                move.w  (SP)+,D1        ; get dimension size
;*LAB_1ED0
                move.w  D1,(A0)+        ; save to array header
                bsr     LAB_1F7C        ; do this dimension size+1 ; array size
; (d1+1)*(Asptl), result in d0
                move.l  D0,Asptl(A3)    ; save array data size
                subq.b  #1,Dimcnt(A3)   ; decrement dimensions count
                bne.s   LAB_1EC0        ; loop while not = 0

                adda.l  Asptl(A3),A0    ; add size to first element address
                bcs     LAB_OMER        ; if overflow go do "Out of memory" error

                cmpa.l  Sstorl(A3),A0   ; compare with bottom of string memory
                bcs.s   LAB_1ED6        ; branch if less (is ok)

                bsr     LAB_GARB        ; do garbage collection routine
                cmpa.l  Sstorl(A3),A0   ; compare with bottom of string memory
                bcc     LAB_OMER        ; if Sstorl <= a0 do "Out of memory"
; error then warm start

LAB_1ED6:                               ; ok exit, carry set
                move.l  A0,Earryl(A3)   ; save array mem end
                moveq   #0,D0           ; zero d0
                move.l  Asptl(A3),D1    ; get size in bytes
                lsr.l   #1,D1           ; /2 for word fill (may be odd # words)
                subq.w  #1,D1           ; adjust for DBF loop
LAB_1ED8:
                move.w  D0,-(A0)        ; decrement pointer and clear word
                dbra    D1,LAB_1ED8     ; decrement & loop until low word done

                swap    D1              ; swap words
                tst.w   D1              ; test high word
                beq.s   LAB_1F07        ; exit if done

                subq.w  #1,D1           ; decrement low (high) word
                swap    D1              ; swap back
                bra.s   LAB_1ED8        ; go do a whole block

; now we need to calculate the array size by doing Earryl - Astrtl

LAB_1F07:
                movea.l Astrtl(A3),A0   ; get for calculation and as pointer
                move.l  Earryl(A3),D0   ; get array memory end
                sub.l   A0,D0           ; calculate array size
                move.l  D0,4(A0)        ; save size to array
                tst.b   Defdim(A3)      ; test default DIM flag
                bne.s   RTS_011         ; exit (RET) if this was a DIM command

; else, find element
                addq.w  #8,A0           ; index to dimension count
                move.w  (A0)+,Dimcnt(A3) ; get array's dimension count

; we have found, or built, the array. now we need to find the element

LAB_1F28:
                moveq   #0,D0           ; clear first result
                move.l  D0,Asptl(A3)    ; clear array data pointer

; compare nth dimension bound (a0) with nth index (sp)+
; if greater do array bounds error

LAB_1F2C:
                move.w  (A0)+,D1        ; get nth dimension bound
                cmp.w   (SP),D1         ; compare nth index with nth dimension bound
                bcs     LAB_ABER        ; if d1 less or = do array bounds error

; now do pointer = pointer ; nth dimension + nth index

                tst.l   D0              ; test pointer
                beq.s   LAB_1F5A        ; skip multiply if last result = null

                bsr.s   LAB_1F7C        ; do this dimension size+1 ; array size
LAB_1F5A:
                moveq   #0,D1           ; clear longword
                move.w  (SP)+,D1        ; get nth dimension index
                add.l   D1,D0           ; add index to size
                move.l  D0,Asptl(A3)    ; save array data pointer

                subq.b  #1,Dimcnt(A3)   ; decrement dimensions count
                bne.s   LAB_1F2C        ; loop if dimensions still to do

                move.b  #0,Dtypef(A3)   ; set data type to float
                moveq   #3,D1           ; set for numeric array
                tst.b   Varname+1(A3)   ; test if string array
                bpl.s   LAB_1F6A        ; branch if not string

                moveq   #5,D1           ; else set for string array
                move.b  #$80,Dtypef(A3) ; and set data type to string
                bra.s   LAB_1F6B        ; skip integer test

LAB_1F6A:
                tst.b   Varname+2(A3)   ; test if integer array
                bpl.s   LAB_1F6B        ; branch if not integer

                move.b  #$40,Dtypef(A3) ; else set data type to integer
LAB_1F6B:
                bsr.s   LAB_1F7C        ; do element size (d1) ; array size (Asptl)
                adda.l  D0,A0           ; add array data start pointer
RTS_011:
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do this dimension size (d1) ; array data size (Asptl)

; do a 16 x 32 bit multiply
; d1 holds the 16 bit multiplier
; Asptl holds the 32 bit multiplicand

; d0    bbbb  bbbb
; d1    0000  aaaa
;       ----------
; d0    rrrr  rrrr

LAB_1F7C:
                move.l  Asptl(A3),D0    ; get result
                move.l  D0,D2           ; copy it
                swap    D2              ; shift high word to low word
                mulu    D1,D0           ; d1 ; low word = low result
                mulu    D1,D2           ; d1 ; high word = high result
                swap    D2              ; align words for test
                tst.w   D2              ; must be zero
                bne     LAB_OMER        ; if overflow go do "Out of memory" error

                add.l   D2,D0           ; calculate result
                bcs     LAB_OMER        ; if overflow go do "Out of memory" error

                add.l   Asptl(A3),D0    ; add original
                bcs     LAB_OMER        ; if overflow go do "Out of memory" error

                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform FRE()

LAB_FRE:
                tst.b   Dtypef(A3)      ; test data type, $80=string, $40=integer,
; $00=float
                bpl.s   LAB_1FB4        ; branch if numeric

                bsr     LAB_22B6        ; pop string off descriptor stack, or from
; top of string space, returns d0 = length,
; a0 = pointer

; FRE(n) was numeric so do this
LAB_1FB4:
                bsr     LAB_GARB        ; go do garbage collection
                move.l  Sstorl(A3),D0   ; get bottom of string space
                sub.l   Earryl(A3),D0   ; subtract array mem end


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; convert d0 to signed longword in FAC1

LAB_AYFC:
                move.b  #$00,Dtypef(A3) ; clear data type, $80=string, $40=integer,
; $00=float
                move.w  #$A000,FAC1_e(A3) ; set FAC1 exponent and clear sign (b7)
                move.l  D0,FAC1_m(A3)   ; save FAC1 mantissa
                bpl     LAB_24D0        ; convert if +ve

                ori     #1,CCR          ; else set carry
                bra     LAB_24D0        ; do +/- (carry is sign) & normalise FAC1


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; remember if the line length is zero (infinite line) then POS(n) will return
; position MOD tabsize

; perform POS()

LAB_POS:
                move.b  TPos(A3),D0     ; get terminal position

; convert d0 to unsigned byte in FAC1

LAB_1FD0:
                and.l   #$FF,D0         ; clear high bits
                bra.s   LAB_AYFC        ; convert d0 to signed longword in FAC1 & RET

; check not direct (used by DEF and INPUT)

LAB_CKRN:
                tst.b   Clinel(A3)      ; test current line #
                bmi     LAB_IDER        ; if -ve go do illegal direct error then warm
; start

                rts                     ; can continue so return


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform DEF

LAB_DEF:
                moveq   #TK_FN-$0100,D0 ; get FN token
                bsr     LAB_SCCA        ; scan for CHR$(d0), else syntax error and
; warm start
; return character after d0
                move.b  #$80,Sufnxf(A3) ; set FN flag bit
                bsr     LAB_1D12        ; get FN name
                move.l  A0,func_l(A3)   ; save function pointer

                bsr.s   LAB_CKRN        ; check not direct (back here if ok)
                cmpi.b  #$28,(A5)+      ; check next byte is "(" and increment
                bne     LAB_SNER        ; else do syntax error/warm start

                move.b  #$7E,Sufnxf(A3) ; set FN variable flag bits
                bsr     LAB_SVAR        ; search for or create a variable
; return the variable address in a0
                bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start
                moveq   #TK_EQUAL-$0100,D0 ; = token
                bsr     LAB_SCCA        ; scan for CHR$(A), else syntax error/warm start
; return character after d0
                move.l  Varname(A3),-(SP) ; push current variable name
                move.l  A5,-(SP)        ; push BASIC execute pointer
                bsr     LAB_DATA        ; go perform DATA, find end of DEF FN statement
                movea.l func_l(A3),A0   ; get the function pointer
                move.l  (SP)+,(A0)      ; save BASIC execute pointer to function
                move.l  (SP)+,4(A0)     ; save current variable name to function
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; evaluate FNx

LAB_201E:
                move.b  #$81,Sufnxf(A3) ; set FN flag (find not create)
                bsr     LAB_IGBY        ; increment & scan memory
                bsr     LAB_1D12        ; get FN name
                move.b  Dtypef(A3),-(SP) ; push data type flag (function type)
                move.l  A0,-(SP)        ; push function pointer
                cmpi.b  #$28,(A5)       ; check next byte is "(", no increment
                bne     LAB_SNER        ; else do syntax error/warm start

                bsr     LAB_1BF7        ; evaluate expression within parentheses
                movea.l (SP)+,A0        ; pop function pointer
                move.l  A0,func_l(A3)   ; set function pointer
                move.b  Dtypef(A3),-(SP) ; push data type flag (function expression type)

                move.l  4(A0),D0        ; get function variable name
                bsr     LAB_1D4A        ; go find function variable (already created)

; now check type match for variable
                move.b  (SP)+,D0        ; pop data type flag (function expression type)
                rol.b   #1,D0           ; set carry if type = string
                bsr     LAB_CKTM        ; type match check, set C for string

; now stack the function variable value before
; use
                beq.s   LAB_2043        ; branch if not string

                lea     des_sk_e(A3),A1 ; get string stack pointer max+1
                cmpa.l  A1,A4           ; compare string stack pointer with max+1
                beq     LAB_SCER        ; if no space on the stack go do string too
; complex error

                move.w  4(A0),-(A4)     ; string length on descriptor stack
                move.l  (A0),-(A4)      ; string address on stack
                bra.s   LAB_204S        ; skip var push

LAB_2043:
                move.l  (A0),-(SP)      ; push variable
LAB_204S:
                move.l  A0,-(SP)        ; push variable address
                move.b  Dtypef(A3),-(SP) ; push variable data type

                bsr.s   LAB_2045        ; pack function expression value into (a0)
; (function variable)
                move.l  A5,-(SP)        ; push BASIC execute pointer
                movea.l func_l(A3),A0   ; get function pointer
                movea.l (A0),A5         ; save function execute ptr as BASIC execute ptr
                bsr     LAB_EVEX        ; evaluate expression
                bsr     LAB_GBYT        ; scan memory
                bne     LAB_SNER        ; if not [EOL] or [EOS] do syntax error and
; warm start

                movea.l (SP)+,A5        ; restore BASIC execute pointer

; restore variable from stack and test data type

                move.b  (SP)+,D0        ; pull variable data type
                movea.l (SP)+,A0        ; pull variable address
                tst.b   D0              ; test variable data type
                bpl.s   LAB_204T        ; branch if not string

                move.l  (A4)+,(A0)      ; string address from descriptor stack
                move.w  (A4)+,4(A0)     ; string length from descriptor stack
                bra.s   LAB_2044        ; skip variable pull

LAB_204T:
                move.l  (SP)+,(A0)      ; restore variable from stack
LAB_2044:
                move.b  (SP)+,D0        ; pop data type flag (function type)
                rol.b   #1,D0           ; set carry if type = string
                bsr     LAB_CKTM        ; type match check, set C for string
                rts

LAB_2045:
                tst.b   Dtypef(A3)      ; test data type
                bpl     LAB_2778        ; if numeric pack FAC1 into variable (a0)
; and return

                movea.l A0,A2           ; copy variable pointer
                bra     LAB_17D6        ; go do string LET & return



; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform STR$()

LAB_STRS:
                bsr     LAB_2970        ; convert FAC1 to string

; scan, set up string
; print " terminated string to FAC1 stack

LAB_20AE:
                moveq   #$22,D2         ; set Srchc character (terminator 1)
                move.w  D2,D3           ; set Asrch character (terminator 2)

; print d2/d3 terminated string to FAC1 stack
; d2 = Srchc, d3 = Asrch, a0 is source
; a6 is temp

LAB_20B4:
                moveq   #0,D1           ; clear longword
                subq.w  #1,D1           ; set length to -1
                movea.l A0,A2           ; copy start to calculate end
LAB_20BE:
                addq.w  #1,D1           ; increment length
                move.b  0(A0,D1.w),D0   ; get byte from string
                beq.s   LAB_20D0        ; exit loop if null byte [EOS]

                cmp.b   D2,D0           ; compare with search character (terminator 1)
                beq.s   LAB_20CB        ; branch if terminator

                cmp.b   D3,D0           ; compare with terminator 2
                bne.s   LAB_20BE        ; loop if not terminator 2 (or null string)

LAB_20CB:
                cmp.b   #$22,D0         ; compare with "
                bne.s   LAB_20D0        ; branch if not "

                addq.w  #1,A2           ; else increment string start (skip " at end)
LAB_20D0:
                adda.l  D1,A2           ; add longowrd length to make string end+1

                cmpa.l  A3,A0           ; is string in ram
                bcs.s   LAB_RTST        ; if not go push descriptor on stack & exit
; (could be message string from ROM)

                cmpa.l  Smeml(A3),A0    ; is string in utility ram
                bcc.s   LAB_RTST        ; if not go push descriptor on stack & exit
; (is in string or program space)

; (else) copy string to string memory
LAB_20C9:
                movea.l A0,A1           ; copy descriptor pointer
                move.l  D1,D0           ; copy longword length
                bne.s   LAB_20D8        ; branch if not null string

                movea.l D1,A0           ; make null pointer
                bra.s   LAB_RTST        ; go push descriptor on stack & exit

LAB_20D8:
                bsr.s   LAB_2115        ; make string space d1 bytes long
                adda.l  D1,A0           ; new string end
                adda.l  D1,A1           ; old string end
                subq.w  #1,D0           ; -1 for DBF loop
LAB_20E0:
                move.b  -(A1),-(A0)     ; copy byte (source can be odd aligned)
                dbra    D0,LAB_20E0     ; loop until done



; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; check for space on descriptor stack then ...
; put string address and length on descriptor stack & update stack pointers
; start is in a0, length is in d1

LAB_RTST:
                lea     des_sk_e(A3),A1 ; get string stack pointer max+1
                cmpa.l  A1,A4           ; compare string stack pointer with max+1
                beq     LAB_SCER        ; if no space on string stack ..
; .. go do 'string too complex' error

; push string & update pointers
                move.w  D1,-(A4)        ; string length on descriptor stack
                move.l  A0,-(A4)        ; string address on stack
                move.l  A4,FAC1_m(A3)   ; string descriptor pointer in FAC1
                move.b  #$80,Dtypef(A3) ; save data type flag, $80=string
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; build descriptor a0/d1
; make space in string memory for string d1.w long
; return pointer in a0/Sutill

LAB_2115:
                tst.w   D1              ; test length
                beq.s   LAB_2128        ; branch if user wants null string

; make space for string d1 long
                move.l  D0,-(SP)        ; save d0
                moveq   #0,D0           ; clear longword
                move.b  D0,Gclctd(A3)   ; clear garbage collected flag (b7)
                moveq   #1,D0           ; +1 to possibly round up
                and.w   D1,D0           ; mask odd bit
                add.w   D1,D0           ; ensure d0 is even length
                bcc.s   LAB_2117        ; branch if no overflow

                moveq   #1,D0           ; set to allocate 65536 bytes
                swap    D0              ; makes $00010000
LAB_2117:
                movea.l Sstorl(A3),A0   ; get bottom of string space
                suba.l  D0,A0           ; subtract string length
                cmpa.l  Earryl(A3),A0   ; compare with top of array space
                bcs.s   LAB_2137        ; if less do out of memory error

                move.l  A0,Sstorl(A3)   ; save bottom of string space
                move.l  A0,Sutill(A3)   ; save string utility pointer
                move.l  (SP)+,D0        ; restore d0
                tst.w   D1              ; set flags on length
                rts

LAB_2128:
                movea.w D1,A0           ; make null pointer
                rts

LAB_2137:
                tst.b   Gclctd(A3)      ; get garbage collected flag
                bmi     LAB_OMER        ; do "Out of memory" error, then warm start

                move.l  A1,-(SP)        ; save a1
                bsr.s   LAB_GARB        ; else go do garbage collection
                movea.l (SP)+,A1        ; restore a1
                move.b  #$80,Gclctd(A3) ; set garbage collected flag
                bra.s   LAB_2117        ; go try again


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; garbage collection routine

LAB_GARB:
                movem.l D0-D2/A0-A2,-(SP) ; save registers
                move.l  Ememl(A3),Sstorl(A3) ; start with no strings

; re-run routine from last ending
LAB_214B:
                move.l  Earryl(A3),D1   ; set highest uncollected string so far
                moveq   #0,D0           ; clear longword
                movea.l D0,A1           ; clear string to move pointer
                movea.l Sstrl(A3),A0    ; set pointer to start of strings
                lea     4(A0),A0        ; index to string pointer
                movea.l Sarryl(A3),A2   ; set end pointer to start of arrays (end of
; strings)
                bra.s   LAB_2176        ; branch into loop at end loop test

LAB_2161:
                bsr     LAB_2206        ; test and set if this is the highest string
                lea     10(A0),A0       ; increment to next string
LAB_2176:
                cmpa.l  A2,A0           ; compare end of area with pointer
                bcs.s   LAB_2161        ; go do next if not at end

; done strings, now do arrays.

                lea     -4(A0),A0       ; decrement pointer to start of arrays
                movea.l Earryl(A3),A2   ; set end pointer to end of arrays
                bra.s   LAB_218F        ; branch into loop at end loop test

LAB_217E:
                move.l  4(A0),D2        ; get array size
                add.l   A0,D2           ; makes start of next array

                move.l  (A0),D0         ; get array name
                btst    #23,D0          ; test string flag
                beq.s   LAB_218B        ; branch if not string

                move.w  8(A0),D0        ; get # of dimensions
                add.w   D0,D0           ; *2
                adda.w  D0,A0           ; add to skip dimension size(s)
                lea     10(A0),A0       ; increment to first element
LAB_2183:
                bsr.s   LAB_2206        ; test and set if this is the highest string
                addq.w  #6,A0           ; increment to next element
                cmpa.l  D2,A0           ; compare with start of next array
                bne.s   LAB_2183        ; go do next if not at end of array

LAB_218B:
                movea.l D2,A0           ; pointer to next array
LAB_218F:
                cmpa.l  A0,A2           ; compare pointer with array end
                bne.s   LAB_217E        ; go do next if not at end

; done arrays and variables, now just the descriptor stack to do

                movea.l A4,A0           ; get descriptor stack pointer
                lea     des_sk(A3),A2   ; set end pointer to end of stack
                bra.s   LAB_21C4        ; branch into loop at end loop test

LAB_21C2:
                bsr.s   LAB_2206        ; test and set if this is the highest string
                lea     6(A0),A0        ; increment to next string
LAB_21C4:
                cmpa.l  A0,A2           ; compare pointer with stack end
                bne.s   LAB_21C2        ; go do next if not at end

; descriptor search complete, now either exit or set-up and move string

                move.l  A1,D0           ; set the flags (a1 is move string)
                beq.s   LAB_21D1        ; go tidy up and exit if no move

                movea.l (A1),A0         ; a0 is now string start
                moveq   #0,D1           ; clear d1
                move.w  4(A1),D1        ; d1 is string length
                addq.l  #1,D1           ; +1
                and.b   #$FE,D1         ; make even length
                adda.l  D1,A0           ; pointer is now to string end+1
                movea.l Sstorl(A3),A2   ; is destination end+1
                cmpa.l  A2,A0           ; does the string need moving
                beq.s   LAB_2240        ; branch if not

                lsr.l   #1,D1           ; word move so do /2
                subq.w  #1,D1           ; -1 for DBF loop
LAB_2216:
                move.w  -(A0),-(A2)     ; copy word
                dbra    D1,LAB_2216     ; loop until done

                move.l  A2,(A1)         ; save new string start
LAB_2240:
                move.l  (A1),Sstorl(A3) ; string start is new string mem start
                bra     LAB_214B        ; re-run routine from last ending
; (but don't collect this string)

LAB_21D1:
                movem.l (SP)+,D0-D2/A0-A2 ; restore registers
                rts

; test and set if this is the highest string

LAB_2206:
                move.l  (A0),D0         ; get this string pointer
                beq.s   RTS_012         ; exit if null string

                cmp.l   D0,D1           ; compare with highest uncollected string so far
                bcc.s   RTS_012         ; exit if <= with highest so far

                cmp.l   Sstorl(A3),D0   ; compare with bottom of string space
                bcc.s   RTS_012         ; exit if >= bottom of string space

                moveq   #-1,D0          ; d0 = $FFFFFFFF
                move.w  4(A0),D0        ; d0 is string length
                neg.w   D0              ; make -ve
                and.b   #$FE,D0         ; make -ve even length
                add.l   Sstorl(A3),D0   ; add string store to -ve length
                cmp.l   (A0),D0         ; compare with string address
                beq.s   LAB_2212        ; if = go move string store pointer down

                move.l  (A0),D1         ; highest = current
                movea.l A0,A1           ; string to move = current
                rts

LAB_2212:
                move.l  D0,Sstorl(A3)   ; set new string store start
RTS_012:
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; concatenate - add strings
; string descriptor 1 is in FAC1_m, string 2 is in line

LAB_224D:
                pea     LAB_1ADB(PC)    ; continue evaluation after concatenate
                move.l  FAC1_m(A3),-(SP) ; stack descriptor pointer for string 1

                bsr     LAB_GVAL        ; get value from line
                tst.b   Dtypef(A3)      ; test data type flag
                bpl     LAB_TMER        ; if type is not string do type mismatch error

                movea.l (SP)+,A0        ; restore descriptor pointer for string 1

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; concatenate
; string descriptor 1 is in a0, string descriptor 2 is in FAC1_m

LAB_224E:
                movea.l FAC1_m(A3),A1   ; copy descriptor pointer 2
                move.w  4(A0),D1        ; get length 1
                add.w   4(A1),D1        ; add length 2
                bcs     LAB_SLER        ; if overflow go do 'string too long' error

                move.l  A0,-(SP)        ; save descriptor pointer 1
                bsr     LAB_2115        ; make space d1 bytes long
                move.l  A0,FAC2_m(A3)   ; save new string start pointer
                movea.l (SP),A0         ; copy descriptor pointer 1 from stack
                move.w  4(A0),D0        ; get length
                movea.l (A0),A0         ; get string pointer
                bsr.s   LAB_229E        ; copy string d0 bytes long from a0 to Sutill
; return with a0 = pointer, d1 = length

                movea.l FAC1_m(A3),A0   ; get descriptor pointer for string 2
                bsr.s   LAB_22BA        ; pop (a0) descriptor, returns with ..
; a0 = pointer, d0 = length
                bsr.s   LAB_229E        ; copy string d0 bytes long from a0 to Sutill
; return with a0 = pointer, d1 = length

                movea.l (SP)+,A0        ; get descriptor pointer for string 1
                bsr.s   LAB_22BA        ; pop (a0) descriptor, returns with ..
; d0 = length, a0 = pointer

                movea.l FAC2_m(A3),A0   ; retreive the result string pointer
                move.l  A0,D1           ; copy the result string pointer
                beq     LAB_RTST        ; if it is a null string just return it
; a0 = pointer, d1 = length

                neg.l   D1              ; else make the start pointer negative
                add.l   Sutill(A3),D1   ; add the end pointert to give the length
                bra     LAB_RTST        ; push string on descriptor stack
; a0 = pointer, d1 = length


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; copy string d0 bytes long from a0 to Sutill
; return with a0 = pointer, d1 = length

LAB_229E:
                move.w  D0,D1           ; copy and check length
                beq.s   RTS_013         ; skip copy if null

                movea.l Sutill(A3),A1   ; get destination pointer
                move.l  A1,-(SP)        ; save destination string pointer
                subq.w  #1,D0           ; subtract for DBF loop
LAB_22A0:
                move.b  (A0)+,(A1)+     ; copy byte
                dbra    D0,LAB_22A0     ; loop if not done

                move.l  A1,Sutill(A3)   ; update Sutill to end of copied string
                movea.l (SP)+,A0        ; restore destination string pointer
RTS_013:
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; pop string off descriptor stack, or from top of string space
; returns with d0.l = length, a0 = pointer

LAB_22B6:
                movea.l FAC1_m(A3),A0   ; get descriptor pointer


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; pop (a0) descriptor off stack or from string space
; returns with d0.l = length, a0 = pointer

LAB_22BA:
                movem.l D1/A1,-(SP)     ; save other regs
                cmpa.l  A0,A4           ; is string on the descriptor stack
                bne.s   LAB_22BD        ; skip pop if not

                addq.w  #$06,A4         ; else update stack pointer
LAB_22BD:
                moveq   #0,D0           ; clear string length longword
                movea.l (A0)+,A1        ; get string address
                move.w  (A0)+,D0        ; get string length

                cmpa.l  A0,A4           ; was it on the descriptor stack
                bne.s   LAB_22E6        ; branch if it wasn't

                cmpa.l  Sstorl(A3),A1   ; compare string address with bottom of string
; space
                bne.s   LAB_22E6        ; branch if <>

                moveq   #1,D1           ; mask for odd bit
                and.w   D0,D1           ; AND length
                add.l   D0,D1           ; make it fit word aligned length

                add.l   D1,Sstorl(A3)   ; add to bottom of string space
LAB_22E6:
                movea.l A1,A0           ; copy to a0
                movem.l (SP)+,D1/A1     ; restore other regs
                tst.l   D0              ; set flags on length
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform CHR$()

LAB_CHRS:
                bsr     LAB_EVBY        ; evaluate byte expression, result in d0 and
; Itemp
LAB_MKCHR:
                moveq   #1,D1           ; string is single byte
                bsr     LAB_2115        ; make string space d1 bytes long
; return a0/Sutill = pointer, others unchanged
                move.b  D0,(A0)         ; save byte in string (byte IS string!)
                bra     LAB_RTST        ; push string on descriptor stack
; a0 = pointer, d1 = length


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform LEFT$()

; enter with a0 is descriptor, d0 & Itemp is word 1

LAB_LEFT:
                exg     D0,D1           ; word in d1
                bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start

                tst.l   D1              ; test returned length
                beq.s   LAB_231C        ; branch if null return

                moveq   #0,D0           ; clear start offset
                cmp.w   4(A0),D1        ; compare word parameter with string length
                bcs.s   LAB_231C        ; branch if string length > word parameter

                bra.s   LAB_2317        ; go copy whole string


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform RIGHT$()

; enter with a0 is descriptor, d0 & Itemp is word 1

LAB_RIGHT:
                exg     D0,D1           ; word in d1
                bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start

                tst.l   D1              ; test returned length
                beq.s   LAB_231C        ; branch if null return

                move.w  4(A0),D0        ; get string length
                sub.l   D1,D0           ; subtract word
                bcc.s   LAB_231C        ; branch if string length > word parameter

; else copy whole string
LAB_2316:
                moveq   #0,D0           ; clear start offset
LAB_2317:
                move.w  4(A0),D1        ; else make parameter = length

; get here with ...
;   a0 - points to descriptor
;   d0 - is offset from string start
;   d1 - is r.EQUired string length

LAB_231C:
                movea.l A0,A1           ; save string descriptor pointer
                bsr     LAB_2115        ; make string space d1 bytes long
; return a0/Sutill = pointer, others unchanged
                movea.l A1,A0           ; restore string descriptor pointer
                move.l  D0,-(SP)        ; save start offset (longword)
                bsr.s   LAB_22BA        ; pop (a0) descriptor, returns with ..
; d0 = length, a0 = pointer
                adda.l  (SP)+,A0        ; adjust pointer to start of wanted string
                move.w  D1,D0           ; length to d0
                bsr     LAB_229E        ; store string d0 bytes long from (a0) to
; (Sutill) return with a0 = pointer,
; d1 = length
                bra     LAB_RTST        ; push string on descriptor stack
; a0 = pointer, d1 = length


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform MID$()

; enter with a0 is descriptor, d0 & Itemp is word 1

LAB_MIDS:
                moveq   #0,D7           ; clear longword
                subq.w  #1,D7           ; set default length = 65535
                move.l  D0,-(SP)        ; save word 1
                bsr     LAB_GBYT        ; scan memory
                cmp.b   #',',D0         ; was it ","
                bne.s   LAB_2358        ; branch if not "," (skip second byte get)

                move.b  (A5)+,D0        ; increment pointer past ","
                move.l  A0,-(SP)        ; save descriptor pointer
                bsr     LAB_GTWO        ; get word parameter, result in d0 and Itemp
                movea.l (SP)+,A0        ; restore descriptor pointer
                move.l  D0,D7           ; copy length
LAB_2358:
                bsr     LAB_1BFB        ; scan for ")", else do syntax error then warm
; start
                move.l  (SP)+,D0        ; restore word 1
                moveq   #0,D1           ; null length
                subq.l  #1,D0           ; decrement start index (word 1)
                bmi     LAB_FCER        ; if was null do function call error then warm
; start

                cmp.w   4(A0),D0        ; compare string length with start index
                bcc.s   LAB_231C        ; if start not in string do null string (d1=0)

                move.l  D7,D1           ; get length back
                add.w   D0,D7           ; d7 now = MID$() end
                bcs.s   LAB_2368        ; already too long so do RIGHT$ .EQUivalent

                cmp.w   4(A0),D7        ; compare string length with start index+length
                bcs.s   LAB_231C        ; if end in string go do string

LAB_2368:
                move.w  4(A0),D1        ; get string length
                sub.w   D0,D1           ; subtract start offset
                bra.s   LAB_231C        ; go do string (effectively RIGHT$)


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform LCASE$()

LAB_LCASE:
                bsr     LAB_22B6        ; pop string off descriptor stack or from memory
; returns with d0 = length, a0 = pointer
                move.l  D0,D1           ; copy the string length
                beq.s   NoString        ; if null go return a null string

; else copy and change the string

                movea.l A0,A1           ; copy the string address
                bsr     LAB_2115        ; make a string space d1 bytes long
                adda.l  D1,A0           ; new string end
                adda.l  D1,A1           ; old string end
                move.w  D1,D2           ; copy length for loop
                subq.w  #1,D2           ; -1 for DBF loop
LC_loop:
                move.b  -(A1),D0        ; get byte from string

                cmp.b   #$5B,D0         ; compare with "Z"+1
                bcc.s   NoUcase         ; if > "Z" skip change

                cmp.b   #$41,D0         ; compare with "A"
                bcs.s   NoUcase         ; if < "A" skip change

                ori.b   #$20,D0         ; convert upper case to lower case
NoUcase:
                move.b  D0,-(A0)        ; copy upper case byte back to string
                dbra    D2,LC_loop      ; decrement and loop if not all done

                bra.s   NoString        ; tidy up & exit (branch always)


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform UCASE$()

LAB_UCASE:
                bsr     LAB_22B6        ; pop string off descriptor stack or from memory
; returns with d0 = length, a0 = pointer
                move.l  D0,D1           ; copy the string length
                beq.s   NoString        ; if null go return a null string

; else copy and change the string

                movea.l A0,A1           ; copy the string address
                bsr     LAB_2115        ; make a string space d1 bytes long
                adda.l  D1,A0           ; new string end
                adda.l  D1,A1           ; old string end
                move.w  D1,D2           ; copy length for loop
                subq.w  #1,D2           ; -1 for DBF loop
UC_loop:
                move.b  -(A1),D0        ; get a byte from the string

                cmp.b   #$61,D0         ; compare with "a"
                bcs.s   NoLcase         ; if < "a" skip change

                cmp.b   #$7B,D0         ; compare with "z"+1
                bcc.s   NoLcase         ; if > "z" skip change

                andi.b  #$DF,D0         ; convert lower case to upper case
NoLcase:
                move.b  D0,-(A0)        ; copy upper case byte back to string
                dbra    D2,UC_loop      ; decrement and loop if not all done

NoString:
                bra     LAB_RTST        ; push string on descriptor stack
; a0 = pointer, d1 = length


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; perform SADD()

LAB_SADD:
                move.b  (A5)+,D0        ; increment pointer
                bsr     LAB_GVAR        ; get variable address in a0
                bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start
                tst.b   Dtypef(A3)      ; test data type flag
                bpl     LAB_TMER        ; if numeric do Type missmatch Error

; if you want a non existant variable to return a null value then set the novar
; value at the top of this file to some non zero value

                IF !novar

                move.l  A0,D0           ; test the variable found flag
                beq     LAB_AYFC        ; if not found go return null

                ENDIF

                move.l  (A0),D0         ; get string address
                bra     LAB_AYFC        ; convert d0 to signed longword in FAC1 & return


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform LEN()

LAB_LENS:
                pea     LAB_AYFC(PC)    ; set return address to convert d0 to signed
; longword in FAC1
                bra     LAB_22B6        ; pop string off descriptor stack or from memory
; returns with d0 = length, a0 = pointer


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform ASC()

LAB_ASC:
                bsr     LAB_22B6        ; pop string off descriptor stack or from memory
; returns with d0 = length, a0 = pointer
                tst.w   D0              ; test length
                beq     LAB_FCER        ; if null do function call error then warm start

                move.b  (A0),D0         ; get first character byte
                bra     LAB_1FD0        ; convert d0 to unsigned byte in FAC1 & return


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; increment and get byte, result in d0 and Itemp

LAB_SGBY:
                bsr     LAB_IGBY        ; increment & scan memory


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; get byte parameter, result in d0 and Itemp

LAB_GTBY:
                bsr     LAB_EVNM        ; evaluate expression & check is numeric,
; else do type mismatch


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; evaluate byte expression, result in d0 and Itemp

LAB_EVBY:
                bsr     LAB_EVPI        ; evaluate positive integer expression
; result in d0 and Itemp
                moveq   #$80,D1         ; set mask/2
                add.l   D1,D1           ; =$FFFFFF00
                and.l   D0,D1           ; check top 24 bits
                bne     LAB_FCER        ; if <> 0 do function call error/warm start

                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; get word parameter, result in d0 and Itemp

LAB_GTWO:
                bsr     LAB_EVNM        ; evaluate expression & check is numeric,
; else do type mismatch
                bsr     LAB_EVPI        ; evaluate positive integer expression
; result in d0 and Itemp
                swap    D0              ; copy high word to low word
                tst.w   D0              ; set flags
                bne     LAB_FCER        ; if <> 0 do function call error/warm start

                swap    D0              ; copy high word to low word
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform VAL()

LAB_VAL:
                bsr     LAB_22B6        ; pop string off descriptor stack or from memory
; returns with d0 = length, a0 = pointer
                beq.s   LAB_VALZ        ; string was null so set result = $00
; clear FAC1 exponent & sign & return

                movea.l A5,A6           ; save BASIC execute pointer
                movea.l A0,A5           ; copy string pointer to execute pointer
                adda.l  D0,A0           ; string end+1
                move.b  (A0),D0         ; get byte from string+1
                move.w  D0,-(SP)        ; save it
                move.l  A0,-(SP)        ; save address
                move.b  #0,(A0)         ; null terminate string
                bsr     LAB_GBYT        ; scan memory
                bsr     LAB_2887        ; get FAC1 from string
                movea.l (SP)+,A0        ; restore pointer
                move.w  (SP)+,D0        ; pop byte
                move.b  D0,(A0)         ; restore to memory
                movea.l A6,A5           ; restore BASIC execute pointer
                rts

LAB_VALZ:
                move.w  D0,FAC1_e(A3)   ; clear FAC1 exponent & sign
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; get two parameters for POKE or WAIT, first parameter in a0, second in d0

LAB_GADB:
                bsr     LAB_EVNM        ; evaluate expression & check is numeric,
; else do type mismatch
                bsr     LAB_EVIR        ; evaluate integer expression
; (does FC error not OF error if out of range)
                move.l  D0,-(SP)        ; copy to stack
                bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start
                bsr.s   LAB_GTBY        ; get byte parameter, result in d0 and Itemp
                movea.l (SP)+,A0        ; pull address
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; get two parameters for DOKE or WAITW, first parameter in a0, second in d0

LAB_GADW:
                bsr.s   LAB_GEAD        ; get even address for word/long memory actions
; address returned in d0 and on the stack
                bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start
                bsr     LAB_EVNM        ; evaluate expression & check is numeric,
; else do type mismatch
                bsr     LAB_EVIR        ; evaluate integer expression
; result in d0 and Itemp
                swap    D0              ; swap words
                tst.w   D0              ; test high word
                beq.s   LAB_XGADW       ; exit if null

                addq.w  #1,D0           ; increment word
                bne     LAB_FCER        ; if <> 0 do function call error/warm start

LAB_XGADW:
                swap    D0              ; swap words back
                movea.l (SP)+,A0        ; pull address
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; get even address (for word or longword memory actions)
; address returned in d0 and on the stack
; does address error if the address is odd

LAB_GEAD:
                bsr     LAB_EVNM        ; evaluate expression & check is numeric,
; else do type mismatch
                bsr     LAB_EVIR        ; evaluate integer expression
; (does FC error not OF error if out of range)
                btst    #0,D0           ; test low bit of longword
                bne     LAB_ADER        ; if address is odd do address error/warm start

                movea.l (SP),A0         ; copy return address
                move.l  D0,(SP)         ; even address on stack
                jmp     (A0)            ; effectively RTS


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform PEEK()

LAB_PEEK:
                bsr     LAB_EVIR        ; evaluate integer expression
; (does FC error not OF error if out of range)
                movea.l D0,A0           ; copy to address register
                move.b  (A0),D0         ; get byte
                bra     LAB_1FD0        ; convert d0 to unsigned byte in FAC1 & return


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;
; perform POKE

LAB_POKE:
                bsr.s   LAB_GADB        ; get two parameters for POKE or WAIT
; first parameter in a0, second in d0
                move.b  D0,(A0)         ; put byte in memory
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform DEEK()

LAB_DEEK:
                bsr     LAB_EVIR        ; evaluate integer expression
; (does FC error not OF error if out of range)
                lsr.b   #1,D0           ; shift bit 0 to carry
                bcs     LAB_ADER        ; if address is odd do address error/warm start

                add.b   D0,D0           ; shift byte back
                exg     A0,D0           ; copy to address register
                moveq   #0,D0           ; clear top bits
                move.w  (A0),D0         ; get word
                bra     LAB_AYFC        ; convert d0 to signed longword in FAC1 & return


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform LEEK()

LAB_LEEK:
                bsr     LAB_EVIR        ; evaluate integer expression
; (does FC error not OF error if out of range)
                lsr.b   #1,D0           ; shift bit 0 to carry
                bcs     LAB_ADER        ; if address is odd do address error/warm start

                add.b   D0,D0           ; shift byte back
                exg     A0,D0           ; copy to address register
                move.l  (A0),D0         ; get longword
                bra     LAB_AYFC        ; convert d0 to signed longword in FAC1 & return


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform DOKE

LAB_DOKE:
                bsr.s   LAB_GADW        ; get two parameters for DOKE or WAIT
; first parameter in a0, second in d0
                move.w  D0,(A0)         ; put word in memory
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform LOKE

LAB_LOKE:
                bsr.s   LAB_GEAD        ; get even address for word/long memory actions
; address returned in d0 and on the stack
                bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start
                bsr     LAB_EVNM        ; evaluate expression & check is numeric,
; else do type mismatch
                bsr     LAB_EVIR        ; evaluate integer value (no sign check)
                movea.l (SP)+,A0        ; pull address
                move.l  D0,(A0)         ; put longword in memory
RTS_015:
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform SWAP

LAB_SWAP:
                bsr     LAB_GVAR        ; get variable 1 address in a0
                move.l  A0,-(SP)        ; save variable 1 address
                move.b  Dtypef(A3),D4   ; copy variable 1 data type, $80=string,
; $40=inetger, $00=float

                bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start
                bsr     LAB_GVAR        ; get variable 2 address in a0
                movea.l (SP)+,A2        ; restore variable 1 address
                cmp.b   Dtypef(A3),D4   ; compare variable 1 data type with variable 2
; data type
                bne     LAB_TMER        ; if not both the same type do "Type mismatch"
; error then warm start

; if you do want a non existant variable to return an error then leave the novar
; value at the top of this file set to zero

                IF novar

                move.l  (A0),D0         ; get variable 2
                move.l  (A2),(A0)+      ; copy variable 1 to variable 2
                move.l  D0,(A2)+        ; save variable 2 to variable 1

                tst.b   D4              ; check data type
                bpl.s   RTS_015         ; exit if not string

                move.w  (A0),D0         ; get string 2 length
                move.w  (A2),(A0)       ; copy string 1 length to string 2 length
                move.w  D0,(A2)         ; save string 2 length to string 1 length

                ENDIF


; if you want a non existant variable to return a null value then set the novar
; value at the top of this file to some non zero value

                IF !novar

                move.l  A2,D2           ; copy the variable 1 pointer
                move.l  D2,D3           ; and again for any length
                beq.s   no_variable1    ; if variable 1 doesn't exist skip the
; value get

                move.l  (A2),D2         ; get variable 1 value
                tst.b   D4              ; check the data type
                bpl.s   no_variable1    ; if not string skip the length get

                move.w  4(A2),D3        ; else get variable 1 string length
no_variable1:
                move.l  A0,D0           ; copy the variable 2 pointer
                move.l  D0,D1           ; and again for any length
                beq.s   no_variable2    ; if variable 2 doesn't exist skip the
; value get and the new value save

                move.l  (A0),D0         ; get variable 2 value
                move.l  D2,(A0)+        ; save variable 2 new value
                tst.b   D4              ; check the data type
                bpl.s   no_variable2    ; if not string skip the length get and
; new length save

                move.w  (A0),D1         ; else get variable 2 string length
                move.w  D3,(A0)         ; save variable 2 new string length
no_variable2:
                tst.l   D2              ; test if variable 1 exists
                beq.s   EXIT_SWAP       ; if variable 1 doesn't exist skip the
; new value save

                move.l  D0,(A2)+        ; save variable 1 new value
                tst.b   D4              ; check the data type
                bpl.s   EXIT_SWAP       ; if not string skip the new length save

                move.w  D1,(A2)         ; save variable 1 new string length
EXIT_SWAP:

                ENDIF

                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform USR

LAB_USR:
                jsr     Usrjmp(A3)      ; do user vector
                bra     LAB_1BFB        ; scan for ")", else do syntax error/warm start


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform LOAD

LAB_LOAD:
                jmp     V_LOAD(A3)      ; do load vector


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform SAVE

LAB_SAVE:
                jmp     V_SAVE(A3)      ; do save vector


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform CALL

LAB_CALL:
                pea     LAB_GBYT(PC)    ; put return address on stack
                bsr     LAB_GEAD        ; get even address for word/long memory actions
; address returned in d0 and on the stack
                rts                     ; effectively calls the routine

; if the called routine exits correctly then it will return via the get byte routine.
; this will then get the next byte for the interpreter and return


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform WAIT

LAB_WAIT:
                bsr     LAB_GADB        ; get two parameters for POKE or WAIT
; first parameter in a0, second in d0
                move.l  A0,-(SP)        ; save address
                move.w  D0,-(SP)        ; save byte
                moveq   #0,D2           ; clear mask
                bsr     LAB_GBYT        ; scan memory
                beq.s   LAB_2441        ; skip if no third argument

                bsr     LAB_SCGB        ; scan for "," & get byte,
; else do syntax error/warm start
                move.l  D0,D2           ; copy mask
LAB_2441:
                move.w  (SP)+,D1        ; get byte
                movea.l (SP)+,A0        ; get address
LAB_2445:
                move.b  (A0),D0         ; read memory byte
                eor.b   D2,D0           ; EOR with second argument (mask)
                and.b   D1,D0           ; AND with first argument (byte)
                beq.s   LAB_2445        ; loop if result is zero

                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform subtraction, FAC1 from FAC2

LAB_SUBTRACT:
                eori.b  #$80,FAC1_s(A3) ; complement FAC1 sign
                move.b  FAC2_s(A3),FAC_sc(A3) ; copy FAC2 sign byte

                move.b  FAC1_s(A3),D0   ; get FAC1 sign byte
                eor.b   D0,FAC_sc(A3)   ; EOR with FAC2 sign


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; add FAC2 to FAC1

LAB_ADD:
                move.b  FAC1_e(A3),D0   ; get exponent
                beq     LAB_279B        ; FAC1 was zero so copy FAC2 to FAC1 & return

; FAC1 is non zero
                lea     FAC2_m(A3),A0   ; set pointer1 to FAC2 mantissa
                move.b  FAC2_e(A3),D0   ; get FAC2 exponent
                beq.s   RTS_016         ; exit if zero

                sub.b   FAC1_e(A3),D0   ; subtract FAC1 exponent
                beq.s   LAB_24A8        ; branch if = (go add mantissa)

                bcs.s   LAB_249C        ; branch if FAC2 < FAC1

; FAC2 > FAC1
                move.w  FAC2_e(A3),FAC1_e(A3) ; copy sign and exponent of FAC2
                neg.b   D0              ; negate exponent difference (make diff -ve)
                subq.w  #8,A0           ; pointer1 to FAC1

LAB_249C:
                neg.b   D0              ; negate exponent difference (make diff +ve)
                move.l  D1,-(SP)        ; save d1
                cmp.b   #32,D0          ; compare exponent diff with 32
                blt.s   LAB_2467        ; branch if range >= 32

                moveq   #0,D1           ; clear d1
                bra.s   LAB_2468        ; go clear smaller mantissa

LAB_2467:
                move.l  (A0),D1         ; get FACx mantissa
                lsr.l   D0,D1           ; shift d0 times right
LAB_2468:
                move.l  D1,(A0)         ; save it back
                move.l  (SP)+,D1        ; restore d1

; exponents are .EQUal now do mantissa add or
; subtract
LAB_24A8:
                tst.b   FAC_sc(A3)      ; test sign compare (FAC1 EOR FAC2)
                bmi.s   LAB_24F8        ; if <> go do subtract

                move.l  FAC2_m(A3),D0   ; get FAC2 mantissa
                add.l   FAC1_m(A3),D0   ; add FAC1 mantissa
                bcc.s   LAB_24F7        ; save and exit if no carry (FAC1 is normal)

                roxr.l  #1,D0           ; else shift carry back into mantissa
                addq.b  #1,FAC1_e(A3)   ; increment FAC1 exponent
                bcs     LAB_OFER        ; if carry do overflow error & warm start

LAB_24F7:
                move.l  D0,FAC1_m(A3)   ; save mantissa
RTS_016:
                rts
; signs are different
LAB_24F8:
                lea     FAC1_m(A3),A1   ; pointer 2 to FAC1
                cmpa.l  A0,A1           ; compare pointers
                bne.s   LAB_24B4        ; branch if <>

                addq.w  #8,A1           ; else pointer2 to FAC2

; take smaller from bigger (take sign of bigger)
LAB_24B4:
                move.l  (A1),D0         ; get larger mantissa
                move.l  (A0),D1         ; get smaller mantissa
                move.l  D0,FAC1_m(A3)   ; save larger mantissa
                sub.l   D1,FAC1_m(A3)   ; subtract smaller


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; do +/- (carry is sign) & normalise FAC1

LAB_24D0:
                bcc.s   LAB_24D5        ; branch if result is +ve

; erk! subtract is the wrong way round so
; negate everything
                eori.b  #$FF,FAC1_s(A3) ; complement FAC1 sign
                neg.l   FAC1_m(A3)      ; negate FAC1 mantissa


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; normalise FAC1

LAB_24D5:
                move.l  FAC1_m(A3),D0   ; get mantissa
                bmi.s   LAB_24DA        ; mantissa is normal so just exit

                bne.s   LAB_24D9        ; mantissa is not zero so go normalise FAC1

                move.w  D0,FAC1_e(A3)   ; else make FAC1 = +zero
                rts

LAB_24D9:
                move.l  D1,-(SP)        ; save d1
                move.l  D0,D1           ; mantissa to d1
                moveq   #0,D0           ; clear d0
                move.b  FAC1_e(A3),D0   ; get exponent byte
                beq.s   LAB_24D8        ; if exponent is zero then clean up and exit
LAB_24D6:
                add.l   D1,D1           ; shift mantissa, ADD is quicker for a single
; shift
                dbmi    D0,LAB_24D6     ; decrement exponent and loop if mantissa and
; exponent +ve

                tst.w   D0              ; test exponent
                beq.s   LAB_24D8        ; if exponent is zero make FAC1 zero

                bpl.s   LAB_24D7        ; if exponent is >zero go save FAC1

                moveq   #1,D0           ; else set for zero after correction
LAB_24D7:
                subq.b  #1,D0           ; adjust exponent for loop
                move.l  D1,FAC1_m(A3)   ; save normalised mantissa
LAB_24D8:
                move.l  (SP)+,D1        ; restore d1
                move.b  D0,FAC1_e(A3)   ; save corrected exponent
LAB_24DA:
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform LOG()

LAB_LOG:
                tst.b   FAC1_s(A3)      ; test sign
                bmi     LAB_FCER        ; if -ve do function call error/warm start

                moveq   #0,D7           ; clear d7
                move.b  D7,FAC_sc(A3)   ; clear sign compare
                move.b  FAC1_e(A3),D7   ; get exponent
                beq     LAB_FCER        ; if 0 do function call error/warm start

                sub.l   #$81,D7         ; normalise exponent
                move.b  #$81,FAC1_e(A3) ; force a value between 1 and 2
                move.l  FAC1_m(A3),D6   ; copy mantissa

                move.l  #$80000000,FAC2_m(A3) ; set mantissa for 1
                move.w  #$8100,FAC2_e(A3) ; set exponent for 1
                bsr     LAB_ADD         ; find arg+1
                moveq   #0,D0           ; setup for calc skip
                move.w  D0,FAC2_e(A3)   ; set FAC1 for zero result
                add.l   D6,D6           ; shift 1 bit out
                move.l  D6,FAC2_m(A3)   ; put back FAC2
                beq.s   LAB_LONN        ; if 0 skip calculation

                move.w  #$8000,FAC2_e(A3) ; set exponent for .5
                bsr     LAB_DIVIDE      ; do (arg-1)/(arg+1)
                tst.b   FAC1_e(A3)      ; test exponent
                beq.s   LAB_LONN        ; if 0 skip calculation

                move.b  FAC1_e(A3),D1   ; get exponent
                sub.b   #$82,D1         ; normalise and two integer bits
                neg.b   D1              ; negate for shift
*;      CMP.b           #$1F,d1                 ; will mantissa vanish?
*;      BGT.s           LAB_dunno                       ; if so do ???

                move.l  FAC1_m(A3),D0   ; get mantissa
                lsr.l   D1,D0           ; shift in two integer bits

; d0 = arg
; d0 = x, d1 = y
; d2 = x1, d3 = y1
; d4 = shift count
; d5 = loop count
; d6 = z
; a0 = table pointer

                moveq   #0,D6           ; z = 0
                move.l  #1<<30,D1       ; y = 1
                lea     TAB_HTHET(PC),A0 ; get pointer to hyperbolic tangent table
                moveq   #30,D5          ; loop 31 times
                moveq   #1,D4           ; set shift count
                bra.s   LAB_LOCC        ; entry point for loop

LAB_LAAD:
                asr.l   D4,D2           ; x1 >> i
                sub.l   D2,D1           ; y = y - x1
                add.l   (A0),D6         ; z = z + tanh(i)
LAB_LOCC:
                move.l  D0,D2           ; x1 = x
                move.l  D1,D3           ; y1 = Y
                asr.l   D4,D3           ; y1 >> i
                bcc.s   LAB_LOLP

                addq.l  #1,D3
LAB_LOLP:
                sub.l   D3,D0           ; x = x - y1
                bpl.s   LAB_LAAD        ; branch if > 0

                move.l  D2,D0           ; get x back
                addq.w  #4,A0           ; next entry
                addq.l  #1,D4           ; next i
                lsr.l   #1,D3           ; /2
                beq.s   LAB_LOCX        ; branch y1 = 0

                dbra    D5,LAB_LOLP     ; decrement and loop if not done

; now sort out the result
LAB_LOCX:
                add.l   D6,D6           ; *2
                move.l  D6,D0           ; setup for d7 = 0
LAB_LONN:
                move.l  D0,D4           ; save cordic result
                moveq   #0,D5           ; set default exponent sign
                tst.l   D7              ; check original exponent sign
                beq.s   LAB_LOXO        ; branch if original was 0

                bpl.s   LAB_LOXP        ; branch if was +ve

                neg.l   D7              ; make original exponent +ve
                moveq   #$80-$0100,D5   ; make sign -ve
LAB_LOXP:
                move.b  D5,FAC1_s(A3)   ; save original exponent sign
                swap    D7              ; 16 bit shift
                lsl.l   #8,D7           ; easy first part
                moveq   #$88-$0100,D5   ; start with byte
LAB_LONE:
                subq.l  #1,D5           ; decrement exponent
                add.l   D7,D7           ; shift mantissa
                bpl.s   LAB_LONE        ; loop if not normal

LAB_LOXO:
                move.l  D7,FAC1_m(A3)   ; save original exponent as mantissa
                move.b  D5,FAC1_e(A3)   ; save exponent for this
                move.l  #$B17217F8,FAC2_m(A3) ; LOG(2) mantissa
                move.w  #$8000,FAC2_e(A3) ; LOG(2) exponent & sign
                move.b  FAC1_s(A3),FAC_sc(A3) ; make sign compare = FAC1 sign
                bsr.s   LAB_MULTIPLY    ; do multiply
                move.l  D4,FAC2_m(A3)   ; save cordic result
                beq.s   LAB_LOWZ        ; branch if zero

                move.w  #$8200,FAC2_e(A3) ; set exponent & sign
                move.b  FAC1_s(A3),FAC_sc(A3) ; clear sign compare
                bsr     LAB_ADD         ; and add for final result

LAB_LOWZ:
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; multiply FAC1 by FAC2

LAB_MULTIPLY:
                movem.l D0-D4,-(SP)     ; save registers
                tst.b   FAC1_e(A3)      ; test FAC1 exponent
                beq.s   LAB_MUUF        ; if exponent zero go make result zero

                move.b  FAC2_e(A3),D0   ; get FAC2 exponent
                beq.s   LAB_MUUF        ; if exponent zero go make result zero

                move.b  FAC_sc(A3),FAC1_s(A3) ; sign compare becomes sign

                add.b   FAC1_e(A3),D0   ; multiply exponents by adding
                bcc.s   LAB_MNOC        ; branch if no carry

                sub.b   #$80,D0         ; normalise result
                bcc     LAB_OFER        ; if no carry do overflow

                bra.s   LAB_MADD        ; branch

; no carry for exponent add
LAB_MNOC:
                sub.b   #$80,D0         ; normalise result
                bcs.s   LAB_MUUF        ; return zero if underflow

LAB_MADD:
                move.b  D0,FAC1_e(A3)   ; save exponent

; d1 (FAC1) x d2 (FAC2)
                move.l  FAC1_m(A3),D1   ; get FAC1 mantissa
                move.l  FAC2_m(A3),D2   ; get FAC2 mantissa

                move.w  D1,D4           ; copy low word FAC1
                move.l  D1,D0           ; copy long word FAC1
                swap    D0              ; high word FAC1 to low word FAC1
                move.w  D0,D3           ; copy high word FAC1

                mulu    D2,D1           ; low word FAC2 x low word FAC1
                mulu    D2,D0           ; low word FAC2 x high word FAC1
                swap    D2              ; high word FAC2 to low word FAC2
                mulu    D2,D4           ; high word FAC2 x low word FAC1
                mulu    D2,D3           ; high word FAC2 x high word FAC1

; done multiply, now add partial products

;                       d1 =                                    aaaa  ----      FAC2_L x FAC1_L
;                       d0 =                            bbbb  aaaa              FAC2_L x FAC1_H
;                       d4 =                            bbbb  aaaa              FAC2_H x FAC1_L
;                       d3 =                    cccc  bbbb                      FAC2_H x FAC1_H
;                       product =               mmmm  mmmm

                add.l   #$8000,D1       ; round up lowest word
                clr.w   D1              ; clear low word, don't need it
                swap    D1              ; align high word
                add.l   D0,D1           ; add FAC2_L x FAC1_H (can't be carry)
LAB_MUF1:
                add.l   D4,D1           ; now add intermediate (FAC2_H x FAC1_L)
                bcc.s   LAB_MUF2        ; branch if no carry

                add.l   #$010000,D3     ; else correct result
LAB_MUF2:
                add.l   #$8000,D1       ; round up low word
                clr.w   D1              ; clear low word
                swap    D1              ; align for final add
                add.l   D3,D1           ; add FAC2_H x FAC1_H, result
                bmi.s   LAB_MUF3        ; branch if normalisation not needed

                add.l   D1,D1           ; shift mantissa
                subq.b  #1,FAC1_e(A3)   ; adjust exponent
                beq.s   LAB_MUUF        ; branch if underflow

LAB_MUF3:
                move.l  D1,FAC1_m(A3)   ; save mantissa
LAB_MUEX:
                movem.l (SP)+,D0-D4     ; restore registers
                rts
; either zero or underflow result
LAB_MUUF:
                moveq   #0,D0           ; quick clear
                move.l  D0,FAC1_m(A3)   ; clear mantissa
                move.w  D0,FAC1_e(A3)   ; clear sign and exponent
                bra.s   LAB_MUEX        ; restore regs & exit


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; do FAC2/FAC1, result in FAC1
; fast hardware divide version

LAB_DIVIDE:
                move.l  D7,-(SP)        ; save d7
                moveq   #0,D0           ; clear FAC2 exponent
                move.l  D0,D2           ; clear FAC1 exponent

                move.b  FAC1_e(A3),D2   ; get FAC1 exponent
                beq     LAB_DZER        ; if zero go do /0 error

                move.b  FAC2_e(A3),D0   ; get FAC2 exponent
                beq.s   LAB_DIV0        ; if zero return zero

                sub.w   D2,D0           ; get result exponent by subtracting
                add.w   #$80,D0         ; correct 16 bit exponent result

                move.b  FAC_sc(A3),FAC1_s(A3) ; sign compare is result sign

; now to do 32/32 bit mantissa divide

                clr.b   flag(A3)        ; clear 'flag' byte
                move.l  FAC1_m(A3),D3   ; get FAC1 mantissa
                move.l  FAC2_m(A3),D4   ; get FAC2 mantissa
                cmp.l   D3,D4           ; compare FAC2 with FAC1 mantissa
                beq.s   LAB_MAN1        ; set mantissa result = 1 if .EQUal

                bcs.s   AC1gtAC2        ; branch if FAC1 > FAC2

                sub.l   D3,D4           ; subtract FAC1 from FAC2, result now must be <1
                addq.b  #3,flag(A3)     ; FAC2>FAC1 so set 'flag' byte
AC1gtAC2:
                bsr.s   LAB_32_16       ; do 32/16 divide
                swap    D1              ; move 16 bit result to high word
                move.l  D2,D4           ; copy remainder longword
                bsr.s   LAB_3216        ; do 32/16 divide again (skip copy d4 to d2)
                divu    D5,D2           ; now divide remainder to make guard word
                move.b  flag(A3),D7     ; now normalise, get flag byte back
                beq.s   LAB_DIVX        ; skip add if null

; else result was >1 so we need to add 1 to result mantissa and adjust exponent

                lsr.b   #1,D7           ; shift 1 into eXtend
                roxr.l  #1,D1           ; shift extend result >>
                roxr.w  #1,D2           ; shift extend guard word >>
                addq.b  #1,D0           ; adjust exponent

; now round result to 32 bits

LAB_DIVX:
                add.w   D2,D2           ; guard bit into eXtend bit
                bcc.s   L_DIVRND        ; branch if guard=0

                addq.l  #1,D1           ; add guard to mantissa
                bcc.s   L_DIVRND        ; branch if no overflow

LAB_SET1:
                roxr.l  #1,D1           ; shift extend result >>
                addq.w  #1,D0           ; adjust exponent

; test for over/under flow
L_DIVRND:
                move.w  D0,D3           ; copy exponent
                bmi.s   LAB_DIV0        ; if -ve return zero

                andi.w  #$FF00,D3       ; mask word high byte
                bne     LAB_OFER        ; branch if overflow

; move result into FAC1
LAB_XDIV:
                move.l  (SP)+,D7        ; restore d7
                move.b  D0,FAC1_e(A3)   ; save result exponent
                move.l  D1,FAC1_m(A3)   ; save result mantissa
                rts

; FAC1 mantissa = FAC2 mantissa so set result mantissa

LAB_MAN1:
                moveq   #1,D1           ; set bit
                lsr.l   D1,D1           ; bit into eXtend
                bra.s   LAB_SET1        ; set mantissa, adjust exponent and exit

; result is zero

LAB_DIV0:
                moveq   #0,D0           ; zero exponent & sign
                move.l  D0,D1           ; zero mantissa
                bra     LAB_XDIV        ; exit divide

; divide 16 bits into 32, AB/Ex
;*
; d4                    AAAA    BBBB                    ; 32 bit numerator
; d3                    EEEE    xxxx                    ; 16 bit denominator
;*
; returns -
;*
; d1                    xxxx    DDDD                    ; 16 bit result
; d2                            HHHH    IIII            ; 32 bit remainder

LAB_32_16:
                move.l  D4,D2           ; copy FAC2 mantissa            (AB)
LAB_3216:
                move.l  D3,D5           ; copy FAC1 mantissa            (EF)
                clr.w   D5              ; clear low word d1             (Ex)
                swap    D5              ; swap high word to low word    (xE)

; d3                    EEEE    FFFF                    ; denominator copy
; d5            0000    EEEE                            ; denominator high word
; d2                    AAAA    BBBB                    ; numerator copy
; d4                    AAAA    BBBB                    ; numerator

                divu    D5,D4           ; do FAC2/FAC1 high word        (AB/E)
                bvc.s   LAB_LT_1        ; if no overflow DIV was ok

                moveq   #-1,D4          ; else set default value

; done the divide, now check the result, we have ...

; d3                    EEEE    FFFF                    ; denominator copy
; d5            0000    EEEE                            ; denominator high word
; d2                    AAAA    BBBB                    ; numerator copy
; d4                    MMMM    DDDD                    ; result MOD and DIV

LAB_LT_1:
                move.w  D4,D6           ; copy 16 bit result
                move.w  D4,D1           ; copy 16 bit result again

; we now have ..
; d3                    EEEE    FFFF                    ; denominator copy
; d5            0000    EEEE                            ; denominator high word
; d6                    xxxx  DDDD                      ; result DIV copy
; d1                    xxxx  DDDD                      ; result DIV copy
; d2                    AAAA    BBBB                    ; numerator copy
; d4                    MMMM    DDDD                    ; result MOD and DIV

; now multiply out 32 bit denominator by 16 bit result
; QRS = AB*D

                mulu    D3,D6           ; FFFF ; DDDD =       rrrr  SSSS
                mulu    D5,D4           ; EEEE ; DDDD = QQQQ  rrrr

; we now have ..
; d3                    EEEE    FFFF                    ; denominator copy
; d5            0000    EEEE                            ; denominator high word
; d6                            rrrr  SSSS              ; 48 bit result partial low
; d1                    xxxx  DDDD                      ; result DIV copy
; d2                    AAAA    BBBB                    ; numerator copy
; d4                    QQQQ    rrrr                    ; 48 bit result partial

                move.w  D6,D7           ; copy low word of low multiply

; d7                            xxxx    SSSS            ; 48 bit result partial low

                clr.w   D6              ; clear low word of low multiply
                swap    D6              ; high word of low multiply to low word

; d6                    0000    rrrr                    ; high word of 48 bit result partial low

                add.l   D6,D4

; d4                    QQQQ    RRRR                    ; 48 bit result partial high longword

                moveq   #0,D6           ; clear to extend numerator to 48 bits

; now do GHI = AB0 - QRS (which is the remainder)

                sub.w   D7,D6           ; low word subtract

; d6                            xxxx    IIII            ; remainder low word

                subx.l  D4,D2           ; high longword subtract

; d2                    GGGG    HHHH                    ; remainder high longword

; now if we got the divide correct then the remainder high longword will be +ve

                bpl.s   L_DDIV          ; branch if result is ok (<needed)

; remainder was -ve so DDDD is too big

LAB_REMM:
                subq.w  #1,D1           ; adjust DDDD

; d3                            xxxx    FFFF            ; denominator copy
; d6                            xxxx    IIII            ; remainder low word

                add.w   D3,D6           ; add EF*1 low remainder low word

; d5                    0000    EEEE                    ; denominator high word
; d2                    GGGG    HHHH                    ; remainder high longword

                addx.l  D5,D2           ; add extend EF*1 to remainder high longword
                bmi.s   LAB_REMM        ; loop if result still too big

; all done and result correct or <

L_DDIV:
                swap    D2              ; remainder mid word to high word

; d2                    HHHH    GGGG                    ; (high word /should/ be $0000)

                move.w  D6,D2           ; remainder in high word

; d2                            HHHH    IIII            ; now is 32 bit remainder
; d1                    xxxx    DDDD                    ; 16 bit result

                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; unpack memory (a0) into FAC1

LAB_UFAC:
                move.l  (A0),D0         ; get packed value
                swap    D0              ; exponent and sign into least significant word
                move.w  D0,FAC1_e(A3)   ; save exponent and sign
                beq.s   LAB_NB1T        ; branch if exponent (and the rest) zero

                or.w    #$80,D0         ; set MSb
                swap    D0              ; word order back to normal
                asl.l   #8,D0           ; shift exponent & clear guard byte
LAB_NB1T:
                move.l  D0,FAC1_m(A3)   ; move into FAC1

                move.b  FAC1_e(A3),D0   ; get FAC1 exponent
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; set numeric variable, pack FAC1 into Lvarpl

LAB_PFAC:
                move.l  A0,-(SP)        ; save pointer
                movea.l Lvarpl(A3),A0   ; get destination pointer
                btst    #6,Dtypef(A3)   ; test data type
                beq.s   LAB_277C        ; branch if floating

                bsr     LAB_2831        ; convert FAC1 floating to fixed
; result in d0 and Itemp
                move.l  D0,(A0)         ; save in var
                movea.l (SP)+,A0        ; restore pointer
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; normalise round and pack FAC1 into (a0)

LAB_2778:
                move.l  A0,-(SP)        ; save pointer
LAB_277C:
                bsr     LAB_24D5        ; normalise FAC1
                bsr.s   LAB_27BA        ; round FAC1
                move.l  FAC1_m(A3),D0   ; get FAC1 mantissa
                ror.l   #8,D0           ; align 24/32 bit mantissa
                swap    D0              ; exponent/sign into 0-15
                and.w   #$7F,D0         ; clear exponent and sign bit
                andi.b  #$80,FAC1_s(A3) ; clear non sign bits in sign
                or.w    FAC1_e(A3),D0   ; OR in exponent and sign
                swap    D0              ; move exponent and sign back to 16-31
                move.l  D0,(A0)         ; store in destination
                movea.l (SP)+,A0        ; restore pointer
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; copy FAC2 to FAC1

LAB_279B:
                move.w  FAC2_e(A3),FAC1_e(A3) ; copy exponent & sign
                move.l  FAC2_m(A3),FAC1_m(A3) ; copy mantissa
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; round FAC1

LAB_27BA:
                move.b  FAC1_e(A3),D0   ; get FAC1 exponent
                beq.s   LAB_27C4        ; branch if zero

                move.l  FAC1_m(A3),D0   ; get FAC1
                add.l   #$80,D0         ; round to 24 bit
                bcc.s   LAB_27C3        ; branch if no overflow

                roxr.l  #1,D0           ; shift FAC1 mantissa
                addq.b  #1,FAC1_e(A3)   ; correct exponent
                bcs     LAB_OFER        ; if carry do overflow error & warm start

LAB_27C3:
                and.b   #$00,D0         ; clear guard byte
                move.l  D0,FAC1_m(A3)   ; save back to FAC1
                rts

LAB_27C4:
                move.b  D0,FAC1_s(A3)   ; make zero always +ve
RTS_017:
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; get FAC1 sign
; return d0=-1,C=1/-ve d0=+1,C=0/+ve

LAB_27CA:
                moveq   #0,D0           ; clear d0
                move.b  FAC1_e(A3),D0   ; get FAC1 exponent
                beq.s   RTS_017         ; exit if zero (already correct SGN(0)=0)


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; return d0=-1,C=1/-ve d0=+1,C=0/+ve
; no = 0 check

LAB_27CE:
                move.b  FAC1_s(A3),D0   ; else get FAC1 sign (b7)


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; return d0=-1,C=1/-ve d0=+1,C=0/+ve
; no = 0 check, sign in d0

LAB_27D0:
                ext.w   D0              ; make word
                ext.l   D0              ; make longword
                asr.l   #8,D0           ; move sign bit through byte to carry
                bcs.s   RTS_017         ; exit if carry set

                moveq   #1,D0           ; set result for +ve sign
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform SGN()

LAB_SGN:
                bsr.s   LAB_27CA        ; get FAC1 sign
; return d0=-1/-ve d0=+1/+ve


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; save d0 as integer longword

LAB_27DB:
                move.l  D0,FAC1_m(A3)   ; save FAC1 mantissa
                move.w  #$A000,FAC1_e(A3) ; set FAC1 exponent & sign
                add.l   D0,D0           ; top bit into carry
                bra     LAB_24D0        ; do +/- (carry is sign) & normalise FAC1


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform ABS()

LAB_ABS:
                move.b  #0,FAC1_s(A3)   ; clear FAC1 sign
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; compare FAC1 with FAC2
; returns d0=+1 Cb=0 if FAC1 > FAC2
; returns d0= 0 Cb=0 if FAC1 = FAC2
; returns d0=-1 Cb=1 if FAC1 < FAC2

LAB_27FA:
                move.b  FAC2_e(A3),D1   ; get FAC2 exponent
                beq.s   LAB_27CA        ; branch if FAC2 exponent=0 & get FAC1 sign
; d0=-1,C=1/-ve d0=+1,C=0/+ve

                move.b  FAC_sc(A3),D0   ; get FAC sign compare
                bmi.s   LAB_27CE        ; if signs <> do return d0=-1,C=1/-ve
; d0=+1,C=0/+ve & return

                move.b  FAC1_s(A3),D0   ; get FAC1 sign
                cmp.b   FAC1_e(A3),D1   ; compare FAC1 exponent with FAC2 exponent
                bne.s   LAB_2828        ; branch if different

                move.l  FAC2_m(A3),D1   ; get FAC2 mantissa
                cmp.l   FAC1_m(A3),D1   ; compare mantissas
                beq.s   LAB_282F        ; exit if mantissas .EQUal

; gets here if number <> FAC1

LAB_2828:
                bcs.s   LAB_27D0        ; if FAC1 > FAC2 return d0=-1,C=1/-ve d0=+1,
; C=0/+ve

                eori.b  #$80,D0         ; else toggle FAC1 sign
LAB_282E:
                bra.s   LAB_27D0        ; return d0=-1,C=1/-ve d0=+1,C=0/+ve

LAB_282F:
                moveq   #0,D0           ; clear result
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; convert FAC1 floating to fixed
; result in d0 and Itemp, sets flags correctly

LAB_2831:
                move.l  FAC1_m(A3),D0   ; copy mantissa
                beq.s   LAB_284J        ; branch if mantissa = 0

                move.l  D1,-(SP)        ; save d1
                moveq   #$A0,D1         ; set for no floating bits
                sub.b   FAC1_e(A3),D1   ; subtract FAC1 exponent
                bcs     LAB_OFER        ; do overflow if too big

                bne.s   LAB_284G        ; branch if exponent was not $A0

                tst.b   FAC1_s(A3)      ; test FAC1 sign
                bpl.s   LAB_284H        ; branch if FAC1 +ve

                neg.l   D0
                bvs.s   LAB_284H        ; branch if was $80000000

                bra     LAB_OFER        ; do overflow if too big

LAB_284G:
                cmp.b   #$20,D1         ; compare with minimum result for integer
                bcs.s   LAB_284L        ; if < minimum just do shift

                moveq   #0,D0           ; else return zero
LAB_284L:
                lsr.l   D1,D0           ; shift integer

                tst.b   FAC1_s(A3)      ; test FAC1 sign (b7)
                bpl.s   LAB_284H        ; branch if FAC1 +ve

                neg.l   D0              ; negate integer value
LAB_284H:
                move.l  (SP)+,D1        ; restore d1
LAB_284J:
                move.l  D0,Itemp(A3)    ; save result to Itemp
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform INT()

LAB_INT:
                moveq   #$A0,D0         ; set for no floating bits
                sub.b   FAC1_e(A3),D0   ; subtract FAC1 exponent
                bls.s   LAB_IRTS        ; exit if exponent >= $A0
; (too big for fraction part!)

                cmp.b   #$20,D0         ; compare with minimum result for integer
                bcc     LAB_POZE        ; if >= minimum go return 0
; (too small for integer part!)

                moveq   #-1,D1          ; set integer mask
                asl.l   D0,D1           ; shift mask [8+2*d0]
                and.l   D1,FAC1_m(A3)   ; mask mantissa
LAB_IRTS:
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; print " in line [LINE #]"

LAB_2953:
                lea     LAB_LMSG(PC),A0 ; point to " in line " message
                bsr     LAB_18C3        ; print null terminated string

; Print Basic line #
                move.l  Clinel(A3),D0   ; get current line


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; print d0 as unsigned integer

LAB_295E:
                lea     Bin2dec(PC),A1  ; get table address
                moveq   #0,D1           ; table index
                lea     Usdss(A3),A0    ; output string start
                move.l  D1,D2           ; output string index
LAB_2967:
                move.l  0(A1,D1.w),D3   ; get table value
                beq.s   LAB_2969        ; exit if end marker

                moveq   #'0'-1,D4       ; set character to "0"-1
LAB_2968:
                addq.w  #1,D4           ; next numeric character
                sub.l   D3,D0           ; subtract table value
                bpl.s   LAB_2968        ; not overdone so loop

                add.l   D3,D0           ; correct value
                move.b  D4,0(A0,D2.w)   ; character out to string
                addq.w  #4,D1           ; increment table pointer
                addq.w  #1,D2           ; increment output string pointer
                bra.s   LAB_2967        ; loop

LAB_2969:
                add.b   #'0',D0         ; make last character
                move.b  D0,0(A0,D2.w)   ; character out to string
                subq.w  #1,A0           ; decrement a0 (allow simple loop)

; now find non zero start of string
LAB_296A:
                addq.w  #1,A0           ; increment a0 (this will never carry to b16)
                lea     BHsend-1(A3),A1 ; get string end
                cmpa.l  A1,A0           ; are we at end
                beq     LAB_18C3        ; if so print null terminated string and RETURN

                cmpi.b  #'0',(A0)       ; is character "0" ?
                beq.s   LAB_296A        ; loop if so

                bra     LAB_18C3        ; print null terminated string from memory & RET


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; convert FAC1 to ASCII string result in (a0)
; STR$() function enters here

; now outputs 7 significant digits

; d0 is character out
; d1 is save index
; d2 is gash

; a0 is output string pointer

LAB_2970:
                lea     Decss(A3),A1    ; set output string start

                moveq   #' ',D2         ; character = " ", assume +ve
                bclr    #7,FAC1_s(A3)   ; test and clear FAC1 sign (b7)
                beq.s   LAB_2978        ; branch if +ve

                moveq   #'-',D2         ; else character = "-"
LAB_2978:
                move.b  D2,(A1)         ; save the sign character
                move.b  FAC1_e(A3),D2   ; get FAC1 exponent
                bne.s   LAB_2989        ; branch if FAC1<>0

; exponent was $00 so FAC1 is 0
                moveq   #'0',D0         ; set character = "0"
                moveq   #1,D1           ; set output string index
                bra     LAB_2A89        ; save last character, [EOT] & exit

; FAC1 is some non zero value
LAB_2989:
                move.b  #0,numexp(A3)   ; clear number exponent count
                cmp.b   #$81,D2         ; compare FAC1 exponent with $81 (>1.00000)

                bcc.s   LAB_299C        ; branch if FAC1=>1

; else FAC1 < 1
                move.l  #$98968000,FAC2_m(A3) ; 10000000 mantissa
                move.w  #$9800,FAC2_e(A3) ; 10000000 exponent & sign
                move.b  FAC1_s(A3),FAC_sc(A3) ; make FAC1 sign sign compare
                bsr     LAB_MULTIPLY    ; do FAC2*FAC1

                move.b  #$F9,numexp(A3) ; set number exponent count (-7)
                bra.s   LAB_299C        ; go test for fit

LAB_29B9:
                move.w  FAC1_e(A3),FAC2_e(A3) ; copy exponent & sign from FAC1 to FAC2
                move.l  FAC1_m(A3),FAC2_m(A3) ; copy FAC1 mantissa to FAC2 mantissa
                move.b  FAC1_s(A3),FAC_sc(A3) ; save FAC1_s as sign compare

                move.l  #$CCCCCCCD,FAC1_m(A3) ; 1/10 mantissa
                move.w  #$7D00,FAC1_e(A3) ; 1/10 exponent & sign
                bsr     LAB_MULTIPLY    ; do FAC2*FAC1, effectively divide by 10 but
; faster

                addq.b  #1,numexp(A3)   ; increment number exponent count
LAB_299C:
                move.l  #$98967F70,FAC2_m(A3) ; 9999999.4375 mantissa
                move.w  #$9800,FAC2_e(A3) ; 9999999.4375 exponent & sign
; (max before scientific notation)
                bsr     LAB_27F0        ; fast compare FAC1 with FAC2
; returns d0=+1 C=0 if FAC1 > FAC2
; returns d0= 0 C=0 if FAC1 = FAC2
; returns d0=-1 C=1 if FAC1 < FAC2
                bhi.s   LAB_29B9        ; go do /10 if FAC1 > 9999999.4375

                beq.s   LAB_29C3        ; branch if FAC1 = 9999999.4375

; FAC1 < 9999999.4375
                move.l  #$F423F800,FAC2_m(A3) ; set mantissa for 999999.5
                move.w  #$9400,FAC2_e(A3) ; set exponent for 999999.5

                lea     FAC1_m(A3),A0   ; set pointer for x10
LAB_29A7:
                bsr     LAB_27F0        ; fast compare FAC1 with FAC2
; returns d0=+1 C=0 if FAC1 > FAC2
; returns d0= 0 C=0 if FAC1 = FAC2
; returns d0=-1 C=1 if FAC1 < FAC2
                bhi.s   LAB_29C0        ; branch if FAC1 > 99999.9375,no decimal places

; FAC1 <= 999999.5 so do x 10
                move.l  (A0),D0         ; get FAC1 mantissa
                move.b  4(A0),D1        ; get FAC1 exponent
                move.l  D0,D2           ; copy it
                lsr.l   #2,D0           ; /4
                add.l   D2,D0           ; add FAC1 (x1.125)
                bcc.s   LAB_29B7        ; branch if no carry

                roxr.l  #1,D0           ; shift carry back in
                addq.b  #1,D1           ; increment exponent (never overflows)
LAB_29B7:
                addq.b  #3,D1           ; correct exponent ( 8 x 1.125 = 10 )
; (never overflows)
                move.l  D0,(A0)         ; save new mantissa
                move.b  D1,4(A0)        ; save new exponent
                subq.b  #1,numexp(A3)   ; decrement number exponent count
                bra.s   LAB_29A7        ; go test again

; now we have just the digits to do
LAB_29C0:
                move.l  #$80000000,FAC2_m(A3) ; set mantissa for 0.5
                move.w  #$8000,FAC2_e(A3) ; set exponent for 0.5
                move.b  FAC1_s(A3),FAC_sc(A3) ; sign compare = sign
                bsr     LAB_ADD         ; add the 0.5 to FAC1 (round FAC1)

LAB_29C3:
                bsr     LAB_2831        ; convert FAC1 floating to fixed
; result in d0 and Itemp
                moveq   #$01,D2         ; set default digits before dp = 1
                move.b  numexp(A3),D0   ; get number exponent count
                add.b   #8,D0           ; allow 7 digits before point
                bmi.s   LAB_29D9        ; if -ve then 1 digit before dp

                cmp.b   #$09,D0         ; d0>=9 if n>=1E7
                bcc.s   LAB_29D9        ; branch if >= $09

; < $08
                subq.b  #1,D0           ; take 1 from digit count
                move.b  D0,D2           ; copy byte
                moveq   #$02,D0         ; set exponent adjust
LAB_29D9:
                moveq   #0,D1           ; set output string index
                subq.b  #2,D0           ; -2
                move.b  D0,expcnt(A3)   ; save exponent adjust
                move.b  D2,numexp(A3)   ; save digits before dp count
                move.b  D2,D0           ; copy digits before dp count
                beq.s   LAB_29E4        ; branch if no digits before dp

                bpl.s   LAB_29F7        ; branch if digits before dp

LAB_29E4:
                addq.l  #1,D1           ; increment index
                move.b  #'.',0(A1,D1.w) ; save to output string

                tst.b   D2              ; test digits before dp count
                beq.s   LAB_29F7        ; branch if no digits before dp

                addq.l  #1,D1           ; increment index
                move.b  #'0',0(A1,D1.w) ; save to output string
LAB_29F7:
                moveq   #0,D2           ; clear index (point to 1,000,000)
                moveq   #$80-$0100,D0   ; set output character
LAB_29FB:
                lea     LAB_2A9A(PC),A0 ; get base of table
                move.l  0(A0,D2.w),D3   ; get table value
LAB_29FD:
                addq.b  #1,D0           ; increment output character
                add.l   D3,Itemp(A3)    ; add to (now fixed) mantissa
                btst    #7,D0           ; set test sense (z flag only)
                bcs.s   LAB_2A18        ; did carry so has wrapped past zero

                beq.s   LAB_29FD        ; no wrap and +ve test so try again

                bra.s   LAB_2A1A        ; found this digit

LAB_2A18:
                bne.s   LAB_29FD        ; wrap and -ve test so try again

LAB_2A1A:
                bcc.s   LAB_2A21        ; branch if +ve test result

                neg.b   D0              ; negate the digit number
                add.b   #$0B,D0         ; and subtract from 11 decimal
LAB_2A21:
                add.b   #$2F,D0         ; add "0"-1 to result
                addq.w  #4,D2           ; increment index to next less power of ten
                addq.w  #1,D1           ; increment output string index
                move.b  D0,D3           ; copy character to d3
                and.b   #$7F,D3         ; mask out top bit
                move.b  D3,0(A1,D1.w)   ; save to output string
                subi.b  #1,numexp(A3)   ; decrement # of characters before the dp
                bne.s   LAB_2A3B        ; branch if still characters to do

; else output the point
                addq.l  #1,D1           ; increment index
                move.b  #'.',0(A1,D1.w) ; save to output string
LAB_2A3B:
                and.b   #$80,D0         ; mask test sense bit
                eori.b  #$80,D0         ; invert it
                cmp.b   #LAB_2A9B-LAB_2A9A,D2 ; compare table index with max+4
                bne.s   LAB_29FB        ; loop if not max

; now remove trailing zeroes
LAB_2A4B:
                move.b  0(A1,D1.w),D0   ; get character from output string
                subq.l  #1,D1           ; decrement output string index
                cmp.b   #'0',D0         ; compare with "0"
                beq.s   LAB_2A4B        ; loop until non "0" character found

                cmp.b   #'.',D0         ; compare with "."
                beq.s   LAB_2A58        ; branch if was dp

; else restore last character
                addq.l  #1,D1           ; increment output string index
LAB_2A58:
                move.b  #'+',2(A1,D1.w) ; save character "+" to output string
                tst.b   expcnt(A3)      ; test exponent count
                beq.s   LAB_2A8C        ; if zero go set null terminator & exit

; exponent isn't zero so write exponent
                bpl.s   LAB_2A68        ; branch if exponent count +ve

                move.b  #'-',2(A1,D1.w) ; save character "-" to output string
                neg.b   expcnt(A3)      ; convert -ve to +ve
LAB_2A68:
                move.b  #'E',1(A1,D1.w) ; save character "E" to output string
                move.b  expcnt(A3),D2   ; get exponent count
                moveq   #$2F,D0         ; one less than "0" character
LAB_2A74:
                addq.b  #1,D0           ; increment 10's character
                sub.b   #$0A,D2         ; subtract 10 from exponent count
                bcc.s   LAB_2A74        ; loop while still >= 0

                add.b   #$3A,D2         ; add character ":", $30+$0A, result is 10-value
                move.b  D0,3(A1,D1.w)   ; save 10's character to output string
                move.b  D2,4(A1,D1.w)   ; save 1's character to output string
                move.b  #0,5(A1,D1.w)   ; save null terminator after last character
                bra.s   LAB_2A91        ; go set string pointer (a0) and exit

LAB_2A89:
                move.b  D0,0(A1,D1.w)   ; save last character to output string
LAB_2A8C:
                move.b  #0,1(A1,D1.w)   ; save null terminator after last character
LAB_2A91:
                movea.l A1,A0           ; set result string pointer (a0)
                rts



; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; fast compare FAC1 with FAC2
; assumes both are +ve and FAC2>0
; returns d0=+1 C=0 if FAC1 > FAC2
; returns d0= 0 C=0 if FAC1 = FAC2
; returns d0=-1 C=1 if FAC1 < FAC2

LAB_27F0:
                moveq   #0,D0           ; set for FAC1 = FAC2
                move.b  FAC2_e(A3),D1   ; get FAC2 exponent
                cmp.b   FAC1_e(A3),D1   ; compare FAC1 exponent with FAC2 exponent
                bne.s   LAB_27F1        ; branch if different

                move.l  FAC2_m(A3),D1   ; get FAC2 mantissa
                cmp.l   FAC1_m(A3),D1   ; compare mantissas
                beq.s   LAB_27F3        ; exit if mantissas .EQUal

LAB_27F1:
                bcs.s   LAB_27F2        ; if FAC1 > FAC2 return d0=+1,C=0

                subq.l  #1,D0           ; else FAC1 < FAC2 return d0=-1,C=1
                rts

LAB_27F2:
                addq.l  #1,D0
LAB_27F3:
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; make FAC1 = 1

LAB_POON:
                move.l  #$80000000,FAC1_m(A3) ; 1 mantissa
                move.w  #$8100,FAC1_e(A3) ; 1 exonent & sign
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; make FAC1 = 0

LAB_POZE:
                moveq   #0,D0           ; clear longword
                move.l  D0,FAC1_m(A3)   ; 0 mantissa
                move.w  D0,FAC1_e(A3)   ; 0 exonent & sign
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform power function
; the number is in FAC2, the power is in FAC1
; no longer trashes Itemp

LAB_POWER:
                tst.b   FAC1_e(A3)      ; test power
                beq.s   LAB_POON        ; if zero go return 1

                tst.b   FAC2_e(A3)      ; test number
                beq.s   LAB_POZE        ; if zero go return 0

                move.b  FAC2_s(A3),-(SP) ; save number sign
                bpl.s   LAB_POWP        ; power of positive number

                moveq   #0,D1           ; clear d1
                move.b  D1,FAC2_s(A3)   ; make sign +ve

; number sign was -ve and can only be raised to
; an integer power which gives an x +j0 result,
; else do 'function call' error
                move.b  FAC1_e(A3),D1   ; get power exponent
                sub.w   #$80,D1         ; normalise to .5
                bls     LAB_FCER        ; if 0<power<1 then do 'function call' error

; now shift all the integer bits out
                move.l  FAC1_m(A3),D0   ; get power mantissa
                asl.l   D1,D0           ; shift mantissa
                bne     LAB_FCER        ; if power<>INT(power) then do 'function call'
; error

                bcs.s   LAB_POWP        ; if integer value odd then leave result -ve

                move.b  D0,(SP)         ; save result sign +ve
LAB_POWP:
                move.l  FAC1_m(A3),-(SP) ; save power mantissa
                move.w  FAC1_e(A3),-(SP) ; save power sign & exponent

                bsr     LAB_279B        ; copy number to FAC1
                bsr     LAB_LOG         ; find log of number

                move.w  (SP)+,D0        ; get power sign & exponent
                move.l  (SP)+,FAC2_m(A3) ; get power mantissa
                move.w  D0,FAC2_e(A3)   ; save sign & exponent to FAC2
                move.b  D0,FAC_sc(A3)   ; save sign as sign compare
                move.b  FAC1_s(A3),D0   ; get FAC1 sign
                eor.b   D0,FAC_sc(A3)   ; make sign compare (FAC1_s EOR FAC2_s)

                bsr     LAB_MULTIPLY    ; multiply by power
                bsr.s   LAB_EXP         ; find exponential
                move.b  (SP)+,FAC1_s(A3) ; restore number sign
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; do - FAC1

LAB_GTHAN:
                tst.b   FAC1_e(A3)      ; test for non zero FAC1
                beq.s   RTS_020         ; branch if null

                eori.b  #$80,FAC1_s(A3) ; (else) toggle FAC1 sign bit
RTS_020:
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; return +1
LAB_EX1:
                move.l  #$80000000,FAC1_m(A3) ; +1 mantissa
                move.w  #$8100,FAC1_e(A3) ; +1 sign & exponent
                rts
; do over/under flow
LAB_EXOU:
                tst.b   FAC1_s(A3)      ; test sign
                bpl     LAB_OFER        ; was +ve so do overflow error

; else underflow so return zero
                moveq   #0,D0           ; clear longword
                move.l  D0,FAC1_m(A3)   ; 0 mantissa
                move.w  D0,FAC1_e(A3)   ; 0 sign & exponent
                rts
; fraction was zero so do 2^n
LAB_EXOF:
                move.l  #$80000000,FAC1_m(A3) ; +n mantissa
                move.b  #0,FAC1_s(A3)   ; clear sign
                tst.b   cosout(A3)      ; test sign flag
                bpl.s   LAB_EXOL        ; branch if +ve

                neg.l   D1              ; else do 1/2^n
LAB_EXOL:
                add.b   #$81,D1         ; adjust exponent
                move.b  D1,FAC1_e(A3)   ; save exponent
                rts

; perform EXP() (x^e)
; valid input range is -88 to +88

LAB_EXP:
                move.b  FAC1_e(A3),D0   ; get exponent
                beq.s   LAB_EX1         ; return 1 for zero in

                cmp.b   #$64,D0         ; compare exponent with min
                bcs.s   LAB_EX1         ; if smaller just return 1

;*;     MOVEM.l d1-d6/a0,-(sp)          ; save the registers
                move.b  #0,cosout(A3)   ; flag +ve number
                move.l  FAC1_m(A3),D1   ; get mantissa
                cmp.b   #$87,D0         ; compare exponent with max
                bhi.s   LAB_EXOU        ; go do over/under flow if greater

                bne.s   LAB_EXCM        ; branch if less

; else is 2^7
                cmp.l   #$B00F33C7,D1   ; compare mantissa with n*2^7 max
                bcc.s   LAB_EXOU        ; if => go over/underflow

LAB_EXCM:
                tst.b   FAC1_s(A3)      ; test sign
                bpl.s   LAB_EXPS        ; branch if arg +ve

                move.b  #$FF,cosout(A3) ; flag -ve number
                move.b  #0,FAC1_s(A3)   ; take absolute value
LAB_EXPS:
; now do n/LOG(2)
                move.l  #$B8AA3B29,FAC2_m(A3) ; 1/LOG(2) mantissa
                move.w  #$8100,FAC2_e(A3) ; 1/LOG(2) exponent & sign
                move.b  #0,FAC_sc(A3)   ; we know they're both +ve
                bsr     LAB_MULTIPLY    ; effectively divide by log(2)

; max here is +/- 127
; now separate integer and fraction
                move.b  #0,tpower(A3)   ; clear exponent add byte
                move.b  FAC1_e(A3),D5   ; get exponent
                sub.b   #$80,D5         ; normalise
                bls.s   LAB_ESML        ; branch if < 1 (d5 is 0 or -ve)

; result is > 1
                move.l  FAC1_m(A3),D0   ; get mantissa
                move.l  D0,D1           ; copy it
                move.l  D5,D6           ; copy normalised exponent

                neg.w   D6              ; make -ve
                add.w   #32,D6          ; is now 32-d6
                lsr.l   D6,D1           ; just integer bits
                move.b  D1,tpower(A3)   ; set exponent add byte

                lsl.l   D5,D0           ; shift out integer bits
                beq     LAB_EXOF        ; fraction is zero so do 2^n

                move.l  D0,FAC1_m(A3)   ; fraction to FAC1
                move.w  #$8000,FAC1_e(A3) ; set exponent & sign

; multiple was < 1
LAB_ESML:
                move.l  #$B17217F8,FAC2_m(A3) ; LOG(2) mantissa
                move.w  #$8000,FAC2_e(A3) ; LOG(2) exponent & sign
                move.b  #0,FAC_sc(A3)   ; clear sign compare
                bsr     LAB_MULTIPLY    ; multiply by log(2)

                move.l  FAC1_m(A3),D0   ; get mantissa
                move.b  FAC1_e(A3),D5   ; get exponent
                sub.w   #$82,D5         ; normalise and -2 (result is -1 to -30)
                neg.w   D5              ; make +ve
                lsr.l   D5,D0           ; shift for 2 integer bits

; d0 = arg
; d6 = x, d1 = y
; d2 = x1, d3 = y1
; d4 = shift count
; d5 = loop count
; now do cordic set-up
                moveq   #0,D1           ; y = 0
                move.l  #KFCTSEED,D6    ; x = 1 with jkh inverse factored out
                lea     TAB_HTHET(PC),A0 ; get pointer to hyperbolic arctan table
                moveq   #0,D4           ; clear shift count

; cordic loop, shifts 4 and 13 (and 39
; if it went that far) need to be repeated
                moveq   #3,D5           ; 4 loops
                bsr.s   LAB_EXCC        ; do loops 1 through 4
                subq.w  #4,A0           ; do table entry again
                subq.l  #1,D4           ; do shift count again
                moveq   #9,D5           ; 10 loops
                bsr.s   LAB_EXCC        ; do loops 4 (again) through 13
                subq.w  #4,A0           ; do table entry again
                subq.l  #1,D4           ; do shift count again
                moveq   #18,D5          ; 19 loops
                bsr.s   LAB_EXCC        ; do loops 13 (again) through 31

; now get the result
                tst.b   cosout(A3)      ; test sign flag
                bpl.s   LAB_EXPL        ; branch if +ve

                neg.l   D1              ; do -y
                neg.b   tpower(A3)      ; do -exp
LAB_EXPL:
                moveq   #$83-$0100,D0   ; set exponent
                add.l   D1,D6           ; y = y +/- x
                bmi.s   LAB_EXRN        ; branch if result normal

LAB_EXNN:
                subq.l  #1,D0           ; decrement exponent
                add.l   D6,D6           ; shift mantissa
                bpl.s   LAB_EXNN        ; loop if not normal

LAB_EXRN:
                move.l  D6,FAC1_m(A3)   ; save exponent result
                add.b   tpower(A3),D0   ; add integer part
                move.b  D0,FAC1_e(A3)   ; save exponent
;*;     MOVEM.l (sp)+,d1-d6/a0          ; restore registers
                rts

; cordic loop
LAB_EXCC:
                addq.l  #1,D4           ; increment shift count
                move.l  D6,D2           ; x1 = x
                asr.l   D4,D2           ; x1 >> n
                move.l  D1,D3           ; y1 = y
                asr.l   D4,D3           ; y1 >> n
                tst.l   D0              ; test arg
                bmi.s   LAB_EXAD        ; branch if -ve

                add.l   D2,D1           ; y = y + x1
                add.l   D3,D6           ; x = x + y1
                sub.l   (A0)+,D0        ; arg = arg - atnh(a0)
                dbra    D5,LAB_EXCC     ; decrement and loop if not done

                rts

LAB_EXAD:
                sub.l   D2,D1           ; y = y - x1
                sub.l   D3,D6           ; x = x + y1
                add.l   (A0)+,D0        ; arg = arg + atnh(a0)
                dbra    D5,LAB_EXCC     ; decrement and loop if not done

                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; RND(n), 32 bit Galois version. make n=0 for 19th next number in s.EQUence or n<>0
; to get 19th next number in s.EQUence after seed n. This version of the PRNG uses
; the Galois method and a sample of 65536 bytes produced gives the following values.

; Entropy = 7.997442 bits per byte
; Optimum compression would reduce these 65536 bytes by 0 percent

; Chi square distribution for 65536 samples is 232.01, and
; randomly would exceed this value 75.00 percent of the time

; Arithmetic mean value of data bytes is 127.6724, 127.5 would be random
; Monte Carlo value for Pi is 3.122871269, error 0.60 percent
; Serial correlation coefficient is -0.000370, totally uncorrelated would be 0.0

LAB_RND:
                tst.b   FAC1_e(A3)      ; get FAC1 exponent
                beq.s   NextPRN         ; do next random number if zero

; else get seed into random number store
                lea     PRNlword(A3),A0 ; set PRNG pointer
                bsr     LAB_2778        ; pack FAC1 into (a0)
NextPRN:
                moveq   #$AF-$0100,D1   ; set EOR value
                moveq   #18,D2          ; do this 19 times
                move.l  PRNlword(A3),D0 ; get current
Ninc0:
                add.l   D0,D0           ; shift left 1 bit
                bcc.s   Ninc1           ; branch if bit 32 not set

                eor.b   D1,D0           ; do Galois LFSR feedback
Ninc1:
                dbra    D2,Ninc0        ; loop

                move.l  D0,PRNlword(A3) ; save back to seed word								
                move.l  D0,FAC1_m(A3)   ; copy to FAC1 mantissa
                move.w  #$8000,FAC1_e(A3) ; set the exponent and clear the sign
                bra     LAB_24D5        ; normalise FAC1 & return


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; cordic TAN(x) routine, TAN(x) = SIN(x)/COS(x)
; x = angle in radians

LAB_TAN:
                bsr.s   LAB_SIN         ; go do SIN/COS cordic compute
                move.w  FAC1_e(A3),FAC2_e(A3) ; copy exponent & sign from FAC1 to FAC2
                move.l  FAC1_m(A3),FAC2_m(A3) ; copy FAC1 mantissa to FAC2 mantissa
                move.l  D1,FAC1_m(A3)   ; get COS(x) mantissa
                move.b  D3,FAC1_e(A3)   ; get COS(x) exponent
                beq     LAB_OFER        ; do overflow if COS = 0

                bsr     LAB_24D5        ; normalise FAC1
                bra     LAB_DIVIDE      ; do FAC2/FAC1 and return, FAC_sc set by SIN
; COS calculation


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; cordic SIN(x), COS(x) routine
; x = angle in radians

LAB_COS:
                move.l  #$C90FDAA3,FAC2_m(A3) ; pi/2 mantissa (LSB is rounded up so
; COS(PI/2)=0)
                move.w  #$8100,FAC2_e(A3) ; pi/2 exponent and sign
                move.b  FAC1_s(A3),FAC_sc(A3) ; sign = FAC1 sign (b7)
                bsr     LAB_ADD         ; add FAC2 to FAC1, adjust for COS(x)


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; SIN/COS cordic calculator

LAB_SIN:
                move.b  #0,cosout(A3)   ; set needed result

                move.l  #$A2F9836F,FAC2_m(A3) ; 1/pi mantissa (LSB is rounded up so SIN(PI)=0)
                move.w  #$7F00,FAC2_e(A3) ; 1/pi exponent & sign
                move.b  FAC1_s(A3),FAC_sc(A3) ; sign = FAC1 sign (b7)
                bsr     LAB_MULTIPLY    ; multiply by 1/pi

                move.b  FAC1_e(A3),D0   ; get FAC1 exponent
                beq.s   LAB_SCZE        ; branch if zero

                lea     TAB_SNCO(PC),A0 ; get pointer to constants table
                move.l  FAC1_m(A3),D6   ; get FAC1 mantissa
                subq.b  #1,D0           ; 2 radians in 360 degrees so /2
                beq.s   LAB_SCZE        ; branch if zero

                sub.b   #$80,D0         ; normalise exponent
                bmi.s   LAB_SCL0        ; branch if < 1

; X is > 1
                cmp.b   #$20,D0         ; is it >= 2^32
                bcc.s   LAB_SCZE        ; may as well do zero

                lsl.l   D0,D6           ; shift out integer part bits
                bne.s   LAB_CORD        ; if fraction go test quadrant and adjust

; else no fraction so do zero
LAB_SCZE:
                moveq   #$81-$0100,D2   ; set exponent for 1.0
                moveq   #0,D3           ; set exponent for 0.0
                move.l  #$80000000,D0   ; mantissa for 1.0
                move.l  D3,D1           ; mantissa for 0.0
                bra.s   outloop         ; go output it

; x is < 1
LAB_SCL0:
                neg.b   D0              ; make +ve
                cmp.b   #$1E,D0         ; is it <= 2^-30
                bcc.s   LAB_SCZE        ; may as well do zero

                lsr.l   D0,D6           ; shift out <= 2^-32 bits

; cordic calculator, argument in d6
; table pointer in a0, returns in d0-d3

LAB_CORD:
                move.b  FAC1_s(A3),FAC_sc(A3) ; copy as sign compare for TAN
                add.l   D6,D6           ; shift 0.5 bit into carry
                bcc.s   LAB_LTPF        ; branch if less than 0.5

                eori.b  #$FF,FAC1_s(A3) ; toggle result sign
LAB_LTPF:
                add.l   D6,D6           ; shift 0.25 bit into carry
                bcc.s   LAB_LTPT        ; branch if less than 0.25

                eori.b  #$FF,cosout(A3) ; toggle needed result
                eori.b  #$FF,FAC_sc(A3) ; toggle sign compare for TAN

LAB_LTPT:
                lsr.l   #2,D6           ; shift the bits back (clear integer bits)
                beq.s   LAB_SCZE        ; no fraction so go do zero

; set start values
                moveq   #1,D5           ; set bit count
                move.l  -4(A0),D0       ; get multiply constant (1st itteration d0)
                move.l  D0,D1           ; 1st itteration d1
                sub.l   (A0)+,D6        ; 1st always +ve so do 1st step
                bra.s   mainloop        ; jump into routine

subloop:
                sub.l   (A0)+,D6        ; z = z - arctan(i)/2pi
                sub.l   D3,D0           ; x = x - y1
                add.l   D2,D1           ; y = y + x1
                bra.s   nexta           ; back to main loop

mainloop:
                move.l  D0,D2           ; x1 = x
                asr.l   D5,D2           ; / (2 ^ i)
                move.l  D1,D3           ; y1 = y
                asr.l   D5,D3           ; / (2 ^ i)
                tst.l   D6              ; test sign (is 2^0 bit)
                bpl.s   subloop         ; go do subtract if > 1

                add.l   (A0)+,D6        ; z = z + arctan(i)/2pi
                add.l   D3,D0           ; x = x + y1
                sub.l   D2,D1           ; y = y + x1
nexta:
                addq.l  #1,D5           ; i = i + 1
                cmp.l   #$1E,D5         ; check end condition
                bne.s   mainloop        ; loop if not all done

; now untangle output value
                moveq   #$81-$0100,D2   ; set exponent for 0 to .99 rec.
                move.l  D2,D3           ; copy it for cos output
outloop:
                tst.b   cosout(A3)      ; did we want cos output?
                bmi.s   subexit         ; if so skip

                exg     D0,D1           ; swap SIN and COS mantissas
                exg     D2,D3           ; swap SIN and COS exponents
subexit:
                move.l  D0,FAC1_m(A3)   ; set result mantissa
                move.b  D2,FAC1_e(A3)   ; set result exponent
                bra     LAB_24D5        ; normalise FAC1 & return



; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; perform ATN()

LAB_ATN:
                move.b  FAC1_e(A3),D0   ; get FAC1 exponent
                beq     RTS_021         ; ATN(0) = 0 so skip calculation

                move.b  #0,cosout(A3)   ; set result needed
                cmp.b   #$81,D0         ; compare exponent with 1
                bcs.s   LAB_ATLE        ; branch if n<1

                bne.s   LAB_ATGO        ; branch if n>1

                move.l  FAC1_m(A3),D0   ; get mantissa
                add.l   D0,D0           ; shift left
                beq.s   LAB_ATLE        ; branch if n=1

LAB_ATGO:
                move.l  #$80000000,FAC2_m(A3) ; set mantissa for 1
                move.w  #$8100,FAC2_e(A3) ; set exponent for 1
                move.b  FAC1_s(A3),FAC_sc(A3) ; sign compare = sign
                bsr     LAB_DIVIDE      ; do 1/n
                move.b  #$FF,cosout(A3) ; set inverse result needed
LAB_ATLE:
                move.l  FAC1_m(A3),D0   ; get FAC1 mantissa
                moveq   #$82,D1         ; set to correct exponent
                sub.b   FAC1_e(A3),D1   ; subtract FAC1 exponent (always <= 1)
                lsr.l   D1,D0           ; shift in two integer part bits
                lea     TAB_ATNC(PC),A0 ; get pointer to arctan table
                moveq   #0,D6           ; Z = 0
                move.l  #1<<30,D1       ; y = 1
                moveq   #29,D5          ; loop 30 times
                moveq   #1,D4           ; shift counter
                bra.s   LAB_ATCD        ; enter loop

LAB_ATNP:
                asr.l   D4,D2           ; x1 / 2^i
                add.l   D2,D1           ; y = y + x1
                add.l   (A0),D6         ; z = z + atn(i)
LAB_ATCD:
                move.l  D0,D2           ; x1 = x
                move.l  D1,D3           ; y1 = y
                asr.l   D4,D3           ; y1 / 2^i
LAB_CATN:
                sub.l   D3,D0           ; x = x - y1
                bpl.s   LAB_ATNP        ; branch if x >= 0

                move.l  D2,D0           ; else get x back
                addq.w  #4,A0           ; increment pointer
                addq.l  #1,D4           ; increment i
                asr.l   #1,D3           ; y1 / 2^i
                dbra    D5,LAB_CATN     ; decrement and loop if not done

                move.b  #$82,FAC1_e(A3) ; set new exponent
                move.l  D6,FAC1_m(A3)   ; save mantissa
                bsr     LAB_24D5        ; normalise FAC1

                tst.b   cosout(A3)      ; was it > 1 ?
                bpl.s   RTS_021         ; branch if not

                move.b  FAC1_s(A3),D7   ; get sign
                move.b  #0,FAC1_s(A3)   ; clear sign
                move.l  #$C90FDAA2,FAC2_m(A3) ; set -(pi/2)
                move.w  #$8180,FAC2_e(A3) ; set exponent and sign
                move.b  #$FF,FAC_sc(A3) ; set sign compare
                bsr     LAB_ADD         ; perform addition, FAC2 to FAC1
                move.b  D7,FAC1_s(A3)   ; restore sign
RTS_021:
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; perform BITSET

LAB_BITSET:
                bsr     LAB_GADB        ; get two parameters for POKE or WAIT
; first parameter in a0, second in d0
                cmp.b   #$08,D0         ; only 0 to 7 are allowed
                bcc     LAB_FCER        ; branch if > 7

                bset    D0,(A0)         ; set bit
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; perform BITCLR

LAB_BITCLR:
                bsr     LAB_GADB        ; get two parameters for POKE or WAIT
; first parameter in a0, second in d0
                cmp.b   #$08,D0         ; only 0 to 7 are allowed
                bcc     LAB_FCER        ; branch if > 7

                bclr    D0,(A0)         ; clear bit
                rts

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; perform RSETLIST  (List Index)

LAB_RSETLIST:	bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start
				bsr		LAB_EVIR
				move.l	d0,r_index

				movem.l	d0-d7/a0-a6,-(a7)
				
				jsr		RAPTOR_setlist
				
				movem.l	(a7)+,d0-d7/a0-a6

                rts	

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; perform RPARTI(fx,x,y) 

LAB_RPARTI:		bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,.p_index

                bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start
                bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,.p_x

                bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start
                bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,.p_y

				bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start

				movem.l	d0-a6,-(a7)
				lea		pixel_list,a0
				move.l	.p_index,d0
				asl.w	#2,d0
				move.l	(a0,d0.w),a0
				move.l	a0,raptor_part_inject_addr
				move.l	.p_x,(a0)
				move.l	.p_y,4(a0)
				lea		RAPTOR_particle_injection_GPU,a0
				jsr 	RAPTOR_call_GPU_code
				movem.l	(a7)+,d0-a6
			
                rts

.p_index:		dc.l	0
.p_x:			dc.l	0
.p_y:			dc.l	0

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; perform RSETMAP(x,y) 

LAB_RSETMAP:	bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,raptor_map_position_x

                bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start
                bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,raptor_map_position_y

				bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start

				movem.l	d0-a6,-(a7)
				jsr		RAPTOR_map_set_position
				movem.l	(a7)+,d0-a6
			
                rts
				
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; perform PLOT(x,y) 

LAB_PLOT:		bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.w	d0,.px
				
                bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start
                bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.w	d0,.py
				
				bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start
				
				movem.l	d0-d3/a0,-(a7)
				move.w	.px,d0
				move.w	.py,d1
				move.b	pcolor,d2
				btst	#0,d0
				beq.s	.even
				ror.w	#4,d2
.even:			asr.w	d0
				lea		RAPTOR_particle_gfx,a0
				add.w	d0,a0
				move.w	d1,d3
				asl.w	#5,d3
				asl.w	#7,d1
				add.w	d1,a0
				add.w	d3,a0
				or.b	d2,(a0)
				movem.l	(a7)+,d0-d3/a0
				
                rts
				
.px:				dc.w	0
.py:				dc.w	0
pcolor:				dc.b	$f0,0

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; perform COLOUR(x)

LAB_COLOUR:		bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				rol.w	#4,d0
				move.b	d0,pcolor
								
				bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start
				
                rts


				
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; perform SETCUR(x,y) 

LAB_SETCUR:		bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				asl.w	#3,d0
				move.l	d0,rap_c_x

                bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start
                bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				asl.w	#3,d0
				move.l	d0,rap_c_y

				bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start
								
                rts

				
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; perform RSETOBJ  (Spr Index,offset,value)

LAB_RSETOBJ:	bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,r_index

                bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start
                bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,r_offset

                bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start
                bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,r_value

				move.l	a0,-(a7)

				move.l	raptor_liststart,a0
			;	lea		RAPTOR_sprite_table,a0
				move.l	r_index,d0
				mulu	#sprite_tabwidth,d0
				add.l	d0,a0
				
				add.l	r_offset,a0
				move.l 	r_value,(a0)
				
				move.l	(a7)+,a0
				bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start

                rts
				
r_index:			dc.l	0
r_offset:			dc.l	0
r_value:			dc.l	0
	
LAB_RUPDALL:	bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start
				bsr		LAB_EVIR		; d0 now contains parameter
				
				move.l	a0,-(a7)
				
				asl.w	#2,d0
				move.l	.RUPDTAB(pc,d0.w),a0
				jmp		(a0)
.RUPDTAB:		dc.l	.rnow,.rvbl,.rnvbl

.rnow:			cmp.l	#4,RUPDALL_FLAG
				bne		.do_now
				
				jsr		RAPTOR_wait_frame
				clr.l	RUPDALL_FLAG
				bra		.rupd_exit

.do_now:		movem.l	d0-d7/a0-a6,-(a7)
				jsr		RAPTOR_wait_frame_UPDATE_ALL
				movem.l	(a7)+,d0-d7/a0-a6
				bra		.rupd_exit

.rvbl:			move.l	#4,RUPDALL_FLAG
				bra		.rupd_exit

.rnvbl:			clr.l	RUPDALL_FLAG

.rupd_exit:		move.l	(a7)+,a0
				rts

RUPDALL_FLAG:	dc.l	0
								
LAB_CLS:		movem.l	d0-d7/a0-a6,-(a7)
				jsr		RAPTOR_particle_clear
				
				lea		scrnbuffer,a0
				move.l	#((40*24)/16)-1,d7
				move.l	#'    ',d0
.reset:			move.l	d0,(a0)+
				move.l	d0,(a0)+
				move.l	d0,(a0)+
				move.l	d0,(a0)+
				dbra	d7,.reset
				
				clr.l	rap_c_x
				clr.l	rap_c_y
				
				movem.l	(a7)+,d0-d7/a0-a6
				rts
								

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform U235MOD

LAB_U235MOD:	bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,u_mod
				tst.l	d0
				bpl		.setmodule
				
;; if here, stop module
.stopmodule:
				bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start
				rts

.setmodule:		movem.l	d0-d7/a0-a6,-(a7)

				jsr		RAPTOR_U235stopmodule
				
				move.l	u_mod,d0
				lea		RAPTOR_module_list,a0
				add.w	d0,d0
				add.w	d0,d0
				move.l	(a0,d0.w),a0
				jsr		RAPTOR_U235setmodule												; U235 module Init
				jsr		RAPTOR_U235gomodule_stereo											; and start it playing			
				
				movem.l	(a7)+,d0-d7/a0-a6
				bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start
				rts
				
u_mod:			dc.l	0

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform U235SND()

LAB_U235SND:	bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,u_sfx

				bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start
                bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR

				movem.l	d0-d7/a0-a6,-(a7)

				move.l	d0,d1
				move.l	u_sfx,d0
				jsr		RAPTOR_U235playsample
				
				movem.l	(a7)+,d0-d7/a0-a6
				bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start
				rts

u_sfx:			dc.l	0
				
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; perform R_PRINT

LAB_RPRINT:		bsr	LAB_EVEX
				bsr	LAB_22B6		; (STRING) d0=len, a0=pointer
				
				subq	#1,d0	
				lea	r_buffer,a1
.cpy:			move.b	(a0)+,(a1)+
				dbra	d0,.cpy
				move.b	#-1,(a1)
		
                bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start
                bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,r_xpos

                bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start
                bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,r_ypos

                bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start
                bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,r_size
				
                bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start
                bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,r_indx
				bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start

				movem.l	d0-d7/a0-a6,-(a7)

				move.l	r_xpos,d0
				move.l	r_ypos,d1
				move.l	r_size,d2
				move.l	r_indx,d3
				lea		r_buffer(pc),a0
				jsr		RAPTOR_print
				movem.l	(a7)+,d0-d7/a0-a6

                rts
				
r_xpos:			dc.l	0
r_ypos:			dc.l	0
r_indx:			dc.l	0
r_size:			dc.l	0
string_addr:	dc.l	0
r_buffer:		dc.b	"                                          "
				
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; perform BITTST()

LAB_BTST:
                move.b  (A5)+,D0        ; increment BASIC pointer
                bsr     LAB_GADB        ; get two parameters for POKE or WAIT
; first parameter in a0, second in d0
                cmp.b   #$08,D0         ; only 0 to 7 are allowed
                bcc     LAB_FCER        ; branch if > 7

                move.l  D0,D1           ; copy bit # to test
                bsr     LAB_GBYT        ; get next BASIC byte
                cmp.b   #')',D0         ; is next character ")"
                bne     LAB_SNER        ; if not ")" go do syntax error, then warm start

                bsr     LAB_IGBY        ; update execute pointer (to character past ")")
                moveq   #0,D0           ; set the result as zero
                btst    D1,(A0)         ; test bit
                beq     LAB_27DB        ; branch if zero (already correct)

                moveq   #-1,D0          ; set for -1 result
                bra     LAB_27DB        ; go do SGN tail


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform USING$()

fsd             .EQU 0           ;   (sp) format string descriptor pointer
fsti            .EQU 4           ;  4(sp) format string this index
fsli            .EQU 6           ;  6(sp) format string last index
fsdpi           .EQU 8           ;  8(sp) format string decimal point index
fsdc            .EQU 10          ; 10(sp) format string decimal characters
fend            .EQU 12-4        ;  x(sp) end-4, fsd is popped by itself

ofchr           .EQU '#'         ; the overflow character

LAB_USINGS:
                tst.b   Dtypef(A3)      ; test data type, $80=string
                bpl     LAB_FOER        ; if not string type go do format error

                movea.l FAC1_m(A3),A2   ; get the format string descriptor pointer
                move.w  4(A2),D7        ; get the format string length
                beq     LAB_FOER        ; if null string go do format error

; clear the format string values

                moveq   #0,D0           ; clear d0
                move.w  D0,-(SP)        ; clear the format string decimal characters
                move.w  D0,-(SP)        ; clear the format string decimal point index
                move.w  D0,-(SP)        ; clear the format string last index
                move.w  D0,-(SP)        ; clear the format string this index
                move.l  A2,-(SP)        ; save the format string descriptor pointer

; make a null return string for the first string add

                moveq   #0,D1           ; make a null string
                movea.l D1,A0           ; with a null pointer
                bsr     LAB_RTST        ; push a string on the descriptor stack
; a0 = pointer, d1 = length

; do the USING$() function next value

                move.b  (A5)+,D0        ; get the next BASIC byte
LAB_U002:
                cmp.b   #',',D0         ; compare with comma
                bne     LAB_SNER        ; if not "," go do syntax error

                bsr     LAB_ProcFo      ; process the format string
                tst.b   D2              ; test the special characters flag
                beq     LAB_FOER        ; if no special characters go do format error

                bsr     LAB_EVEX        ; evaluate the expression
                tst.b   Dtypef(A3)      ; test the data type
                bmi     LAB_TMER        ; if string type go do type missmatch error

                tst.b   FAC1_e(A3)      ; test FAC1 exponent
                beq.s   LAB_U004        ; if FAC1 = 0 skip the rounding

                move.w  fsdc(SP),D1     ; get the format string decimal character count
                cmp.w   #8,D1           ; compare the fraction digit count with 8
                bcc.s   LAB_U004        ; if >= 8 skip the rounding

                move.w  D1,D0           ; else copy the fraction digit count
                add.w   D1,D1           ; ; 2
                add.w   D0,D1           ; ; 3
                add.w   D1,D1           ; ; 6
                lea     LAB_P_10(PC),A0 ; get the rounding table base
                move.l  2(A0,D1.w),FAC2_m(A3) ; get the rounding mantissa
                move.w  0(A0,D1.w),D0   ; get the rounding exponent
                sub.w   #$0100,D0       ; effectively divide the mantissa by 2
                move.w  D0,FAC2_e(A3)   ; save the rounding exponent
                move.b  #$00,FAC_sc(A3) ; clear the sign compare
                bsr     LAB_ADD         ; round the value to n places
LAB_U004:
                bsr     LAB_2970        ; convert FAC1 to string - not on stack

                bsr     LAB_DupFmt      ; duplicate the processed format string section
; returns length in d1, pointer in a0

; process the number string, length in d6, decimal point index in d2

                lea     Decss(A3),A2    ; set the number string start
                moveq   #0,D6           ; clear the number string index
                moveq   #'.',D4         ; set the decimal point character
LAB_U005:
                move.w  D6,D2           ; save the index to flag the decimal point
LAB_U006:
                addq.w  #1,D6           ; increment the number string index
                move.b  0(A2,D6.w),D0   ; get a number string character
                beq.s   LAB_U010        ; if null then number complete

                cmp.b   #'E',D0         ; compare the character with an "E"
                beq.s   LAB_U008        ; was sx[.x]Esxx so go handle sci notation

                cmp.b   D4,D0           ; compare the character with "."
                bne.s   LAB_U006        ; if not decimal point go get the next digit

                bra.s   LAB_U005        ; go save the index and get the next digit

; have found an sx[.x]Esxx number, the [.x] will not be present for a single digit

LAB_U008:
                move.w  D6,D3           ; copy the index to the "E"
                subq.w  #1,D3           ; -1 gives the last digit index

                addq.w  #1,D6           ; increment the index to the exponent sign
                move.b  0(A2,D6.w),D0   ; get the exponent sign character
                cmp.b   #'-',D0         ; compare the exponent sign with "-"
                bne     LAB_FCER        ; if it wasn't sx[.x]E-xx go do function
; call error

; found an sx[.x]E-xx number so check the exponent magnitude

                addq.w  #1,D6           ; increment the index to the exponent 10s
                move.b  0(A2,D6.w),D0   ; get the exponent 10s character
                cmp.b   #'0',D0         ; compare the exponent 10s with "0"
                beq.s   LAB_U009        ; if it was sx[.x]E-0x go get the exponent
; 1s character

                moveq   #10,D0          ; else start writing at index 10
                bra.s   LAB_U00A        ; go copy the digits

; found an sx[.x]E-0x number so get the exponent magnitude

LAB_U009:
                addq.w  #1,D6           ; increment the index to the exponent 1s
                moveq   #$0F,D0         ; set the mask for the exponent 1s digit
                and.b   0(A2,D6.w),D0   ; get and convert the exponent 1s digit
LAB_U00A:
                move.w  D3,D2           ; copy the number last digit index
                cmpi.w  #1,D2           ; is the number of the form sxE-0x
                bne.s   LAB_U00B        ; if it is sx.xE-0x skip the increment

; else make room for the decimal point
                addq.w  #1,D2           ; add 1 to the write index
LAB_U00B:
                add.w   D0,D2           ; add the exponent 1s to the write index
                moveq   #10,D0          ; set the maximum write index
                sub.w   D2,D0           ; compare the index with the maximum
                bgt.s   LAB_U00C        ; if the index < the maximum continue

                add.w   D0,D2           ; else set the index to the maximum
                add.w   D0,D3           ; adjust the read index
                cmpi.w  #1,D3           ; compare the adjusted index with 1
                bgt.s   LAB_U00C        ; if > 1 continue

                moveq   #0,D3           ; else allow for the decimal point
LAB_U00C:
                move.l  D2,D6           ; copy the write index as the number
; string length
                moveq   #0,D0           ; clear d0 to null terminate the number
; string
LAB_U00D:
                move.b  D0,0(A2,D2.w)   ; save the character to the number string
                subq.w  #1,D2           ; decrement the number write index
                cmpi.w  #1,D2           ; compare the number write index with 1
                beq.s   LAB_U00F        ; if at the decimal point go save it

; else write a digit to the number string
                moveq   #'0',D0         ; default to "0"
                tst.w   D3              ; test the number read index
                beq.s   LAB_U00D        ; if zero just go save the "0"

LAB_U00E:
                move.b  0(A2,D3.w),D0   ; read the next number digit
                subq.w  #1,D3           ; decrement the read index
                cmp.b   D4,D0           ; compare the digit with "."
                bne.s   LAB_U00D        ; if not "." go save the digit

                bra.s   LAB_U00E        ; else go get the next digit

LAB_U00F:
                move.b  D4,0(A2,D2.w)   ; save the decimal point
LAB_U010:
                tst.w   D2              ; test the number string decimal point index
                bne.s   LAB_U014        ; if dp present skip the reset

                move.w  D6,D2           ; make the decimal point index = the length

; copy the fractional digit characters from the number string

LAB_U014:
                move.w  D2,D3           ; copy the number string decimal point index
                addq.w  #1,D3           ; increment the number string index
                move.w  fsdpi(SP),D4    ; get the new format string decimal point index
LAB_U018:
                addq.w  #1,D4           ; increment the new format string index
                cmp.w   D4,D1           ; compare it with the new format string length
                bls.s   LAB_U022        ; if done the fraction digits go do integer

                move.b  0(A0,D4.w),D0   ; get a new format string character
                cmp.b   #'%',D0         ; compare it with "%"
                beq.s   LAB_U01C        ; if "%" go copy a number character

                cmp.b   #'#',D0         ; compare it with "#"
                bne.s   LAB_U018        ; if not "#" go do the next new format character

LAB_U01C:
                moveq   #'0',D0         ; default to "0" character
                cmp.w   D3,D6           ; compare the number string index with length
                bls.s   LAB_U020        ; if there skip the character get

                move.b  0(A2,D3.w),D0   ; get a character from the number string
                addq.w  #1,D3           ; increment the number string index
LAB_U020:
                move.b  D0,0(A0,D4.w)   ; save the number character to the new format
; string
                bra.s   LAB_U018        ; go do the next new format character

; now copy the integer digit characters from the number string

LAB_U022:
                moveq   #0,D6           ; clear the sign done flag
                moveq   #0,D5           ; clear the sign present flag
                subq.w  #1,D2           ; decrement the number string index
                bne.s   LAB_U026        ; if not now at sign continue

                moveq   #1,D2           ; increment the number string index
                move.b  #'0',0(A2,D2.w) ; replace the point with a zero
LAB_U026:
                move.w  fsdpi(SP),D4    ; get the new format string decimal point index
                cmp.w   D4,D1           ; compare it with the new format string length
                bcc.s   LAB_U02A        ; if within the string go use the index

                move.w  D1,D4           ; else set the index to the end of the string
LAB_U02A:
                subq.w  #1,D4           ; decrement the new format string index
                bmi.s   LAB_U03E        ; if all done go test for any overflow

                move.b  0(A0,D4.w),D0   ; else get a new format string character

                moveq   #'0',D7         ; default to "0" character
                cmp.b   #'%',D0         ; compare it with "%"
                beq.s   LAB_U02B        ; if "%" go copy a number character

                moveq   #' ',D7         ; default to " " character
                cmp.b   #'#',D0         ; compare it with "#"
                bne.s   LAB_U02C        ; if not "#" go try ","

LAB_U02B:
                tst.w   D2              ; test the number string index
                bne.s   LAB_U036        ; if not at the sign go get a number character

                bra.s   LAB_U03C        ; else go save the default character

LAB_U02C:
                cmp.b   #',',D0         ; compare it with ","
                bne.s   LAB_U030        ; if not "," go try the sign characters

                tst.w   D2              ; test the number string index
                bne.s   LAB_U02E        ; if not at the sign keep the ","

                cmpi.b  #'%',-1(A0,D4.w) ; else compare the next format string character
; with "%"
                bne.s   LAB_U03C        ; if not "%" keep the default character

LAB_U02E:
                move.b  D0,D7           ; else use the "," character
                bra.s   LAB_U03C        ; go save the character to the string

LAB_U030:
                cmp.b   #'-',D0         ; compare it with "-"
                beq.s   LAB_U034        ; if "-" go do the sign character

                cmp.b   #'+',D0         ; compare it with "+"
                bne.s   LAB_U02A        ; if not "+" go do the next new format character

                cmpi.b  #'-',(A2)       ; compare the sign character with "-"
                beq.s   LAB_U034        ; if "-" don't change the sign character

                move.b  #'+',(A2)       ; else make the sign character "+"
LAB_U034:
                move.b  D0,D5           ; set the sign present flag
                tst.w   D2              ; test the number string index
                beq.s   LAB_U038        ; if at the sign keep the default character

LAB_U036:
                move.b  0(A2,D2.w),D7   ; else get a character from the number string
                subq.w  #1,D2           ; decrement the number string index
                bra.s   LAB_U03C        ; go save the character

LAB_U038:
                tst.b   D6              ; test the sign done flag
                bne.s   LAB_U03C        ; if the sign has been done go use the space
; character

                move.b  (A2),D7         ; else get the sign character
                move.b  D7,D6           ; flag that the sign has been done
LAB_U03C:
                move.b  D7,0(A0,D4.w)   ; save the number character to the new format
; string
                bra.s   LAB_U02A        ; go do the next new format character

; test for overflow conditions

LAB_U03E:
                tst.w   D2              ; test the number string index
                bne.s   LAB_U040        ; if all the digits aren't done go output
; an overflow indication

; test for sign overflows

                tst.b   D5              ; test the sign present flag
                beq.s   LAB_U04A        ; if no sign present go add the string

; there was a sign in the format string

                tst.b   D6              ; test the sign done flag
                bne.s   LAB_U04A        ; if the sign is done go add the string

; the sign isn't done so see if it was mandatory

                cmpi.b  #'+',D5         ; compare the sign with "+"
                beq.s   LAB_U040        ; if it was "+" go output an overflow
; indication

; the sign wasn't mandatory but the number may have been negative

                cmpi.b  #'-',(A2)       ; compare the sign character with "-"
                bne.s   LAB_U04A        ; if it wasn't "-" go add the string

; else the sign was "-" and a sign hasn't been output so ..

; the number overflowed the format string so replace all the special format characters
; with the overflow character

LAB_U040:
                moveq   #ofchr,D5       ; set the overflow character
                move.w  D1,D7           ; copy the new format string length
                subq.w  #1,D7           ; adjust for the loop type
                move.w  fsti(SP),D6     ; copy the new format string last index
                subq.w  #1,D6           ; -1 gives the last character of this string
                bgt.s   LAB_U044        ; if not zero continue

                move.w  D7,D6           ; else set the format string index to the end
LAB_U044:
                move.b  0(A1,D6.w),D0   ; get a character from the format string
                cmpi.b  #'#',D0         ; compare it with "#" special format character
                beq.s   LAB_U046        ; if "#" go use the overflow character

                cmpi.b  #'%',D0         ; compare it with "%" special format character
                beq.s   LAB_U046        ; if "%" go use the overflow character

                cmpi.b  #',',D0         ; compare it with "," special format character
                beq.s   LAB_U046        ; if "," go use the overflow character

                cmpi.b  #'+',D0         ; compare it with "+" special format character
                beq.s   LAB_U046        ; if "+" go use the overflow character

                cmpi.b  #'-',D0         ; compare it with "-" special format character
                beq.s   LAB_U046        ; if "-" go use the overflow character

                cmpi.b  #'.',D0         ; compare it with "." special format character
                bne.s   LAB_U048        ; if not "." skip the using overflow character

LAB_U046:
                move.b  D5,D0           ; use the overflow character
LAB_U048:
                move.b  D0,0(A0,D7.w)   ; save the character to the new format string
                subq.w  #1,D6           ; decrement the format string index
                dbra    D7,LAB_U044     ; decrement the count and loop if not all done

; add the new string to the previous string

LAB_U04A:
                lea     6(A4),A0        ; get the descriptor pointer for string 1
                move.l  A4,FAC1_m(A3)   ; save the descriptor pointer for string 2
                bsr     LAB_224E        ; concatenate the strings

; now check for any tail on the format string

                move.w  fsti(SP),D0     ; get this index
                beq.s   LAB_U04C        ; if at start of string skip the output

                move.w  D0,fsli(SP)     ; save this index to the last index
                bsr     LAB_ProcFo      ; now process the format string
                tst.b   D2              ; test the special characters flag
                bne.s   LAB_U04C        ; if special characters present skip the output

; else output the new string part

                bsr.s   LAB_DupFmt      ; duplicate the processed format string section
                move.w  fsti(SP),fsli(SP) ; copy this index to the last index

; add the new string to the previous string

                lea     6(A4),A0        ; get the descriptor pointer for string 1
                move.l  A4,FAC1_m(A3)   ; save the descriptor pointer for string 2
                bsr     LAB_224E        ; concatenate the strings

; check for another value or end of function

LAB_U04C:
                move.b  (A5)+,D0        ; get the next BASIC byte
                cmp.b   #')',D0         ; compare with close bracket
                bne     LAB_U002        ; if not ")" go do next value

; pop the result string off the descriptor stack

                movea.l A4,A0           ; copy the result string descriptor pointer
                move.l  Sstorl(A3),D1   ; save the bottom of string space
                bsr     LAB_22BA        ; pop (a0) descriptor, returns with ..
; d0 = length, a0 = pointer
                move.l  D1,Sstorl(A3)   ; restore the bottom of string space
                movea.l A0,A1           ; copy the string result pointer
                move.w  D0,D1           ; copy the string result length

; pop the format string off the descriptor stack

                movea.l (SP)+,A0        ; pull the format string descriptor pointer
                bsr     LAB_22BA        ; pop (a0) descriptor, returns with ..
; d0 = length, a0 = pointer

                lea     fend(SP),SP     ; dump the saved values

; push the result string back on the descriptor stack and return

                movea.l A1,A0           ; copy the result string pointer back
                bra     LAB_RTST        ; push a string on the descriptor stack and
; return. a0 = pointer, d1 = length


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; duplicate the processed format string section

; make a string as long as the format string
LAB_DupFmt:
                movea.l 4+fsd(SP),A1    ; get the format string descriptor pointer
                move.w  4(A1),D7        ; get the format string length
                move.w  4+fsli(SP),D2   ; get the format string last index
                move.w  4+fsti(SP),D6   ; get the format string this index
                move.w  D6,D1           ; copy the format string this index
                sub.w   D2,D1           ; subtract the format string last index
                bhi.s   LAB_D002        ; if > 0 skip the correction

                add.w   D7,D1           ; else add the format string length as the
; correction
LAB_D002:
                bsr     LAB_2115        ; make string space d1 bytes long
; return a0/Sutill = pointer, others unchanged

; push the new string on the descriptor stack

                bsr     LAB_RTST        ; push a string on the descriptor stack and
; return. a0 = pointer, d1 = length

; copy the characters from the format string

                movea.l 4+fsd(SP),A1    ; get the format string descriptor pointer
                movea.l (A1),A1         ; get the format string pointer
                moveq   #0,D4           ; clear the new string index
LAB_D00A:
                move.b  0(A1,D2.w),0(A0,D4.w) ; get a character from the format string and
; save it to the new string
                addq.w  #1,D4           ; increment the new string index
                addq.w  #1,D2           ; increment the format string index
                cmp.w   D2,D7           ; compare the format index with the length
                bne.s   LAB_D00E        ; if not there skip the reset

                moveq   #0,D2           ; else reset the format string index
LAB_D00E:
                cmp.w   D2,D6           ; compare the index with this index
                bne.s   LAB_D00A        ; if not .EQUal go do the next character

                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
;*
; process the format string

LAB_ProcFo:
                movea.l 4+fsd(SP),A1    ; get the format string descriptor pointer
                move.w  4(A1),D7        ; get the format string length
                movea.l (A1),A1         ; get the format string pointer
                move.w  4+fsli(SP),D6   ; get the format string last index

                move.w  D7,4+fsdpi(SP)  ; set the format string decimal point index
;*##    MOVE.w  #-1,4+fsdpi(sp)         ; set the format string decimal point index
                moveq   #0,D5           ; no decimal point
                moveq   #0,D3           ; no decimal characters
                moveq   #0,D2           ; no special characters
LAB_P004:
                move.b  0(A1,D6.w),D0   ; get a format string byte

                cmp.b   #',',D0         ; compare it with ","
                beq.s   LAB_P01A        ; if "," go do the next format string byte

                cmp.b   #'#',D0         ; compare it with "#"
                beq.s   LAB_P008        ; if "#" go flag special characters

                cmp.b   #'%',D0         ; compare it with "%"
                bne.s   LAB_P00C        ; if not "%" go try "+"

LAB_P008:
                tst.l   D5              ; test the decimal point flag
                bpl.s   LAB_P00E        ; if no point skip counting decimal characters

                addq.w  #1,D3           ; else increment the decimal character count
                bra.s   LAB_P01A        ; go do the next character

LAB_P00C:
                cmp.b   #'+',D0         ; compare it with "+"
                beq.s   LAB_P00E        ; if "+" go flag special characters

                cmp.b   #'-',D0         ; compare it with "-"
                bne.s   LAB_P010        ; if not "-" go check decimal point

LAB_P00E:
                or.b    D0,D2           ; flag special characters
                bra.s   LAB_P01A        ; go do the next character

LAB_P010:
                cmp.b   #'.',D0         ; compare it with "."
                bne.s   LAB_P018        ; if not "." go check next

; "." a decimal point

                tst.l   D5              ; if there is already a decimal point
                bmi.s   LAB_P01A        ; go do the next character

                move.w  D6,D0           ; copy the decimal point index
                sub.w   4+fsli(SP),D0   ; calculate it from the scan start
                move.w  D0,4+fsdpi(SP)  ; save the decimal point index
                moveq   #-1,D5          ; flag decimal point
                or.b    D0,D2           ; flag special characters
                bra.s   LAB_P01A        ; go do the next character

; was not a special character

LAB_P018:
                tst.b   D2              ; test if there have been special characters
                bne.s   LAB_P01E        ; if so exit the format string process

LAB_P01A:
                addq.w  #1,D6           ; increment the format string index
                cmp.w   D6,D7           ; compare it with the format string length
                bhi.s   LAB_P004        ; if length > index go get the next character

                moveq   #0,D6           ; length = index so reset the format string
; index
LAB_P01E:
                move.w  D6,4+fsti(SP)   ; save the format string this index
                move.w  D3,4+fsdc(SP)   ; save the format string decimal characters

                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; perform BIN$()
; # of leading 0s is in d1, the number is in d0

LAB_BINS:
                cmp.b   #$21,D1         ; max + 1
                bcc     LAB_FCER        ; exit if too big ( > or = )

                moveq   #$1F,D2         ; bit count-1
                lea     Binss(A3),A0    ; point to string
                moveq   #$30,D4         ; "0" character for ADDX
NextB1:
                moveq   #0,D3           ; clear byte
                lsr.l   #1,D0           ; shift bit into Xb
                addx.b  D4,D3           ; add carry and character to zero
                move.b  D3,0(A0,D2.w)   ; save character to string
                dbra    D2,NextB1       ; decrement and loop if not done

; this is the exit code and is also used by HEX$()

EndBHS:
                move.b  #0,BHsend(A3)   ; null terminate the string
                tst.b   D1              ; test # of characters
                beq.s   NextB2          ; go truncate string

                neg.l   D1              ; make -ve
                add.l   #BHsend,D1      ; effectively (end-length)
                lea     0(A3,D1.w),A0   ; effectively add (end-length) to pointer
                bra.s   BinPr           ; go print string

; truncate string to remove leading "0"s

NextB2:
                move.b  (A0),D0         ; get byte
                beq.s   BinPr           ; if null then end of string so add 1 and go
; print it

                cmp.b   #'0',D0         ; compare with "0"
                bne.s   GoPr            ; if not "0" then go print string from here

                addq.w  #1,A0           ; else increment pointer
                bra.s   NextB2          ; loop always

; make fixed length output string - ignore overflows!

BinPr:
                lea     BHsend(A3),A1   ; get string end
                cmpa.l  A1,A0           ; are we at the string end
                bne.s   GoPr            ; branch if not

                subq.w  #1,A0           ; else need at least one zero
GoPr:
                bra     LAB_20AE        ; print " terminated string to FAC1, stack & RET


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform HEX$()
; # of leading 0s is in d1, the number is in d0

LAB_HEXS:
                cmp.b   #$09,D1         ; max + 1
                bcc     LAB_FCER        ; exit if too big ( > or = )

                moveq   #$07,D2         ; nibble count-1
                lea     Hexss(A3),A0    ; point to string
                moveq   #$30,D4         ; "0" character for ABCD
NextH1:
                move.b  D0,D3           ; copy lowest byte
                ror.l   #4,D0           ; shift nibble into 0-3
                and.b   #$0F,D3         ; just this nibble
                move.b  D3,D5           ; copy it
                add.b   #$F6,D5         ; set extend bit
                abcd    D4,D3           ; decimal add extend and character to zero
                move.b  D3,0(A0,D2.w)   ; save character to string
                dbra    D2,NextH1       ; decrement and loop if not done

                bra.s   EndBHS          ; go process string


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; ctrl-c check routine. includes limited "life" byte save for INGET routine

VEC_CC:
                tst.b   ccflag(A3)      ; check [CTRL-C] check flag
                bne.s   RTS_022         ; exit if [CTRL-C] check inhibited

                jsr     V_INPT(A3)      ; scan input device
                bcc.s   LAB_FBA0        ; exit if buffer empty

                move.b  D0,ccbyte(A3)   ; save received byte
                move.b  #$20,ccnull(A3) ; set "life" timer for bytes countdown
                bra     LAB_1636        ; return to BASIC

LAB_FBA0:
                tst.b   ccnull(A3)      ; get countdown byte
                beq.s   RTS_022         ; exit if finished

                subq.b  #1,ccnull(A3)   ; else decrement countdown
RTS_022:
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; get byte from input device, no waiting
; returns with carry set if byte in A

INGET:
                jsr     V_INPT(A3)      ; call scan input device
                bcs.s   LAB_FB95        ; if byte go reset timer

                move.b  ccnull(A3),D0   ; get countdown
                beq.s   RTS_022         ; exit if empty

                move.b  ccbyte(A3),D0   ; get last received byte
LAB_FB95:
                move.b  #$00,ccnull(A3) ; clear timer because we got a byte
                ori     #1,CCR          ; set carry, flag we got a byte
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform MAX()

LAB_MAX:
                bsr     LAB_EVEZ        ; evaluate expression (no decrement)
                tst.b   Dtypef(A3)      ; test data type
                bmi     LAB_TMER        ; if string do Type missmatch Error/warm start

LAB_MAXN:
                bsr.s   LAB_PHFA        ; push FAC1, evaluate expression,
; pull FAC2 & compare with FAC1
                bcc.s   LAB_MAXN        ; branch if no swap to do

                bsr     LAB_279B        ; copy FAC2 to FAC1
                bra.s   LAB_MAXN        ; go do next


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform MIN()

LAB_MIN:
                bsr     LAB_EVEZ        ; evaluate expression (no decrement)
                tst.b   Dtypef(A3)      ; test data type
                bmi     LAB_TMER        ; if string do Type missmatch Error/warm start

LAB_MINN:
                bsr.s   LAB_PHFA        ; push FAC1, evaluate expression,
; pull FAC2 & compare with FAC1
                bls.s   LAB_MINN        ; branch if no swap to do

                bsr     LAB_279B        ; copy FAC2 to FAC1
                bra.s   LAB_MINN        ; go do next (branch always)

; exit routine. don't bother returning to the loop code
; check for correct exit, else so syntax error

LAB_MMEC:
                cmp.b   #')',D0         ; is it end of function?
                bne     LAB_SNER        ; if not do MAX MIN syntax error

                lea     4(SP),SP        ; dump return address (faster)
                bra     LAB_IGBY        ; update BASIC execute pointer (to chr past ")")
; and return

; check for next, evaluate & return or exit
; this is the routine that does most of the work

LAB_PHFA:
                bsr     LAB_GBYT        ; get next BASIC byte
                cmp.b   #',',D0         ; is there more ?
                bne.s   LAB_MMEC        ; if not go do end check

                move.w  FAC1_e(A3),-(SP) ; push exponent and sign
                move.l  FAC1_m(A3),-(SP) ; push mantissa

                bsr     LAB_EVEZ        ; evaluate expression (no decrement)
                tst.b   Dtypef(A3)      ; test data type
                bmi     LAB_TMER        ; if string do Type missmatch Error/warm start


; pop FAC2 (MAX/MIN expression so far)
                move.l  (SP)+,FAC2_m(A3) ; pop mantissa

                move.w  (SP)+,D0        ; pop exponent and sign
                move.w  D0,FAC2_e(A3)   ; save exponent and sign
                move.b  FAC1_s(A3),FAC_sc(A3) ; get FAC1 sign
                eor.b   D0,FAC_sc(A3)   ; EOR to create sign compare
                bra     LAB_27FA        ; compare FAC1 with FAC2 & return
; returns d0=+1 Cb=0 if FAC1 > FAC2
; returns d0= 0 Cb=0 if FAC1 = FAC2
; returns d0=-1 Cb=1 if FAC1 < FAC2


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform WIDTH

LAB_WDTH:
                cmp.b   #',',D0         ; is next byte ","
                beq.s   LAB_TBSZ        ; if so do tab size

                bsr     LAB_GTBY        ; get byte parameter, result in d0 and Itemp
                tst.b   D0              ; test result
                beq.s   LAB_NSTT        ; branch if set for infinite line

                cmp.b   #$10,D0         ; else make min width = 16d
                bcs     LAB_FCER        ; if less do function call error & exit

; this next compare ensures that we can't exit WIDTH via an error leaving the
; tab size greater than the line length.

                cmp.b   TabSiz(A3),D0   ; compare with tab size
                bcc.s   LAB_NSTT        ; branch if >= tab size

                move.b  D0,TabSiz(A3)   ; else make tab size = terminal width
LAB_NSTT:
                move.b  D0,TWidth(A3)   ; set the terminal width
                bsr     LAB_GBYT        ; get BASIC byte back
                beq.s   WExit           ; exit if no following

                cmp.b   #',',D0         ; else is it ","
                bne     LAB_SNER        ; if not do syntax error

LAB_TBSZ:
                bsr     LAB_SGBY        ; increment and get byte, result in d0 and Itemp
                tst.b   D0              ; test TAB size
                bmi     LAB_FCER        ; if >127 do function call error & exit

                cmp.b   #1,D0           ; compare with min-1
                bcs     LAB_FCER        ; if <=1 do function call error & exit

                move.b  TWidth(A3),D1   ; set flags for width
                beq.s   LAB_SVTB        ; skip check if infinite line

                cmp.b   TWidth(A3),D0   ; compare TAB with width
                bgt     LAB_FCER        ; branch if too big

LAB_SVTB:
                move.b  D0,TabSiz(A3)   ; save TAB size

; calculate tab column limit from TAB size. The Iclim is set to the last tab
; position on a line that still has at least one whole tab width between it
; and the end of the line.

WExit:
                move.b  TWidth(A3),D0   ; get width
                beq.s   LAB_WDLP        ; branch if infinite line

                cmp.b   TabSiz(A3),D0   ; compare with tab size
                bcc.s   LAB_WDLP        ; branch if >= tab size

                move.b  D0,TabSiz(A3)   ; else make tab size = terminal width
LAB_WDLP:
                sub.b   TabSiz(A3),D0   ; subtract tab size
                bcc.s   LAB_WDLP        ; loop while no borrow

                add.b   TabSiz(A3),D0   ; add tab size back
                add.b   TabSiz(A3),D0   ; add tab size back again

                neg.b   D0              ; make -ve
                add.b   TWidth(A3),D0   ; subtract remainder from width
                move.b  D0,Iclim(A3)    ; save tab column limit
RTS_023:
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform SQR()

; d0 is number to find the root of
; d1 is the root result
; d2 is the remainder
; d3 is a counter
; d4 is temp

LAB_SQR:
                tst.b   FAC1_s(A3)      ; test FAC1 sign
                bmi     LAB_FCER        ; if -ve do function call error

                tst.b   FAC1_e(A3)      ; test exponent
                beq.s   RTS_023         ; exit if zero

                movem.l D1-D4,-(SP)     ; save registers
                move.l  FAC1_m(A3),D0   ; copy FAC1
                moveq   #0,D2           ; clear remainder
                move.l  D2,D1           ; clear root

                moveq   #$1F,D3         ; $1F for DBF, 64 pairs of bits to
; do for a 32 bit result
                btst    #0,FAC1_e(A3)   ; test exponent odd/even
                bne.s   LAB_SQE2        ; if odd only 1 shift first time

LAB_SQE1:
                add.l   D0,D0           ; shift highest bit of number ..
                addx.l  D2,D2           ; .. into remainder .. never overflows
                add.l   D1,D1           ; root = root ; 2 .. never overflows
LAB_SQE2:
                add.l   D0,D0           ; shift highest bit of number ..
                addx.l  D2,D2           ; .. into remainder .. never overflows

                move.l  D1,D4           ; copy root
                add.l   D4,D4           ; 2n

                addq.l  #1,D4           ; 2n+1

                cmp.l   D4,D2           ; compare 2n+1 to remainder
                bcs.s   LAB_SQNS        ; skip sub if remainder smaller

                sub.l   D4,D2           ; subtract temp from remainder
                addq.l  #1,D1           ; increment root
LAB_SQNS:
                dbra    D3,LAB_SQE1     ; loop if not all done

                move.l  D1,FAC1_m(A3)   ; save result mantissa
                move.b  FAC1_e(A3),D0   ; get exponent (d0 is clear here)
                sub.w   #$80,D0         ; normalise
                lsr.w   #1,D0           ; /2
                bcc.s   LAB_SQNA        ; skip increment if carry clear

                addq.w  #1,D0           ; add bit zero back in (allow for half shift)
LAB_SQNA:
                add.w   #$80,D0         ; re-bias to $80
                move.b  D0,FAC1_e(A3)   ; save it
                movem.l (SP)+,D1-D4     ; restore registers
                bra     LAB_24D5        ; normalise FAC1 & return


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform VARPTR()

LAB_VARPTR:
                move.b  (A5)+,D0        ; increment pointer
LAB_VARCALL:
                bsr     LAB_GVAR        ; get variable address in a0
                bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start
                move.l  A0,D0           ; copy the variable address
                bra     LAB_AYFC        ; convert d0 to signed longword in FAC1 & return


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform RAMBASE

LAB_RAM:
                lea     ram_base(A3),A0 ; get start of EhBASIC RAM
                move.l  A0,D0           ; copy it
                bra     LAB_AYFC        ; convert d0 to signed longword in FAC1 & return


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform PI

LAB_PI:
                move.l  #$C90FDAA2,FAC1_m(A3) ; pi mantissa (32 bit)
                move.w  #$8200,FAC1_e(A3) ; pi exponent and sign
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform U235PAD

LAB_U235PAD:	bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start
				bsr		LAB_EVIR
				
				cmp.l	#1,d0
				beq		.read_pad1
				
				cmp.l	#2,d0
				beq		.read_pad2
				
.badvalue:		moveq	#0,d0
				bra		LAB_AYFC
				
.read_pad1:		move.l	U235SE_pad1,d0
                bra     LAB_AYFC        ; convert d0 to signed longword in FAC1 & return

.read_pad2:		move.l	U235SE_pad2,d0
                bra     LAB_AYFC        ; convert d0 to signed longword in FAC1 & return

				


				
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; perform TWOPI

LAB_TWOPI:
                move.l  #$C90FDAA2,FAC1_m(A3) ; 2pi mantissa (32 bit)
                move.w  #$8300,FAC1_e(A3) ; 2pi exponent and sign
                rts

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform RGETOBJ

LAB_RGETOBJ:
				bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,r_index

                bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start
                bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,r_offset
				bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start
				
				move.l	a0,-(a7)
				move.l	raptor_liststart,a0
			;	lea		RAPTOR_sprite_table,a0
				move.l	r_index,d0
				mulu	#sprite_tabwidth,d0
				add.l	d0,a0
				add.l	r_offset,a0
				move.l	(a0),D0
				move.l	(a7)+,a0
				
				
                bra     LAB_AYFC        ; convert d0 to signed longword in FAC1 & return

				
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform LOCATE()

LAB_LOCATE:
				bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,r_lx

                bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start
                bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,r_ly

				bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start

			
				move.l	r_ly,d0
				lea		scrnbuffer,a0
				add.l	r_lx,a0
				mulu	#40,d0
				add.l	d0,a0
				move.b	(a0),lbyte
				
                moveq   #1,D1           ; string is single byte
                bsr     LAB_2115        ; make string space d1 bytes long
; return a0/Sutill = pointer, others unchanged
                move.b  lbyte,(A0)         ; save byte in string (byte IS string!)

				bra     LAB_RTST        ; push string on descriptor stack
 				
r_ly:			dc.l 	0
r_lx:			dc.l	0
lbyte:			dc.w	0
				
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; perform RHIT

LAB_RHIT:
				bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,r_sl

                bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start
                bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,r_sh

                bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start
                bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,r_tl

                bsr     LAB_1C01        ; scan for ",", else do syntax error/warm start
                bsr     LAB_EVNM        ; evaluate expression & check is numeric
				bsr		LAB_EVIR
				move.l	d0,r_th
				bsr     LAB_1BFB        ; scan for ")", else do syntax error/warm start

				movem.l	d1-d7/a0-a6,-(a7)
			
				clr.l	raptor_result						
				move.l	r_sl,raptor_sourcel			
				move.l	r_sh,raptor_sourceh			
				move.l	r_tl,raptor_targetl			
				move.l	r_th,raptor_targeth			
				lea		RAPTOR_GPU_COLLISION,a0				
				jsr 	RAPTOR_call_GPU_code
			
				movem.l	(a7)+,d1-d7/a0-a6
				move.l	raptor_result,d0				
				
                bra     LAB_AYFC        ; convert d0 to signed longword in FAC1 & return

r_sl:			dc.l	0
r_sh:			dc.l	0
r_tl:			dc.l	0
r_th:			dc.l	0

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; get ASCII string .EQUivalent into FAC1 as integer32 or float

; entry is with a5 pointing to the first character of the string
; exit with a5 pointing to the first character after the string

; d0 is character
; d1 is mantissa
; d2 is partial and table mantissa
; d3 is mantissa exponent (decimal & binary)
; d4 is decimal exponent

; get FAC1 from string
; this routine now handles hex and binary values from strings
; starting with "$" and "%" respectively

LAB_2887:
                movem.l D1-D5,-(SP)     ; save registers
                moveq   #$00,D1         ; clear temp accumulator
                move.l  D1,D3           ; set mantissa decimal exponent count
                move.l  D1,D4           ; clear decimal exponent
                move.b  D1,FAC1_s(A3)   ; clear sign byte
                move.b  D1,Dtypef(A3)   ; set float data type
                move.b  D1,expneg(A3)   ; clear exponent sign
                bsr     LAB_GBYT        ; get first byte back
                bcs.s   LAB_28FE        ; go get floating if 1st character numeric

                cmp.b   #'-',D0         ; or is it -ve number
                bne.s   LAB_289A        ; branch if not

                move.b  #$FF,FAC1_s(A3) ; set sign byte
                bra.s   LAB_289C        ; now go scan & check for hex/bin/int

LAB_289A:
; first character wasn't numeric or -
                cmp.b   #'+',D0         ; compare with '+'
                bne.s   LAB_289D        ; branch if not '+' (go check for '.'/hex/binary
; /integer)

LAB_289C:
; was "+" or "-" to start, so get next character
                bsr     LAB_IGBY        ; increment & scan memory
                bcs.s   LAB_28FE        ; branch if numeric character

LAB_289D:
                cmp.b   #'.',D0         ; else compare with '.'
                beq     LAB_2904        ; branch if '.'

; code here for hex/binary/integer numbers
                cmp.b   #'$',D0         ; compare with '$'
                beq     LAB_CHEX        ; branch if '$'

                cmp.b   #'%',D0         ; else compare with '%'
                beq     LAB_CBIN        ; branch if '%'

                bra     LAB_2Y01        ; not #.$%& so return 0

LAB_28FD:
                bsr     LAB_IGBY        ; get next character
                bcc.s   LAB_2902        ; exit loop if not a digit

LAB_28FE:
                bsr     d1x10           ; multiply d1 by 10 and add character
                bcc.s   LAB_28FD        ; loop for more if no overflow

LAB_28FF:
; overflowed mantissa, count 10s exponent
                addq.l  #1,D3           ; increment mantissa decimal exponent count
                bsr     LAB_IGBY        ; get next character
                bcs.s   LAB_28FF        ; loop while numeric character

; done overflow, now flush fraction or do E
                cmp.b   #'.',D0         ; else compare with '.'
                bne.s   LAB_2901        ; branch if not '.'

LAB_2900:
; flush remaining fraction digits
                bsr     LAB_IGBY        ; get next character
                bcs     LAB_2900        ; loop while numeric character

LAB_2901:
; done number, only (possible) exponent remains
                cmp.b   #'E',D0         ; else compare with 'E'
                bne.s   LAB_2Y01        ; if not 'E' all done, go evaluate

; process exponent
                bsr     LAB_IGBY        ; get next character
                bcs.s   LAB_2X04        ; branch if digit

                cmp.b   #'-',D0         ; or is it -ve number
                beq.s   LAB_2X01        ; branch if so

                cmp.b   #TK_MINUS,D0    ; or is it -ve number
                bne.s   LAB_2X02        ; branch if not

LAB_2X01:
                move.b  #$FF,expneg(A3) ; set exponent sign
                bra.s   LAB_2X03        ; now go scan & check exponent

LAB_2X02:
                cmp.b   #'+',D0         ; or is it +ve number
                beq.s   LAB_2X03        ; branch if so

                cmp.b   #TK_PLUS,D0     ; or is it +ve number
                bne     LAB_SNER        ; wasn't - + TK_MINUS TK_PLUS or # so do error

LAB_2X03:
                bsr     LAB_IGBY        ; get next character
                bcc.s   LAB_2Y01        ; if not digit all done, go evaluate
LAB_2X04:
                mulu    #10,D4          ; multiply decimal exponent by 10
                and.l   #$FF,D0         ; mask character
                sub.b   #'0',D0         ; convert to value
                add.l   D0,D4           ; add to decimal exponent
                cmp.b   #48,D4          ; compare with decimal exponent limit+10
                ble.s   LAB_2X03        ; loop if no overflow/underflow

LAB_2X05:
; exponent value has overflowed
                bsr     LAB_IGBY        ; get next character
                bcs.s   LAB_2X05        ; loop while numeric digit

                bra.s   LAB_2Y01        ; all done, go evaluate

LAB_2902:
                cmp.b   #'.',D0         ; else compare with '.'
                beq.s   LAB_2904        ; branch if was '.'

                bra.s   LAB_2901        ; branch if not '.' (go check/do 'E')

LAB_2903:
                subq.l  #1,D3           ; decrement mantissa decimal exponent
LAB_2904:
; was dp so get fraction part
                bsr     LAB_IGBY        ; get next character
                bcc.s   LAB_2901        ; exit loop if not a digit (go check/do 'E')

                bsr     d1x10           ; multiply d1 by 10 and add character
                bcc.s   LAB_2903        ; loop for more if no overflow

                bra.s   LAB_2900        ; else go flush remaining fraction part

LAB_2Y01:
; now evaluate result
                tst.b   expneg(A3)      ; test exponent sign
                bpl.s   LAB_2Y02        ; branch if sign positive

                neg.l   D4              ; negate decimal exponent
LAB_2Y02:
                add.l   D3,D4           ; add mantissa decimal exponent
                moveq   #32,D3          ; set up max binary exponent
                tst.l   D1              ; test mantissa
                beq.s   LAB_rtn0        ; if mantissa=0 return 0

                bmi.s   LAB_2Y04        ; branch if already mormalised

                subq.l  #1,D3           ; decrement bianry exponent for DBMI loop
LAB_2Y03:
                add.l   D1,D1           ; shift mantissa
                dbmi    D3,LAB_2Y03     ; decrement & loop if not normalised

; ensure not too big or small
LAB_2Y04:
                cmp.l   #38,D4          ; compare decimal exponent with max exponent
                bgt     LAB_OFER        ; if greater do overflow error and warm start

                cmp.l   #-38,D4         ; compare decimal exponent with min exponent
                blt.s   LAB_ret0        ; if less just return zero

                neg.l   D4              ; negate decimal exponent to go right way
                muls    #6,D4           ; 6 bytes per entry
                move.l  A0,-(SP)        ; save register
                lea     LAB_P_10(PC),A0 ; point to table
                move.b  0(A0,D4.w),FAC2_e(A3) ; copy exponent for multiply
                move.l  2(A0,D4.w),FAC2_m(A3) ; copy table mantissa
                movea.l (SP)+,A0        ; restore register

                eori.b  #$80,D3         ; normalise input exponent
                move.l  D1,FAC1_m(A3)   ; save input mantissa
                move.b  D3,FAC1_e(A3)   ; save input exponent
                move.b  FAC1_s(A3),FAC_sc(A3) ; set sign as sign compare

                movem.l (SP)+,D1-D5     ; restore registers
                bra     LAB_MULTIPLY    ; go multiply input by table

LAB_ret0:
                moveq   #0,D1           ; clear mantissa
LAB_rtn0:
                move.l  D1,D3           ; clear exponent
                move.b  D3,FAC1_e(A3)   ; save exponent
                move.l  D1,FAC1_m(A3)   ; save mantissa
                movem.l (SP)+,D1-D5     ; restore registers
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; $ for hex add-on

; gets here if the first character was "$" for hex
; get hex number

LAB_CHEX:
                move.b  #$40,Dtypef(A3) ; set integer numeric data type
                moveq   #32,D3          ; set up max binary exponent
LAB_CHXX:
                bsr     LAB_IGBY        ; increment & scan memory
                bcs.s   LAB_ISHN        ; branch if numeric character

                or.b    #$20,D0         ; case convert, allow "A" to "F" and "a" to "f"
                sub.b   #'a',D0         ; subtract "a"
                bcs.s   LAB_CHX3        ; exit if <"a"

                cmp.b   #$06,D0         ; compare normalised with $06 (max+1)
                bcc.s   LAB_CHX3        ; exit if >"f"

                add.b   #$3A,D0         ; convert to nibble+"0"
LAB_ISHN:
                bsr.s   d1x16           ; multiply d1 by 16 and add the character
                bcc.s   LAB_CHXX        ; loop for more if no overflow

; overflowed mantissa, count 16s exponent
LAB_CHX1:
                addq.l  #4,D3           ; increment mantissa exponent count
                bvs     LAB_OFER        ; do overflow error if overflowed

                bsr     LAB_IGBY        ; get next character
                bcs.s   LAB_CHX1        ; loop while numeric character

                or.b    #$20,D0         ; case convert, allow "A" to "F" and "a" to "f"
                sub.b   #'a',D0         ; subtract "a"
                bcs.s   LAB_CHX3        ; exit if <"a"

                cmp.b   #$06,D0         ; compare normalised with $06 (max+1)
                bcs.s   LAB_CHX1        ; loop if <="f"

; now return value
LAB_CHX3:
                tst.l   D1              ; test mantissa
                beq.s   LAB_rtn0        ; if mantissa=0 return 0

                bmi.s   LAB_exxf        ; branch if already mormalised

                subq.l  #1,D3           ; decrement bianry exponent for DBMI loop
LAB_CHX2:
                add.l   D1,D1           ; shift mantissa
                dbmi    D3,LAB_CHX2     ; decrement & loop if not normalised

LAB_exxf:
                eori.b  #$80,D3         ; normalise exponent
                move.b  D3,FAC1_e(A3)   ; save exponent
                move.l  D1,FAC1_m(A3)   ; save mantissa
                movem.l (SP)+,D1-D5     ; restore registers
RTS_024:
                rts


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; % for binary add-on

; gets here if the first character was "%" for binary
; get binary number

LAB_CBIN:
                move.b  #$40,Dtypef(A3) ; set integer numeric data type
                moveq   #32,D3          ; set up max binary exponent
LAB_CBXN:
                bsr     LAB_IGBY        ; increment & scan memory
                bcc.s   LAB_CHX3        ; if not numeric character go return value

                cmp.b   #'2',D0         ; compare with "2" (max+1)
                bcc.s   LAB_CHX3        ; if >="2" go return value

                move.l  D1,D2           ; copy value
                bsr.s   d1x02           ; multiply d1 by 2 and add character
                bcc.s   LAB_CBXN        ; loop for more if no overflow

; overflowed mantissa, count 2s exponent
LAB_CBX1:
                addq.l  #1,D3           ; increment mantissa exponent count
                bvs     LAB_OFER        ; do overflow error if overflowed

                bsr     LAB_IGBY        ; get next character
                bcc.s   LAB_CHX3        ; if not numeric character go return value

                cmp.b   #'2',D0         ; compare with "2" (max+1)
                bcs.s   LAB_CBX1        ; loop if <"2"

                bra.s   LAB_CHX3        ; if not numeric character go return value

; half way decent times 16 and times 2 with overflow checks

d1x16:
                move.l  D1,D2           ; copy value
                add.l   D2,D2           ; times two
                bcs.s   RTS_024         ; return if overflow

                add.l   D2,D2           ; times four
                bcs.s   RTS_024         ; return if overflow

                add.l   D2,D2           ; times eight
                bcs.s   RTS_024         ; return if overflow

d1x02:
                add.l   D2,D2           ; times sixteen (ten/two)
                bcs.s   RTS_024         ; return if overflow

; now add in new digit

                and.l   #$FF,D0         ; mask character
                sub.b   #'0',D0         ; convert to value
                add.l   D0,D2           ; add to result
                bcs.s   RTS_024         ; return if overflow, it should never ever do
; this

                move.l  D2,D1           ; copy result
                rts

; half way decent times 10 with overflow checks

d1x10:
                move.l  D1,D2           ; copy value
                add.l   D2,D2           ; times two
                bcs.s   RTS_025         ; return if overflow

                add.l   D2,D2           ; times four
                bcs.s   RTS_025         ; return if overflow

                add.l   D1,D2           ; times five
                bcc.s   d1x02           ; do times two and add in new digit if ok

RTS_025:
                rts

RBASIC_START:
				lea		basic_ram,a0
				move.l	#128000,d0
				jmp		LAB_COLD
				

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; token values needed for BASIC

TK_END          .EQU $80         ; $80
TK_FOR          .EQU TK_END+1    ; $81
TK_NEXT         .EQU TK_FOR+1    ; $82
TK_DATA         .EQU TK_NEXT+1   ; $83
TK_INPUT        .EQU TK_DATA+1   ; $84
TK_DIM          .EQU TK_INPUT+1  ; $85
TK_READ         .EQU TK_DIM+1    ; $86
TK_LET          .EQU TK_READ+1   ; $87
TK_DEC          .EQU TK_LET+1    ; $88
TK_GOTO         .EQU TK_DEC+1    ; $89
TK_RUN          .EQU TK_GOTO+1   ; $8A
TK_IF           .EQU TK_RUN+1    ; $8B
TK_RESTORE      .EQU TK_IF+1     ; $8C
TK_GOSUB        .EQU TK_RESTORE+1 ; $8D
TK_RETURN       .EQU TK_GOSUB+1  ; $8E
TK_REM          .EQU TK_RETURN+1 ; $8F
TK_STOP         .EQU TK_REM+1    ; $90
TK_ON           .EQU TK_STOP+1   ; $91
TK_NULL         .EQU TK_ON+1     ; $92
TK_INC          .EQU TK_NULL+1   ; $93
TK_WAIT         .EQU TK_INC+1    ; $94
TK_LOAD         .EQU TK_WAIT+1   ; $95
TK_SAVE         .EQU TK_LOAD+1   ; $96
TK_DEF          .EQU TK_SAVE+1   ; $97
TK_POKE         .EQU TK_DEF+1    ; $98
TK_DOKE         .EQU TK_POKE+1   ; $99
TK_LOKE         .EQU TK_DOKE+1   ; $9A
TK_CALL         .EQU TK_LOKE+1   ; $9B
TK_DO           .EQU TK_CALL+1   ; $9C
TK_LOOP         .EQU TK_DO+1     ; $9D
TK_PRINT        .EQU TK_LOOP+1   ; $9E
TK_CONT         .EQU TK_PRINT+1  ; $9F
TK_LIST         .EQU TK_CONT+1   ; $A0
TK_CLEAR        .EQU TK_LIST+1   ; $A1
TK_NEW          .EQU TK_CLEAR+1  ; $A2
TK_WIDTH        .EQU TK_NEW+1    ; $A3
TK_GET          .EQU TK_WIDTH+1  ; $A4
TK_SWAP         .EQU TK_GET+1    ; $A5
TK_BITSET       .EQU TK_SWAP+1   ; $A6
TK_BITCLR       .EQU TK_BITSET+1 ; $A7

TK_RPRINT		.EQU TK_BITCLR+1
TK_RSETOBJ		.EQU TK_RPRINT+1
TK_RUPDALL		.EQU TK_RSETOBJ+1
TK_RSETLIST		.EQU TK_RUPDALL+1
TK_U235MOD		.EQU TK_RSETLIST+1
TK_U235SND		.EQU TK_U235MOD+1
TK_CLS			.EQU TK_U235SND+1
TK_SETCUR		.EQU TK_CLS+1
TK_PLOT			.EQU TK_SETCUR+1
TK_COLOUR		.EQU TK_PLOT+1
TK_RPARTI		.EQU TK_COLOUR+1
TK_RSETMAP		.EQU TK_RPARTI+1

TK_TAB          .EQU TK_RSETMAP+1	

TK_ELSE         .EQU TK_TAB+1    ; $A9
TK_TO           .EQU TK_ELSE+1   ; $AA
TK_FN           .EQU TK_TO+1     ; $AB
TK_SPC          .EQU TK_FN+1     ; $AC
TK_THEN         .EQU TK_SPC+1    ; $AD
TK_NOT          .EQU TK_THEN+1   ; $AE
TK_STEP         .EQU TK_NOT+1    ; $AF
TK_UNTIL        .EQU TK_STEP+1   ; $B0
TK_WHILE        .EQU TK_UNTIL+1  ; $B1
TK_PLUS         .EQU TK_WHILE+1  ; $B2
TK_MINUS        .EQU TK_PLUS+1   ; $B3
TK_MULT         .EQU TK_MINUS+1  ; $B4
TK_DIV          .EQU TK_MULT+1   ; $B5
TK_POWER        .EQU TK_DIV+1    ; $B6
TK_AND          .EQU TK_POWER+1  ; $B7
TK_EOR          .EQU TK_AND+1    ; $B8
TK_OR           .EQU TK_EOR+1    ; $B9
TK_RSHIFT       .EQU TK_OR+1     ; $BA
TK_LSHIFT       .EQU TK_RSHIFT+1 ; $BB
TK_GT           .EQU TK_LSHIFT+1 ; $BC
TK_EQUAL        .EQU TK_GT+1     ; $BD
TK_LT           .EQU TK_EQUAL+1  ; $BE
TK_SGN          .EQU TK_LT+1     ; $BF
TK_INT          .EQU TK_SGN+1    ; $C0
TK_ABS          .EQU TK_INT+1    ; $C1
TK_USR          .EQU TK_ABS+1    ; $C2
TK_FRE          .EQU TK_USR+1    ; $C3
TK_POS          .EQU TK_FRE+1    ; $C4
TK_SQR          .EQU TK_POS+1    ; $C5
TK_RND          .EQU TK_SQR+1    ; $C6
TK_LOG          .EQU TK_RND+1    ; $C7
TK_EXP          .EQU TK_LOG+1    ; $C8
TK_COS          .EQU TK_EXP+1    ; $C9
TK_SIN          .EQU TK_COS+1    ; $CA
TK_TAN          .EQU TK_SIN+1    ; $CB
TK_ATN          .EQU TK_TAN+1    ; $CC
TK_PEEK         .EQU TK_ATN+1    ; $CD
TK_DEEK         .EQU TK_PEEK+1   ; $CE
TK_LEEK         .EQU TK_DEEK+1   ; $CF
TK_LEN          .EQU TK_LEEK+1   ; $D0
TK_STRS         .EQU TK_LEN+1    ; $D1
TK_VAL          .EQU TK_STRS+1   ; $D2
TK_ASC          .EQU TK_VAL+1    ; $D3
TK_UCASES       .EQU TK_ASC+1    ; $D4
TK_LCASES       .EQU TK_UCASES+1 ; $D5
TK_CHRS         .EQU TK_LCASES+1 ; $D6
TK_HEXS         .EQU TK_CHRS+1   ; $D7
TK_BINS         .EQU TK_HEXS+1   ; $D8
TK_BITTST       .EQU TK_BINS+1   ; $D9
TK_MAX          .EQU TK_BITTST+1 ; $DA
TK_MIN          .EQU TK_MAX+1    ; $DB
TK_RAM          .EQU TK_MIN+1    ; $DC
TK_PI           .EQU TK_RAM+1    ; $DD
TK_TWOPI        .EQU TK_PI+1     ; $DE
TK_VPTR         .EQU TK_TWOPI+1  ; $DF
TK_SADD         .EQU TK_VPTR+1   ; $E0
TK_LEFTS        .EQU TK_SADD+1   ; $E1
TK_RIGHTS       .EQU TK_LEFTS+1  ; $E2
TK_MIDS         .EQU TK_RIGHTS+1 ; $E3
TK_USINGS       .EQU TK_MIDS+1   ; $E4
TK_U235PAD		.EQU TK_USINGS+1
TK_RGETOBJ		.EQU TK_U235PAD+1
TK_RHIT			.EQU TK_RGETOBJ+1
TK_LOCATE		.EQU TK_RHIT+1

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; binary to unsigned decimal table

Bin2dec:
                DC.L $3B9ACA00  ; 1000000000
                DC.L $05F5E100  ; 100000000
                DC.L $989680    ; 10000000
                DC.L $0F4240    ; 1000000
                DC.L $0186A0    ; 100000
                DC.L $2710      ; 10000
                DC.L $03E8      ; 1000
                DC.L $64        ; 100
                DC.L $0A        ; 10
                DC.L $00        ; 0 end marker

LAB_RSED:
                DC.L $332E3232  ; 858665522

; string to value exponent table

                DC.W 255<<8     ; 10; 38
                DC.L $96769951
                DC.W 251<<8     ; 10; 37
                DC.L $F0BDC21B
                DC.W 248<<8     ; 10; 36
                DC.L $C097CE7C
                DC.W 245<<8     ; 10; 35
                DC.L $9A130B96
                DC.W 241<<8     ; 10; 34
                DC.L $F684DF57
                DC.W 238<<8     ; 10; 33
                DC.L $C5371912
                DC.W 235<<8     ; 10; 32
                DC.L $9DC5ADA8
                DC.W 231<<8     ; 10; 31
                DC.L $FC6F7C40
                DC.W 228<<8     ; 10; 30
                DC.L $C9F2C9CD
                DC.W 225<<8     ; 10; 29
                DC.L $A18F07D7
                DC.W 222<<8     ; 10; 28
                DC.L $813F3979
                DC.W 218<<8     ; 10; 27
                DC.L $CECB8F28
                DC.W 215<<8     ; 10; 26
                DC.L $A56FA5BA
                DC.W 212<<8     ; 10; 25
                DC.L $84595161
                DC.W 208<<8     ; 10; 24
                DC.L $D3C21BCF
                DC.W 205<<8     ; 10; 23
                DC.L $A968163F
                DC.W 202<<8     ; 10; 22
                DC.L $87867832
                DC.W 198<<8     ; 10; 21
                DC.L $D8D726B7
                DC.W 195<<8     ; 10; 20
                DC.L $AD78EBC6
                DC.W 192<<8     ; 10; 19
                DC.L $8AC72305
                DC.W 188<<8     ; 10; 18
                DC.L $DE0B6B3A
                DC.W 185<<8     ; 10; 17
                DC.L $B1A2BC2F
                DC.W 182<<8     ; 10; 16
                DC.L $8E1BC9BF
                DC.W 178<<8     ; 10; 15
                DC.L $E35FA932
                DC.W 175<<8     ; 10; 14
                DC.L $B5E620F5
                DC.W 172<<8     ; 10; 13
                DC.L $9184E72A
                DC.W 168<<8     ; 10; 12
                DC.L $E8D4A510
                DC.W 165<<8     ; 10; 11
                DC.L $BA43B740
                DC.W 162<<8     ; 10; 10
                DC.L $9502F900
                DC.W 158<<8     ; 10; 9
                DC.L $EE6B2800
                DC.W 155<<8     ; 10; 8
                DC.L $BEBC2000
                DC.W 152<<8     ; 10; 7
                DC.L $98968000
                DC.W 148<<8     ; 10; 6
                DC.L $F4240000
                DC.W 145<<8     ; 10; 5
                DC.L $C3500000
                DC.W 142<<8     ; 10; 4
                DC.L $9C400000
                DC.W 138<<8     ; 10; 3
                DC.L $FA000000
                DC.W 135<<8     ; 10; 2
                DC.L $C8000000
                DC.W 132<<8     ; 10; 1
                DC.L $A0000000
LAB_P_10:
                DC.W 129<<8     ; 10; 0
                DC.L $80000000
                DC.W 125<<8     ; 10; -1
                DC.L $CCCCCCCD
                DC.W 122<<8     ; 10; -2
                DC.L $A3D70A3D
                DC.W 119<<8     ; 10; -3
                DC.L $83126E98
                DC.W 115<<8     ; 10; -4
                DC.L $D1B71759
                DC.W 112<<8     ; 10; -5
                DC.L $A7C5AC47
                DC.W 109<<8     ; 10; -6
                DC.L $8637BD06
                DC.W 105<<8     ; 10; -7
                DC.L $D6BF94D6
                DC.W 102<<8     ; 10; -8
                DC.L $ABCC7712
                DC.W 99<<8      ; 10; -9
                DC.L $89705F41
                DC.W 95<<8      ; 10; -10
                DC.L $DBE6FECF
                DC.W 92<<8      ; 10; -11
                DC.L $AFEBFF0C
                DC.W 89<<8      ; 10; -12
                DC.L $8CBCCC09
                DC.W 85<<8      ; 10; -13
                DC.L $E12E1342
                DC.W 82<<8      ; 10; -14
                DC.L $B424DC35
                DC.W 79<<8      ; 10; -15
                DC.L $901D7CF7
                DC.W 75<<8      ; 10; -16
                DC.L $E69594BF
                DC.W 72<<8      ; 10; -17
                DC.L $B877AA32
                DC.W 69<<8      ; 10; -18
                DC.L $9392EE8F
                DC.W 65<<8      ; 10; -19
                DC.L $EC1E4A7E
                DC.W 62<<8      ; 10; -20
                DC.L $BCE50865
                DC.W 59<<8      ; 10; -21
                DC.L $971DA050
                DC.W 55<<8      ; 10; -22
                DC.L $F1C90081
                DC.W 52<<8      ; 10; -23
                DC.L $C16D9A01
                DC.W 49<<8      ; 10; -24
                DC.L $9ABE14CD
                DC.W 45<<8      ; 10; -25
                DC.L $F79687AE
                DC.W 42<<8      ; 10; -26
                DC.L $C6120625
                DC.W 39<<8      ; 10; -27
                DC.L $9E74D1B8
                DC.W 35<<8      ; 10; -28
                DC.L $FD87B5F3
                DC.W 32<<8      ; 10; -29
                DC.L $CAD2F7F5
                DC.W 29<<8      ; 10; -30
                DC.L $A2425FF7
                DC.W 26<<8      ; 10; -31
                DC.L $81CEB32C
                DC.W 22<<8      ; 10; -32
                DC.L $CFB11EAD
                DC.W 19<<8      ; 10; -33
                DC.L $A6274BBE
                DC.W 16<<8      ; 10; -34
                DC.L $84EC3C98
                DC.W 12<<8      ; 10; -35
                DC.L $D4AD2DC0
                DC.W 9<<8       ; 10; -36
                DC.L $AA242499
                DC.W 6<<8       ; 10; -37
                DC.L $881CEA14
                DC.W 2<<8       ; 10; -38
                DC.L $D9C7DCED


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; table of constants for cordic SIN/COS/TAN calculations
; constants are un normalised fractions and are atn(2^-i)/2pi

                DC.L $4DBA76D4  ; SIN/COS multiply constant
TAB_SNCO:
                DC.L $20000000  ; atn(2^0)/2pi
                DC.L $12E4051E  ; atn(2^1)/2pi
                DC.L $09FB385C  ; atn(2^2)/2pi
                DC.L $051111D5  ; atn(2^3)/2pi
                DC.L $028B0D44  ; atn(2^4)/2pi
                DC.L $0145D7E2  ; atn(2^5)/2pi
                DC.L $A2F61F    ; atn(2^6)/2pi
                DC.L $517C56    ; atn(2^7)/2pi
                DC.L $28BE54    ; atn(2^8)/2pi
                DC.L $145F2F    ; atn(2^9)/2pi
                DC.L $0A2F99    ; atn(2^10)/2pi
                DC.L $0517CD    ; atn(2^11)/2pi
                DC.L $028BE7    ; atn(2^12)/2pi
                DC.L $0145F4    ; atn(2^13)/2pi
                DC.L $A2FA      ; atn(2^14)/2pi
                DC.L $517D      ; atn(2^15)/2pi
                DC.L $28BF      ; atn(2^16)/2pi
                DC.L $1460      ; atn(2^17)/2pi
                DC.L $0A30      ; atn(2^18)/2pi
                DC.L $0518      ; atn(2^19)/2pi
                DC.L $028C      ; atn(2^20)/2pi
                DC.L $0146      ; atn(2^21)/2pi
                DC.L $A3        ; atn(2^22)/2pi
                DC.L $52        ; atn(2^23)/2pi
                DC.L $29        ; atn(2^24)/2pi
                DC.L $15        ; atn(2^25)/2pi
                DC.L $0B        ; atn(2^26)/2pi
                DC.L $06        ; atn(2^27)/2pi
                DC.L $03        ; atn(2^28)/2pi
                DC.L $02        ; atn(2^29)/2pi
                DC.L $01        ; atn(2^30)/2pi
                DC.L $01        ; atn(2^31)/2pi


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; table of constants for cordic ATN calculation
; constants are normalised to two integer bits and are atn(2^-i)

TAB_ATNC:
                DC.L $1DAC6705  ; atn(2^-1)
                DC.L $0FADBAFD  ; atn(2^-2)
                DC.L $07F56EA7  ; atn(2^-3)
                DC.L $03FEAB77  ; atn(2^-4)
                DC.L $01FFD55C  ; atn(2^-5)
                DC.L $FFFAAB    ; atn(2^-6)
                DC.L $7FFF55    ; atn(2^-7)
                DC.L $3FFFEB    ; atn(2^-8)
                DC.L $1FFFFD    ; atn(2^-9)
                DC.L $100000    ; atn(2^-10)
                DC.L $080000    ; atn(2^-11)
                DC.L $040000    ; atn(2^-12)
                DC.L $020000    ; atn(2^-13)
                DC.L $010000    ; atn(2^-14)
                DC.L $8000      ; atn(2^-15)
                DC.L $4000      ; atn(2^-16)
                DC.L $2000      ; atn(2^-17)
                DC.L $1000      ; atn(2^-18)
                DC.L $0800      ; atn(2^-19)
                DC.L $0400      ; atn(2^-20)
                DC.L $0200      ; atn(2^-21)
                DC.L $0100      ; atn(2^-22)
                DC.L $80        ; atn(2^-23)
                DC.L $40        ; atn(2^-24)
                DC.L $20        ; atn(2^-25)
                DC.L $10        ; atn(2^-26)
                DC.L $08        ; atn(2^-27)
                DC.L $04        ; atn(2^-28)
                DC.L $02        ; atn(2^-29)
                DC.L $01        ; atn(2^-30)
LAB_1D96:
                DC.L $00        ; atn(2^-31)
                DC.L $00        ; atn(2^-32)

; constants are normalised to n integer bits and are tanh(2^-i)
n               .EQU 2
TAB_HTHET:
                DC.L $8C9F53D0>>n ; atnh(2^-1)    .549306144
                DC.L $4162BBE8>>n ; atnh(2^-2)    .255412812
                DC.L $202B1238>>n ; atnh(2^-3)
                DC.L $10055888>>n ; atnh(2^-4)
                DC.L $0800AAC0>>n ; atnh(2^-5)
                DC.L $04001550>>n ; atnh(2^-6)
                DC.L $020002A8>>n ; atnh(2^-7)
                DC.L $01000050>>n ; atnh(2^-8)
                DC.L $800008>>n ; atnh(2^-9)
                DC.L $400000>>n ; atnh(2^-10)
                DC.L $200000>>n ; atnh(2^-11)
                DC.L $100000>>n ; atnh(2^-12)
                DC.L $080000>>n ; atnh(2^-13)
                DC.L $040000>>n ; atnh(2^-14)
                DC.L $020000>>n ; atnh(2^-15)
                DC.L $010000>>n ; atnh(2^-16)
                DC.L $8000>>n   ; atnh(2^-17)
                DC.L $4000>>n   ; atnh(2^-18)
                DC.L $2000>>n   ; atnh(2^-19)
                DC.L $1000>>n   ; atnh(2^-20)
                DC.L $0800>>n   ; atnh(2^-21)
                DC.L $0400>>n   ; atnh(2^-22)
                DC.L $0200>>n   ; atnh(2^-23)
                DC.L $0100>>n   ; atnh(2^-24)
                DC.L $80>>n     ; atnh(2^-25)
                DC.L $40>>n     ; atnh(2^-26)
                DC.L $20>>n     ; atnh(2^-27)
                DC.L $10>>n     ; atnh(2^-28)
                DC.L $08>>n     ; atnh(2^-29)
                DC.L $04>>n     ; atnh(2^-30)
                DC.L $02>>n     ; atnh(2^-31)
                DC.L $01>>n     ; atnh(2^-32)

KFCTSEED        .EQU $9A8F4441>>n ; $26A3D110
				
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; function pre process routine table

LAB_FTPP:
                DC.W LAB_PPFN-LAB_FTPP ; SGN(n)        process numeric expression in ()
                DC.W LAB_PPFN-LAB_FTPP ; INT(n)                "
                DC.W LAB_PPFN-LAB_FTPP ; ABS(n)                "
                DC.W LAB_EVEZ-LAB_FTPP ; USR(x)        process any expression
                DC.W LAB_1BF7-LAB_FTPP ; FRE(x)        process any expression in ()
                DC.W LAB_1BF7-LAB_FTPP ; POS(x)                "
                DC.W LAB_PPFN-LAB_FTPP ; SQR(n)        process numeric expression in ()
                DC.W LAB_PPFN-LAB_FTPP ; RND(n)                "
                DC.W LAB_PPFN-LAB_FTPP ; LOG(n)                "
                DC.W LAB_PPFN-LAB_FTPP ; EXP(n)                "
                DC.W LAB_PPFN-LAB_FTPP ; COS(n)                "
                DC.W LAB_PPFN-LAB_FTPP ; SIN(n)                "
                DC.W LAB_PPFN-LAB_FTPP ; TAN(n)                "
                DC.W LAB_PPFN-LAB_FTPP ; ATN(n)                "
                DC.W LAB_PPFN-LAB_FTPP ; PEEK(n)               "
                DC.W LAB_PPFN-LAB_FTPP ; DEEK(n)               "
                DC.W LAB_PPFN-LAB_FTPP ; LEEK(n)               "
                DC.W LAB_PPFS-LAB_FTPP ; LEN($)        process string expression in ()
                DC.W LAB_PPFN-LAB_FTPP ; STR$(n)       process numeric expression in ()
                DC.W LAB_PPFS-LAB_FTPP ; VAL($)        process string expression in ()
                DC.W LAB_PPFS-LAB_FTPP ; ASC($)                "
                DC.W LAB_PPFS-LAB_FTPP ; UCASE$($)             "
                DC.W LAB_PPFS-LAB_FTPP ; LCASE$($)             "
                DC.W LAB_PPFN-LAB_FTPP ; CHR$(n)       process numeric expression in ()
                DC.W LAB_BHSS-LAB_FTPP ; HEX$()        bin/hex pre process
                DC.W LAB_BHSS-LAB_FTPP ; BIN$()                "
                DC.W $00        ; BITTST()      none
                DC.W $00        ; MAX()         "
                DC.W $00        ; MIN()         "
                DC.W LAB_PPBI-LAB_FTPP ; RAMBASE       advance pointer
                DC.W LAB_PPBI-LAB_FTPP ; PI                    "
                DC.W LAB_PPBI-LAB_FTPP ; TWOPI         "
                DC.W $00        ; VARPTR()      none
                DC.W $00        ; SADD()                "
                DC.W LAB_LRMS-LAB_FTPP ; LEFT$()       process string expression
                DC.W LAB_LRMS-LAB_FTPP ; RIGHT$()              "
                DC.W LAB_LRMS-LAB_FTPP ; MID$()                "
                DC.W LAB_EVEZ-LAB_FTPP ; USING$(x)     process any expression
				dc.w LAB_PPBI-LAB_FTPP		; U235PAD		NONE
				dc.w LAB_PPBI-LAB_FTPP		; RGETOBJ		NONE
				dc.w LAB_PPBI-LAB_FTPP		; RHIT			NONE
				dc.w LAB_PPBI-LAB_FTPP		; LOCATE		NONE
			
; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; action addresses for functions

LAB_FTBL:
                DC.W LAB_SGN-LAB_FTBL ; SGN()
                DC.W LAB_INT-LAB_FTBL ; INT()
                DC.W LAB_ABS-LAB_FTBL ; ABS()
                DC.W LAB_USR-LAB_FTBL ; USR()
                DC.W LAB_FRE-LAB_FTBL ; FRE()
                DC.W LAB_POS-LAB_FTBL ; POS()
                DC.W LAB_SQR-LAB_FTBL ; SQR()
                DC.W LAB_RND-LAB_FTBL ; RND()
                DC.W LAB_LOG-LAB_FTBL ; LOG()
                DC.W LAB_EXP-LAB_FTBL ; EXP()
                DC.W LAB_COS-LAB_FTBL ; COS()
                DC.W LAB_SIN-LAB_FTBL ; SIN()
                DC.W LAB_TAN-LAB_FTBL ; TAN()
                DC.W LAB_ATN-LAB_FTBL ; ATN()
                DC.W LAB_PEEK-LAB_FTBL ; PEEK()
                DC.W LAB_DEEK-LAB_FTBL ; DEEK()
                DC.W LAB_LEEK-LAB_FTBL ; LEEK()
                DC.W LAB_LENS-LAB_FTBL ; LEN()
                DC.W LAB_STRS-LAB_FTBL ; STR$()
                DC.W LAB_VAL-LAB_FTBL ; VAL()
                DC.W LAB_ASC-LAB_FTBL ; ASC()
                DC.W LAB_UCASE-LAB_FTBL ; UCASE$()
                DC.W LAB_LCASE-LAB_FTBL ; LCASE$()
                DC.W LAB_CHRS-LAB_FTBL ; CHR$()
                DC.W LAB_HEXS-LAB_FTBL ; HEX$()
                DC.W LAB_BINS-LAB_FTBL ; BIN$()
                DC.W LAB_BTST-LAB_FTBL ; BITTST()
                DC.W LAB_MAX-LAB_FTBL ; MAX()
                DC.W LAB_MIN-LAB_FTBL ; MIN()
                DC.W LAB_RAM-LAB_FTBL ; RAMBASE
                DC.W LAB_PI-LAB_FTBL ; PI
                DC.W LAB_TWOPI-LAB_FTBL ; TWOPI
                DC.W LAB_VARPTR-LAB_FTBL ; VARPTR()
                DC.W LAB_SADD-LAB_FTBL ; SADD()
                DC.W LAB_LEFT-LAB_FTBL ; LEFT$()
                DC.W LAB_RIGHT-LAB_FTBL ; RIGHT$()
                DC.W LAB_MIDS-LAB_FTBL ; MID$()
                DC.W LAB_USINGS-LAB_FTBL ; USING$()
				DC.W LAB_U235PAD-LAB_FTBL ; U235PAD()
				dc.w LAB_RGETOBJ-LAB_FTBL  ; RGETOBJ()
				dc.w LAB_RHIT-LAB_FTBL ; RHIT()
				dc.w LAB_LOCATE-LAB_FTBL ; LOCATE()


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; hierarchy and action addresses for operator

LAB_OPPT:
                DC.W $79        ; +
                DC.W LAB_ADD-LAB_OPPT
                DC.W $79        ; -
                DC.W LAB_SUBTRACT-LAB_OPPT
                DC.W $7B        ; *
                DC.W LAB_MULTIPLY-LAB_OPPT
                DC.W $7B        ; /
                DC.W LAB_DIVIDE-LAB_OPPT
                DC.W $7F        ; ^
                DC.W LAB_POWER-LAB_OPPT
                DC.W $50        ; AND
                DC.W LAB_AND-LAB_OPPT
                DC.W $46        ; EOR
                DC.W LAB_EOR-LAB_OPPT
                DC.W $46        ; OR
                DC.W LAB_OR-LAB_OPPT
                DC.W $56        ; >>
                DC.W LAB_RSHIFT-LAB_OPPT
                DC.W $56        ; <<
                DC.W LAB_LSHIFT-LAB_OPPT
                DC.W $7D        ; >
                DC.W LAB_GTHAN-LAB_OPPT ; used to evaluate -n
                DC.W $5A        ; =
                DC.W LAB_EQUAL-LAB_OPPT ; used to evaluate NOT
                DC.W $64        ; <
                DC.W LAB_LTHAN-LAB_OPPT


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; misc constants

; This table is used in converting numbers to ASCII.
; first four entries for expansion to 9.25 digits

LAB_2A9A:
                DC.L $FFF0BDC0  ; -1000000
                DC.L $0186A0    ; 100000
                DC.L $FFFFD8F0  ; -10000
                DC.L $03E8      ; 1000
                DC.L $FFFFFF9C  ; -100
                DC.L $0A        ; 10
                DC.L $FFFFFFFF  ; -1
LAB_2A9B:


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; new keyword tables

; offsets to keyword tables

TAB_CHRT:
                DC.W TAB_STAR-TAB_STAR ; "*"   $2A
                DC.W TAB_PLUS-TAB_STAR ; "+"   $2B
                DC.W -1         ; "," $2C no keywords
                DC.W TAB_MNUS-TAB_STAR ; "-"   $2D
                DC.W -1         ; "." $2E no keywords
                DC.W TAB_SLAS-TAB_STAR ; "/"   $2F
                DC.W -1         ; "0" $30 no keywords
                DC.W -1         ; "1" $31 no keywords
                DC.W -1         ; "2" $32 no keywords
                DC.W -1         ; "3" $33 no keywords
                DC.W -1         ; "4" $34 no keywords
                DC.W -1         ; "5" $35 no keywords
                DC.W -1         ; "6" $36 no keywords
                DC.W -1         ; "7" $37 no keywords
                DC.W -1         ; "8" $38 no keywords
                DC.W -1         ; "9" $39 no keywords
                DC.W -1         ; ";" $3A no keywords
                DC.W -1         ; ":" $3B no keywords
                DC.W TAB_LESS-TAB_STAR ; "<"   $3C
                DC.W TAB_EQUL-TAB_STAR ; "="   $3D
                DC.W TAB_MORE-TAB_STAR ; ">"   $3E
                DC.W TAB_QEST-TAB_STAR ; "?"   $3F
                DC.W -1         ; "@" $40 no keywords
                DC.W TAB_ASCA-TAB_STAR ; "A"   $41
                DC.W TAB_ASCB-TAB_STAR ; "B"   $42
                DC.W TAB_ASCC-TAB_STAR ; "C"   $43
                DC.W TAB_ASCD-TAB_STAR ; "D"   $44
                DC.W TAB_ASCE-TAB_STAR ; "E"   $45
                DC.W TAB_ASCF-TAB_STAR ; "F"   $46
                DC.W TAB_ASCG-TAB_STAR ; "G"   $47
                DC.W TAB_ASCH-TAB_STAR ; "H"   $48
                DC.W TAB_ASCI-TAB_STAR ; "I"   $49
                DC.W -1         ; "J" $4A no keywords
                DC.W -1         ; "K" $4B no keywords
                DC.W TAB_ASCL-TAB_STAR ; "L"   $4C
                DC.W TAB_ASCM-TAB_STAR ; "M"   $4D
                DC.W TAB_ASCN-TAB_STAR ; "N"   $4E
                DC.W TAB_ASCO-TAB_STAR ; "O"   $4F
                DC.W TAB_ASCP-TAB_STAR ; "P"   $50
                DC.W -1         ; "Q" $51 no keywords
                DC.W TAB_ASCR-TAB_STAR ; "R"   $52
                DC.W TAB_ASCS-TAB_STAR ; "S"   $53
                DC.W TAB_ASCT-TAB_STAR ; "T"   $54
                DC.W TAB_ASCU-TAB_STAR ; "U"   $55
                DC.W TAB_ASCV-TAB_STAR ; "V"   $56
                DC.W TAB_ASCW-TAB_STAR ; "W"   $57
                DC.W -1         ; "X" $58 no keywords
                DC.W -1         ; "Y" $59 no keywords
                DC.W -1         ; "Z" $5A no keywords
                DC.W -1         ; "[" $5B no keywords
                DC.W -1         ; "\" $5C no keywords
                DC.W -1         ; "]" $5D no keywords
                DC.W TAB_POWR-TAB_STAR ; "^"   $5E

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; Table of Basic keywords for LIST command
; [byte]first character,[byte]remaining length -1
; [word]offset from table start

LAB_KEYT:
                DC.B 'E',1
                DC.W KEY_END-TAB_STAR ; END
                DC.B 'F',1
                DC.W KEY_FOR-TAB_STAR ; FOR
                DC.B 'N',2
                DC.W KEY_NEXT-TAB_STAR ; NEXT
                DC.B 'D',2
                DC.W KEY_DATA-TAB_STAR ; DATA
                DC.B 'I',3
                DC.W KEY_INPUT-TAB_STAR ; INPUT
                DC.B 'D',1
                DC.W KEY_DIM-TAB_STAR ; DIM
                DC.B 'R',2
                DC.W KEY_READ-TAB_STAR ; READ
                DC.B 'L',1
                DC.W KEY_LET-TAB_STAR ; LET
                DC.B 'D',1
                DC.W KEY_DEC-TAB_STAR ; DEC
                DC.B 'G',2
                DC.W KEY_GOTO-TAB_STAR ; GOTO
                DC.B 'R',1
                DC.W KEY_RUN-TAB_STAR ; RUN
                DC.B 'I',0
                DC.W KEY_IF-TAB_STAR ; IF
                DC.B 'R',5
                DC.W KEY_RESTORE-TAB_STAR ; RESTORE
                DC.B 'G',3
                DC.W KEY_GOSUB-TAB_STAR ; GOSUB
                DC.B 'R',4
                DC.W KEY_RETURN-TAB_STAR ; RETURN
                DC.B 'R',1
                DC.W KEY_REM-TAB_STAR ; REM
                DC.B 'S',2
                DC.W KEY_STOP-TAB_STAR ; STOP
                DC.B 'O',0
                DC.W KEY_ON-TAB_STAR ; ON
                DC.B 'N',2
                DC.W KEY_NULL-TAB_STAR ; NULL
                DC.B 'I',1
                DC.W KEY_INC-TAB_STAR ; INC
                DC.B 'W',2
                DC.W KEY_WAIT-TAB_STAR ; WAIT
                DC.B 'L',2
                DC.W KEY_LOAD-TAB_STAR ; LOAD
                DC.B 'S',2
                DC.W KEY_SAVE-TAB_STAR ; SAVE
                DC.B 'D',1
                DC.W KEY_DEF-TAB_STAR ; DEF
                DC.B 'P',2
                DC.W KEY_POKE-TAB_STAR ; POKE
                DC.B 'D',2
                DC.W KEY_DOKE-TAB_STAR ; DOKE
                DC.B 'L',2
                DC.W KEY_LOKE-TAB_STAR ; LOKE
                DC.B 'C',2
                DC.W KEY_CALL-TAB_STAR ; CALL
                DC.B 'D',0
                DC.W KEY_DO-TAB_STAR ; DO
                DC.B 'L',2
                DC.W KEY_LOOP-TAB_STAR ; LOOP
                DC.B 'P',3
                DC.W KEY_PRINT-TAB_STAR ; PRINT
                DC.B 'C',2
                DC.W KEY_CONT-TAB_STAR ; CONT
                DC.B 'L',2
                DC.W KEY_LIST-TAB_STAR ; LIST
                DC.B 'C',3
                DC.W KEY_CLEAR-TAB_STAR ; CLEAR
                DC.B 'N',1
                DC.W KEY_NEW-TAB_STAR ; NEW
                DC.B 'W',3
                DC.W KEY_WIDTH-TAB_STAR ; WIDTH
                DC.B 'G',1
                DC.W KEY_GET-TAB_STAR ; GET
                DC.B 'S',2
                DC.W KEY_SWAP-TAB_STAR ; SWAP
                DC.B 'B',4
                DC.W KEY_BITSET-TAB_STAR ; BITSET
                DC.B 'B',4
                DC.W KEY_BITCLR-TAB_STAR ; BITCLR
				
				dc.b 'R',5
				dc.w KEY_RPRINT-TAB_STAR ; RPRINT
				dc.b 'R',6
				dc.w KEY_RSETOBJ-TAB_STAR ; RSETOBJ
				dc.b 'R',6
				dc.w KEY_RUPDALL-TAB_STAR ; RUPDALL(
				dc.b 'R',7
				dc.w KEY_RSETLIST-TAB_STAR ; RSETLIST
				dc.b 'U',8
				dc.w KEY_U235MOD-TAB_STAR	; U235MOD(
				dc.b 'U',8
				dc.w KEY_U235SND-TAB_STAR  ; U235SND(
				dc.b 'C',1
				dc.w KEY_CLS-TAB_STAR	; CLS
				dc.b 'S',5
				dc.w KEY_SETCUR-TAB_STAR ; SETCUR(
				dc.b 'P',3
				dc.w KEY_PLOT-TAB_STAR ; PLOT(
				dc.b 'C',5
				dc.w KEY_COLOUR-TAB_STAR ; COLOUR(
				dc.b 'R',5
				dc.w KEY_RPARTI-TAB_STAR ; RPARTI(
				dc.b 'R',6
				dc.w KEY_RSETMAP-TAB_STAR ; RSETMAP(
				
                DC.B 'T',2
                DC.W KEY_TAB-TAB_STAR ; TAB(
                DC.B 'E',2
                DC.W KEY_ELSE-TAB_STAR ; ELSE
                DC.B 'T',0
                DC.W KEY_TO-TAB_STAR ; TO
                DC.B 'F',0
                DC.W KEY_FN-TAB_STAR ; FN
                DC.B 'S',2
                DC.W KEY_SPC-TAB_STAR ; SPC(
                DC.B 'T',2
                DC.W KEY_THEN-TAB_STAR ; THEN
                DC.B 'N',1
                DC.W KEY_NOT-TAB_STAR ; NOT
                DC.B 'S',2
                DC.W KEY_STEP-TAB_STAR ; STEP
                DC.B 'U',3
                DC.W KEY_UNTIL-TAB_STAR ; UNTIL
                DC.B 'W',3
                DC.W KEY_WHILE-TAB_STAR ; WHILE

                DC.B '+',-1
                DC.W KEY_PLUS-TAB_STAR ; +
                DC.B '-',-1
                DC.W KEY_MINUS-TAB_STAR ; -
                DC.B '*',-1
                DC.W KEY_MULT-TAB_STAR ; *
                DC.B '/',-1
                DC.W KEY_DIV-TAB_STAR ; /
                DC.B '^',-1
                DC.W KEY_POWER-TAB_STAR ; ^
                DC.B 'A',1
                DC.W KEY_AND-TAB_STAR ; AND
                DC.B 'E',1
                DC.W KEY_EOR-TAB_STAR ; EOR
                DC.B 'O',0
                DC.W KEY_OR-TAB_STAR ; OR
                DC.B '>',0
                DC.W KEY_RSHIFT-TAB_STAR ; >>
                DC.B '<',0
                DC.W KEY_LSHIFT-TAB_STAR ; <<
                DC.B '>',-1
                DC.W KEY_GT-TAB_STAR ; >
                DC.B '=',-1
                DC.W KEY_EQUAL-TAB_STAR ; =
                DC.B '<',-1
                DC.W KEY_LT-TAB_STAR ; <

                DC.B 'S',2
                DC.W KEY_SGN-TAB_STAR ; SGN(
                DC.B 'I',2
                DC.W KEY_INT-TAB_STAR ; INT(
                DC.B 'A',2
                DC.W KEY_ABS-TAB_STAR ; ABS(
                DC.B 'U',2
                DC.W KEY_USR-TAB_STAR ; USR(
                DC.B 'F',2
                DC.W KEY_FRE-TAB_STAR ; FRE(
                DC.B 'P',2
                DC.W KEY_POS-TAB_STAR ; POS(
                DC.B 'S',2
                DC.W KEY_SQR-TAB_STAR ; SQR(
                DC.B 'R',2
                DC.W KEY_RND-TAB_STAR ; RND(
                DC.B 'L',2
                DC.W KEY_LOG-TAB_STAR ; LOG(
                DC.B 'E',2
                DC.W KEY_EXP-TAB_STAR ; EXP(
                DC.B 'C',2
                DC.W KEY_COS-TAB_STAR ; COS(
                DC.B 'S',2
                DC.W KEY_SIN-TAB_STAR ; SIN(
                DC.B 'T',2
                DC.W KEY_TAN-TAB_STAR ; TAN(
                DC.B 'A',2
                DC.W KEY_ATN-TAB_STAR ; ATN(
                DC.B 'P',3
                DC.W KEY_PEEK-TAB_STAR ; PEEK(
                DC.B 'D',3
                DC.W KEY_DEEK-TAB_STAR ; DEEK(
                DC.B 'L',3
                DC.W KEY_LEEK-TAB_STAR ; LEEK(
                DC.B 'L',2
                DC.W KEY_LEN-TAB_STAR ; LEN(
                DC.B 'S',3
                DC.W KEY_STRS-TAB_STAR ; STR$(
                DC.B 'V',2
                DC.W KEY_VAL-TAB_STAR ; VAL(
                DC.B 'A',2
                DC.W KEY_ASC-TAB_STAR ; ASC(
                DC.B 'U',5
                DC.W KEY_UCASES-TAB_STAR ; UCASE$(
                DC.B 'L',5
                DC.W KEY_LCASES-TAB_STAR ; LCASE$(
                DC.B 'C',3
                DC.W KEY_CHRS-TAB_STAR ; CHR$(
                DC.B 'H',3
                DC.W KEY_HEXS-TAB_STAR ; HEX$(
                DC.B 'B',3
                DC.W KEY_BINS-TAB_STAR ; BIN$(
                DC.B 'B',5
                DC.W KEY_BITTST-TAB_STAR ; BITTST(
                DC.B 'M',2
                DC.W KEY_MAX-TAB_STAR ; MAX(
                DC.B 'M',2
                DC.W KEY_MIN-TAB_STAR ; MIN(
                DC.B 'R',5
                DC.W KEY_RAM-TAB_STAR ; RAMBASE
                DC.B 'P',0
                DC.W KEY_PI-TAB_STAR ; PI
                DC.B 'T',3
                DC.W KEY_TWOPI-TAB_STAR ; TWOPI
                DC.B 'V',5
                DC.W KEY_VPTR-TAB_STAR ; VARPTR(
                DC.B 'S',3
                DC.W KEY_SADD-TAB_STAR ; SADD(
                DC.B 'L',4
                DC.W KEY_LEFTS-TAB_STAR ; LEFT$(
                DC.B 'R',5
                DC.W KEY_RIGHTS-TAB_STAR ; RIGHT$(
                DC.B 'M',3
                DC.W KEY_MIDS-TAB_STAR ; MID$(
                DC.B 'U',5
                DC.W KEY_USINGS-TAB_STAR ; USING$(

				dc.b 'U',6
				dc.w KEY_U235PAD-TAB_STAR ; U235PAD(
				dc.b 'R',6
				dc.w KEY_RGETOBJ-TAB_STAR
				dc.b 'R',2
				dc.w KEY_RHIT-TAB_STAR
				dc.b 'L',5
				dc.w KEY_LOCATE-TAB_STAR

; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; BASIC error messages

LAB_BAER:
                DC.W LAB_NF-LAB_BAER ; $00 NEXT without FOR
                DC.W LAB_SN-LAB_BAER ; $02 syntax
                DC.W LAB_RG-LAB_BAER ; $04 RETURN without GOSUB
                DC.W LAB_OD-LAB_BAER ; $06 out of data
                DC.W LAB_FC-LAB_BAER ; $08 function call
                DC.W LAB_OV-LAB_BAER ; $0A overflow
                DC.W LAB_OM-LAB_BAER ; $0C out of memory
                DC.W LAB_US-LAB_BAER ; $0E undefined statement
                DC.W LAB_BS-LAB_BAER ; $10 array bounds
                DC.W LAB_DD-LAB_BAER ; $12 double dimension array
                DC.W LAB_D0-LAB_BAER ; $14 divide by 0
                DC.W LAB_ID-LAB_BAER ; $16 illegal direct
                DC.W LAB_TM-LAB_BAER ; $18 type mismatch
                DC.W LAB_LS-LAB_BAER ; $1A long string
                DC.W LAB_ST-LAB_BAER ; $1C string too complex
                DC.W LAB_CN-LAB_BAER ; $1E continue error
                DC.W LAB_UF-LAB_BAER ; $20 undefined function
                DC.W LAB_LD-LAB_BAER ; $22 LOOP without DO
                DC.W LAB_UV-LAB_BAER ; $24 undefined variable
                DC.W LAB_UA-LAB_BAER ; $26 undimensioned array
                DC.W LAB_WD-LAB_BAER ; $28 wrong dimensions
                DC.W LAB_AD-LAB_BAER ; $2A address
                DC.W LAB_FO-LAB_BAER ; $2C format

LAB_NF:         DC.B 'NEXT without FOR',$00
LAB_SN:         DC.B 'Syntax',$00
LAB_RG:         DC.B 'RETURN without GOSUB',$00
LAB_OD:         DC.B 'Out of DATA',$00
LAB_FC:         DC.B 'Function call',$00
LAB_OV:         DC.B 'Overflow',$00
LAB_OM:         DC.B 'Out of memory',$00
LAB_US:         DC.B 'Undefined statement',$00
LAB_BS:         DC.B 'Array bounds',$00
LAB_DD:         DC.B 'Double dimension',$00
LAB_D0:         DC.B 'Divide by zero',$00
LAB_ID:         DC.B 'Illegal direct',$00
LAB_TM:         DC.B 'Type mismatch',$00
LAB_LS:         DC.B 'String too long',$00
LAB_ST:         DC.B 'String too complex',$00
LAB_CN:         DC.B "Can't continue",$00
LAB_UF:         DC.B 'Undefined function',$00
LAB_LD:         DC.B 'LOOP without DO',$00
LAB_UV:         DC.B 'Undefined variable',$00
LAB_UA:         DC.B 'Undimensioned array',$00
LAB_WD:         DC.B 'Wrong dimensions',$00
LAB_AD:         DC.B 'Address',$00
LAB_FO:         DC.B 'Format',$00


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
*
; keyword table for line (un)crunching

; [keyword,token
; [keyword,token]]
; end marker (#$00)

TAB_STAR:
KEY_MULT:
                DC.B TK_MULT,$00 ; *
TAB_PLUS:
KEY_PLUS:
                DC.B TK_PLUS,$00 ; +
TAB_MNUS:
KEY_MINUS:
                DC.B TK_MINUS,$00 ; -
TAB_SLAS:
KEY_DIV:
                DC.B TK_DIV,$00 ; /
TAB_LESS:
KEY_LSHIFT:
                DC.B '<',TK_LSHIFT ; <<
KEY_LT:
                DC.B TK_LT      ; <
                DC.B $00
TAB_EQUL:
KEY_EQUAL:
                DC.B TK_EQUAL,$00 ; =
TAB_MORE:
KEY_RSHIFT:
                DC.B '>',TK_RSHIFT ; >>
KEY_GT:
                DC.B TK_GT      ; >
                DC.B $00
TAB_QEST:
                DC.B TK_PRINT,$00 ; ?
TAB_ASCA:
KEY_ABS:
                DC.B 'BS(',TK_ABS ; ABS(
KEY_AND:
                DC.B 'ND',TK_AND ; AND
KEY_ASC:
                DC.B 'SC(',TK_ASC ; ASC(
KEY_ATN:
                DC.B 'TN(',TK_ATN ; ATN(
                DC.B $00
TAB_ASCB:
KEY_BINS:
                DC.B 'IN$(',TK_BINS ; BIN$(
KEY_BITCLR:
                DC.B 'ITCLR',TK_BITCLR ; BITCLR	
 
KEY_BITSET:
                DC.B 'ITSET',TK_BITSET ; BITSET
KEY_BITTST:
                DC.B 'ITTST(',TK_BITTST ; BITTST(
                DC.B $00
TAB_ASCC:
KEY_CLS:
				dc.b 'LS',TK_CLS	; CLS
				
KEY_CALL:
                DC.B 'ALL',TK_CALL ; CALL
KEY_CHRS:
                DC.B 'HR$(',TK_CHRS ; CHR$(
KEY_CLEAR:
                DC.B 'LEAR',TK_CLEAR ; CLEAR
KEY_CONT:
                DC.B 'ONT',TK_CONT ; CONT
KEY_COS:
                DC.B 'OS(',TK_COS ; COS(
KEY_COLOUR:
				dc.b 'OLOUR(',TK_COLOUR ; COLOUR(
                DC.B $00
TAB_ASCD:
KEY_DATA:
                DC.B 'ATA',TK_DATA ; DATA
KEY_DEC:
                DC.B 'EC',TK_DEC ; DEC
KEY_DEEK:
                DC.B 'EEK(',TK_DEEK ; DEEK(
KEY_DEF:
                DC.B 'EF',TK_DEF ; DEF
KEY_DIM:
                DC.B 'IM',TK_DIM ; DIM
KEY_DOKE:
                DC.B 'OKE',TK_DOKE ; DOKE
KEY_DO:
                DC.B 'O',TK_DO  ; DO
                DC.B $00
TAB_ASCE:
KEY_ELSE:
                DC.B 'LSE',TK_ELSE ; ELSE
KEY_END:
                DC.B 'ND',TK_END ; END
KEY_EOR:
                DC.B 'OR',TK_EOR ; EOR
KEY_EXP:
                DC.B 'XP(',TK_EXP ; EXP(
                DC.B $00
TAB_ASCF:
KEY_FOR:
                DC.B 'OR',TK_FOR ; FOR
KEY_FN:
                DC.B 'N',TK_FN  ; FN
KEY_FRE:
                DC.B 'RE(',TK_FRE ; FRE(
                DC.B $00
TAB_ASCG:
KEY_GET:
                DC.B 'ET',TK_GET ; GET
KEY_GOTO:
                DC.B 'OTO',TK_GOTO ; GOTO
KEY_GOSUB:
                DC.B 'OSUB',TK_GOSUB ; GOSUB
                DC.B $00
TAB_ASCH:
KEY_HEXS:
                DC.B 'EX$(',TK_HEXS,$00 ; HEX$(
TAB_ASCI:
KEY_IF:
                DC.B 'F',TK_IF  ; IF
KEY_INC:
                DC.B 'NC',TK_INC ; INC
KEY_INPUT:
                DC.B 'NPUT',TK_INPUT ; INPUT
KEY_INT:
                DC.B 'NT(',TK_INT ; INT(
                DC.B $00
TAB_ASCL:
KEY_LCASES:
                DC.B 'CASE$(',TK_LCASES ; LCASE$(
KEY_LEEK:
                DC.B 'EEK(',TK_LEEK ; LEEK(
KEY_LEFTS:
                DC.B 'EFT$(',TK_LEFTS ; LEFT$(
KEY_LEN:
                DC.B 'EN(',TK_LEN ; LEN(
KEY_LET:
                DC.B 'ET',TK_LET ; LET
KEY_LIST:
                DC.B 'IST',TK_LIST ; LIST
KEY_LOAD:
                DC.B 'OAD',TK_LOAD ; LOAD
KEY_LOG:
                DC.B 'OG(',TK_LOG ; LOG(
KEY_LOKE:
                DC.B 'OKE',TK_LOKE ; LOKE
KEY_LOOP:
                DC.B 'OOP',TK_LOOP ; LOOP
KEY_LOCATE:
				dc.b 'OCATE(',TK_LOCATE ; LOCATE(
                DC.B $00
TAB_ASCM:
KEY_MAX:
                DC.B 'AX(',TK_MAX ; MAX(
KEY_MIDS:
                DC.B 'ID$(',TK_MIDS ; MID$(
KEY_MIN:
                DC.B 'IN(',TK_MIN ; MIN(
                DC.B $00
TAB_ASCN:
KEY_NEW:
                DC.B 'EW',TK_NEW ; NEW
KEY_NEXT:
                DC.B 'EXT',TK_NEXT ; NEXT
KEY_NOT:
                DC.B 'OT',TK_NOT ; NOT
KEY_NULL:
                DC.B 'ULL',TK_NULL ; NULL
                DC.B $00
TAB_ASCO:
KEY_ON:
                DC.B 'N',TK_ON  ; ON
KEY_OR:
                DC.B 'R',TK_OR  ; OR
                DC.B $00
TAB_ASCP:
KEY_PLOT:		
				dc.b 'LOT(',TK_PLOT ; PLOT(
KEY_PEEK:
                DC.B 'EEK(',TK_PEEK ; PEEK(
KEY_PI:
                DC.B 'I',TK_PI  ; PI
KEY_POKE:
                DC.B 'OKE',TK_POKE ; POKE
KEY_POS:
                DC.B 'OS(',TK_POS ; POS(
KEY_PRINT:
                DC.B 'RINT',TK_PRINT ; PRINT
                DC.B $00
TAB_ASCR:
KEY_RAM:
                DC.B 'AMBASE',TK_RAM ; RAMBASE
KEY_READ:
                DC.B 'EAD',TK_READ ; READ
KEY_REM:
                DC.B 'EM',TK_REM ; REM
KEY_RESTORE:
                DC.B 'ESTORE',TK_RESTORE ; RESTORE
KEY_RETURN:
                DC.B 'ETURN',TK_RETURN ; RETURN
KEY_RIGHTS:
                DC.B 'IGHT$(',TK_RIGHTS ; RIGHT$(
KEY_RND:
                DC.B 'ND(',TK_RND ; RND(
KEY_RUN:
                DC.B 'UN',TK_RUN ; RUN
KEY_RPRINT:     
				DC.B 'PRINT(',TK_RPRINT ; RPRINT
KEY_RSETOBJ:
				dc.b 'SETOBJ(',TK_RSETOBJ ; RSETOBJ(
KEY_RUPDALL:
				dc.b 'UPDALL(',TK_RUPDALL ; RUPDALL
KEY_RGETOBJ:
				dc.b 'GETOBJ(',TK_RGETOBJ ; RGETOBJ(
KEY_RSETLIST:
				dc.b 'SETLIST(',TK_RSETLIST ; RSETLIST(
KEY_RHIT:
				dc.b 'HIT(',TK_RHIT ; RHIT(
KEY_RPARTI:
				dc.b 'PARTI(',TK_RPARTI ; RPARTI(
KEY_RSETMAP:
				dc.b 'SETMAP(',TK_RSETMAP ; RSETMAP(
                DC.B $00
TAB_ASCS:
KEY_SADD:
                DC.B 'ADD(',TK_SADD ; SADD(
KEY_SAVE:
                DC.B 'AVE',TK_SAVE ; SAVE
KEY_SGN:
                DC.B 'GN(',TK_SGN ; SGN(
KEY_SIN:
                DC.B 'IN(',TK_SIN ; SIN(
KEY_SPC:
                DC.B 'PC(',TK_SPC ; SPC(
KEY_SQR:
                DC.B 'QR(',TK_SQR ; SQR(
KEY_STEP:
                DC.B 'TEP',TK_STEP ; STEP
KEY_STOP:
                DC.B 'TOP',TK_STOP ; STOP
KEY_STRS:
                DC.B 'TR$(',TK_STRS ; STR$(
KEY_SWAP:
                DC.B 'WAP',TK_SWAP ; SWAP
KEY_SETCUR:
				dc.b 'ETCUR(',TK_SETCUR ; SETCUR
                DC.B $00
TAB_ASCT:
KEY_TAB:
                DC.B 'AB(',TK_TAB ; TAB(
KEY_TAN:
                DC.B 'AN(',TK_TAN ; TAN
KEY_THEN:
                DC.B 'HEN',TK_THEN ; THEN
KEY_TO:
                DC.B 'O',TK_TO  ; TO
KEY_TWOPI:
                DC.B 'WOPI',TK_TWOPI ; TWOPI
                DC.B $00
TAB_ASCU:
KEY_U235PAD:	dc.b '235PAD(',TK_U235PAD
KEY_U235MOD:	
				dc.b '235MOD(',TK_U235MOD
KEY_U235SND:
				dc.b '235SND(',TK_U235SND
KEY_UCASES:
                DC.B 'CASE$(',TK_UCASES ; UCASE$(
KEY_UNTIL:
                DC.B 'NTIL',TK_UNTIL ; UNTIL
KEY_USINGS:
                DC.B 'SING$(',TK_USINGS ; USING$(
KEY_USR:
                DC.B 'SR(',TK_USR ; USR(
                DC.B $00
TAB_ASCV:
KEY_VAL:
                DC.B 'AL(',TK_VAL ; VAL(
KEY_VPTR:
                DC.B 'ARPTR(',TK_VPTR ; VARPTR(
                DC.B $00
TAB_ASCW:
KEY_WAIT:
                DC.B 'AIT',TK_WAIT ; WAIT
KEY_WHILE:
                DC.B 'HILE',TK_WHILE ; WHILE
KEY_WIDTH:
                DC.B 'IDTH',TK_WIDTH ; WIDTH
                DC.B $00
TAB_POWR:
KEY_POWER:
                DC.B TK_POWER,$00 ; ^


; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; *
;*
; just messages

LAB_BMSG:
                DC.B $0D,$0A,'Break',$00
LAB_EMSG:
                DC.B ' Error',$00
LAB_LMSG:
                DC.B ' in line ',$00
LAB_IMSG:
                DC.B 'Extra ignored',$0D,$0A,$00
LAB_REDO:
                DC.B 'Redo from start',$0D,$0A,$00
LAB_RMSG:
                DC.B $0D,$0A,'Ready',$0D,$0A,$00
LAB_SMSG:
                DC.B ' Bytes free',$0D,$0A,$0A
                DC.B 'Enhanced 68k BASIC Version 3.52',$0D,$0A,$00

				.even
basic_ram:
				.rept	128000
				dc.b	0
				.endr

                EVEN


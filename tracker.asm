.cpu "65816"
.include "macros_inc.asm"
.include "bank_00_inc.asm"
.include "vicky_def.asm"
.include "interrupt_def.asm"

* = HRESET
                CLC
                XCE   ; go into native mode
                SEI   ; ignore interrupts
                JML TRACKER


; Interrupt Vectors
* = VECTORS_BEGIN
JUMP_READY      JML TRACKER    ; Kernel READY routine. Rewrite this address to jump to a custom kernel.
RVECTOR_COP     .addr HCOP     ; FFE4
RVECTOR_BRK     .addr HBRK     ; FFE6
RVECTOR_ABORT   .addr HABORT   ; FFE8
RVECTOR_NMI     .addr HNMI     ; FFEA
                .word $0000    ; FFEC
RVECTOR_IRQ     .addr HIRQ     ; FFEE

RRETURN         JML TRACKER

RVECTOR_ECOP    .addr HCOP     ; FFF4
RVECTOR_EBRK    .addr HBRK     ; FFF6
RVECTOR_EABORT  .addr HABORT   ; FFF8
RVECTOR_ENMI    .addr HNMI     ; FFFA
RVECTOR_ERESET  .addr HRESET   ; FFFC
RVECTOR_EIRQ    .addr HIRQ     ; FFFE

* = $181000


.include "OPL2_library.asm"
.include "keyboard_def.asm"
.include "display.asm"
.include "Interrupt_Handler.asm" ; Interrupt Handler Routines

; Draw the screen
; Top portion is the instruments editor (left) and order list (right)
; Bottom part is the pattern editor
; we'll need to figure out how to do stereo, left- and right-only.

TRACKER
                ; Setup the Interrupt Controller
                ; For Now all Interrupt are Falling Edge Detection (IRQ)
                LDA #$FF
                STA @lINT_EDGE_REG0
                STA @lINT_EDGE_REG1
                STA @lINT_EDGE_REG2
                
                ; Mask all Interrupt @ This Point
                STA @lINT_MASK_REG0
                STA @lINT_MASK_REG1
                STA @lINT_MASK_REG2
                
                JSR DRAW_DISPLAY

                JSR LOAD_INSTRUMENTS

                ; we allow input of data via MIDI
                JSR INIT_MIDI

                ; we allow keyboard inputs 
                JSR INIT_KEYBOARD
                
                JSR INITMOUSEPOINTER

                ; enable the mouse pointer
                CLI
          
ALWAYS          NOP
                BRA ALWAYS
          

DRAW_DISPLAY
                ; set the display size - 128 x 64
                LDA #128
                STA COLS_PER_LINE
                LDA #64
                STA LINES_MAX

                ; set the visible display size - 80 x 60
                LDA #80
                STA COLS_VISIBLE
                LDA #60
                STA LINES_VISIBLE
                LDA #0
                STA BORDER_X_SIZE
                STA BORDER_Y_SIZE

                ; set the border to purple
                setas
                LDA #$20
                STA BORDER_COLOR_B
                STA BORDER_COLOR_R
                LDA #0
                STA BORDER_COLOR_G

                ; enable the border
                LDA #Border_Ctrl_Enable
                STA BORDER_CTRL_REG

                ; enable text display
                LDA #Mstr_Ctrl_Text_Mode_En + Mstr_Ctrl_Text_Overlay
                STA MASTER_CTRL_REG_L

                setal
                LDA #<>CS_TEXT_MEM_PTR      ; store the initial screen buffer location
                STA SCREENBEGIN
                setas
                LDA #`CS_TEXT_MEM_PTR
                STA SCREENBEGIN+2

                ; copy screen data from TRACKER_SCREEN to CS_TEXT_MEM_PTR
                setaxl
                LDA #128*64-1
                LDX #<>TRACKER_SCREEN
                LDY #<>CS_TEXT_MEM_PTR
                MVN #`TRACKER_SCREEN,#$AF

COPYFONT        LDA #256 * 8
                LDX #<>FNXFONT
                LDY #<>FONT_MEMORY_BANK0
                MVN #`FNXFONT,#$AF

                ; set the fg LUT to Green
                LDA #$60FF
                STA FG_CHAR_LUT_PTR + 8;
                LDA #$0080
                STA FG_CHAR_LUT_PTR + 10;

                ; set the character bg and fg color
                LDX #128*64
                setas
                LDA #$20
SETTEXTCOLOR
                STA CS_COLOR_MEM_PTR-1,X
                DEX
                BNE SETTEXTCOLOR

                RTS
          

;
;IPUTC
; Print a single character to a channel.
; Handles terminal sequences, based on the selected text mode
; Modifies: none
;
IPUTC           PHD
                PHP             ; stash the flags (we'll be changing M)
                setdp 0
                setas
                CMP #$0D        ; handle CR
                BNE iputc_bs
                JSR IPRINTCR
                bra iputc_done
iputc_bs        CMP #$08        ; backspace
                BNE iputc_print
                JSR IPRINTBS
                BRA iputc_done
iputc_print     STA [CURSORPOS] ; Save the character on the screen
                JSR ICSRRIGHT
iputc_done      
                PLP
                PLD
                RTL
                
;
; IPRINTCR
; Prints a carriage return.
; This moves the cursor to the beginning of the next line of text on the screen
; Modifies: Flags
IPRINTCR        PHX
                PHY
                PHP
                LDX #0
                LDY CURSORY
                INY
                ; JSL ILOCATE
                PLP
                PLY
                PLX
                RTS
;
; IPRINTBS
; Prints a carriage return.
; This moves the cursor to the beginning of the next line of text on the screen
; Modifies: Flags
IPRINTBS        PHX
                PHY
                PHP
                LDX CURSORX
                LDY CURSORY
                DEX
                ; JSL ILOCATE
                PLP
                PLY
                PLX
                RTS
;
;ICSRRIGHT
; Move the cursor right one space
; Modifies: none
;
ICSRRIGHT ; move the cursor right one space
                PHX
                PHB
                setal
                setxl
                setdp $0
                INC CURSORPOS
                LDX CURSORX
                INX
                CPX COLS_VISIBLE
                BCC icsr_nowrap  ; wrap if the cursor is at or past column 80
                LDX #0
                PHY
                LDY CURSORY
                INY
                ;JSL ILOCATE
                PLY
icsr_nowrap     STX CURSORX
                PHA
                TXA
                STA @lVKY_TXT_CURSOR_X_REG_L  ;Store in Vicky's register
                PLA
                PLB
                PLX
                RTS

LOAD_INSTRUMENTS
                RTS

INIT_MIDI
                RTS

INIT_KEYBOARD
                PHD
                PHP
                PHA
                PHX
                
                CLC
                setas
                LDA #$00
                STA KEYBOARD_SC_FLG     ; Clear the Keyboard Flag
                
                JSR Poll_Inbuf
                
                LDA #$AA      ;Send self test command
                STA KBD_CMD_BUF
                ;; Sent Self-Test Code and Waiting for Return value, it ought to be 0x55.
                JSR Poll_Outbuf ;

                LDA KBD_OUT_BUF   ;Check self test result
                CMP #$55
                BEQ passAAtest

                BRL initkb_loop_out

passAAtest      
;; Test AB
                LDA #$AB      ;Send test Interface command
                STA KBD_CMD_BUF

                JSR Poll_Outbuf ;

                LDA KBD_OUT_BUF   ;Display Interface test results
                CMP #$00      ;Should be 00
                BEQ passABtest

                BRL initkb_loop_out

passABtest      

                ;LDA #$A8        ; Enable Second PS2 Port
                ;STA KBD_DATA_BUF
                ;JSR Poll_Outbuf ;

;; Program the Keyboard & Enable Interrupt with Cmd 0x60
                LDA #$60            ; Send Command 0x60 so to Enable Interrupt
                STA KBD_CMD_BUF
                JSR Poll_Inbuf ;
                LDA #%01101001      ; Enable Interrupt
                ;LDA #%01001011      ; Enable Interrupt for Mouse and Keyboard
                STA KBD_DATA_BUF
                JSR Poll_Inbuf ;
                
; Reset Keyboard
                LDA #$FF      ; Send Keyboard Reset command
                STA KBD_DATA_BUF
                ; Must wait here;
                LDX #$FFFF
DLY_LOOP1       DEX
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                CPX #$0000
                BNE DLY_LOOP1
                JSR Poll_Outbuf ;

                LDA KBD_OUT_BUF   ; Read Output Buffer

DO_CMD_F4_AGAIN
                JSR Poll_Inbuf ;
                LDA #$F4      ; Enable the Keyboard
                STA KBD_DATA_BUF
                JSR Poll_Outbuf ;

                LDA KBD_OUT_BUF   ; Clear the Output buffer
                CMP #$FA
                BNE DO_CMD_F4_AGAIN
                
                ; Till We Reach this point, the Keyboard is setup Properly
                JSR INIT_MOUSE

                ; Unmask the Keyboard interrupt
                ; Clear Any Pending Interrupt
                LDA @lINT_PENDING_REG0  ; Read the Pending Register &
                AND #FNX0_INT07_MOUSE
                STA @lINT_PENDING_REG0  ; Writing it back will clear the Active Bit

                LDA @lINT_PENDING_REG1  ; Read the Pending Register &
                AND #FNX1_INT00_KBD
                STA @lINT_PENDING_REG1  ; Writing it back will clear the Active Bit
                ; Disable the Mask
                LDA @lINT_MASK_REG1
                AND #~FNX1_INT00_KBD
                STA @lINT_MASK_REG1

                LDA @lINT_MASK_REG0
                AND #~FNX0_INT07_MOUSE
                STA @lINT_MASK_REG0

initkb_loop_out 
InitSuccess     
                PLX
                PLA
                PLP
                PLD
                RTS
          
;INITMOUSEPOINTER
INITMOUSEPOINTER
                setaxl
                LDX #<>MOUSE_POINTER_PTR
                LDA #$100
                LDY #$0500
                MVN #`MOUSE_POINTER_PTR,#$AF
                
                setas
                LDA #$01
                STA @lMOUSE_PTR_CTRL_REG_L  ; Enable Mouse, Mouse Pointer Graphic Bank 0
                RTS
                
Poll_Inbuf      .as
                LDA STATUS_PORT   ; Load Status Byte
                AND #<INPT_BUF_FULL ; Test bit $02 (if 0, Empty)
                CMP #<INPT_BUF_FULL
                BEQ Poll_Inbuf
                RTS

Poll_Outbuf     .as
                LDA STATUS_PORT
                AND #OUT_BUF_FULL ; Test bit $01 (if 1, Full)
                CMP #OUT_BUF_FULL
                BNE Poll_Outbuf
                RTS

INIT_MOUSE      .as

                JSR Poll_Inbuf
                LDA #$A8          ; Enable the second PS2 Channel
                STA KBD_CMD_BUF

;                LDX #$4000
;DLY_MOUSE_LOOP  DEX
                ;CPX #$0000
                ;BNE DLY_MOUSE_LOOP
DO_CMD_A9_AGAIN
                JSR Poll_Inbuf
                LDA #$A9          ; Tests second PS2 Channel
                STA KBD_CMD_BUF
                JSR Poll_Outbuf ;
                LDA KBD_OUT_BUF   ; Clear the Output buffer
                CMP #$00
                BNE DO_CMD_A9_AGAIN
                ; IF we pass this point, the Channel is OKAY, Let's move on

                JSR Poll_Inbuf
                LDA #$20
                STA KBD_CMD_BUF
                JSR Poll_Outbuf ;

                LDA KBD_OUT_BUF
                ORA #$02
                PHA
                JSR Poll_Inbuf
                LDA #$60
                STA KBD_CMD_BUF
                JSR Poll_Inbuf ;
                PLA
                STA KBD_DATA_BUF

                LDA #$F6        ;Tell the mouse to use default settings
                JSR MOUSE_WRITE
                JSR MOUSE_READ

                ; Set the Mouse Resolution 1 Clicks for 1mm - For a 640 x 480, it needs to be the slowest
                LDA #$E8
                JSR MOUSE_WRITE
                JSR MOUSE_READ
                
                LDA #$00
                JSR MOUSE_WRITE
                JSR MOUSE_READ

                ; Set the Refresh Rate to 60
;                LDA #$F2
;                JSR MOUSE_WRITE
;                JSR MOUSE_READ
;                LDA #60
;                JSR MOUSE_WRITE
;                JSR MOUSE_READ


                LDA #$F4        ; Enable the Mouse
                JSR MOUSE_WRITE
                JSR MOUSE_READ
                
                ; Let's Clear all the Variables Necessary to Computer the Absolute Position of the Mouse
                LDA #$00
                STA MOUSE_PTR
                RTS

MOUSE_WRITE     .as
                PHA
                JSR Poll_Inbuf
                LDA #$D4
                STA KBD_CMD_BUF
                JSR Poll_Inbuf
                PLA
                STA KBD_DATA_BUF
                RTS

MOUSE_READ      .as
                JSR Poll_Outbuf ;
                LDA KBD_INPT_BUF
                RTS
